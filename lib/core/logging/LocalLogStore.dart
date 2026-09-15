import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'Logger.dart';

/// One locally retained application log event.
class LocalLogEntry {
  const LocalLogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime time;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  /// Whether this event belongs to the connected-playback diagnostic view.
  bool get isRemote {
    final text = '$message ${error ?? ''}'.toLowerCase();
    return text.contains('connected playback') ||
        text.contains('remote') ||
        text.contains('syncplay') ||
        text.contains('/sessions') ||
        text.contains('/syncplay');
  }

  String get formatted {
    final buffer = StringBuffer(
      '${time.toIso8601String()} [${level.name.toUpperCase()}] $message',
    );
    if (error != null) buffer.write('\nerror: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}

/// A bounded, in-memory copy of every event passed to [Logger].
///
/// This is deliberately owned by the logging layer rather than the Remote
/// feature: a command failure often needs the surrounding HTTP, session, and
/// lifecycle events to explain it. The UI can filter entries to Remote while
/// retaining the complete current-launch context for copying to a bug report.
@lazySingleton
class LocalLogStore extends ChangeNotifier {
  static const int maximumEntries = 10000;

  final List<LocalLogEntry> _entries = [];

  List<LocalLogEntry> get entries => List.unmodifiable(_entries);

  void add({
    required LogLevel level,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _entries.add(
      LocalLogEntry(
        time: DateTime.now(),
        level: level,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    if (_entries.length > maximumEntries) _entries.removeAt(0);
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  String text({bool remoteOnly = false}) {
    final selected = remoteOnly
        ? _entries.where((entry) => entry.isRemote)
        : _entries;
    return selected.map((entry) => entry.formatted).join('\n\n');
  }
}
