import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized logging service for the MEVI Dashboard
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  /// Log levels
  static const int _levelError = 1000;
  static const int _levelWarning = 900;
  static const int _levelInfo = 800;
  static const int _levelDebug = 700;

  /// Log an error message
  static void error(
    String message, {
    String? component,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final logMessage = _formatMessage('ERROR', component ?? 'App', message);

    developer.log(
      logMessage,
      level: _levelError,
      name: component ?? 'MEVI',
      error: error,
      stackTrace: stackTrace,
    );

    if (kDebugMode) {
      print('🔴 $logMessage');
      if (error != null) print('   Error: $error');
      if (stackTrace != null) print('   StackTrace: $stackTrace');
    }
  }

  /// Log a warning message
  static void warning(String message, {String? component}) {
    final logMessage = _formatMessage('WARNING', component ?? 'App', message);

    developer.log(logMessage, level: _levelWarning, name: component ?? 'MEVI');

    if (kDebugMode) {
      print('🟡 $logMessage');
    }
  }

  /// Log an info message
  static void info(String message, {String? component}) {
    final logMessage = _formatMessage('INFO', component ?? 'App', message);

    developer.log(logMessage, level: _levelInfo, name: component ?? 'MEVI');

    if (kDebugMode) {
      print('🔵 $logMessage');
    }
  }

  /// Log a debug message (only in debug mode)
  static void debug(String message, {String? component}) {
    if (kDebugMode) {
      final logMessage = _formatMessage('DEBUG', component ?? 'App', message);

      developer.log(logMessage, level: _levelDebug, name: component ?? 'MEVI');

      print('⚪ $logMessage');
    }
  }

  /// Format log message with timestamp and component
  static String _formatMessage(String level, String component, String message) {
    final timestamp = DateTime.now().toIso8601String();
    return '[$timestamp] [$level] [$component] $message';
  }

  /// Log system startup information
  static void logStartup() {
    info('🚀 MEVI Dashboard starting up', component: 'Main');
    debug('Flutter version: ${_getFlutterVersion()}', component: 'Main');
    debug('Debug mode: $kDebugMode', component: 'Main');
  }

  /// Get Flutter version (simplified)
  static String _getFlutterVersion() {
    // This is a placeholder - in production you might want to get actual version
    return 'Unknown';
  }

  /// Log ROS connection events
  static void rosConnection(String event, {bool connected = false}) {
    final emoji = connected ? '🟢' : '🔴';
    info('$emoji ROS: $event', component: 'RosService');
  }
}
