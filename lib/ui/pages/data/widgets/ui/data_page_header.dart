import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../services/data_recorder_service.dart';
import '../../../../../core/theme/colors.dart';

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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return ListenableBuilder(
      listenable: _recorderService,
      builder: (context, _) {
        _updatePulseAnimation();

        // ── Card Styles (Edaca style) ──
        final cardBg = isLight ? Colors.white : AppColors.glassNavyTint;
        final cardBorder = isLight
            ? const Color(0xFFE2E8F0)
            : AppColors.glassBlueBorder.withValues(alpha: 0.65);
        final cardShadow = isLight
            ? const Color(0x0A0F172A)
            : Colors.black.withValues(alpha: 0.35);

        // Record states
        final isRecording = _recorderService.isRecording;
        final recBg = isRecording
            ? (isLight ? const Color(0xFFFEF2F2) : const Color(0xFF2A0E10))
            : cardBg;
        final recBorder = isRecording
            ? (isLight
                ? const Color(0xFFFCA5A5)
                : Colors.redAccent.withValues(alpha: 0.85))
            : cardBorder;

        return Row(
          children: [
            // ── Widget "Data Visualization" ────────────────────────────────
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: cardShadow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFEFF6FF)
                          : const Color(0x1A7DB4FF),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      LucideIcons.chartBar,
                      size: 19,
                      color: isLight
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF7DB4FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Data Visualization',
                        style: TextStyle(
                          fontSize: 14.0,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isLight
                              ? const Color(0xFF0F172A)
                              : AppColors.glassTextPrimary,
                        ),
                      ),
                      Text(
                        'Telemetry & Analytics',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                          color: isLight
                              ? const Color(0xFF64748B)
                              : AppColors.glassTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Widget "Record" ────────────────────────────────────────────
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: recBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: recBorder, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: cardShadow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                            color: isRecording
                                ? const Color(0xFFDC2626)
                                : (isLight
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0x1AFF5252)),
                            shape: BoxShape.circle,
                            boxShadow: isRecording
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withValues(
                                        alpha: 0.4 * _pulseAnimation.value,
                                      ),
                                      blurRadius: 8 * _pulseAnimation.value,
                                      spreadRadius: 2 * _pulseAnimation.value,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isRecording
                                ? LucideIcons.square
                                : LucideIcons.circle,
                            size: 15,
                            color: isRecording
                                ? Colors.white
                                : const Color(0xFFDC2626),
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
                        isRecording ? 'RECORDING' : 'Record',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isRecording
                              ? const Color(0xFFDC2626)
                              : (isLight
                                  ? const Color(0xFF0F172A)
                                  : AppColors.glassTextPrimary),
                        ),
                      ),
                      if (isRecording)
                        _RecordingTimer(recorderService: _recorderService)
                      else
                        Text(
                          _getModeLabel(_recorderService.mode),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: isLight
                                ? const Color(0xFF64748B)
                                : AppColors.glassTextSecondary,
                          ),
                        ),
                    ],
                  ),

                  if (isRecording) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_recorderService.recordCount}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 10),

                  // Settings button
                  GestureDetector(
                    onTap: _showRecordingOptions,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isLight
                            ? const Color(0xFFF1F5F9)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isLight
                              ? const Color(0xFFE2E8F0)
                              : AppColors.glassBlueBorder.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.slidersHorizontal,
                        size: 14,
                        color: isLight
                            ? const Color(0xFF475569)
                            : AppColors.glassTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    // REVISI: light mode → dialog "Recording Settings" pakai style
    // terang (putih, border abu-abu tipis, teks navy gelap) senada
    // dengan komponen lain di light mode, bukan lagi navy glass gelap.
    final dialogBg = isLight ? Colors.white : AppColors.glassSurface;
    final dialogBorder = isLight
        ? const Color(0xFFDDE3EC)
        : AppColors.glassBlueBorder.withValues(alpha: 0.5);
    final accentClr = isLight
        ? const Color(0xFF1565C0)
        : AppColors.glassBlueBorder;
    final titleTextClr = isLight
        ? const Color(0xFF1A2331)
        : AppColors.glassTextPrimary;
    final secondaryTextClr = isLight
        ? const Color(0xFF5B6472)
        : AppColors.glassTextSecondary;
    final dividerClr = isLight
        ? const Color(0xFFE3E7EE)
        : AppColors.glassDivider;
    final unselectedOptionBg = isLight
        ? const Color(0xFFF5F7FA)
        : AppColors.glassSurfaceAlt;
    final unselectedOptionBorder = isLight
        ? const Color(0xFFE3E7EE)
        : AppColors.glassDivider;
    final unselectedIconBoxBg = isLight
        ? const Color(0xFF1A2331).withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.06);

    // Blue-black glass dialog — dark navy surface + neon blue accents,
    // matching the rest of the cockpit theme instead of the old plain
    // white AlertDialog.
    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dialogBorder, width: 1.2),
      ),
      title: Row(
        children: [
          Icon(LucideIcons.settings2, size: 20, color: accentClr),
          const SizedBox(width: 8),
          Text(
            'Recording Settings',
            style: TextStyle(fontSize: 18, color: titleTextClr),
          ),
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
                color: secondaryTextClr,
              ),
            ),
            const SizedBox(height: 8),
            _buildModeOption(
              RecordingMode.manual,
              'Manual',
              'Start/Stop recording via button',
              LucideIcons.hand,
              isLight: isLight,
              accentClr: accentClr,
              titleTextClr: titleTextClr,
              secondaryTextClr: secondaryTextClr,
              unselectedOptionBg: unselectedOptionBg,
              unselectedOptionBorder: unselectedOptionBorder,
              unselectedIconBoxBg: unselectedIconBoxBg,
            ),
            _buildModeOption(
              RecordingMode.auto,
              'Auto (Goal-based)',
              'Record when navigating to destination',
              LucideIcons.navigation,
              isLight: isLight,
              accentClr: accentClr,
              titleTextClr: titleTextClr,
              secondaryTextClr: secondaryTextClr,
              unselectedOptionBg: unselectedOptionBg,
              unselectedOptionBorder: unselectedOptionBorder,
              unselectedIconBoxBg: unselectedIconBoxBg,
            ),
            _buildModeOption(
              RecordingMode.continuous,
              'Continuous',
              'Record while connected to vehicle',
              LucideIcons.infinity,
              isLight: isLight,
              accentClr: accentClr,
              titleTextClr: titleTextClr,
              secondaryTextClr: secondaryTextClr,
              unselectedOptionBg: unselectedOptionBg,
              unselectedOptionBorder: unselectedOptionBorder,
              unselectedIconBoxBg: unselectedIconBoxBg,
            ),
            const SizedBox(height: 16),
            Divider(color: dividerClr),
            const SizedBox(height: 12),
            Text(
              'Recording Rate',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryTextClr,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentClr,
                      inactiveTrackColor: dividerClr,
                      thumbColor: accentClr,
                      overlayColor: accentClr.withValues(alpha: 0.2),
                    ),
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
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${(1000 / _selectedInterval).toStringAsFixed(0)} Hz',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: titleTextClr,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Higher rate = more data points, larger files',
              style: TextStyle(fontSize: 10, color: secondaryTextClr),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: secondaryTextClr)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.recorderService.setMode(_selectedMode);
            widget.recorderService.setRecordingInterval(_selectedInterval);
            widget.onModeChanged();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: accentClr,
            foregroundColor: isLight ? Colors.white : Colors.black,
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
    IconData icon, {
    required bool isLight,
    required Color accentClr,
    required Color titleTextClr,
    required Color secondaryTextClr,
    required Color unselectedOptionBg,
    required Color unselectedOptionBorder,
    required Color unselectedIconBoxBg,
  }) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentClr.withValues(alpha: 0.12)
              : unselectedOptionBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentClr : unselectedOptionBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentClr.withValues(alpha: 0.18)
                    : unselectedIconBoxBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? accentClr : secondaryTextClr,
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
                      color: isSelected ? accentClr : titleTextClr,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: secondaryTextClr),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.circleCheck, size: 18, color: accentClr),
          ],
        ),
      ),
    );
  }
}
