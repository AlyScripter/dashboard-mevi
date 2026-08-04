import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('should be a singleton', () {
      final instance1 = NotificationService();
      final instance2 = NotificationService();

      expect(identical(instance1, instance2), true);
    });

    test('should have scaffold key', () {
      expect(NotificationService.scaffoldKey, isNotNull);
    });
  });

  group('InAppNotification', () {
    test('should create notification with default seconds', () {
      final notification = InAppNotification(title: 'Test', body: 'Test body');

      expect(notification.title, 'Test');
      expect(notification.body, 'Test body');
      expect(notification.seconds, 4);
    });

    test('should create notification with custom seconds', () {
      final notification = InAppNotification(
        title: 'Test',
        body: 'Test body',
        seconds: 10,
      );

      expect(notification.seconds, 10);
    });
  });

  group('NotificationType', () {
    test('should have all notification types', () {
      expect(NotificationType.values.length, 5);
      expect(NotificationType.values, contains(NotificationType.info));
      expect(NotificationType.values, contains(NotificationType.warning));
      expect(NotificationType.values, contains(NotificationType.error));
      expect(NotificationType.values, contains(NotificationType.critical));
      expect(NotificationType.values, contains(NotificationType.success));
    });
  });
}
