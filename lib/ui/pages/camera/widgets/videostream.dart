import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

class LocalUvcWidget extends StatefulWidget {
  final BoxFit fit;
  final bool showControls;

  /// Kalau true, UI akan crop setengah kiri (cocok untuk ZED UVC SBS)
  final bool defaultCropLeft;

  /// Kalau di Linux label device kosong sebelum permission, widget ini akan
  /// melakukan warmup stream sekali agar label muncul.
  final bool warmupForLabels;

  /// Whether to show the source toggle (ROS/USB) in the status bar
  final bool showSourceToggle;

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

  const LocalUvcWidget({
    super.key,
    this.fit = BoxFit.cover,
    this.showControls = true,
    this.defaultCropLeft = false,
    this.warmupForLabels = true,
    this.showSourceToggle = false,
    this.onSourceChanged,
    this.borderRadius = 12,
    this.showOwnBorder = true,
  });

  @override
  State<LocalUvcWidget> createState() => _LocalUvcWidgetState();
}

class _LocalUvcWidgetState extends State<LocalUvcWidget> {
  // Preferences keys
  static const _kPrefDeviceId = 'uvc_selected_device_id';
  static const _kPrefCropLeft = 'uvc_crop_left_enabled';
  static const _kPrefPreferZed = 'uvc_prefer_zed';

  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _stream;

  bool _isInitializing = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Device list
  List<MediaDeviceInfo> _videoDevices = [];
  String? _selectedDeviceId;

  // Settings
  bool _cropLeft = false;
  bool _preferZed = true;

  // Constraints
  int _idealW = 1280;
  int _idealH = 720;
  int _idealFps = 30;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _renderer.initialize();

    final prefs = await SharedPreferences.getInstance();
    _selectedDeviceId = prefs.getString(_kPrefDeviceId);
    _cropLeft = prefs.getBool(_kPrefCropLeft) ?? widget.defaultCropLeft;
    _preferZed = prefs.getBool(_kPrefPreferZed) ?? true;

    // Enumerate dulu (kadang label kosong di Linux sebelum warmup)
    await _refreshDevices();

    // Kalau deviceId tersimpan tapi udah tidak ada, reset
    if (_selectedDeviceId != null &&
        !_videoDevices.any((d) => d.deviceId == _selectedDeviceId)) {
      _selectedDeviceId = null;
    }

    // Pilih otomatis: saved > zed label > last device
    _selectedDeviceId ??= _pickBestDeviceId();

    // Start stream
    await _startStream();

