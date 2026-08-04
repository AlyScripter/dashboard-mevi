import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum NotificationKind { error, info, success }

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

class _InAppNotificationWidgetState extends State<InAppNotificationWidget> {
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.showNotification) {
      _startAutoHideTimer();
    }
  }

  @override
  void didUpdateWidget(InAppNotificationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showNotification && !oldWidget.showNotification) {
      _startAutoHideTimer();
    } else if (!widget.showNotification) {
      _autoHideTimer?.cancel();
    }
  }

  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showSearchResults && widget.showNotification) {
      // Apple-style notification colors
      Color iconBgColor;
      Color accentColor;
      switch (widget.kind) {
        case NotificationKind.error:
          iconBgColor = const Color(0xFFFF3B30); // Apple red
          accentColor = const Color(0xFFFF3B30);
          break;
        case NotificationKind.success:
          iconBgColor = const Color(0xFF34C759); // Apple green
          accentColor = const Color(0xFF34C759);
          break;
        case NotificationKind.info:
          iconBgColor = const Color(0xFF007AFF); // Apple blue
          accentColor = const Color(0xFF007AFF);
          break;
      }

      // Responsive sizing
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final isFullHD = screenWidth >= 1900 && screenHeight >= 1000;

      final notifWidth = isFullHD ? 400.0 : 340.0;
      final notifTop = isFullHD ? 110.0 : 95.0;
      final titleSize = isFullHD ? 16.0 : 14.0;
      final bodySize = isFullHD ? 14.0 : 13.0;
      final iconBoxSize = isFullHD ? 44.0 : 38.0;
      final iconSize = isFullHD ? 22.0 : 18.0;

      return Positioned(
        top: notifTop,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap: () {
              widget.onDismiss?.call();
            },
            child: Container(
              width: notifWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon with accent color
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: iconBgColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.car,
                        color: accentColor,
                        size: iconSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title & body
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.body,
                          style: TextStyle(
                            fontSize: bodySize,
                            color: Colors.grey.shade600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dismiss hint
                  Icon(
                    LucideIcons.x,
                    size: 16,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
