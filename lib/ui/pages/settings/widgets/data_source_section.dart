import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../services/data_source_service.dart';
import '../../../../services/ros_service.dart';
import '../../../../services/rosbag_player_service.dart';

/// Data Source Section for Settings Page
class DataSourceSection extends StatefulWidget {
  const DataSourceSection({super.key});

  @override
  State<DataSourceSection> createState() => _DataSourceSectionState();
}

class _DataSourceSectionState extends State<DataSourceSection> {
  final DataSourceService _dataSourceService = DataSourceService();
  final RosService _rosService = RosService();
  final RosbagPlayerService _rosbagPlayerService = RosbagPlayerService();

  // Text controllers
  final _liveIpController = TextEditingController(); // Jetson IP for ROS Bridge
  final _liveCameraIpController =
      TextEditingController(); // Camera IP for web_video_server (can be different)
  final _rosbagRosUrlController = TextEditingController();

  // Available rosbag files
  List<String> _availableRosbags = [];
  String? _selectedRosbag;
  bool _loadingRosbags = false;

  // Playback options
  bool _loopPlayback = false;
  double _playbackRate = 1.0;

  // Connection status - listen to ROS service directly
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _listenToConnectionStatus();
  }

  Future<void> _initializeService() async {
    await _dataSourceService.initialize();
    _loadSettings();
    _loadAvailableRosbags();
    // Get initial connection status
    _isConnected = _rosService.isConnected;
    // Check if rosbag is already playing
    _checkRosbagStatus();
  }

  Future<void> _checkRosbagStatus() async {
    final isPlaying = await _rosbagPlayerService.isRosbagPlaying();
    if (isPlaying && !_rosbagPlayerService.isPlaying) {
      // Rosbag is playing but service doesn't know - sync state
      setState(() {
        _showSnackBar('⚠️ Rosbag sedang berjalan dari proses sebelumnya');
      });
    }
  }

  void _listenToConnectionStatus() {
    // Listen to ROS connection stream for real-time updates
    _rosService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
        // Also update the data source service
        _dataSourceService.setConnectionStatus(connected);
      }
    });
  }

  void _loadSettings() {
    setState(() {
      // Extract IP from ROS URL for Jetson (ws://IP:9090 -> IP)
      final rosUrl = _dataSourceService.liveRosUrl;
      if (rosUrl.isNotEmpty) {
        final ip = _extractIpFromUrl(rosUrl);
        _liveIpController.text = ip;
      }

      // Load camera IP (may be different from Jetson IP)
      final cameraIp = _dataSourceService.liveCameraIp;
      if (cameraIp.isNotEmpty) {
        _liveCameraIpController.text = cameraIp;
      } else {
        // Fallback: extract from camera URL
        final cameraUrl = _dataSourceService.liveCameraUrl;
        if (cameraUrl.isNotEmpty) {
          _liveCameraIpController.text = _extractIpFromHttpUrl(cameraUrl);
        }
      }

      _rosbagRosUrlController.text = _dataSourceService.rosbagRosUrl;
      if (_dataSourceService.rosbagFile.isNotEmpty) {
        _selectedRosbag = _dataSourceService.rosbagFile.split('/').last;
      }
    });
  }

  String _extractIpFromUrl(String url) {
    // Extract IP from ws://192.168.1.100:9090 -> 192.168.1.100
    final regex = RegExp(r'ws://([^:]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }

  String _extractIpFromHttpUrl(String url) {
    // Extract IP from http://192.168.1.100:8080/... -> 192.168.1.100
    final regex = RegExp(r'http://([^:]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }

  Future<void> _loadAvailableRosbags() async {
    setState(() => _loadingRosbags = true);
    try {
      final files = await _rosbagPlayerService.listRosbagFiles();
      setState(() {
        _availableRosbags = files;
        _loadingRosbags = false;
      });
    } catch (e) {
      setState(() => _loadingRosbags = false);
    }
  }

  @override
  void dispose() {
    _liveIpController.dispose();
    _liveCameraIpController.dispose();
    _rosbagRosUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dataSourceService,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 16),

              // Status Badge
              _buildStatusBadge(),
              const SizedBox(height: 18),

              // Mode Selection
              _buildSectionLabel('CONNECTION MODE'),
              const SizedBox(height: 10),
              _buildModeSelector(),
              const SizedBox(height: 18),

              // Mode-specific settings
              if (_dataSourceService.mode == DataSourceMode.live)
                _buildLiveSettings()
              else
                _buildRosbagSettings(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            LucideIcons.database,
            size: 18,
            color: Colors.blue.shade600,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Data Source',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        _buildReconnectButton(),
      ],
    );
  }

  Widget _buildReconnectButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _reconnect,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.refreshCw,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Reconnect',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    // Use local _isConnected which is synced with RosService
    final isConnected = _isConnected || _rosService.isConnected;
    final isLive = _dataSourceService.mode == DataSourceMode.live;
    final isRosbagPlaying = _rosbagPlayerService.isPlaying;

    // Determine status text and color
    String statusText;
    Color statusColor;
    Color bgColor;
    Color borderColor;

    if (isConnected) {
      statusText = 'Connected';
      statusColor = Colors.green.shade600;
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
    } else {
      statusText = 'Disconnected';
      statusColor = Colors.orange.shade600;
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Animated connection indicator
          _AnimatedConnectionDot(isConnected: isConnected),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dataSourceService.modeDisplayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 11, color: statusColor),
                    ),
                    if (!isLive && isRosbagPlaying) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '▶ Playing',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            isLive ? LucideIcons.car : LucideIcons.circlePlay,
            size: 20,
            color: statusColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade400,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeOption(
            mode: DataSourceMode.live,
            icon: LucideIcons.car,
            title: 'Live',
            subtitle: 'Vehicle Stream',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildModeOption(
            mode: DataSourceMode.rosbag,
            icon: LucideIcons.circlePlay,
            title: 'Rosbag',
            subtitle: 'Playback',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required DataSourceMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _dataSourceService.mode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setMode(mode),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? color : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? color.withValues(alpha: 0.7)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(LucideIcons.check, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('LIVE CONNECTION'),
        const SizedBox(height: 10),

        // Quick IP presets
        _buildQuickIpPresets(),
        const SizedBox(height: 10),

        // Jetson IP input field (for ROS Bridge - vehicle data)
        _buildCompactTextField(
          controller: _liveIpController,
          label: 'Jetson IP (ROS Bridge)',
          hint: '192.168.1.101',
          icon: LucideIcons.server,
        ),
        const SizedBox(height: 8),

        // Camera IP input field (for web_video_server - ZED 2i)
        _buildCompactTextField(
          controller: _liveCameraIpController,
          label: 'Camera IP (ZED 2i / Laptop)',
          hint: '192.168.1.100',
          icon: LucideIcons.camera,
        ),
        const SizedBox(height: 8),

        // Display generated URLs
        _buildGeneratedUrlsInfo(),
        const SizedBox(height: 14),

        _buildTipCard(
          'Jetson IP untuk ROS Bridge (data sensor, navigasi). Camera IP untuk web_video_server (ZED 2i). Bisa dari device berbeda!',
          Colors.blue,
        ),
        const SizedBox(height: 14),

        _buildSaveButton(onSave: _saveLiveSettings),
      ],
    );
  }

  Widget _buildGeneratedUrlsInfo() {
    final jetsonIp = _liveIpController.text.trim();
    final cameraIp = _liveCameraIpController.text.trim();
    final hasJetsonIp = jetsonIp.isNotEmpty;
    final hasCameraIp = cameraIp.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.info, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Generated URLs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildUrlRow(
            'ROS Bridge (Jetson)',
            hasJetsonIp ? 'ws://$jetsonIp:9090' : 'ws://[Jetson IP]:9090',
            LucideIcons.globe,
          ),
          const SizedBox(height: 4),
          _buildUrlRow(
            'Camera (Laptop)',
            hasCameraIp
                ? 'http://$cameraIp:8080/stream?topic=/zed/...'
                : 'http://[Camera IP]:8080/stream?topic=...',
            LucideIcons.camera,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlRow(String label, String url, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            url,
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade700,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickIpPresets() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.zap, size: 12, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Text(
                'Quick Presets',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetChip('Laptop (192.168.1.100)', '192.168.1.100'),
              _buildPresetChip('MEVI Car (192.168.4.1)', '192.168.4.1'),
              _buildPresetChip('Local (localhost)', 'localhost'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String ip) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _liveIpController.text = ip;
          });
          _showSnackBar('Preset applied: $label');
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.wifi, size: 10, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRosbagSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('ROSBAG PLAYBACK'),
        const SizedBox(height: 10),

        _buildCompactTextField(
          controller: _rosbagRosUrlController,
          label: 'Local ROS Bridge',
          hint: 'ws://localhost:9090',
          icon: LucideIcons.globe,
          hintColor: Colors.grey.shade400,
        ),
        const SizedBox(height: 10),

        // Rosbag file dropdown
        _buildRosbagDropdown(),
        const SizedBox(height: 14),

        // Playback options
        _buildPlaybackOptions(),
        const SizedBox(height: 14),

        // Playback controls with real Docker integration
        _buildPlaybackControlsNew(),
        const SizedBox(height: 14),

        _buildTipCard(
          'Camera stream otomatis dari web_video_server. Pastikan Docker running.',
          Colors.purple,
        ),
        const SizedBox(height: 14),

        _buildSaveButton(onSave: _saveRosbagSettings),
      ],
    );
  }

  Widget _buildRosbagDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Rosbag File',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            // Upload button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _uploadRosbagToContainer,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.upload,
                        size: 14,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Upload',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Refresh button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loadAvailableRosbags,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _loadingRosbags
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : Icon(
                          LucideIcons.refreshCw,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.file, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: _availableRosbags.isEmpty
                    ? Text(
                        _loadingRosbags
                            ? 'Loading...'
                            : 'No rosbags found (is Docker running?)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _availableRosbags.contains(_selectedRosbag)
                              ? _selectedRosbag
                              : null,
                          hint: Text(
                            'Select rosbag file...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          items: _availableRosbags.map((file) {
                            return DropdownMenuItem(
                              value: file,
                              child: Text(
                                file,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedRosbag = value);
                            if (value != null) {
                              _dataSourceService.setRosbagSettings(
                                rosbagFile: value,
                              );
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackOptions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLAYBACK OPTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Loop checkbox
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _loopPlayback = !_loopPlayback),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _loopPlayback
                          ? Colors.purple.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _loopPlayback
                            ? Colors.purple.shade300
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _loopPlayback ? LucideIcons.squareCheck : LucideIcons.square,
                          size: 16,
                          color: _loopPlayback
                              ? Colors.purple.shade600
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loop',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _loopPlayback
                                ? Colors.purple.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Playback rate
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.gauge,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Speed:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            isExpanded: true,
                            value: _playbackRate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 0.25,
                                child: Text('0.25x'),
                              ),
                              DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                              DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                              DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                              DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _playbackRate = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControlsNew() {
    return ListenableBuilder(
      listenable: _rosbagPlayerService,
      builder: (context, _) {
        final isPlaying = _rosbagPlayerService.isPlaying;
        final isLoading = _rosbagPlayerService.isLoading;
        final statusMessage = _rosbagPlayerService.statusMessage;
        final hasRosbag =
            _selectedRosbag != null && _selectedRosbag!.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPlaying ? Colors.green.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPlaying ? Colors.green.shade200 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? Colors.green.shade100
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPlaying ? LucideIcons.play : LucideIcons.circlePlay,
                      size: 18,
                      color: isPlaying
                          ? Colors.green.shade700
                          : Colors.purple.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPlaying ? 'Now Playing' : 'Playback Control',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isPlaying
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (statusMessage.isNotEmpty)
                          Text(
                            statusMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Play/Stop buttons
                  if (isLoading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.purple.shade400,
                      ),
                    )
                  else ...[
                    _buildControlButton(
                      icon: isPlaying ? LucideIcons.pause : LucideIcons.play,
                      label: isPlaying ? 'Pause' : 'Play',
                      color: isPlaying ? Colors.orange : Colors.green,
                      onTap: hasRosbag ? _handlePlayPause : null,
                    ),
                    const SizedBox(width: 8),
                    _buildControlButton(
                      icon: LucideIcons.square,
                      label: 'Stop',
                      color: Colors.red,
                      onTap: isPlaying ? _handleStop : null,
                    ),
                  ],
                ],
              ),
              if (!hasRosbag && !isPlaying)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '↑ Select a rosbag file first',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isEnabled ? color : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePlayPause() async {
    if (_rosbagPlayerService.isPlaying) {
      await _rosbagPlayerService.stop();
    } else {
      if (_selectedRosbag == null || _selectedRosbag!.isEmpty) {
        _showSnackBar('Please select a rosbag file first');
        return;
      }

      final success = await _rosbagPlayerService.play(
        rosbagFile: _selectedRosbag!,
        loop: _loopPlayback,
        rate: _playbackRate,
      );

      if (success) {
        _showSnackBar('Playing: $_selectedRosbag');
      } else {
        _showSnackBar('Failed: ${_rosbagPlayerService.lastError}');
      }
    }
  }

  Future<void> _handleStop() async {
    await _rosbagPlayerService.stop();
    _showSnackBar('Playback stopped');
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color? hintColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: hintColor ?? Colors.grey.shade400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(icon, size: 16, color: Colors.grey.shade500),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFilePicker({
    required String label,
    required String value,
    required IconData icon,
    required List<String> extensions,
    required Function(String) onPicked,
  }) {
    final hasValue = value.isNotEmpty;
    final fileName = hasValue ? value.split('/').last : 'Select file...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Text field for manual path input
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: TextEditingController(text: value),
                  onChanged: (text) {
                    if (text.isNotEmpty) {
                      onPicked(text);
                    }
                  },
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: hasValue ? fileName : '/path/to/file...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(icon, size: 16, color: Colors.grey.shade500),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.blue.shade400,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Browse button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pickFile(extensions, onPicked),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.folderOpen,
                        size: 14,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Browse',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTipCard(String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.lightbulb,
            size: 14,
            color: color.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton({required VoidCallback onSave}) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.save, size: 14),
            SizedBox(width: 6),
            Text(
              'Save & Apply',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Actions
  Future<void> _setMode(DataSourceMode mode) async {
    // Disconnect first for clean switch
    _rosService.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));

    await _dataSourceService.setMode(mode);
    _reconnect();
  }

  void _reconnect() {
    // Ensure clean disconnect before reconnecting
    _rosService.disconnect();
    Future.delayed(const Duration(milliseconds: 300), () {
      _rosService.reconnect(_dataSourceService.currentRosUrl);
    });
  }

  Future<void> _saveLiveSettings() async {
    // Validate IPs
    final jetsonIp = _liveIpController.text.trim();
    final cameraIp = _liveCameraIpController.text.trim();

    if (jetsonIp.isEmpty) {
      _showSnackBar('⚠️ Please enter Jetson IP address');
      return;
    }

    if (cameraIp.isEmpty) {
      _showSnackBar('⚠️ Please enter Camera IP address');
      return;
    }

    // Generate URLs from separate IPs
    final rosUrl = 'ws://$jetsonIp:9090';

    await _dataSourceService.setLiveUrls(rosUrl: rosUrl, cameraIp: cameraIp);

    if (_dataSourceService.mode == DataSourceMode.live) {
      _showSnackBar('Reconnecting to Jetson ($jetsonIp)...');
      _reconnect();
      await Future.delayed(const Duration(seconds: 2));
      if (_rosService.isConnected) {
        _showSnackBar('✅ Connected! ROS: $jetsonIp, Camera: $cameraIp');
      } else {
        _showSnackBar('⚠️ Connection failed. Check Jetson IP and port.');
      }
    } else {
      _showSnackBar('Live settings saved');
    }
  }

  Future<void> _saveRosbagSettings() async {
    // Validate URL
    final rosUrl = _rosbagRosUrlController.text.trim();

    if (rosUrl.isEmpty || !rosUrl.startsWith('ws://')) {
      _showSnackBar('⚠️ Invalid ROS URL. Must start with ws://');
      return;
    }

    await _dataSourceService.setRosbagSettings(rosUrl: rosUrl);

    if (_dataSourceService.mode == DataSourceMode.rosbag) {
      _showSnackBar('Reconnecting to $rosUrl...');
      _reconnect();
      await Future.delayed(const Duration(seconds: 2));
      if (_rosService.isConnected) {
        _showSnackBar('✅ Connected successfully!');
      } else {
        _showSnackBar('⚠️ Connection failed. Check if rosbridge is running.');
      }
    } else {
      _showSnackBar('Rosbag settings saved');
    }
  }

  Future<void> _pickFile(
    List<String> extensions,
    Function(String) onPicked,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        dialogTitle: 'Select File',
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          onPicked(path);
        }
      }
    } catch (e) {
      _showSnackBar('Error selecting file: $e');
    }
  }

  /// Upload rosbag file to Docker container
  Future<void> _uploadRosbagToContainer() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bag'],
        dialogTitle: 'Select Rosbag File to Upload',
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          // Show loading
          _showSnackBar('Uploading rosbag to container...');

          final success = await _rosbagPlayerService.copyRosbagToContainer(
            path,
          );

          if (success) {
            _showSnackBar('✅ Rosbag uploaded successfully!');
            // Reload the list
            await _loadAvailableRosbags();
            // Select the newly uploaded file
            final filename = path.split('/').last;
            setState(() => _selectedRosbag = filename);
            _dataSourceService.setRosbagSettings(rosbagFile: filename);
          } else {
            _showSnackBar(
              '❌ Failed to upload: ${_rosbagPlayerService.lastError}',
            );
          }
        }
      }
    } catch (e) {
      _showSnackBar('Error uploading file: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Animated connection dot with pulse effect when connected
class _AnimatedConnectionDot extends StatefulWidget {
  final bool isConnected;

  const _AnimatedConnectionDot({required this.isConnected});

  @override
  State<_AnimatedConnectionDot> createState() => _AnimatedConnectionDotState();
}

class _AnimatedConnectionDotState extends State<_AnimatedConnectionDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isConnected) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedConnectionDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected != oldWidget.isConnected) {
      if (widget.isConnected) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isConnected
                ? Colors.green.shade500
                : Colors.orange.shade500,
            boxShadow: widget.isConnected
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(
                        alpha: _animation.value * 0.5,
                      ),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
