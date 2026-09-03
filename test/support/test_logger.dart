import 'package:jellyfinity/core/logging/logger.dart';

/// A [Logger] that records entries instead of printing, for asserting on
/// (or just silencing) log output in tests.
class TestLogger implements Logger {
  final List<({LogLevel level, String message})> entries = [];

  List<String> get messages => entries.map((e) => e.message).toList();

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add((level: LogLevel.debug, message: message));

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add((level: LogLevel.info, message: message));

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add((level: LogLevel.warning, message: message));

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add((level: LogLevel.error, message: message));
}
