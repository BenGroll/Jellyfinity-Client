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
  ///
  /// [accountKey], when given, overlays that profile's current favorite
  /// state (`cached_favorites` — which a favorite toggled offline also
  /// updates, v0.4.3) onto the result, so a detail screen reopened while
  /// offline shows the same heart it did a moment ago rather than the
  /// unconditional `false` `cached_media_items` itself carries (ADR-0019).
  /// Omitted by a caller with nothing to scope it to.
  Future<MediaItem?> readItem(MediaId id, {String? accountKey});

  /// Replaces [accountKey]'s cached favorites of [kind] with exactly
  /// [items], recording their metadata on the way (v0.3.4, ADR-0028).
  ///
  /// Called after an online favorites-list read, so a favorite removed on
  /// another client stops appearing in the offline list here too. The
  /// window is treated as the whole of that kind's favorites — the
  /// Favorites destination pages within one kind, but only the first
  /// window is cached.
  Future<void> replaceFavorites(
    String accountKey,
    MediaKind kind,
    List<MediaItem> items,
  );

  /// One window of [accountKey]'s cached favorites of [kind], alphabetical,
  /// or `null` if this profile's favorites of that kind have never been
  /// read online — which the caller turns back into the failure that sent
  /// it here rather than an empty list that would read as "you have no
  /// favorites".
  Future<Page<T>?> readFavorites<T extends MediaItem>(
    String accountKey,
    MediaKind kind,
    PageRequest request,
  );

  /// Records or clears one favorite for [accountKey] locally (v0.3.4), so
  /// a toggle made online shows in an offline Favorites view without
  /// waiting for the next full sync. A no-op for a kind the cache does not
  /// store.
  Future<void> setFavorite(
    String accountKey,
    MediaId id,
    MediaKind kind, {
    required bool favorite,
  });

  /// Records [accountKey]'s intent to set [id]'s favorite state, made
  /// while the server could not be reached (v0.4.3, ADR-0033).
  ///
  /// One row per `(accountKey, id)`: a second offline toggle of the same
  /// item overwrites the first rather than queuing behind it, so only the
  /// latest local intent is ever replayed once the server is reachable
  /// again — "a later local action wins" falls out of the upsert, with no
  /// ordering logic needed. Does not itself touch `cached_favorites`; the
  /// caller keeps that in step so every offline-facing read stays honest.
  Future<void> recordPendingFavorite(
    String accountKey,
    MediaId id,
    MediaKind kind, {
    required bool favorite,
  });

  /// [accountKey]'s outstanding favorite intents, oldest first — what a
  /// reconnect replays against the server.
  Future<List<PendingFavoriteIntent>> pendingFavorites(String accountKey);

  /// Forgets [accountKey]'s pending intent for [id], once it has reached
  /// the server (or been superseded by a fresh online change).
  Future<void> clearPendingFavorite(String accountKey, MediaId id);

  /// Forgets everything belonging to [serverId]. Called when a server is
  /// removed: its metadata is meaningless without it.
  Future<void> clearServer(String serverId);
}

/// One profile's not-yet-confirmed favorite/unfavorite, as
/// [MediaCacheStore.pendingFavorites] returns it.
class PendingFavoriteIntent {
  const PendingFavoriteIntent({
    required this.id,
    required this.kind,
    required this.favorite,
  });

  final MediaId id;
  final MediaKind kind;

  /// The favorite state this intent asks the server to set.
  final bool favorite;
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

    // A row the server sent that could not be mapped keeps a place in the
    // collection, so the numbering the user sees offline matches the
    // numbering they saw online. A source that recorded which slot it
    // occupied (v0.4.2) gets that slot back; one that did not — an
    // offline gap standing in for a member whose file never downloaded —
    // still lands after the readable rows, as it always did.
    final reserved = <int, UnavailableItem>{};
    final floating = <UnavailableItem>[];
    for (final missing in page.unavailable) {
      final at = missing.position;
      if (at != null && at >= page.startIndex && !reserved.containsKey(at)) {
        reserved[at] = missing;
      } else {
        floating.add(missing);
      }
    }

