import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Local Webcam Widget using WebRTC
/// Menampilkan stream dari webcam lokal untuk development/testing
///
/// Menggunakan flutter_webrtc untuk cross-platform webcam access
class LocalWebcamWidget extends StatefulWidget {
  final BoxFit fit;
  final double? width;
  final double? height;

  const LocalWebcamWidget({
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<LocalWebcamWidget> createState() => _LocalWebcamWidgetState();
}

class _LocalWebcamWidgetState extends State<LocalWebcamWidget> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isInitialized = false;
  bool _isConnecting = true;
  String _errorMessage = '';
  final int _fps = 0;
  final int _frameCount = 0;
  final DateTime _lastFpsUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isConnecting = true;
      _isInitialized = false;
      _errorMessage = '';
    });

    try {
      // Initialize renderer
      await _localRenderer.initialize();

      // Get webcam stream
      final mediaConstraints = {
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      if (mounted) {
        setState(() {
          _localRenderer.srcObject = _localStream;
          _isInitialized = true;
          _isConnecting = false;
        });
      }

      print('Local webcam initialized successfully');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isInitialized = false;
          _errorMessage = 'Camera initialization failed: ${e.toString()}';
        });
      }
      print('Error accessing camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video content
            _buildVideoContent(),

            // Status overlay (loading/error)
            if (_isConnecting || (!_isInitialized && _errorMessage.isNotEmpty))
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(child: _buildStatusWidget()),
              ),

            // Camera info overlay (top-left)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, size: 16, color: Colors.white70),
                    SizedBox(width: 6),
                    Text(
                      'Local Webcam',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status indicator (top-right)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(), size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // WebRTC info (bottom-right)
            if (_isInitialized)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'WebRTC',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_localRenderer.renderVideo && _isInitialized) {
      return RTCVideoView(
        _localRenderer,
        objectFit: widget.fit == BoxFit.cover
            ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
            : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      );
    }

    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(Icons.videocam_off, size: 64, color: Colors.grey),
      ),
    );
  }

  Widget _buildStatusWidget() {
    if (_isConnecting) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Initializing Webcam...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Webcam Error',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeCamera,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor() {
    if (_isConnecting) return Colors.orange;
    if (_isInitialized) return Colors.green;
    return Colors.red;
  }

  IconData _getStatusIcon() {
    if (_isConnecting) return Icons.hourglass_empty;
    if (_isInitialized) return Icons.videocam;
    return Icons.videocam_off;
  }

  String _getStatusText() {
    if (_isConnecting) return 'Connecting';
    if (_isInitialized) return 'Live';
    return 'Offline';
  }
}
