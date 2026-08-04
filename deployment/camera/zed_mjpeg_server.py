#!/usr/bin/env python3
"""
ZED Camera MJPEG Streaming Server for MEVI Dashboard
=====================================================

Streams ZED Camera video as MJPEG over HTTP for Flutter dashboard.
Optimized for low latency and bandwidth efficiency.

Requirements:
    pip install flask opencv-python pyzed

Usage:
    python3 zed_mjpeg_server.py

Configuration:
    - Resolution: VGA (672x376) for streaming efficiency
    - FPS: 30
    - JPEG Quality: 70% (adjustable)
    - Port: 8080

Dashboard .env:
    ZED_CAMERA_URL=http://<JETSON_IP>:8080/video_feed
"""

import cv2
import time
import argparse
import threading
from flask import Flask, Response, jsonify

# Try to import ZED SDK
try:
    import pyzed.sl as sl
    ZED_AVAILABLE = True
except ImportError:
    ZED_AVAILABLE = False
    print("⚠️  ZED SDK not found. Running in simulation mode with test pattern.")

app = Flask(__name__)

# Configuration
CONFIG = {
    'resolution': 'VGA',  # VGA, HD720, HD1080, HD2K
    'fps': 30,
    'jpeg_quality': 70,
    'port': 8080,
    'host': '0.0.0.0'
}

# Global variables
camera = None
current_frame = None
frame_lock = threading.Lock()
is_running = True
stats = {
    'frames_sent': 0,
    'fps': 0,
    'resolution': '',
    'status': 'initializing'
}


def get_zed_resolution(res_str):
    """Convert resolution string to ZED SDK resolution enum"""
    if not ZED_AVAILABLE:
        return None
    resolutions = {
        'VGA': sl.RESOLUTION.VGA,      # 672x376
        'HD720': sl.RESOLUTION.HD720,  # 1280x720
        'HD1080': sl.RESOLUTION.HD1080, # 1920x1080
        'HD2K': sl.RESOLUTION.HD2K     # 2208x1242
    }
    return resolutions.get(res_str, sl.RESOLUTION.VGA)


def init_zed_camera():
    """Initialize ZED Camera"""
    global camera, stats
    
    if not ZED_AVAILABLE:
        stats['status'] = 'simulation'
        stats['resolution'] = '640x480 (simulated)'
        return True
    
    camera = sl.Camera()
    
    init_params = sl.InitParameters()
    init_params.camera_resolution = get_zed_resolution(CONFIG['resolution'])
    init_params.camera_fps = CONFIG['fps']
    init_params.depth_mode = sl.DEPTH_MODE.NONE  # Disable depth for streaming
    init_params.coordinate_units = sl.UNIT.METER
    
    status = camera.open(init_params)
    
    if status != sl.ERROR_CODE.SUCCESS:
        print(f"❌ Failed to open ZED Camera: {status}")
        stats['status'] = f'error: {status}'
        return False
    
    # Get actual resolution
    cam_info = camera.get_camera_information()
    res = cam_info.camera_configuration.resolution
    stats['resolution'] = f'{res.width}x{res.height}'
    stats['status'] = 'running'
    
    print(f"✅ ZED Camera initialized: {stats['resolution']} @ {CONFIG['fps']} FPS")
    return True


def generate_test_frame():
    """Generate a test frame when ZED is not available"""
    import numpy as np
    
    # Create test pattern
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    
    # Add grid pattern
    for i in range(0, 640, 40):
        cv2.line(frame, (i, 0), (i, 480), (40, 40, 40), 1)
    for i in range(0, 480, 40):
        cv2.line(frame, (0, i), (640, i), (40, 40, 40), 1)
    
    # Add center cross
    cv2.line(frame, (320, 0), (320, 480), (0, 100, 0), 2)
    cv2.line(frame, (0, 240), (640, 240), (0, 100, 0), 2)
    
    # Add text
    cv2.putText(frame, 'ZED Camera Simulation', (150, 200),
                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
    cv2.putText(frame, f'Time: {time.strftime("%H:%M:%S")}', (220, 260),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (200, 200, 200), 1)
    cv2.putText(frame, 'Connect ZED Camera to see live feed', (120, 320),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (100, 100, 100), 1)
    
    return frame


def capture_thread():
    """Background thread to capture frames from ZED Camera"""
    global current_frame, is_running, stats
    
    if ZED_AVAILABLE and camera is not None:
        image = sl.Mat()
    
    frame_count = 0
    last_fps_time = time.time()
    
    while is_running:
        try:
            if ZED_AVAILABLE and camera is not None:
                if camera.grab() == sl.ERROR_CODE.SUCCESS:
                    camera.retrieve_image(image, sl.VIEW.LEFT)
                    frame = image.get_data()
                    # Convert BGRA to BGR
                    frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
                else:
                    time.sleep(0.01)
                    continue
            else:
                # Simulation mode
                frame = generate_test_frame()
                time.sleep(1.0 / CONFIG['fps'])  # Simulate FPS
            
            # Encode to JPEG
            _, buffer = cv2.imencode(
                '.jpg', 
                frame, 
                [cv2.IMWRITE_JPEG_QUALITY, CONFIG['jpeg_quality']]
            )
            
            with frame_lock:
                current_frame = buffer.tobytes()
            
            # Update FPS stats
            frame_count += 1
            elapsed = time.time() - last_fps_time
            if elapsed >= 1.0:
                stats['fps'] = round(frame_count / elapsed, 1)
                stats['frames_sent'] += frame_count
                frame_count = 0
                last_fps_time = time.time()
                
        except Exception as e:
            print(f"⚠️  Capture error: {e}")
            time.sleep(0.1)


def generate_mjpeg():
    """Generator for MJPEG stream"""
    while True:
        with frame_lock:
            if current_frame is not None:
                frame_data = current_frame
            else:
                time.sleep(0.01)
                continue
        
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_data + b'\r\n')


