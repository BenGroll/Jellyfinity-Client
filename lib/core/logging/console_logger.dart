import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'logger.dart';

/// A [Logger] that writes to the console via `debugPrint`.
///
/// Debug-level logs are suppressed outside debug builds; info/warning/
/// error are kept, since they are expected to remain useful (without
/// containing sensitive data, per [Logger]'s privacy rule) in a release
/// build a user might report a problem from.
@LazySingleton(as: Logger)
class ConsoleLogger implements Logger {
  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer('[${level.name.toUpperCase()}] $message');
    if (error != null) buffer.write(' | error: $error');
    debugPrint(buffer.toString());
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