    // Setelah stream jalan, label device sering baru muncul -> refresh lagi
    if (widget.warmupForLabels) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _refreshDevices();
      // Kalau preferZed dan ada zed, boleh auto-switch (optional)
      if (_preferZed) {
        final zedId = _pickZedDeviceId();
        if (zedId != null && zedId != _selectedDeviceId) {
          _selectedDeviceId = zedId;
          await _persistSelectedDevice();
          await _restartStream();
        }
      }
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _stopStream();
    _renderer.dispose();
    super.dispose();
  }

  Future<void> _persistSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedDeviceId == null) {
      await prefs.remove(_kPrefDeviceId);
    } else {
      await prefs.setString(_kPrefDeviceId, _selectedDeviceId!);
    }
  }

  Future<void> _persistCropLeft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefCropLeft, _cropLeft);
  }

  Future<void> _persistPreferZed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefPreferZed, _preferZed);
  }

  Future<void> _refreshDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final videoInputs = devices.where((d) => d.kind == 'videoinput').toList();

      if (kDebugMode) {
        for (final d in videoInputs) {
          debugPrint('VIDEO: label="${d.label}" id=${d.deviceId}');
        }
      }

      if (mounted) {
        setState(() {
          _videoDevices = videoInputs;
        });
      }
    } catch (e) {
      // Tidak fatal. Masih bisa coba start stream.
      if (kDebugMode) debugPrint('enumerateDevices error: $e');
    }
  }

  String? _pickZedDeviceId() {
    for (int i = 0; i < _videoDevices.length; i++) {
      final label = _videoDevices[i].label.toLowerCase();
      final deviceId = _videoDevices[i].deviceId.toLowerCase();

      // Match various ZED camera naming patterns
      if (label.contains('zed') ||
          label.contains('stereolabs') ||
          label.contains('svo') ||
          label.contains('sl zed') ||
          deviceId.contains('zed')) {
        if (kDebugMode) {
          debugPrint(
            '🎥 Found ZED device: label="$label" id=${_videoDevices[i].deviceId}',
          );
        }
        return _videoDevices[i].deviceId;
      }
    }
    if (kDebugMode) {
      debugPrint(
        '⚠️ No ZED device found among ${_videoDevices.length} devices',
      );
    }
    return null;
  }

  String? _pickBestDeviceId() {
    if (_videoDevices.isEmpty) return null;

    if (_preferZed) {
      final zedId = _pickZedDeviceId();
      if (zedId != null) return zedId;
    }

    // fallback: device terakhir sering = external cam
    return _videoDevices.last.deviceId;
  }

  Future<void> _startStream() async {
    try {
      setState(() {
        _isInitializing = true;
        _hasError = false;
        _errorMessage = '';
      });

      // stop stream sebelumnya kalau ada
      await _stopStream();

      if (kDebugMode) {
        debugPrint('🎬 Starting stream with deviceId: $_selectedDeviceId');
      }

      final video = <String, dynamic>{
        // kalau deviceId null, getUserMedia ambil default camera
        if (_selectedDeviceId != null) 'deviceId': _selectedDeviceId,
        'width': {'ideal': _idealW},
        'height': {'ideal': _idealH},
        'frameRate': {'ideal': _idealFps},
      };

      final constraints = <String, dynamic>{'audio': false, 'video': video};

      if (kDebugMode) {
        debugPrint('📹 Constraints: $constraints');
      }

      _stream = await navigator.mediaDevices.getUserMedia(constraints);
      _renderer.srcObject = _stream;

      // Log actual track info
      if (kDebugMode && _stream != null) {
        final tracks = _stream!.getVideoTracks();
        for (final track in tracks) {
          debugPrint('✅ Active track: label="${track.label}" id=${track.id}');
        }
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isInitializing = false;
        _errorMessage = 'Camera access failed: $e';
      });
    }
  }

  Future<void> _restartStream() async {
    await _startStream();
  }

  Future<void> _stopStream() async {
    try {
      final s = _stream;
      _stream = null;
      _renderer.srcObject = null;

      if (s != null) {
        for (final track in s.getTracks()) {
          await track.stop();
        }
        await s.dispose();
      }
    } catch (_) {
      // ignore
    }
  }

  String _deviceLabel(MediaDeviceInfo d) {
    final label = d.label.trim();
    if (label.isNotEmpty) return label;
    // Label bisa kosong di Linux sebelum permission; tampilkan deviceId pendek
    final id = d.deviceId;
    return 'Camera (${id.length > 8 ? id.substring(0, 8) : id})';
    // kalau mau lebih jelas, bisa append index di dropdown
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // REVISI: gradient gelap-navy (tema glass hitam-biru) alih-alih
        // Colors.black polos, dan radius/border sekarang bisa diatur dari
        // luar (widget.borderRadius, widget.showOwnBorder) supaya saat
        // dibungkus CameraPage lengkungannya sama persis dan tidak dobel
        // border dengan radius berbeda.
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
                  color: Colors.black.withValues(alpha: 0.30),
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
            _buildVideo(),

            if (widget.showControls)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: _buildTopControls(context),
              ),

            if (_isInitializing || _hasError)
              Container(
                color: Colors.black.withValues(alpha: 0.70),
                child: Center(child: _buildStatus()),
              ),

            // Source toggle (ROS/USB) - positioned at bottom left when enabled
            if (widget.showSourceToggle)
              Positioned(bottom: 10, left: 10, child: _buildSourceToggle()),

            Positioned(bottom: 10, right: 10, child: _buildBadge()),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_renderer.srcObject == null || !_renderer.renderVideo) {
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

    final view = RTCVideoView(
      _renderer,
      objectFit: _mapFit(widget.fit),
      mirror: false,
    );

    if (!_cropLeft) return view;

    // Crop setengah kiri untuk kasus ZED UVC output side-by-side
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 0.5,
        child: view,
      ),
    );
  }

  RTCVideoViewObjectFit _mapFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
      case BoxFit.cover:
      case BoxFit.fill:
      default:
        return RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    }
  }

  Widget _buildTopControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.usb, color: Colors.white70, size: 16),
          const SizedBox(width: 8),

          // Dropdown device
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: Colors.grey.shade900,
                value:
                    _selectedDeviceId != null &&
                        _videoDevices.any(
                          (d) => d.deviceId == _selectedDeviceId,
                        )
                    ? _selectedDeviceId
                    : null,
                hint: const Text(
                  'Select camera device',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                items: _videoDevices
                    .map(
                      (d) => DropdownMenuItem<String>(
                        value: d.deviceId,
                        child: Text(
                          _deviceLabel(d),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) async {
                  if (id == null) return;
                  setState(() => _selectedDeviceId = id);
                  await _persistSelectedDevice();
                  await _restartStream();
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Crop left toggle
          _tinyToggle(
            label: 'Left',
            value: _cropLeft,
            onTap: () async {
              setState(() => _cropLeft = !_cropLeft);
              await _persistCropLeft();
            },
          ),

          const SizedBox(width: 6),

          // Prefer ZED toggle (auto pick)
          _tinyToggle(
            label: 'ZED',
            value: _preferZed,
            onTap: () async {
              setState(() => _preferZed = !_preferZed);
              await _persistPreferZed();

              // kalau baru dinyalakan, langsung auto-pick zed kalau ada
              if (_preferZed) {
                final zedId = _pickZedDeviceId();
                if (zedId != null && zedId != _selectedDeviceId) {
                  setState(() => _selectedDeviceId = zedId);
                  await _persistSelectedDevice();
                  await _restartStream();
                }
              }
            },
          ),

          const SizedBox(width: 6),

          // Refresh devices
          IconButton(
            tooltip: 'Refresh devices',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
            onPressed: () async {
              await _refreshDevices();
              // kalau device terpilih hilang, pilih best
              if (_selectedDeviceId != null &&
                  !_videoDevices.any((d) => d.deviceId == _selectedDeviceId)) {
                _selectedDeviceId = _pickBestDeviceId();
                await _persistSelectedDevice();
                await _restartStream();
              }
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _tinyToggle({
    required String label,
    required bool value,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? Colors.green.withValues(alpha: 0.85) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    if (_isInitializing) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 14),
          Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      );
    }

    if (_hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Camera Error',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _startStream,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await _refreshDevices();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.usb),
                label: const Text('Refresh devices'),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBadge() {
    final host = (_selectedDeviceId == null)
        ? 'default'
        : (_selectedDeviceId!.length > 8
              ? _selectedDeviceId!.substring(0, 8)
              : _selectedDeviceId!);

    final text = _hasError
        ? 'Offline'
        : _isInitializing
        ? 'Connecting'
        : 'Live';

    final color = _hasError
        ? Colors.red
        : _isInitializing
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasError
                ? Icons.videocam_off
                : _isInitializing
                ? Icons.hourglass_empty
                : Icons.videocam,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '$text • $host',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build source toggle widget (ROS/USB)
  Widget _buildSourceToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSourceToggleButton(
            label: 'ROS',
            isSelected: false, // USB widget shows, so ROS is not selected
            onTap: () => widget.onSourceChanged?.call(true),
          ),
          const SizedBox(width: 4),
          _buildSourceToggleButton(
            label: 'USB',
            isSelected: true, // USB widget shows, so USB is selected
            onTap: () {}, // Already on USB
          ),
        ],
      ),
    );
  }

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
