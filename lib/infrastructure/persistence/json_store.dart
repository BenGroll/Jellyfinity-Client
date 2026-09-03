import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logging/logger.dart';

/// A minimal persistent store for small named JSON documents.
///
/// This is the **interim** persistence mechanism for v0.0.5: the roadmap
/// puts the real local database in v0.0.6, but the saved-servers and
/// saved-accounts registries need *somewhere* durable to live now. Each
/// document is a single JSON file in a directory the caller provides
/// (the app support directory in production). One file per concern, so a
/// corrupt or partially-written file loses only that concern.
///
/// v0.0.6 replaces the [ServerRegistry] / [AccountStore] implementations
/// that sit on top of this with database-backed ones; this class and its
/// files then go away. See ADR-0009.
abstract class JsonStore {
  /// Reads document [name]. Returns an empty map if it has never been
  /// written, or if the file is missing/unreadable/corrupt (a corrupt
  /// registry should degrade to "no saved servers", not crash the app).
  Future<Map<String, dynamic>> read(String name);

  /// Writes document [name], replacing its contents. The write is atomic
  /// (write to a temp file, then rename) so a crash mid-write cannot
  /// leave a half-written document.
  Future<void> write(String name, Map<String, dynamic> data);

  /// Deletes document [name] if it exists.
  Future<void> delete(String name);
}

/// A [JsonStore] backed by one file per document in a directory.
class FileJsonStore implements JsonStore {
  /// [directoryProvider] resolves the directory the document files live
  /// in — `path_provider`'s application-support directory in production.
  /// It is called lazily (on the first read/write) and memoized, so
  /// constructing the store touches no platform channel.
  FileJsonStore(this._directoryProvider, this._logger);

  final Future<Directory> Function() _directoryProvider;
  final Logger _logger;

  Future<Directory>? _directory;

  /// Serializes writes so two near-simultaneous saves cannot interleave.
  Future<void> _writeChain = Future<void>.value();

  Future<Directory> _dir() => _directory ??= _directoryProvider();

  Future<File> _fileFor(String name) async =>
      File('${(await _dir()).path}/$name.json');

  @override
  Future<Map<String, dynamic>> read(String name) async {
    try {
      final file = await _fileFor(name);
      if (!await file.exists()) return <String, dynamic>{};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      _logger.warning(
        'Store document "$name" was not a JSON object; ignoring.',
      );
      return <String, dynamic>{};
    } catch (error, stackTrace) {
      _logger.warning(
        'Could not read store document "$name"; treating it as empty.',
        error: error,
        stackTrace: stackTrace,
      );
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> write(String name, Map<String, dynamic> data) {
    final next = _writeChain.then((_) => _writeAtomic(name, data));
    // Keep the chain going even if this write failed.
    _writeChain = next.catchError((_) {});
    return next;
  }

  Future<void> _writeAtomic(String name, Map<String, dynamic> data) async {
    final directory = await _dir();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final target = await _fileFor(name);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(target.path);
  }

  @override
  Future<void> delete(String name) async {
    final file = await _fileFor(name);
    if (await file.exists()) await file.delete();
  }
}
