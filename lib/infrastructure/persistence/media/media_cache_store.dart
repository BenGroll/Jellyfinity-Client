import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/partial.dart';
import '../../../domain/media/media.dart';
import '../database/AppDatabase.dart';
import 'MediaCacheMapper.dart';

/// Jellyfinity's local copy of the media metadata it has already read.
///
/// ADR-0010 put this in the "persisted metadata" category: it lives until
/// it is refreshed or the server it belongs to is removed, and it is never
/// evicted behind the user's back. It exists to satisfy one roadmap
/// requirement — a music library the user has browsed stays browsable when
/// the server stops answering.
///
/// It caches what was *browsed*, not the library. Nothing here syncs, and
/// nothing here fetches: at 130k songs a full local mirror is a different
/// feature with a different cost, and this one has to earn its place in a
/// release that is mostly UI.
abstract class MediaCacheStore {
  /// Records one window of [collectionKey] exactly as the server ordered
  /// it, together with the items in it.
  Future<void> savePage(String collectionKey, Page<MediaItem> page);

  /// The cached window of [collectionKey] for [request], or `null` if
  /// none of it has ever been read.
  ///
  /// `null` and an empty page mean different things: `null` is "there is
  /// nothing saved to show you", which the caller turns back into the
  /// failure that sent it here, while an empty page is "this collection
  /// really is empty".
  Future<Page<T>?> readPage<T extends MediaItem>(
    String serverId,
    String collectionKey,
    PageRequest request,
  );

  /// Stores one item on its own, for the detail screens that load a
  /// header before its children.
  Future<void> saveItem(MediaItem item);

  /// The cached form of [id], marked unavailable, or `null` if it was
  /// never read.
  Future<MediaItem?> readItem(MediaId id);

  /// Forgets everything belonging to [serverId]. Called when a server is
  /// removed: its metadata is meaningless without it.
  Future<void> clearServer(String serverId);
}

/// [MediaCacheStore] over the `cached_*` tables (schema v2).
@LazySingleton(as: MediaCacheStore)
class DriftMediaCacheStore implements MediaCacheStore {
  DriftMediaCacheStore(this._db);

  final AppDatabase _db;
  final MediaCacheMapper _mapper = const MediaCacheMapper();

