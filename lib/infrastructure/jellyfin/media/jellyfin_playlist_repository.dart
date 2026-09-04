import 'package:injectable/injectable.dart';

import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';
import 'base_item_mapper.dart';
import 'jellyfin_media_api.dart';

/// [PlaylistRepository] backed by the active session's Jellyfin server.
@LazySingleton(as: PlaylistRepository)
class JellyfinPlaylistRepository implements PlaylistRepository {
  JellyfinPlaylistRepository(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
  }) async {
    final mapperResult = _api.mapper();
    if (mapperResult case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final mapper = (mapperResult as Ok<BaseItemMapper>).value;

    final response = await _api.queryItems(
      includeItemTypes: const [BaseItemMapper.playlistType],
      sortBy: const ['SortName'],
      // ChildCount is how a playlist row says "38 songs".
      fields: JellyfinMediaApi.detailFields,
      page: page,
    );

    return response.map(
      (dto) => mapper.toPage(
        dto,
        request: page,
        map: mapper.toPlaylist,
        reason: 'This playlist could not be read.',
      ),
    );
  }

  @override
  Future<Result<Page<Track>>> tracks(
    MediaId playlistId, {
    PageRequest page = const PageRequest.first(),
  }) async {
    final mapperResult = _api.mapper();
    if (mapperResult case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final mapper = (mapperResult as Ok<BaseItemMapper>).value;

    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);

    final response = await _api.queryItems(
      path: JellyfinMediaApi.playlistItemsPath((itemId as Ok<String>).value),
      // No sort: a playlist's order is the user's own.
      page: page,
    );

    return response.map(
      (dto) => mapper.toPage(
        dto,
        request: page,
        map: mapper.toTrack,
        // A playlist can hold anything, and can outlive the items in it.
        // Either way the entry stays in place, marked, so the list the
        // user built still looks like the list they built.
        reason: 'This entry is not an available song.',
      ),
    );
  }
}
