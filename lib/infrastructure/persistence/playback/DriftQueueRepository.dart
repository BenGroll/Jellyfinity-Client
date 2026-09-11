import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/artist.dart';
import '../../../domain/media/media_availability.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/media/MediaImage.dart';
import '../../../domain/playback/PlaybackQueue.dart';
import '../../../domain/playback/QueueEntry.dart';
import '../../../domain/playback/QueueOrigin.dart';
import '../../../domain/playback/QueueRepository.dart';
import '../../../domain/playback/repeat_mode.dart';
import '../database/AppDatabase.dart';
import '../key_value_store.dart';

/// [QueueRepository] over `QueueEntries` (schema v3) and [KeyValueStore].
///
/// Entries are always rewritten in full on [replace]: a queue is at most
/// a few hundred rows, nowhere near the scale that made incremental
/// writes matter for the 130k-row media cache. [savePosition] never
/// touches the entries table at all, which is what makes it cheap enough
/// to call on a timer while a track plays.
@LazySingleton(as: QueueRepository)
class DriftQueueRepository implements QueueRepository {
  DriftQueueRepository(this._db, this._keyValueStore);

  final AppDatabase _db;
  final KeyValueStore _keyValueStore;

  static const String _currentIndexKey = 'playback.queue.currentIndex';
  static const String _positionMicrosKey = 'playback.queue.positionMicros';
  static const String _shuffleEnabledKey = 'playback.queue.shuffleEnabled';
  static const String _repeatModeKey = 'playback.queue.repeatMode';

  /// The shuffled play order, as comma-separated indices into the saved
  /// entry rows (v0.4.1).
  ///
  /// Scalar queue state on [KeyValueStore] alongside the current index,
  /// shuffle flag and repeat mode, rather than a column on
  /// `queue_entries`: it is one value about the queue as a whole, not a
  /// property of any single entry, and writing it costs nothing next to
  /// rewriting every row. Without it a restart regenerated a fresh random
  /// order, so the Up Next list a listener left was never the one they
  /// came back to.
  static const String _shuffleOrderKey = 'playback.queue.shuffleOrder';

  /// The playlist this queue was started from, as JSON (v0.4.2).
  ///
  /// Beside the play order for the same reason: it is one fact about the
  /// queue as a whole, not a property of any entry. Without it a restart
  /// forgot what a listener was in the middle of, which is exactly what
  /// "resume this playlist" has to know.
  static const String _originKey = 'playback.queue.origin';

