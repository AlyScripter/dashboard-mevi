import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/services/logging_service.dart';

void main() {
  group('LoggingService', () {
    test('should be a singleton', () {
      final instance1 = LoggingService();
      final instance2 = LoggingService();

      expect(identical(instance1, instance2), true);
    });

    test('should log error message', () {
      expect(
        () => LoggingService.error('Test error', component: 'Test'),
        returnsNormally,
      );
    });

    test('should log error with exception and stack trace', () {
      final error = Exception('Test exception');
      final stackTrace = StackTrace.current;

      expect(
        () => LoggingService.error(
          'Test error',
          component: 'Test',
          error: error,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });

    test('should log warning message', () {
      expect(
        () => LoggingService.warning('Test warning', component: 'Test'),
        returnsNormally,
      );
    });

    test('should log info message', () {
      expect(
        () => LoggingService.info('Test info', component: 'Test'),
        returnsNormally,
      );
    });

    test('should log debug message', () {
      expect(
        () => LoggingService.debug('Test debug', component: 'Test'),
        returnsNormally,
      );
    });

    test('should log startup', () {
      expect(() => LoggingService.logStartup(), returnsNormally);
    });

    test('should log ROS connection events', () {
      expect(
        () => LoggingService.rosConnection('Connected', connected: true),
        returnsNormally,
      );

      expect(
        () => LoggingService.rosConnection('Disconnected', connected: false),
        returnsNormally,
      );
    });
  });
}
