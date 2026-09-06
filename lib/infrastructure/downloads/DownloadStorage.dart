import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/media/MediaId.dart';

/// Where downloaded audio lives on the device, and the only place that
/// knows it (ADR-0020).
///
/// ## Not a cache
///
/// `CONTEXT.md`: "Downloaded media is first-class local media and is not
/// disposable cache." So downloads go under the **application support**
/// directory — which the platform backs up and does not reclaim — rather
/// than the caches directory `flutter_cache_manager` uses for artwork,
/// which Android and iOS are both free to empty whenever they are short
/// of space. A user who downloaded an album for a flight must still have
/// it at the gate.
///
/// ## One directory per download
///
/// Each track gets its own directory, `<server id>_<item id>/`, holding
/// `audio.part` while it transfers, `source.key` naming what those bytes
/// are of, and `audio.<extension>` once it is finished. That makes every
/// operation deterministic without the database having to remember a file
/// name: finding the finished file is a listing of a directory with one
/// audio entry in it, completing a transfer is a rename inside a single
/// directory (which is atomic on both platforms), and removing a download
/// is one recursive delete that cannot leave a stray partial behind.
///
/// The extension is kept because iOS's AVFoundation leans on it to pick
/// a decoder for a local file; Android's ExoPlayer sniffs the content
/// either way.
///
/// `source.key` deliberately does not start with `audio.`, so it can
/// never be mistaken for the finished file by [completedFile].
@lazySingleton
class DownloadStorage {
  DownloadStorage({Future<Directory> Function()? rootDirectory})
    : _rootDirectory = rootDirectory ?? getApplicationSupportDirectory;

  /// Overridable so tests can point the whole layout at a temporary
  /// directory instead of a platform channel.
  @factoryMethod
  factory DownloadStorage.platform() => DownloadStorage();

  final Future<Directory> Function() _rootDirectory;

  static const String _downloadsFolder = 'downloads';
  static const String _partialName = 'audio.part';
  static const String _audioPrefix = 'audio.';
  static const String _sourceKeyName = 'source.key';

  /// The directory holding every download. Created if it is not there.
  Future<Directory> downloadsDirectory() async {
    final root = await _rootDirectory();
    final directory = Directory('${root.path}/$_downloadsFolder');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// [id]'s own directory. Created if it is not there.
  Future<Directory> directoryFor(MediaId id) async {
    final downloads = await downloadsDirectory();
    final directory = Directory('${downloads.path}/${_folderName(id)}');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// The file an in-flight transfer for [id] is appended to. May not
  /// exist yet.
  Future<File> partialFile(MediaId id) async =>
      File('${(await directoryFor(id)).path}/$_partialName');

  /// [id]'s partial file, prepared to receive bytes from [sourceKey].
  ///
  /// A partial only means anything alongside the address it came from.
  /// The download-quality preference (v0.2.2) changes that address, so a
  /// track paused or failed at one quality and retried at another would
  /// otherwise have the tail of one encoding appended to the head of
  /// another — a file that reports itself complete and plays as noise,
  /// the same hazard [HttpDownloadEngine] already guards for a server
  /// that ignores a `Range` request.
  ///
  /// So the address the bytes came from is recorded beside them, and a
  /// partial left by a different one is thrown away rather than resumed.
  /// Starting a track over is a few seconds; a silently corrupt download
  /// is the thing this release cannot ship.
  Future<File> partialFileForSource(MediaId id, String sourceKey) async {
    final directory = await directoryFor(id);
    final partial = File('${directory.path}/$_partialName');
    final marker = File('${directory.path}/$_sourceKeyName');

    final recorded = await marker.exists() ? await marker.readAsString() : null;
    if (recorded != sourceKey) {
      if (await partial.exists()) await partial.delete();
      await marker.writeAsString(sourceKey, flush: true);
    }
    return partial;
  }

  /// The finished file for [id], or `null` when the download has not
  /// completed. A partial transfer is never returned.
  Future<File?> completedFile(MediaId id) async {
    final downloads = await downloadsDirectory();
    final directory = Directory('${downloads.path}/${_folderName(id)}');
    if (!await directory.exists()) return null;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name.startsWith(_audioPrefix) && name != _partialName) return entry;
    }
    return null;
  }

  /// Renames [partial] to the finished name for [extension], replacing
  /// any earlier finished file. The rename is what makes completion
  /// atomic: until it returns, [completedFile] reports nothing.
  Future<File> complete(
    MediaId id,
    File partial, {
    required String extension,
  }) async {
    final existing = await completedFile(id);
    if (existing != null) await existing.delete();
    final directory = await directoryFor(id);
    final finished = await partial.rename(
      '${directory.path}/$_audioPrefix$extension',
    );
    // The source marker only ever describes a partial. Leaving it behind
    // would be a stray file in a finished download's directory.
    final marker = File('${directory.path}/$_sourceKeyName');
    if (await marker.exists()) await marker.delete();
    return finished;
  }

  /// Deletes everything stored for [id]. Safe when there is nothing.
  Future<void> discard(MediaId id) async {
    final downloads = await downloadsDirectory();
    final directory = Directory('${downloads.path}/${_folderName(id)}');
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Both halves of a [MediaId] are UUIDs, so this is unique and needs
  /// no escaping — the same reasoning `MediaId.key` uses, with `_`
  /// instead of `:` because `:` is not a portable file name character.
  String _folderName(MediaId id) => '${id.serverId}_${id.itemId}';
}