@app.route('/video_feed')
def video_feed():
    """MJPEG stream endpoint"""
    return Response(
        generate_mjpeg(),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )


@app.route('/snapshot')
def snapshot():
    """Single frame snapshot endpoint"""
    with frame_lock:
        if current_frame is not None:
            return Response(current_frame, mimetype='image/jpeg')
    return Response('No frame available', status=503)


@app.route('/status')
def status():
    """Camera status endpoint"""
    return jsonify({
        'camera': 'ZED' if ZED_AVAILABLE else 'Simulated',
        'status': stats['status'],
        'resolution': stats['resolution'],
        'fps': stats['fps'],
        'frames_sent': stats['frames_sent'],
        'jpeg_quality': CONFIG['jpeg_quality']
    })


@app.route('/')
def index():
    """Simple HTML page for testing"""
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>ZED Camera Stream - MEVI Dashboard</title>
        <style>
            body { 
                background: #1a1a1a; 
                color: white; 
                font-family: Arial, sans-serif;
                text-align: center;
                padding: 20px;
            }
            img { 
                max-width: 100%; 
                border: 2px solid #333;
                border-radius: 8px;
            }
            .info { 
                margin: 20px; 
                padding: 10px;
                background: #333;
                border-radius: 8px;
                display: inline-block;
            }
        </style>
    </head>
    <body>
        <h1>🎥 ZED Camera Stream</h1>
        <img src="/video_feed" alt="ZED Camera Feed">
        <div class="info">
            <p>Endpoints:</p>
            <ul style="text-align: left;">
                <li><a href="/video_feed" style="color: #4CAF50;">/video_feed</a> - MJPEG Stream</li>
                <li><a href="/snapshot" style="color: #4CAF50;">/snapshot</a> - Single Frame</li>
                <li><a href="/status" style="color: #4CAF50;">/status</a> - Camera Status</li>
            </ul>
        </div>
    </body>
    </html>
    '''


def main():
    global is_running
    
    parser = argparse.ArgumentParser(description='ZED Camera MJPEG Server for MEVI Dashboard')
    parser.add_argument('--port', type=int, default=8080, help='Server port (default: 8080)')
    parser.add_argument('--resolution', choices=['VGA', 'HD720', 'HD1080', 'HD2K'], 
                       default='VGA', help='Camera resolution (default: VGA)')
    parser.add_argument('--fps', type=int, default=30, help='Target FPS (default: 30)')
    parser.add_argument('--quality', type=int, default=70, help='JPEG quality 1-100 (default: 70)')
    args = parser.parse_args()
    
    CONFIG['port'] = args.port
    CONFIG['resolution'] = args.resolution
    CONFIG['fps'] = args.fps
    CONFIG['jpeg_quality'] = args.quality
    
    print("=" * 50)
    print("🎥 ZED Camera MJPEG Server for MEVI Dashboard")
    print("=" * 50)
    print(f"   Resolution: {CONFIG['resolution']}")
    print(f"   FPS: {CONFIG['fps']}")
    print(f"   JPEG Quality: {CONFIG['jpeg_quality']}%")
    print(f"   Port: {CONFIG['port']}")
    print("=" * 50)
    
    if not init_zed_camera():
        if not ZED_AVAILABLE:
            print("⚠️  Running in simulation mode (ZED SDK not installed)")
        else:
            print("❌ Failed to initialize ZED Camera")
            return
    
    # Start capture thread
    capture = threading.Thread(target=capture_thread, daemon=True)
    capture.start()
    
    print(f"\n🚀 Server starting at http://0.0.0.0:{CONFIG['port']}")
    print(f"   Stream URL: http://<YOUR_IP>:{CONFIG['port']}/video_feed")
    print("\nPress Ctrl+C to stop\n")
    
    try:
        app.run(
            host=CONFIG['host'], 
            port=CONFIG['port'], 
            threaded=True,
            debug=False
        )
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")
    finally:
        is_running = False
        if ZED_AVAILABLE and camera is not None:
            camera.close()


if __name__ == '__main__':
    main()
