import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media_availability.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/media/MediaImage.dart';
import '../../../domain/playback/PlaybackQueue.dart';
import '../../../domain/playback/QueueEntry.dart';
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
          .withRepeatMode(repeatMode);

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
      albumName: Value(entry.albumName),
      durationMicros: Value(entry.duration?.inMicroseconds),
      imageItemId: Value(image?.itemId.itemId),
      imageKind: Value(image?.kind.name),
      imageTag: Value(image?.tag),
      imageAspectRatio: Value(image?.aspectRatio),
      availability: Value(entry.availability.name),
    );
  }

  QueueEntry _toEntry(QueueEntryRow row) {
    return QueueEntry(
      id: MediaId(serverId: row.serverId, itemId: row.itemId),
      title: row.title,
      artist: row.artist,
      albumName: row.albumName,
      duration: row.durationMicros == null
          ? null
          : Duration(microseconds: row.durationMicros!),
      image: _image(row),
      availability: _availabilityFrom(row.availability),
    );
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

  RepeatMode _repeatModeFrom(String? name) {
    for (final mode in RepeatMode.values) {
      if (mode.name == name) return mode;
    }
    return RepeatMode.off;
  }
}
