import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dashboardmevi/services/data_source_service.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

class ZedCameraStreamWidget extends StatefulWidget {
  final String? streamUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// ROS image topic yang mau distream (left RGB)
  final String rosImageTopic;

  /// Port web_video_server di Jetson
  final int webVideoPort;

  /// Whether to show the source toggle (ROS/USB) in the status bar
  final bool showSourceToggle;

  /// Whether this widget is currently the ROS source (for toggle display)
  final bool isRosSource;

  /// Callback when source is changed (true = ROS, false = USB)
  final ValueChanged<bool>? onSourceChanged;

  /// Corner radius used for this widget's own clip + border. Override this
  /// when embedding inside another rounded frame (e.g. CameraPage) so the
  /// radii match exactly and the border doesn't look "cut off" at corners.
  final double borderRadius;

  /// Whether this widget draws its own outer border/shadow. Set to false
  /// when a parent container (e.g. CameraPage's outer frame) already draws
  /// a border, to avoid a double/mismatched border.
  final bool showOwnBorder;

  const ZedCameraStreamWidget({
    super.key,
    this.streamUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.rosImageTopic = '/zed/zed_node/left/image_rect_color',
    this.webVideoPort = 8080,
    this.showSourceToggle = false,
    this.isRosSource = true,
    this.onSourceChanged,
    this.borderRadius = 12,
    this.showOwnBorder = true,
  });

  @override
  State<ZedCameraStreamWidget> createState() => _ZedCameraStreamWidgetState();
}

class _ZedCameraStreamWidgetState extends State<ZedCameraStreamWidget> {
  final DataSourceService _dataSourceService = DataSourceService();

  // Track if initialization has started to prevent double-init
  bool _hasInitialized = false;

  Uint8List? _currentFrame;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _errorMessage = '';
  int _fps = 0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  StreamSubscription? _streamSubscription;
  http.Client? _httpClient;
  String? _lastUsedUrl;

  // ============================================================
  // URL Helpers
  // ============================================================

  /// Normalisasi input:
  /// - kalau user kasih IP saja: "192.168.1.106" -> http://192.168.1.106:8080/stream?topic=...
  /// - kalau user kasih URL lama: http://ip:8080/video_feed -> jadi http://ip:8080/stream?topic=...
  /// - kalau user kasih URL web_video_server langsung: tetap dipakai
  String _buildRosMjpegUrl(String raw) {
    raw = raw.trim();
    if (raw.isEmpty) {
      return _defaultRosMjpegUrl('localhost');
    }

    // Kalau user cuma ngasih IP tanpa skema
    if (!raw.contains('://')) {
      return _defaultRosMjpegUrl(raw);
    }

    Uri uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      // fallback: treat as host
      return _defaultRosMjpegUrl(raw);
    }

    // Kalau sudah web_video_server endpoint (/stream atau /stream_viewer)
    if (uri.path.contains('/stream')) {
      // Build URL manually to avoid double-encoding
      final topic = uri.queryParameters['topic'] ?? widget.rosImageTopic;
      final type = uri.queryParameters['type'] ?? 'mjpeg';
      final transport = uri.queryParameters['default_transport'] ?? 'raw';
      return '${uri.scheme}://${uri.host}:${uri.port}${uri.path}?topic=$topic&type=$type&default_transport=$transport';
    }

    final host = uri.host.isNotEmpty ? uri.host : raw;
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';

