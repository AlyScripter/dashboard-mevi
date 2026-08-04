import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/data_source_service.dart';
import '../../../services/ros_service.dart';

/// Compact Data Source Settings Widget for Left Panel
/// Switch between Live (Vehicle) and Rosbag modes
class DataSourceSettingsWidget extends StatefulWidget {
  const DataSourceSettingsWidget({super.key});

  @override
  State<DataSourceSettingsWidget> createState() =>
      _DataSourceSettingsWidgetState();
}

class _DataSourceSettingsWidgetState extends State<DataSourceSettingsWidget> {
  final DataSourceService _dataSourceService = DataSourceService();
  final RosService _rosService = RosService();
  bool _isExpanded = false;

  // Text controllers for URLs
  final _liveRosUrlController = TextEditingController();
  final _liveCameraUrlController = TextEditingController();
  final _rosbagRosUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _dataSourceService.initialize();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _liveRosUrlController.text = _dataSourceService.liveRosUrl;
      _liveCameraUrlController.text = _dataSourceService.liveCameraUrl;
      _rosbagRosUrlController.text = _dataSourceService.rosbagRosUrl;
    });
  }

  @override
  void dispose() {
    _liveRosUrlController.dispose();
    _liveCameraUrlController.dispose();
    _rosbagRosUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dataSourceService,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - always visible
              _buildHeader(),
              // Expandable content
              if (_isExpanded) ...[
                const Divider(height: 1),
                _buildExpandedContent(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final isLive = _dataSourceService.mode == DataSourceMode.live;
    final isConnected = _dataSourceService.isConnected;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Mode icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isLive ? Colors.blue.shade50 : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isLive ? LucideIcons.car : LucideIcons.circlePlay,
                size: 20,
                color: isLive ? Colors.blue.shade700 : Colors.purple.shade700,
              ),
            ),
            const SizedBox(width: 12),
            // Mode info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dataSourceService.modeDisplayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Expand/collapse icon
            Icon(
              _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 18,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode toggle
          _buildModeToggle(),
          const SizedBox(height: 16),

          // Mode-specific settings
          if (_dataSourceService.mode == DataSourceMode.live)
            _buildLiveSettings()
          else
            _buildRosbagSettings(),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Row(
      children: [
        Expanded(
          child: _buildModeButton(
            mode: DataSourceMode.live,
            icon: LucideIcons.car,
            label: 'Live',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeButton(
            mode: DataSourceMode.rosbag,
            icon: LucideIcons.circlePlay,
            label: 'Rosbag',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required DataSourceMode mode,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _dataSourceService.mode == mode;

    return InkWell(
      onTap: () => _setMode(mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Live Connection'),
        const SizedBox(height: 8),
        _buildCompactTextField(
          controller: _liveRosUrlController,
          label: 'ROS Bridge URL',
          hint: 'ws://192.168.1.100:9090',
          icon: LucideIcons.globe,
        ),
        const SizedBox(height: 8),
        _buildCompactTextField(
          controller: _liveCameraUrlController,
          label: 'Camera IP/URL',
          hint: '192.168.1.100 (web_video_server)',
          icon: LucideIcons.camera,
        ),
        const SizedBox(height: 12),
        _buildActionButtons(onSave: _saveLiveSettings),
      ],
    );
  }

  Widget _buildRosbagSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Rosbag Playback'),
        const SizedBox(height: 8),

        _buildCompactTextField(
          controller: _rosbagRosUrlController,
          label: 'Local ROS Bridge',
          hint: 'ws://localhost:9090',
          icon: LucideIcons.globe,
        ),
        const SizedBox(height: 8),

        // Rosbag file picker
        _buildFilePicker(
          label: 'Rosbag File',
          value: _dataSourceService.rosbagFile,
          icon: LucideIcons.file,
          extensions: ['bag'],
          onPicked: (path) =>
              _dataSourceService.setRosbagSettings(rosbagFile: path),
        ),
        const SizedBox(height: 8),

        // Video file picker
        _buildFilePicker(
          label: 'Video File (Optional)',
          value: _dataSourceService.videoFile,
          icon: LucideIcons.video,
          extensions: ['mp4', 'avi', 'mkv', 'mov'],
          onPicked: (path) =>
              _dataSourceService.setRosbagSettings(videoFile: path),
        ),
        const SizedBox(height: 12),

        // Playback controls
        _buildPlaybackControls(),
        const SizedBox(height: 12),

        // Info
        _buildInfoBox(),
        const SizedBox(height: 12),

        _buildActionButtons(onSave: _saveRosbagSettings),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              prefixIcon: Icon(icon, size: 14),
              prefixIconConstraints: const BoxConstraints(minWidth: 32),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePicker({
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
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _pickFile(extensions, onPicked),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 11,
                      color: hasValue ? Colors.black87 : Colors.grey.shade400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  LucideIcons.folderOpen,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    final isPlaying = _dataSourceService.isRosbagPlaying;
    final hasRosbag = _dataSourceService.rosbagFile.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.circlePlay,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Playback',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
              // Play/Pause button
              _buildIconButton(
                icon: isPlaying ? LucideIcons.pause : LucideIcons.play,
                color: Colors.purple,
                onTap: hasRosbag ? _togglePlayback : null,
                tooltip: isPlaying ? 'Pause' : 'Play',
              ),
              const SizedBox(width: 4),
              // Stop button
              _buildIconButton(
                icon: LucideIcons.square,
                color: Colors.grey,
                onTap: hasRosbag ? _stopPlayback : null,
                tooltip: 'Stop',
              ),
            ],
          ),
          if (isPlaying) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _dataSourceService.rosbagProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(Colors.purple.shade400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:
                isEnabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isEnabled ? color : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 14, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Run in terminal:\n'
              '1. roscore\n'
              '2. roslaunch rosbridge_server rosbridge_websocket.launch\n'
              '3. rosbag play <file> --clock',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({required VoidCallback onSave}) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _reconnect,
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Reconnect', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(LucideIcons.save, size: 14),
            label: const Text('Save', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // Actions
  Future<void> _setMode(DataSourceMode mode) async {
    await _dataSourceService.setMode(mode);
    _reconnect();
  }

  void _reconnect() {
    _rosService.reconnect(_dataSourceService.currentRosUrl);
  }

  Future<void> _saveLiveSettings() async {
    await _dataSourceService.setLiveUrls(
      rosUrl: _liveRosUrlController.text,
      cameraUrl: _liveCameraUrlController.text,
    );
    if (_dataSourceService.mode == DataSourceMode.live) {
      _reconnect();
    }
    _showSnackBar('Live settings saved');
  }

  Future<void> _saveRosbagSettings() async {
    await _dataSourceService.setRosbagSettings(
      rosUrl: _rosbagRosUrlController.text,
    );
    if (_dataSourceService.mode == DataSourceMode.rosbag) {
      _reconnect();
    }
    _showSnackBar('Rosbag settings saved');
  }

  Future<void> _pickFile(
      List<String> extensions, Function(String) onPicked) async {
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

  void _togglePlayback() {
    final isPlaying = _dataSourceService.isRosbagPlaying;
    _dataSourceService.setRosbagPlaybackState(playing: !isPlaying);

    if (!isPlaying) {
      _startRosbagPlayback();
    } else {
      _pauseRosbagPlayback();
    }
  }

  void _stopPlayback() {
    _dataSourceService.setRosbagPlaybackState(playing: false, progress: 0);
    _stopRosbagPlayback();
  }

  void _startRosbagPlayback() async {
    final rosbagFile = _dataSourceService.rosbagFile;
    if (rosbagFile.isEmpty) {
      _showSnackBar('Please select a rosbag file first');
      return;
    }

    // Check if file exists
    if (!File(rosbagFile).existsSync()) {
      _showSnackBar('Rosbag file not found');
      return;
    }

    // The actual rosbag playback would be handled externally
    // This just updates the UI state
    _showSnackBar(
        'Starting rosbag playback...\nRun: rosbag play $rosbagFile --clock');
  }

  void _pauseRosbagPlayback() {
    _showSnackBar('Playback paused');
  }

  void _stopRosbagPlayback() {
    _showSnackBar('Playback stopped');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
