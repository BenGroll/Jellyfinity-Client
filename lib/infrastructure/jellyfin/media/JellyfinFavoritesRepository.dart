import 'package:injectable/injectable.dart';

import '../../../core/result/result.dart';
import '../../../domain/media/FavoritesRepository.dart';
import '../../../domain/media/MediaId.dart';
import 'jellyfin_media_api.dart';

/// [FavoritesRepository] backed by the active session's Jellyfin server.
///
/// No local half: a favorite toggle is only ever attempted while the
/// screen showing it is online (a cached/offline detail hides the heart
/// button entirely — see `Artist.isFavorite`'s doc comment), so there is
/// nothing here for `CachedMusicLibraryRepository`'s fallback pattern to
/// do. Registered directly as [FavoritesRepository].
@LazySingleton(as: FavoritesRepository)
class JellyfinFavoritesRepository implements FavoritesRepository {
  JellyfinFavoritesRepository(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<void>> setFavorite(MediaId id, {required bool favorite}) {
    final itemId = _api.localItemId(id);
    if (itemId case Err<String>(:final failure)) {
      return Future.value(Result.err(failure));
    }
    return _api.setFavorite((itemId as Ok<String>).value, favorite: favorite);
  }
}
