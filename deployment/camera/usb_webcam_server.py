#!/usr/bin/env python3
"""
Simple USB Webcam MJPEG Server for Testing
==========================================

Streams USB webcam (like ZED left camera) via MJPEG over HTTP.
No CUDA required - uses standard OpenCV with V4L2.

Usage:
    python3 usb_webcam_server.py [--device 0] [--port 8080] [--width 1280] [--height 720]

For ZED Camera (left RGB only without SDK):
    python3 usb_webcam_server.py --device 0 --width 1280 --height 720

Dependencies:
    pip install opencv-python flask

Author: MEVI Dashboard Team
"""

import argparse
import cv2
from flask import Flask, Response
import threading
import time

app = Flask(__name__)

# Global variables
camera = None
output_frame = None
lock = threading.Lock()
frame_count = 0
fps = 0
last_fps_time = time.time()

def capture_frames(device_id, width, height, target_fps):
    """Capture frames from USB webcam"""
    global camera, output_frame, frame_count, fps, last_fps_time
    
    print(f"📷 Opening camera device {device_id}...")
    
    # Open camera with V4L2 backend (Linux)
    camera = cv2.VideoCapture(device_id, cv2.CAP_V4L2)
    
    if not camera.isOpened():
        # Try without V4L2 specification
        camera = cv2.VideoCapture(device_id)
    
    if not camera.isOpened():
        print(f"❌ Failed to open camera device {device_id}")
        return
    
    # Set resolution
    camera.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    camera.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
    camera.set(cv2.CAP_PROP_FPS, target_fps)
    
    # For ZED camera - set to side-by-side mode and crop left
    # ZED outputs 2560x720 (side-by-side) or 1280x720 (single)
    actual_width = int(camera.get(cv2.CAP_PROP_FRAME_WIDTH))
    actual_height = int(camera.get(cv2.CAP_PROP_FRAME_HEIGHT))
    actual_fps = camera.get(cv2.CAP_PROP_FPS)
    
    print(f"✅ Camera opened successfully!")
    print(f"   Resolution: {actual_width}x{actual_height}")
    print(f"   FPS: {actual_fps}")
    
    # Check if side-by-side (ZED default)
    is_side_by_side = actual_width > 1920  # ZED side-by-side is 2560 or wider
    
    if is_side_by_side:
        print(f"   Mode: Side-by-side detected, will crop LEFT camera")
    
    frame_interval = 1.0 / target_fps if target_fps > 0 else 0
    
    while True:
        start_time = time.time()
        
        ret, frame = camera.read()
        
        if not ret:
            print("⚠️ Failed to read frame, retrying...")
            time.sleep(0.1)
            continue
        
        # If side-by-side, crop left half (left camera)
        if is_side_by_side:
            half_width = frame.shape[1] // 2
            frame = frame[:, :half_width]
        
        # Encode frame as JPEG
        _, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        
        with lock:
            output_frame = jpeg.tobytes()
        
        # Calculate FPS
        frame_count += 1
        current_time = time.time()
        if current_time - last_fps_time >= 1.0:
            fps = frame_count
            frame_count = 0
            last_fps_time = current_time
        
        # Maintain target FPS
        elapsed = time.time() - start_time
        if frame_interval > elapsed:
            time.sleep(frame_interval - elapsed)

def generate_mjpeg():
    """Generate MJPEG stream"""
    global output_frame
    
    while True:
        with lock:
            if output_frame is None:
                continue
            frame = output_frame
        
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
        
        time.sleep(0.01)  # Small delay to prevent overwhelming

@app.route('/video_feed')
def video_feed():
    """MJPEG stream endpoint"""
    return Response(
        generate_mjpeg(),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )

@app.route('/status')
def status():
    """Status endpoint"""
    return {
        'status': 'running',
        'camera_open': camera is not None and camera.isOpened() if camera else False,
        'fps': fps
    }

@app.route('/')
def index():
    """Simple HTML page to test stream"""
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>USB Webcam Stream</title>
        <style>
            body { 
                margin: 0; 
                background: #1a1a1a; 
                display: flex; 
                justify-content: center; 
                align-items: center; 
                min-height: 100vh;
                flex-direction: column;
                font-family: system-ui;
                color: white;
            }
            img { 
                max-width: 100%; 
                border-radius: 12px;
                box-shadow: 0 4px 20px rgba(0,0,0,0.5);
            }
            h1 { margin-bottom: 20px; }
            .info { margin-top: 15px; opacity: 0.7; }
        </style>
    </head>
    <body>
        <h1>📷 USB Webcam / ZED Camera Stream</h1>
        <img src="/video_feed" alt="Camera Stream">
        <p class="info">Stream URL: <code>/video_feed</code></p>
    </body>
    </html>
    '''

def list_cameras():
    """List available camera devices"""
    print("\n🔍 Scanning for available cameras...")
    available = []
    
    for i in range(10):
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            print(f"   ✅ /dev/video{i}: {width}x{height}")
            available.append(i)
            cap.release()
    
    if not available:
        print("   ❌ No cameras found")
    
    return available

def main():
    parser = argparse.ArgumentParser(description='USB Webcam MJPEG Server')
    parser.add_argument('--device', '-d', type=int, default=0,
                        help='Camera device ID (default: 0)')
    parser.add_argument('--port', '-p', type=int, default=8080,
                        help='Server port (default: 8080)')
    parser.add_argument('--width', '-W', type=int, default=1280,
                        help='Frame width (default: 1280)')
    parser.add_argument('--height', '-H', type=int, default=720,
                        help='Frame height (default: 720)')
    parser.add_argument('--fps', '-f', type=int, default=30,
                        help='Target FPS (default: 30)')
    parser.add_argument('--list', '-l', action='store_true',
                        help='List available cameras')
    
    args = parser.parse_args()
    
    if args.list:
        list_cameras()
        return
    
    print("=" * 50)
    print("  USB Webcam / ZED Camera MJPEG Server")
    print("=" * 50)
    print(f"\n📌 Configuration:")
    print(f"   Device: /dev/video{args.device}")
    print(f"   Resolution: {args.width}x{args.height}")
    print(f"   Target FPS: {args.fps}")
    print(f"   Port: {args.port}")
    
    # Start capture thread
    capture_thread = threading.Thread(
        target=capture_frames,
        args=(args.device, args.width, args.height, args.fps),
        daemon=True
    )
    capture_thread.start()
    
    # Wait for camera to initialize
    time.sleep(1)
    
    print(f"\n🌐 Starting server...")
    print(f"   Stream URL: http://localhost:{args.port}/video_feed")
    print(f"   Status URL: http://localhost:{args.port}/status")
    print(f"   Web UI: http://localhost:{args.port}/")
    print(f"\n   Press Ctrl+C to stop\n")
    
    # Run Flask server
    app.run(host='0.0.0.0', port=args.port, threaded=True)

if __name__ == '__main__':
    main()
