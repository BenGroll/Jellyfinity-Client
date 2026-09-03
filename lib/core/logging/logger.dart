/// Severity for a single log entry.
enum LogLevel { debug, info, warning, error }

/// Application-wide logging abstraction.
///
/// Every log call in Jellyfinity goes through a [Logger] rather than
/// `print`/`debugPrint` directly, so:
///
/// - the implementation can be swapped (console, file, crash reporter)
///   without touching call sites;
/// - production/development behavior can differ (e.g. suppressing debug
///   logs in release builds) in one place;
/// - the privacy rule below can be enforced consistently.
///
/// **Privacy rule:** never pass credentials, auth tokens, session
/// identifiers, or other sensitive user data to a [Logger] method, even
/// at [LogLevel.debug]. Use [redact] when a value must appear in a log
/// for diagnostic purposes but its full contents must not.
abstract class Logger {
  void debug(String message, {Object? error, StackTrace? stackTrace});

  void info(String message, {Object? error, StackTrace? stackTrace});

  void warning(String message, {Object? error, StackTrace? stackTrace});

  void error(String message, {Object? error, StackTrace? stackTrace});
}

/// Masks all but a small, fixed prefix of [value], for the rare case
/// where a sensitive value's presence (not its content) is useful in a
/// log line, e.g. confirming a token was non-empty without logging it.
///
/// Prefer omitting sensitive values from logs entirely; only reach for
/// this when a partially-identifying diagnostic is genuinely necessary.
String redact(String value, {int visiblePrefixLength = 2}) {
  if (value.isEmpty) return value;
  final visible = value.substring(
    0,
    value.length < visiblePrefixLength ? value.length : visiblePrefixLength,
  );
  final maskedLength = value.length - visible.length;
  return '$visible${'*' * maskedLength}';
}