    // Build URL manually to avoid encoding slashes in topic name
    return '$scheme://$host:${widget.webVideoPort}/stream?topic=${widget.rosImageTopic}&type=mjpeg&default_transport=raw';
  }

  String _defaultRosMjpegUrl(String host) {
    if (host == 'localhost') {
      host = '127.0.0.1';
    }
    // Build URL manually to avoid encoding slashes in topic name
    return 'http://$host:${widget.webVideoPort}/stream?topic=${widget.rosImageTopic}&type=mjpeg&default_transport=raw';
  }

  // ============================================================
  // Lifecycle

  @override
  void initState() {
    super.initState();

    if (_hasInitialized) {
      print('⚠️ ZED WIDGET: Already initialized, skipping');
      return;
    }

    _hasInitialized = true;
    print('==================== ZED WIDGET INIT ====================');
    print('Widget created, preparing to initialize...');
    print('=========================================================');
    // Set initial URL before adding listener to prevent false "URL changed" events
    _lastUsedUrl = _streamUrl;
    _initializeService();
  }

  Future<void> _initializeService() async {
    print('📱 Initializing DataSourceService...');

    try {
      await _dataSourceService.initialize();
      print('📱 DataSourceService initialized');

      if (!mounted) {
        print('⚠️ Widget unmounted after DataSourceService init');
        return;
      }

      _dataSourceService.addListener(_onDataSourceChanged);
      print('📱 Listener added to DataSourceService');
      print('📱 Starting connection to stream...');
      print('📱 Stream URL will be: $_streamUrl');

      // Small delay to ensure widget is fully mounted
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        _connectToStream();
      } else {
        print('⚠️ Widget unmounted before connectToStream');
      }
    } catch (e) {
      print('❌ Error initializing DataSourceService: $e');
    }
  }

  void _onDataSourceChanged() {
    if (!mounted) return;
    final currentUrl = _streamUrl;
    // Only reconnect if URL actually changed
    if (currentUrl != _lastUsedUrl) {
      debugPrint('Camera URL changed: $_lastUsedUrl -> $currentUrl');
      _connectToStream();
    }
  }

  @override
  void dispose() {
    _dataSourceService.removeListener(_onDataSourceChanged);
    _streamSubscription?.cancel();
    _snapshotTimer?.cancel();
    _watchdogTimer?.cancel();
    _httpClient?.close();
    super.dispose();
  }

  // ============================================================
  // Stream Connect + Parse
  // ============================================================

  // Snapshot polling variables
  Timer? _snapshotTimer;
  Timer? _watchdogTimer;
  bool _useSnapshotPolling = false;

  Future<void> _connectToStream() async {
    print('🔵 _connectToStream() called');
    final url = _streamUrl;
    print('🔵 URL retrieved: $url');

    // Skip if already connecting or connected to the same URL
    if (_isConnecting) {
      print('⚠️ Skipping: already connecting in progress');
      return;
    }

    if (_isConnected && _lastUsedUrl == url) {
      print('⚠️ Skipping: already connected to same URL');
      return;
    }

    print('🔵 Proceeding with connection...');
    _lastUsedUrl = url;

    // Reset everything
    print('🔵 Resetting previous connections...');
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _httpClient?.close();
    _httpClient = http.Client();
    _useSnapshotPolling = false; // Try stream first

    print('🔵 Checking mounted state: $mounted');
    if (!mounted) {
      print('⚠️ Widget not mounted, aborting');
      return;
    }

    print('🔵 Setting state to connecting...');
    setState(() {
      _isConnecting = true;
      _isConnected = false;
      _errorMessage = '';
      _currentFrame = null;
      _fps = 0;
      _frameCount = 0;
      _lastFpsUpdate = DateTime.now();
    });
    print('🔵 State updated, isConnecting=$_isConnecting');

    try {
      print('🎥 Connecting to ROS MJPEG: $url');

      // Attempt MJPEG stream connection
      print('🔵 Creating HTTP request...');
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Connection'] = 'keep-alive';
      request.headers['Cache-Control'] = 'no-cache';
      print('🔵 Sending request to $url...');
      print('🔵 Request headers: ${request.headers}');

      final response = await _httpClient!
          .send(request)
          .timeout(
            const Duration(seconds: 5), // Increased timeout
            onTimeout: () {
              print('❌ Request timed out after 5 seconds');
              throw TimeoutException('Stream connection timed out');
            },
          );

      print('📡 Response received!');
      print('📡 Response status: ${response.statusCode}');
      print('📋 Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        print('✅ HTTP 200 OK received');
        if (!mounted) {
          print('⚠️ Widget unmounted, aborting');
          return;
        }
        print('🔵 Setting state to connected...');
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
        print(
          '✅ State updated: connected=$_isConnected, connecting=$_isConnecting',
        );

        print('✅ Connected! Starting stream processing...');
        _processMjpegStream(response.stream);
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Stream connection failed to $url: $e');

      // Smart Fallback: If we failed to connect to a remote IP, try localhost
      // This handles the case where user has a saved IP but is running local docker
      final uri = Uri.parse(url);
      if (uri.host != 'localhost' && uri.host != '127.0.0.1') {
        debugPrint('🔄 Attempting fallback to localhost...');
        final fallbackUrl = uri.replace(host: 'localhost').toString();
        // Recursive call with fallback URL (ensure we don't loop infinitely)
        if (_lastUsedUrl != fallbackUrl) {
          _streamUrlOverride = fallbackUrl; // Temporary override
          _connectToStream();
          return;
        }
      }

      debugPrint('⚠️ Switching to Snapshot Polling.');
      // Auto-fallback to snapshot polling
      if (mounted) {
        _startSnapshotPolling();
      }
    }
  }

  // Temporary override for fallback
  String? _streamUrlOverride;

  String get _streamUrl {
    if (_streamUrlOverride != null) return _streamUrlOverride!;

    // Priority: widget.streamUrl > DataSourceService > default
    final fromWidget = widget.streamUrl;
    if (fromWidget != null && fromWidget.isNotEmpty) {
      return _buildRosMjpegUrl(fromWidget);
    }

    final cameraUrl = _dataSourceService.currentCameraUrl;
    if (cameraUrl != null && cameraUrl.isNotEmpty) {
      return _buildRosMjpegUrl(cameraUrl);
    }

    // Default to localhost for Docker/local development
    // Change to 192.168.1.100 for Jetson in production
    return _defaultRosMjpegUrl('localhost');
  }

  void _processMjpegStream(Stream<List<int>> stream) {
    List<int> buffer = [];
    bool foundStart = false;
    DateTime? lastFrameTime; // Changed to nullable
    int bytesReceived = 0;
    int totalFrames = 0;

    // Watchdog timer - only triggers after first frame received
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_isConnected || _useSnapshotPolling) {
        timer.cancel();
        return;
      }

      // Only check stall AFTER we've received at least one frame
      if (lastFrameTime != null &&
          DateTime.now().difference(lastFrameTime!).inSeconds > 5) {
        debugPrint(
          '⚠️ Stream stalled (no frames for 5s). Switching to Snapshot Polling.',
        );
        timer.cancel();
        _startSnapshotPolling();
      }
    });

    _streamSubscription = stream.listen(
      (data) {
        bytesReceived += data.length;
        debugPrint(
          '📦 Received ${data.length} bytes (total: $bytesReceived bytes, frames: $totalFrames)',
        );

        lastFrameTime = DateTime.now();
        buffer.addAll(data);

        while (buffer.length > 2) {
          // Find JPEG start marker (0xFF 0xD8)
          if (!foundStart) {
            int startIndex = -1;
            for (int i = 0; i < buffer.length - 1; i++) {
              if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
                startIndex = i;
                break;
              }
            }
            if (startIndex == -1) {
              // No start marker found yet
              if (buffer.length > 2000000) {
                debugPrint(
                  '⚠️ Buffer overflow without JPEG start marker! Clearing buffer.',
                );
                buffer.clear();
              }
              break;
            }

            if (startIndex > 0) {
              debugPrint(
                '🔍 Found JPEG start at index $startIndex (skipped ${startIndex} bytes)',
              );
            }
            buffer = buffer.sublist(startIndex);
            foundStart = true;
          }

          // Find JPEG end marker (0xFF 0xD9)
          int endIndex = -1;
          for (int i = 0; i < buffer.length - 1; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
              endIndex = i + 2;
              break;
            }
          }
          if (endIndex == -1) {
            // No end marker yet, wait for more data
            if (buffer.length > 2000000) {
              debugPrint('⚠️ Buffer overflow looking for JPEG end! Resetting.');
              buffer.clear();
              foundStart = false;
            }
            break;
          }

          // Extract complete JPEG frame
          final frameData = Uint8List.fromList(buffer.sublist(0, endIndex));
          buffer = buffer.sublist(endIndex);
          foundStart = false;
          totalFrames++;

          debugPrint(
            '🖼️ Complete frame #$totalFrames extracted (${frameData.length} bytes)',
          );

          if (mounted) {
            setState(() => _currentFrame = frameData);
            _updateFps();
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Stream error: $error. Switching to polling.');
        if (mounted) _startSnapshotPolling();
      },
      onDone: () {
        debugPrint('⚠️ Stream ended. Switching to polling.');
        if (mounted) _startSnapshotPolling();
      },
      cancelOnError: true,
    );
  }

  // Fallback: Poll /snapshot endpoint
  void _startSnapshotPolling() {
    if (_useSnapshotPolling) return; // Already polling

    _streamSubscription?.cancel();
    _streamSubscription = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    if (!mounted) return;
    setState(() {
      _useSnapshotPolling = true;
      _isConnecting = false;
      _isConnected = true;
    });

    // Construct snapshot URL (replace /stream with /snapshot)
    final streamUrl = Uri.parse(_streamUrl);
    final snapshotUrl = streamUrl.replace(path: '/snapshot').toString();
    debugPrint('📸 Starting Snapshot Polling: $snapshotUrl');

    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final response = await http
            .get(Uri.parse(snapshotUrl))
            .timeout(const Duration(seconds: 1));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() => _currentFrame = response.bodyBytes);
            _updateFps();
          }
        }
      } catch (e) {
        // Ignore single failures in polling
      }
    });
  }

  void _updateFps() {
    _frameCount++;
    final now = DateTime.now();
    final diff = now.difference(_lastFpsUpdate);

    if (diff.inMilliseconds >= 1000) {
      if (mounted) {
        setState(() {
          _fps = (_frameCount * 1000 / diff.inMilliseconds).round();
        });
      }
      _frameCount = 0;
      _lastFpsUpdate = now;
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        // REVISI: dulu polos Colors.black — sekarang disamakan dengan
        // tema "glass hitam-biru" panel kiri (gradient gelap navy).
        // Border/shadow sekarang opsional (showOwnBorder) dan radiusnya
        // memakai widget.borderRadius, supaya saat dibungkus frame lain
        // (CameraPage) radiusnya bisa disamakan persis dan tidak dobel
        // border dengan lengkungan yang berbeda ("putus" di sudut).
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.showOwnBorder
            ? Border.all(
                color: AppColors.glassBlueBorder.withValues(alpha: 0.55),
                width: 1.2,
              )
            : null,
        boxShadow: widget.showOwnBorder
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoContent(),

            if (_isConnecting || (!_isConnected && _errorMessage.isNotEmpty))
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(child: _buildStatusWidget()),
              ),

            // Combined status badge: [ROS/USB Toggle] • ZED • Status • FPS
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Source toggle (ROS/USB) - only show if enabled
                    if (widget.showSourceToggle) ...[
                      _buildSourceToggleButton(
                        label: 'ROS',
                        isSelected: widget.isRosSource,
                        onTap: () => widget.onSourceChanged?.call(true),
                      ),
                      const SizedBox(width: 4),
                      _buildSourceToggleButton(
                        label: 'USB',
                        isSelected: !widget.isRosSource,
                        onTap: () => widget.onSourceChanged?.call(false),
                      ),
                      // Separator after toggle
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 1,
                        height: 12,
                        color: Colors.white24,
                      ),
                    ],
                    // Status indicator dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // FPS (if connected)
                    if (_isConnected && _fps > 0) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 1,
                        height: 12,
                        color: Colors.white24,
                      ),
                      Text(
                        '$_fps FPS',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  Uri.parse(_streamUrl).host,
                  style: const TextStyle(
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
    if (_currentFrame != null && _isConnected) {
      return Image.memory(
        _currentFrame!,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    // REVISI: dulu Colors.grey.shade900 polos — sekarang gradient
    // gelap-navy yang sama dengan panel kiri, ikon & aksen biru neon,
    // supaya konsisten dengan tema "glass hitam-biru" dashboard.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12161F), Color(0xFF0A0D13)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off,
              size: 64,
              color: AppColors.glassBlueBorder.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 8),
            Text(
              'No signal',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget() {
    if (_isConnecting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connecting to ZED (ROS)...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _streamUrl,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
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
            'ZED Stream Error',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'URL: $_streamUrl',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _connectToStream,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor() {
    if (_isConnecting) return Colors.orange;
    if (_isConnected) return Colors.green;
    return Colors.red;
  }

  IconData _getStatusIcon() {
    if (_isConnecting) return Icons.hourglass_empty;
    if (_isConnected) return Icons.videocam;
    return Icons.videocam_off;
  }

  String _getStatusText() {
    if (_isConnecting) return 'Connecting';
    if (_isConnected) return 'Live';
    return 'Offline';
  }

  /// Build a source toggle button (ROS/USB)
  Widget _buildSourceToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
