import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'LocalLogStore.dart';
import 'Logger.dart';

/// A [Logger] that writes to the console and retains local diagnostics.
///
/// Debug events remain suppressed from release console output, but are kept
/// in [LocalLogStore] so the in-app Logs > Remote screen can diagnose an
/// installed build as completely as a debug run.
@LazySingleton(as: Logger)
class ConsoleLogger implements Logger {
  ConsoleLogger(this._localLogs);

  final LocalLogStore _localLogs;

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(
      LogLevel.debug,
      message,
      printToConsole: kDebugMode,
      error: error,
      stackTrace: stackTrace,
    );
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
    bool printToConsole = true,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _localLogs.add(
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    if (!printToConsole) return;
    final buffer = StringBuffer('[${level.name.toUpperCase()}] $message');
    if (error != null) buffer.write(' | error: $error');
    debugPrint(buffer.toString());
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
