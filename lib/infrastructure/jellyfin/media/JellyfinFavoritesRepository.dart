import 'package:injectable/injectable.dart';

import '../../../core/result/result.dart';
import '../../../domain/media/FavoritesRepository.dart';
import '../../../domain/media/media_kind.dart';
import '../../../domain/media/MediaId.dart';
import 'jellyfin_media_api.dart';

/// The server half of [FavoritesRepository]: the write itself.
///
/// Since v0.3.4 this is wrapped by `CachedFavoritesRepository`, which
/// mirrors a successful toggle into the local favorites cache (ADR-0028)
/// so an offline Favorites view stays honest. That is why this class is
/// registered as itself rather than as the contract — the same
/// remote-half convention `JellyfinMusicLibraryRepository` follows.
@lazySingleton
class JellyfinFavoritesRepository implements FavoritesRepository {
  JellyfinFavoritesRepository(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<void>> setFavorite(
    MediaId id, {
    required bool favorite,
    MediaKind? kind,
  }) {
    final itemId = _api.localItemId(id);
    if (itemId case Err<String>(:final failure)) {
      return Future.value(Result.err(failure));
    }
    return _api.setFavorite((itemId as Ok<String>).value, favorite: favorite);
  }
}
