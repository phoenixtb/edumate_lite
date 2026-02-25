import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application-wide logger utility
/// Provides consistent logging across the app with proper levels
/// 
/// In release builds, only warnings, errors, and fatal logs are shown.
/// Debug/info logs are disabled in release mode.
class AppLogger {
  /// Production-friendly printer: no stack traces for info/debug, minimal output
  static final Logger _logger = Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    printer: kReleaseMode 
        ? SimplePrinter(colors: false, printTime: false)
        : PrettyPrinter(
            methodCount: 0, // No stack trace for normal logs
            errorMethodCount: 5, // Stack trace only for errors
            lineLength: 100,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTime,
          ),
  );

  /// Log verbose/trace messages (lowest priority) - dev only
  static void verbose(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kReleaseMode) return;
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log debug messages (development only)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kReleaseMode) return;
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info messages (general information) - dev only  
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kReleaseMode) return;
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning messages (potential issues) - shown in release
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error messages (recoverable errors) - shown in release
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal errors (unrecoverable errors) - shown in release
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}