  @override
  Future<void> savePage(String collectionKey, Page<MediaItem> page) async {
    final rows = <CachedMediaItemsCompanion>[];
    final entries = <CachedCollectionEntriesCompanion>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    String? serverId;
    var position = page.startIndex;

    for (final item in page.items) {
      final row = _mapper.toRow(item, now: now);
      if (row == null) continue;
      serverId ??= item.id.serverId;
      rows.add(row);
      entries.add(
        CachedCollectionEntriesCompanion.insert(
          serverId: item.id.serverId,
          collectionKey: collectionKey,
          position: position++,
          itemId: item.id.itemId,
        ),
      );
    }

    // A row the server sent that could not be mapped keeps a place in the
    // collection, so the numbering the user sees offline matches the
    // numbering they saw online. Its exact slot within the window is lost
    // — Partial separates the usable rows from the rest and does not
    // record how they were interleaved — so unavailable entries land at
    // the end of the window they came from.
    if (serverId != null) {
      for (final missing in page.unavailable) {
        entries.add(
          CachedCollectionEntriesCompanion.insert(
            serverId: serverId,
            collectionKey: collectionKey,
            position: position++,
            itemId: missing.id,
            unavailableReason: Value(missing.reason),
          ),
        );
      }
    }

    if (serverId == null) return;
    final server = serverId;

    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.cachedMediaItems, rows);
        // Rewrite the window rather than merging into it, so a row that
        // left the library stops occupying a position.
        batch.deleteWhere(
          _db.cachedCollectionEntries,
          (t) =>
              t.serverId.equals(server) &
              t.collectionKey.equals(collectionKey) &
              t.position.isBiggerOrEqualValue(page.startIndex) &
              t.position.isSmallerThanValue(position),
        );
        // And drop anything past the collection's reported end: when a
        // library shrinks, the windows already saved beyond the new end
        // are the only evidence left of rows that no longer exist.
        batch.deleteWhere(
          _db.cachedCollectionEntries,
          (t) =>
              t.serverId.equals(server) &
              t.collectionKey.equals(collectionKey) &
              t.position.isBiggerOrEqualValue(page.totalCount),
        );
        batch.insertAllOnConflictUpdate(_db.cachedCollectionEntries, entries);
        batch.insert(
          _db.cachedCollections,
          CachedCollectionsCompanion.insert(
            serverId: server,
            collectionKey: collectionKey,
            totalCount: page.totalCount,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => CachedCollectionsCompanion(
              totalCount: Value(page.totalCount),
              updatedAt: Value(now),
            ),
          ),
        );
      });
    });
  }

  @override
  Future<Page<T>?> readPage<T extends MediaItem>(
    String serverId,
    String collectionKey,
    PageRequest request,
  ) async {
    final collection =
        await (_db.select(_db.cachedCollections)..where(
              (t) =>
                  t.serverId.equals(serverId) &
                  t.collectionKey.equals(collectionKey),
            ))
            .getSingleOrNull();
    if (collection == null) return null;

    final entries =
        await (_db.select(_db.cachedCollectionEntries)
              ..where(
                (t) =>
                    t.serverId.equals(serverId) &
                    t.collectionKey.equals(collectionKey) &
                    t.position.isBiggerOrEqualValue(request.startIndex) &
                    t.position.isSmallerThanValue(
                      request.startIndex + request.limit,
                    ),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    if (entries.isEmpty) return null;

    final items = await _itemsById(serverId, [
      for (final entry in entries)
        if (entry.unavailableReason == null) entry.itemId,
    ]);

    final available = <T>[];
    final unavailable = <UnavailableItem>[];
    for (final entry in entries) {
      final reason = entry.unavailableReason;
      if (reason != null) {
        unavailable.add(UnavailableItem(id: entry.itemId, reason: reason));
        continue;
      }
      final row = items[entry.itemId];
      final item = row == null
          ? null
          : _mapper.toItem(
              row,
              availability: MediaAvailability.remoteUnavailable,
            );
      if (item is T) {
        available.add(item);
      } else {
        unavailable.add(
          UnavailableItem(
            id: entry.itemId,
            reason: 'This item is not saved on this device.',
          ),
        );
      }
    }

    return Page<T>(
      content: Partial(available: available, unavailable: unavailable),
      startIndex: request.startIndex,
      // What is saved, not what the server has: paging offline must end
      // where the cache ends instead of asking forever for windows that
      // were never fetched.
      totalCount: await _cachedCount(serverId, collectionKey),
      source: PageSource.cache,
    );
  }

  @override
  Future<void> saveItem(MediaItem item) async {
    final row = _mapper.toRow(item, now: DateTime.now().millisecondsSinceEpoch);
    if (row == null) return;
    await _db
        .into(_db.cachedMediaItems)
        .insert(row, onConflict: DoUpdate((_) => row));
  }

  @override
  Future<MediaItem?> readItem(MediaId id) async {
    final row =
        await (_db.select(_db.cachedMediaItems)..where(
              (t) =>
                  t.serverId.equals(id.serverId) & t.itemId.equals(id.itemId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return _mapper.toItem(
      row,
      availability: MediaAvailability.remoteUnavailable,
    );
  }

  @override
  Future<void> clearServer(String serverId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.cachedCollectionEntries,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.cachedCollections,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.cachedMediaItems,
      )..where((t) => t.serverId.equals(serverId))).go();
    });
  }

  /// The window's items in one indexed query, rather than one query per
  /// row: a hundred point lookups per page is exactly the pattern that
  /// stops feeling fine somewhere around a 130k-row table.
  Future<Map<String, CachedMediaItemRow>> _itemsById(
    String serverId,
    List<String> itemIds,
  ) async {
    if (itemIds.isEmpty) return const {};
    final rows =
        await (_db.select(_db.cachedMediaItems)..where(
              (t) => t.serverId.equals(serverId) & t.itemId.isIn(itemIds),
            ))
            .get();
    return {for (final row in rows) row.itemId: row};
  }

  Future<int> _cachedCount(String serverId, String collectionKey) async {
    final count = _db.cachedCollectionEntries.position.count();
    final query = _db.selectOnly(_db.cachedCollectionEntries)
      ..addColumns([count])
      ..where(
        _db.cachedCollectionEntries.serverId.equals(serverId) &
            _db.cachedCollectionEntries.collectionKey.equals(collectionKey),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