    var position = page.startIndex;
    int nextFreePosition() {
      while (reserved.containsKey(position)) {
        position++;
      }
      return position++;
    }

    for (final item in page.items) {
      final row = _mapper.toRow(item, now: now);
      if (row == null) continue;
      serverId ??= item.id.serverId;
      rows.add(row);
      entries.add(
        CachedCollectionEntriesCompanion.insert(
          serverId: item.id.serverId,
          collectionKey: collectionKey,
          position: nextFreePosition(),
          itemId: item.id.itemId,
        ),
      );
    }

    if (serverId != null) {
      for (final missing in floating) {
        entries.add(
          CachedCollectionEntriesCompanion.insert(
            serverId: serverId,
            collectionKey: collectionKey,
            position: nextFreePosition(),
            itemId: missing.id,
            unavailableReason: Value(missing.reason),
          ),
        );
      }
      for (final MapEntry(key: at, value: missing) in reserved.entries) {
        entries.add(
          CachedCollectionEntriesCompanion.insert(
            serverId: serverId,
            collectionKey: collectionKey,
            position: at,
            itemId: missing.id,
            unavailableReason: Value(missing.reason),
          ),
        );
        if (at >= position) position = at + 1;
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
        unavailable.add(
          UnavailableItem(
            id: entry.itemId,
            reason: reason,
            position: entry.position,
          ),
        );
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
            position: entry.position,
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
  Future<MediaItem?> readItem(MediaId id, {String? accountKey}) async {
    final row =
        await (_db.select(_db.cachedMediaItems)..where(
              (t) =>
                  t.serverId.equals(id.serverId) & t.itemId.equals(id.itemId),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    var isFavorite = false;
    if (accountKey != null) {
      final favorite =
          await (_db.select(_db.cachedFavorites)..where(
                (t) =>
                    t.accountKey.equals(accountKey) &
                    t.itemId.equals(id.itemId),
              ))
              .getSingleOrNull();
      isFavorite = favorite != null;
    }

    return _mapper.toItem(
      row,
      availability: MediaAvailability.remoteUnavailable,
      isFavorite: isFavorite,
    );
  }

  /// The `cached_collections` key that marks a profile's favorites of one
  /// kind as having been synced at least once — so [readFavorites] can
  /// tell "no favorite albums" (an empty sync) from "never synced".
  static String _favoritesMarker(String accountKey, String kindName) =>
      'favorites:$kindName:$accountKey';

  static String _serverFromAccount(String accountKey) {
    final slash = accountKey.indexOf('/');
    return slash < 0 ? accountKey : accountKey.substring(0, slash);
  }

  @override
  Future<void> replaceFavorites(
    String accountKey,
    MediaKind kind,
    List<MediaItem> items,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final kindName = kind.name;
    final serverId = _serverFromAccount(accountKey);

    final rows = <CachedMediaItemsCompanion>[];
    final favourites = <CachedFavoritesCompanion>[];
    for (final item in items) {
      final row = _mapper.toRow(item, now: now);
      if (row == null) continue;
      rows.add(row);
      favourites.add(
        CachedFavoritesCompanion.insert(
          accountKey: accountKey,
          serverId: item.id.serverId,
          itemId: item.id.itemId,
          kind: kindName,
          updatedAt: now,
        ),
      );
    }

    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.cachedMediaItems, rows);
        // Rewrite this profile's favorites of exactly this kind — a
        // removal on another client has to disappear here too.
        batch.deleteWhere(
          _db.cachedFavorites,
          (t) => t.accountKey.equals(accountKey) & t.kind.equals(kindName),
        );
        batch.insertAllOnConflictUpdate(_db.cachedFavorites, favourites);
        batch.insert(
          _db.cachedCollections,
          CachedCollectionsCompanion.insert(
            serverId: serverId,
            collectionKey: _favoritesMarker(accountKey, kindName),
            totalCount: favourites.length,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => CachedCollectionsCompanion(
              totalCount: Value(favourites.length),
              updatedAt: Value(now),
            ),
          ),
        );
      });
    });
  }

  @override
  Future<Page<T>?> readFavorites<T extends MediaItem>(
    String accountKey,
    MediaKind kind,
    PageRequest request,
  ) async {
    final kindName = kind.name;
    final serverId = _serverFromAccount(accountKey);

    final marker =
        await (_db.select(_db.cachedCollections)..where(
              (t) =>
                  t.serverId.equals(serverId) &
                  t.collectionKey.equals(
                    _favoritesMarker(accountKey, kindName),
                  ),
            ))
            .getSingleOrNull();
    if (marker == null) return null;

    final favourites =
        await (_db.select(_db.cachedFavorites)..where(
              (t) => t.accountKey.equals(accountKey) & t.kind.equals(kindName),
            ))
            .get();

    final itemsById = await _itemsById(serverId, [
      for (final row in favourites) row.itemId,
    ]);

    final available = <T>[];
    for (final favourite in favourites) {
      final row = itemsById[favourite.itemId];
      final item = row == null
          ? null
          : _mapper.toItem(
              row,
              availability: MediaAvailability.remoteUnavailable,
            );
      if (item is T) available.add(item);
    }
    available.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    final start = request.startIndex.clamp(0, available.length);
    final end = (start + request.limit).clamp(0, available.length);
    return Page<T>(
      content: Partial(available: available.sublist(start, end)),
      startIndex: start,
      totalCount: available.length,
      source: PageSource.cache,
    );
  }

  @override
  Future<void> setFavorite(
    String accountKey,
    MediaId id,
    MediaKind kind, {
    required bool favorite,
  }) async {
    if (!MediaCacheMapper.cachedKinds.contains(kind)) return;
    if (favorite) {
      await _db
          .into(_db.cachedFavorites)
          .insert(
            CachedFavoritesCompanion.insert(
              accountKey: accountKey,
              serverId: id.serverId,
              itemId: id.itemId,
              kind: kind.name,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
            onConflict: DoUpdate(
              (_) => CachedFavoritesCompanion(
                kind: Value(kind.name),
                updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
              ),
            ),
          );
    } else {
      await (_db.delete(_db.cachedFavorites)..where(
            (t) => t.accountKey.equals(accountKey) & t.itemId.equals(id.itemId),
          ))
          .go();
    }
  }

  @override
  Future<void> recordPendingFavorite(
    String accountKey,
    MediaId id,
    MediaKind kind, {
    required bool favorite,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.pendingFavoriteIntents)
        .insert(
          PendingFavoriteIntentsCompanion.insert(
            accountKey: accountKey,
            serverId: id.serverId,
            itemId: id.itemId,
            kind: kind.name,
            favorite: favorite,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => PendingFavoriteIntentsCompanion(
              kind: Value(kind.name),
              favorite: Value(favorite),
              updatedAt: Value(now),
            ),
          ),
        );
  }

  @override
  Future<List<PendingFavoriteIntent>> pendingFavorites(
    String accountKey,
  ) async {
    final rows =
        await (_db.select(_db.pendingFavoriteIntents)
              ..where((t) => t.accountKey.equals(accountKey))
              ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
            .get();
    return [
      for (final row in rows)
        if (_kind(row.kind) case final kind?)
          PendingFavoriteIntent(
            id: MediaId(serverId: row.serverId, itemId: row.itemId),
            kind: kind,
            favorite: row.favorite,
          ),
    ];
  }

  @override
  Future<void> clearPendingFavorite(String accountKey, MediaId id) async {
    await (_db.delete(_db.pendingFavoriteIntents)..where(
          (t) => t.accountKey.equals(accountKey) & t.itemId.equals(id.itemId),
        ))
        .go();
  }

  MediaKind? _kind(String name) {
    for (final kind in MediaKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
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
      await (_db.delete(
        _db.cachedFavorites,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.pendingFavoriteIntents,
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
