import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/media/FavoritesRepository.dart';
import '../../domain/media/media_kind.dart';
import '../../domain/media/MediaId.dart';
import '../jellyfin/identity/JellyfinSessionContext.dart';
import '../jellyfin/media/JellyfinFavoritesRepository.dart';
import '../persistence/media/media_cache_store.dart';

/// The [FavoritesRepository] the app uses: the server write, with the local
/// favorites cache kept in step behind it (v0.3.4, ADR-0028).
///
/// A favorite toggle is still only ever attempted online — the heart is
/// hidden on a cached detail copy (ADR-0019) — so there is no offline write
/// path here. What this adds over [JellyfinFavoritesRepository] is the
/// mirror: once the server has accepted the change, the same change is
/// written to `cached_favorites`, so the Favorites destination and its Home
/// section reflect it immediately when the connection next drops, instead
/// of waiting for the next full favorites sync.
@LazySingleton(as: FavoritesRepository)
class CachedFavoritesRepository implements FavoritesRepository {
  CachedFavoritesRepository(this._remote, this._cache, this._context);

  final JellyfinFavoritesRepository _remote;
  final MediaCacheStore _cache;
  final JellyfinSessionContext _context;

  @override
  Future<Result<void>> setFavorite(
    MediaId id, {
    required bool favorite,
    MediaKind? kind,
  }) async {
    final result = await _remote.setFavorite(
      id,
      favorite: favorite,
      kind: kind,
    );
    if (result.isOk && kind != null) {
      final accountKey = _accountKey;
      if (accountKey != null) {
        await _cache.setFavorite(accountKey, id, kind, favorite: favorite);
      }
    }
    return result;
  }

  String? get _accountKey {
    final serverId = _context.serverId;
    final userId = _context.userId;
    if (serverId == null || userId == null) return null;
    return '$serverId/$userId';
  }
}
