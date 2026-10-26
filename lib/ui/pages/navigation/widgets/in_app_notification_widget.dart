import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/theme_controller.dart';

enum NotificationKind { error, warning, info, success }

/// Card popup notifikasi sederhana di tengah layar
class CenterNotificationCard extends StatelessWidget {
  final String? title;
  final String message;
  final NotificationKind kind;
  final VoidCallback? onDismiss;

  const CenterNotificationCard({
    super.key,
    this.title,
    required this.message,
    this.kind = NotificationKind.info,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark ||
            Theme.of(context).brightness == Brightness.dark;

        // Visual token berdasarkan tipe notifikasi
        Color accentColor;
        Color badgeBgColor;
        IconData iconData;

        switch (kind) {
          case NotificationKind.error:
            accentColor = const Color(0xFFEF4444);
            badgeBgColor = isDark
                ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                : const Color(0xFFFEE2E2);
            iconData = LucideIcons.circleAlert;
            break;
          case NotificationKind.warning:
            accentColor = const Color(0xFFF59E0B);
            badgeBgColor = isDark
                ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                : const Color(0xFFFEF3C7);
            iconData = LucideIcons.triangleAlert;
            break;
          case NotificationKind.success:
            accentColor = const Color(0xFF10B981);
            badgeBgColor = isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                : const Color(0xFFD1FAE5);
            iconData = LucideIcons.circleCheck;
            break;
          case NotificationKind.info:
            accentColor = const Color(0xFF0284C7);
            badgeBgColor = isDark
                ? const Color(0xFF0284C7).withValues(alpha: 0.18)
                : const Color(0xFFE0F2FE);
            final isPreview = message.toLowerCase().contains('preview') ||
                (title?.toLowerCase().contains('preview') ?? false);
            iconData = isPreview ? LucideIcons.mapPin : LucideIcons.info;
            break;
        }

        // Warna kartu sesuai tema
        final cardBg = isDark ? const Color(0xFF121622) : Colors.white;
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFE2E8F0);
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final textColor = isDark
            ? (title != null && title!.isNotEmpty
                ? Colors.white70
                : Colors.white)
            : (title != null && title!.isNotEmpty
                ? const Color(0xFF475569)
                : const Color(0xFF1E293B));
        final closeIconColor = isDark ? Colors.white38 : Colors.black38;

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isFullHD = screenWidth >= 1900;
        final maxCardWidth = isFullHD ? 420.0 : 360.0;

        return GestureDetector(
          onTap: onDismiss,
          child: Container(
            constraints: BoxConstraints(
              minWidth: 260.0,
              maxWidth: maxCardWidth,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: isDark ? 0.15 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      iconData,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                // Text Konten
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title!.isNotEmpty) ...[
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: isFullHD ? 14.5 : 13.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: isFullHD ? 13.5 : 12.5,
                          fontWeight: (title != null && title!.isNotEmpty)
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: textColor,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Tombol Tutup (X)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.x,
                        size: 14,
                        color: closeIconColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Host widget untuk animasi overlay popup di tengah layar
class _CenterNotificationOverlayHost extends StatefulWidget {
  final String? title;
  final String message;
  final NotificationKind kind;
  final Duration duration;
  final VoidCallback onRemove;

  const _CenterNotificationOverlayHost({
    this.title,
    required this.message,
    required this.kind,
    required this.duration,
    required this.onRemove,
  });

  @override
  State<_CenterNotificationOverlayHost> createState() =>
      _CenterNotificationOverlayHostState();
}

class _CenterNotificationOverlayHostState
    extends State<_CenterNotificationOverlayHost>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _timer?.cancel();
    if (!mounted) {
      widget.onRemove();
      return;
    }
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onRemove();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: CenterNotificationCard(
                title: widget.title,
                message: widget.message,
                kind: widget.kind,
                onDismiss: _dismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper publik untuk menampilkan popup card notifikasi di tengah layar
class CenterNotification {
  static OverlayEntry? _activeEntry;
  static Timer? _autoHideTimer;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    NotificationKind kind = NotificationKind.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _autoHideTimer?.cancel();
    if (_activeEntry != null) {
      if (_activeEntry!.mounted) {
        _activeEntry!.remove();
      }
      _activeEntry = null;
    }

    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _CenterNotificationOverlayHost(
        title: title,
        message: message,
        kind: kind,
        duration: duration,
        onRemove: () {
          if (_activeEntry == entry) {
            if (entry.mounted) {
              entry.remove();
            }
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _autoHideTimer?.cancel();
    if (_activeEntry != null) {
      if (_activeEntry!.mounted) {
        _activeEntry!.remove();
      }
      _activeEntry = null;
    }
  }
}

/// Widget notifikasi yang terintegrasi di dalam Stack NavigationWidget
class InAppNotificationWidget extends StatefulWidget {
  final bool showNotification;
  final String title;
  final String body;
  final VoidCallback? onDismiss;
  final bool showSearchResults;
  final NotificationKind kind;

  const InAppNotificationWidget({
    super.key,
    required this.showNotification,
    required this.title,
    required this.body,
    this.onDismiss,
    this.showSearchResults = false,
    this.kind = NotificationKind.info,
  });

  @override
  State<InAppNotificationWidget> createState() =>
      _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<InAppNotificationWidget>
    with SingleTickerProviderStateMixin {
  Timer? _autoHideTimer;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    if (widget.showNotification) {
      _animController.forward();
      _startAutoHideTimer();
    }
  }

  @override
  void didUpdateWidget(InAppNotificationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showNotification && !oldWidget.showNotification) {
      _animController.forward(from: 0.0);
      _startAutoHideTimer();
    } else if (!widget.showNotification && oldWidget.showNotification) {
      _autoHideTimer?.cancel();
      _animController.reverse();
    }
  }

  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) {
            widget.onDismiss?.call();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showSearchResults) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        if (_animController.isDismissed && !widget.showNotification) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          ignoring: !widget.showNotification,
          child: Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: CenterNotificationCard(
                    title: widget.title.isNotEmpty ? widget.title : null,
                    message: widget.body,
                    kind: widget.kind,
                    onDismiss: () {
                      _autoHideTimer?.cancel();
                      _animController.reverse().then((_) {
                        if (mounted) {
                          widget.onDismiss?.call();
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
