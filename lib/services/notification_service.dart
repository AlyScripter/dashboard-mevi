import 'dart:async';
import 'package:flutter/material.dart';

enum NotificationType { info, warning, error, critical, success }

// Simple data class for in-app notifications
class InAppNotification {
  final String title;
  final String body;
  final int seconds;
  InAppNotification({
    required this.title,
    required this.body,
    this.seconds = 4,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Global key for scaffold messenger
  static final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  static GlobalKey<ScaffoldMessengerState> get scaffoldKey => _scaffoldKey;

  // Show toast notification
  void showToast({
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final context = _scaffoldKey.currentContext;
    if (context == null) return;

    final color = _getColorForType(type);
    final icon = _getIconForType(type);

    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  // In-app notification stream for positioned notifications (e.g. under search bar)
  final StreamController<InAppNotification> _inAppController =
      StreamController<InAppNotification>.broadcast();

  Stream<InAppNotification> get inAppStream => _inAppController.stream;

  void notifyInApp({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _inAppController.add(
      InAppNotification(
        title: title,
        body: message,
        seconds: duration.inSeconds,
      ),
    );
  }

  // Dispose controllers if needed
  void dispose() {
    if (!_inAppController.isClosed) _inAppController.close();
  }

  // Show critical vehicle alert
  void showVehicleAlert({
    required String title,
    required String message,
    required VoidCallback onAcknowledge,
    bool canDismiss = false,
  }) {
    final context = _scaffoldKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: canDismiss,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAcknowledge();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ACKNOWLEDGE'),
          ),
        ],
      ),
    );
  }

  // Show sensor status notification
  void showSensorStatus({
    required String sensorName,
    required bool isOnline,
    String? additionalInfo,
  }) {
    final message = isOnline
        ? '$sensorName connected successfully'
        : '$sensorName connection lost${additionalInfo != null ? ' - $additionalInfo' : ''}';

    showToast(
      message: message,
      type: isOnline ? NotificationType.success : NotificationType.error,
      duration: Duration(seconds: isOnline ? 2 : 5),
    );
  }

  // Show loading notification with progress
  void showLoadingProgress({required String message, double? progress}) {
    // This would integrate with a loading overlay service
    // Implementation depends on specific loading UI requirements
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return Colors.blue;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.critical:
        return Colors.red.shade800;
      case NotificationType.success:
        return Colors.green;
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.critical:
        return Icons.dangerous_outlined;
      case NotificationType.success:
        return Icons.check_circle_outline;
    }
  }
}

// Vehicle-specific notifications
class VehicleNotificationService {
  final NotificationService _notificationService = NotificationService();

  // Battery alerts
  void showBatteryAlert(double batteryLevel) {
    if (batteryLevel < 15) {
      _notificationService.showVehicleAlert(
        title: 'CRITICAL BATTERY LEVEL',
        message:
            'Battery level is critically low (${batteryLevel.toInt()}%). '
            'Find charging station immediately.',
        onAcknowledge: () {
          // Log to vehicle system
        },
      );
    } else if (batteryLevel < 25) {
      _notificationService.showToast(
        message: 'Low battery warning: ${batteryLevel.toInt()}%',
        type: NotificationType.warning,
        duration: const Duration(seconds: 5),
      );
    }
  }

  // Speed alerts
  void showSpeedAlert(double currentSpeed, double speedLimit) {
    if (currentSpeed > speedLimit * 1.2) {
      _notificationService.showVehicleAlert(
        title: 'EXCESSIVE SPEED WARNING',
        message:
            'Current speed: ${currentSpeed.toInt()} km/h\n'
            'Speed limit: ${speedLimit.toInt()} km/h',
        onAcknowledge: () {
          // Log speeding event
        },
      );
    }
  }

  // Obstacle detection
  void showObstacleAlert(double distance) {
    if (distance < 2.0) {
      _notificationService.showVehicleAlert(
        title: 'COLLISION WARNING',
        message:
            'Obstacle detected at ${distance.toStringAsFixed(1)}m. '
            'Emergency braking activated.',
        onAcknowledge: () {
          // Log safety event
        },
        canDismiss: false,
      );
    }
  }

  // System status
  void showSystemStatus(String systemName, bool isOperational) {
    _notificationService.showSensorStatus(
      sensorName: systemName,
      isOnline: isOperational,
      additionalInfo: isOperational ? null : 'Check system diagnostics',
    );
  }
}
