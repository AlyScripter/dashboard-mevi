import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../services/data_recorder_service.dart';

class DataPageHeader extends StatefulWidget {
  final bool isConnected;

  const DataPageHeader({super.key, required this.isConnected});

  @override
  State<DataPageHeader> createState() => _DataPageHeaderState();
}

class _DataPageHeaderState extends State<DataPageHeader>
    with SingleTickerProviderStateMixin {
  final DataRecorderService _recorderService = DataRecorderService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _recorderService.initialize();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updatePulseAnimation() {
    if (_recorderService.isRecording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showRecordingOptions() {
    showDialog(
      context: context,
      builder: (context) => _RecordingOptionsDialog(
        recorderService: _recorderService,
        onModeChanged: () => setState(() {}),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_recorderService.isRecording) {
      final path = await _recorderService.stopRecording();
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording saved: ${_recorderService.currentFileName ?? "trip.csv"}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Location: $path',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } else {
      final success = await _recorderService.startRecording();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to start recording. Check storage permission.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
    _updatePulseAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _recorderService,
      builder: (context, _) {
        _updatePulseAnimation();

        return Row(
          children: [
            // Title container
            Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 255, 255, 255),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.chartBar, size: 24, color: Colors.black54),
                  SizedBox(width: 8),
                  Text(
                    'Data Visualization',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Recording control container
            Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _recorderService.isRecording
                    ? Colors.red.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _recorderService.isRecording
                      ? Colors.red.shade200
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Recording indicator with pulse animation
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _recorderService.isRecording
                                ? Colors.red
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            boxShadow: _recorderService.isRecording
                                ? [
                                    BoxShadow(
                                      color: Colors.red.withValues(
                                        alpha: 0.4 * _pulseAnimation.value,
                                      ),
                                      blurRadius: 8 * _pulseAnimation.value,
                                      spreadRadius: 2 * _pulseAnimation.value,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            _recorderService.isRecording
                                ? LucideIcons.square
                                : LucideIcons.circle,
                            size: 16,
                            color: _recorderService.isRecording
                                ? Colors.white
                                : Colors.red,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Recording info
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recorderService.isRecording ? 'REC' : 'Record',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _recorderService.isRecording
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (_recorderService.isRecording)
                        _RecordingTimer(recorderService: _recorderService)
                      else
                        Text(
                          _getModeLabel(_recorderService.mode),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),

                  if (_recorderService.isRecording) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_recorderService.recordCount}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 8),

                  // Settings button
                  GestureDetector(
                    onTap: _showRecordingOptions,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        LucideIcons.settings2,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        );
      },
    );
  }

  String _getModeLabel(RecordingMode mode) {
    switch (mode) {
      case RecordingMode.auto:
        return 'Auto (Goal)';
      case RecordingMode.manual:
        return 'Manual';
      case RecordingMode.continuous:
        return 'Continuous';
    }
  }
}

/// Timer widget that updates every second
class _RecordingTimer extends StatefulWidget {
  final DataRecorderService recorderService;

  const _RecordingTimer({required this.recorderService});

  @override
  State<_RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<_RecordingTimer> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(widget.recorderService.recordingDuration),
      style: TextStyle(
        fontSize: 10,
        fontFamily: 'monospace',
        color: Colors.red.shade600,
      ),
    );
  }
}

/// Dialog for recording options
class _RecordingOptionsDialog extends StatefulWidget {
  final DataRecorderService recorderService;
  final VoidCallback onModeChanged;

  const _RecordingOptionsDialog({
    required this.recorderService,
    required this.onModeChanged,
  });

  @override
  State<_RecordingOptionsDialog> createState() =>
      _RecordingOptionsDialogState();
}

class _RecordingOptionsDialogState extends State<_RecordingOptionsDialog> {
  late RecordingMode _selectedMode;
  late int _selectedInterval;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.recorderService.mode;
    _selectedInterval = widget.recorderService.recordingIntervalMs;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(LucideIcons.settings2, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          const Text('Recording Settings',
              style: TextStyle(fontSize: 18, color: Colors.black87)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recording Mode',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            _buildModeOption(
              RecordingMode.manual,
              'Manual',
              'Start/Stop recording via button',
              LucideIcons.hand,
            ),
            _buildModeOption(
              RecordingMode.auto,
              'Auto (Goal-based)',
              'Record when navigating to destination',
              LucideIcons.navigation,
            ),
            _buildModeOption(
              RecordingMode.continuous,
              'Continuous',
              'Record while connected to vehicle',
              LucideIcons.infinity,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Recording Rate',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _selectedInterval.toDouble(),
                    min: 50,
                    max: 500,
                    divisions: 9,
                    label:
                        '${(1000 / _selectedInterval).toStringAsFixed(0)} Hz',
                    onChanged: (value) {
                      setState(() => _selectedInterval = value.toInt());
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${(1000 / _selectedInterval).toStringAsFixed(0)} Hz',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Higher rate = more data points, larger files',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.recorderService.setMode(_selectedMode);
            widget.recorderService.setRecordingInterval(_selectedInterval);
            widget.onModeChanged();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildModeOption(
    RecordingMode mode,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.blue.shade700
                          : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                LucideIcons.circleCheck,
                size: 18,
                color: Colors.blue.shade600,
              ),
          ],
        ),
      ),
    );
  }
}
