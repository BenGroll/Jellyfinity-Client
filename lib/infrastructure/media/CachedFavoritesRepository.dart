import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/connectivity/OfflineMode.dart';
import '../../domain/media/FavoritesRepository.dart';
import '../../domain/media/media_kind.dart';
import '../../domain/media/MediaId.dart';
import '../jellyfin/identity/JellyfinSessionContext.dart';
import '../jellyfin/media/JellyfinFavoritesRepository.dart';
import '../persistence/media/media_cache_store.dart';

/// The [FavoritesRepository] the app uses: the server write, with the local
/// favorites cache kept in step behind it (v0.3.4, ADR-0028) — and, since
/// v0.4.3 (ADR-0033), a pending-intent fallback for when there is no server
/// to write to at all.
///
/// Online, this is unchanged from v0.3.4: attempt the write, and on success
/// mirror it into `cached_favorites`. Offline, the write cannot reach the
/// server, so it is not attempted: the intended state is written straight
/// into `cached_favorites` instead (the same mirror a successful online
/// write already updates, so Favorites, its Home strip, and a reopened
/// detail page all agree immediately) and recorded as a pending intent for
/// `PendingFavoritesSync` to replay once a session can reach the server
/// again.
@LazySingleton(as: FavoritesRepository)
class CachedFavoritesRepository implements FavoritesRepository {
  CachedFavoritesRepository(
    this._remote,
    this._cache,
    this._context,
    this._offline,
  );

  final JellyfinFavoritesRepository _remote;
  final MediaCacheStore _cache;
  final JellyfinSessionContext _context;
  final OfflineMode _offline;

  @override
  Future<Result<void>> setFavorite(
    MediaId id, {
    required bool favorite,
    MediaKind? kind,
  }) async {
    final accountKey = _accountKey;

    if (_offline.status.isOffline) {
      return _recordPending(
        id,
        favorite: favorite,
        kind: kind,
        accountKey: accountKey,
      );
    }

    final result = await _remote.setFavorite(
      id,
      favorite: favorite,
      kind: kind,
    );
    if (result.isOk && kind != null && accountKey != null) {
      await _cache.setFavorite(accountKey, id, kind, favorite: favorite);
      // The server just confirmed the true state; a stale offline intent
      // for the same item (recorded before this online change, not yet
      // replayed) must not overwrite it on a later reconnect.
      await _cache.clearPendingFavorite(accountKey, id);
    }
    return result;
  }

  /// Offline, there is no server to attempt the write against — retaining
  /// a pending intent rather than pretending it already reached one
  /// (ADR-0033). Requires both a signed-in profile and [kind]: neither is
  /// optional here the way they are online, since without a profile there
  /// is nothing to scope the intent to, and without a kind there is
  /// nothing to enqueue, so the write is refused instead of silently
  /// doing nothing.
  Future<Result<void>> _recordPending(
    MediaId id, {
    required bool favorite,
    required MediaKind? kind,
    required String? accountKey,
  }) async {
    if (accountKey == null || kind == null) {
      return const Result.err(RecoverableFailure('You are offline.'));
    }
    await _cache.setFavorite(accountKey, id, kind, favorite: favorite);
    await _cache.recordPendingFavorite(
      accountKey,
      id,
      kind,
      favorite: favorite,
    );
    return const Result.ok(null);
  }

  String? get _accountKey {
    final serverId = _context.serverId;
    final userId = _context.userId;
    if (serverId == null || userId == null) return null;
    return '$serverId/$userId';
  }
}