  @override
  Future<Result<RestoredQueue>> load() async {
    try {
      final rows = await (_db.select(
        _db.queueEntries,
      )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();

      if (rows.isEmpty) {
        return const Result.ok((
          queue: PlaybackQueue.empty,
          position: Duration.zero,
        ));
      }

      final entries = [for (final row in rows) _toEntry(row)];
      final savedIndex = await _keyValueStore.getInt(_currentIndexKey) ?? 0;
      final shuffleEnabled =
          await _keyValueStore.getBool(_shuffleEnabledKey) ?? false;
      final repeatMode = _repeatModeFrom(
        await _keyValueStore.getString(_repeatModeKey),
      );
      final positionMicros =
          await _keyValueStore.getInt(_positionMicrosKey) ?? 0;

      final queue = PlaybackQueue.empty
          .withEntries(
            entries,
            startIndex: savedIndex.clamp(0, entries.length - 1),
          )
          .withShuffle(shuffleEnabled)
          .withRepeatMode(repeatMode)
          // Applied last: `withShuffle` above generated a fresh order,
          // and this replaces it with the saved one when that is still a
          // valid permutation of these rows. `PlaybackQueue` rejects
          // anything else, so a stale or corrupt value degrades to the
          // fresh shuffle rather than to a broken play order.
          .withRestoredShuffleOrder(
            _decodeShuffleOrder(
              await _keyValueStore.getString(_shuffleOrderKey),
            ),
          )
          .withOrigin(
            _decodeOrigin(await _keyValueStore.getString(_originKey)),
          );

      return Result.ok((
        queue: queue,
        position: Duration(microseconds: positionMicros),
      ));
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not load the saved queue.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> replace(PlaybackQueue queue) async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.queueEntries).go();
        if (queue.entries.isEmpty) return;
        await _db.batch((batch) {
          batch.insertAll(_db.queueEntries, [
            for (var i = 0; i < queue.entries.length; i++)
              _toCompanion(queue.entries[i], position: i),
          ]);
        });
      });
      await _keyValueStore.setInt(_currentIndexKey, queue.currentIndex ?? 0);
      await _keyValueStore.setBool(_shuffleEnabledKey, queue.shuffleEnabled);
      await _keyValueStore.setString(_repeatModeKey, queue.repeatMode.name);
      await _keyValueStore.setString(
        _shuffleOrderKey,
        (queue.shuffleOrder ?? const []).join(','),
      );
      await _keyValueStore.setString(_originKey, _encodeOrigin(queue.origin));
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not save the queue.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> savePosition({
    required int? currentIndex,
    required Duration position,
  }) async {
    try {
      await _keyValueStore.setInt(_currentIndexKey, currentIndex ?? 0);
      await _keyValueStore.setInt(_positionMicrosKey, position.inMicroseconds);
      return const Result.ok(null);
    } catch (error, stackTrace) {
      return Result.err(
        UnexpectedFailure(
          'Could not save the playback position.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  QueueEntriesCompanion _toCompanion(
    QueueEntry entry, {
    required int position,
  }) {
    final image = entry.image;
    return QueueEntriesCompanion.insert(
      position: Value(position),
      serverId: entry.id.serverId,
      itemId: entry.id.itemId,
      title: entry.title,
      artist: Value(entry.artist),
      artistsJson: Value(_encodeArtists(entry.artists)),
      albumItemId: Value(entry.albumId?.itemId),
      albumName: Value(entry.albumName),
      durationMicros: Value(entry.duration?.inMicroseconds),
      normalizationGain: Value(entry.normalizationGain),
      imageItemId: Value(image?.itemId.itemId),
      imageKind: Value(image?.kind.name),
      imageTag: Value(image?.tag),
      imageAspectRatio: Value(image?.aspectRatio),
      availability: Value(entry.availability.name),
      failureMessage: Value(entry.failureMessage),
    );
  }

  QueueEntry _toEntry(QueueEntryRow row) {
    return QueueEntry(
      id: MediaId(serverId: row.serverId, itemId: row.itemId),
      title: row.title,
      artist: row.artist,
      artists: _decodeArtists(row.artistsJson, row.serverId),
      albumId: row.albumItemId == null
          ? null
          : MediaId(serverId: row.serverId, itemId: row.albumItemId!),
      albumName: row.albumName,
      duration: row.durationMicros == null
          ? null
          : Duration(microseconds: row.durationMicros!),
      normalizationGain: row.normalizationGain,
      image: _image(row),
      availability: _availabilityFrom(row.availability),
      failureMessage: row.failureMessage,
    );
  }

  /// Encoded exactly as `MediaCacheMapper` and `DriftDownloadStore` encode
  /// the same list, so the tables stay readable by one another's
  /// conventions.
  static String? _encodeArtists(List<ArtistRef> artists) {
    if (artists.isEmpty) return null;
    return jsonEncode([
      for (final credit in artists)
        <String, Object?>{'name': credit.name, 'id': credit.id?.itemId},
    ]);
  }

  static List<ArtistRef> _decodeArtists(String? json, String serverId) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic> && entry['name'] is String)
            ArtistRef(
              name: entry['name'] as String,
              id: entry['id'] is String
                  ? MediaId(serverId: serverId, itemId: entry['id'] as String)
                  : null,
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  MediaImage? _image(QueueEntryRow row) {
    final owner = row.imageItemId;
    final tag = row.imageTag;
    final kind = _imageKindFrom(row.imageKind);
    if (owner == null || tag == null || kind == null) return null;
    return MediaImage(
      itemId: MediaId(serverId: row.serverId, itemId: owner),
      kind: kind,
      tag: tag,
      aspectRatio: row.imageAspectRatio,
    );
  }

  /// Enum lookups are by name, not index — a row from an older build must
  /// not start meaning something else because a value moved.
  MediaAvailability _availabilityFrom(String name) {
    for (final value in MediaAvailability.values) {
      if (value.name == name) return value;
    }
    return MediaAvailability.remoteOnly;
  }

  MediaImageKind? _imageKindFrom(String? name) {
    if (name == null) return null;
    for (final kind in MediaImageKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  /// Parses the saved play order. Anything unparseable becomes `null` —
  /// `PlaybackQueue.withRestoredShuffleOrder` treats that the same as an
  /// order that no longer matches the entries, and shuffles afresh.
  static List<int>? _decodeShuffleOrder(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final order = <int>[];
    for (final part in raw.split(',')) {
      final index = int.tryParse(part);
      if (index == null) return null;
      order.add(index);
    }
    return order;
  }

  /// The queue's origin as JSON, or an empty string for a queue that has
  /// none — which is also what clears a previously saved one.
  static String _encodeOrigin(QueueOrigin? origin) {
    if (origin == null) return '';
    final image = origin.image;
    return jsonEncode(<String, Object?>{
      'serverId': origin.playlistId.serverId,
      'itemId': origin.playlistId.itemId,
      'name': origin.name,
      if (image != null) ...<String, Object?>{
        'imageItemId': image.itemId.itemId,
        'imageKind': image.kind.name,
        'imageTag': image.tag,
        'imageAspectRatio': image.aspectRatio,
      },
    });
  }

  /// The saved origin, or `null` for anything missing or unreadable — a
  /// queue with no remembered playlist behaves exactly as every queue did
  /// before v0.4.2, which is the right way for a corrupt value to fail.
  static QueueOrigin? _decodeOrigin(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final serverId = decoded['serverId'];
      final itemId = decoded['itemId'];
      final name = decoded['name'];
      if (serverId is! String || itemId is! String || name is! String) {
        return null;
      }
      return QueueOrigin.playlist(
        playlistId: MediaId(serverId: serverId, itemId: itemId),
        name: name,
        image: _decodeOriginImage(decoded, serverId),
      );
    } on FormatException {
      return null;
    }
  }

  static MediaImage? _decodeOriginImage(
    Map<String, dynamic> decoded,
    String serverId,
  ) {
    final owner = decoded['imageItemId'];
    final tag = decoded['imageTag'];
    final kindName = decoded['imageKind'];
    if (owner is! String || tag is! String || kindName is! String) return null;
    for (final kind in MediaImageKind.values) {
      if (kind.name != kindName) continue;
      final ratio = decoded['imageAspectRatio'];
      return MediaImage(
        itemId: MediaId(serverId: serverId, itemId: owner),
        kind: kind,
        tag: tag,
        aspectRatio: ratio is num ? ratio.toDouble() : null,
      );
    }
    return null;
  }

  RepeatMode _repeatModeFrom(String? name) {
    for (final mode in RepeatMode.values) {
      if (mode.name == name) return mode;
    }
    return RepeatMode.off;
  }
}
