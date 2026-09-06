import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';
import 'BaseItemMapper.dart';
import 'jellyfin_media_api.dart';

/// [PlaylistRepository] backed by the active session's Jellyfin server.
///
/// The remote half of the contract: `CachedPlaylistRepository` is what
/// resolves for [PlaylistRepository] and wraps this one, so this class is
/// registered as itself.
@lazySingleton
class JellyfinPlaylistRepository implements PlaylistRepository {
  JellyfinPlaylistRepository(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final mapperResult = _api.mapper();
    if (mapperResult case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final mapper = (mapperResult as Ok<BaseItemMapper>).value;

    final response = await _api.queryItems(
      includeItemTypes: const [BaseItemMapper.playlistType],
      searchTerm: searchTerm,
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
        // Playlist rows, not bare tracks: each carries the entry id
        // `removeEntries` needs to name one appearance of a song.
        map: mapper.toPlaylistTrack,
        // A playlist can hold anything, and can outlive the items in it.
        // Either way the entry stays in place, marked, so the list the
        // user built still looks like the list they built.
        reason: 'This entry is not an available song.',
      ),
    );
  }

  @override
  Future<Result<void>> addTracks(
    MediaId playlistId,
    List<MediaId> trackIds,
  ) async {
    final playlistItemId = _api.localItemId(playlistId);
    if (playlistItemId case Err<String>(:final failure)) {
      return Result.err(failure);
    }
    final trackItemIds = <String>[];
    for (final id in trackIds) {
      final resolved = _api.localItemId(id);
      if (resolved case Err<String>(:final failure)) return Result.err(failure);
      trackItemIds.add((resolved as Ok<String>).value);
    }
    if (trackItemIds.isEmpty) return const Result.ok(null);

    return _api.addPlaylistItems(
      (playlistItemId as Ok<String>).value,
      trackItemIds,
    );
  }

  @override
  Future<Result<MediaId>> create(
    String name, {
    List<MediaId> trackIds = const [],
  }) async {
    final mapperResult = _api.mapper();
    if (mapperResult case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final serverId = (mapperResult as Ok<BaseItemMapper>).value.serverId;

    final seedIds = _localIds(trackIds);
    if (seedIds case Err<List<String>>(:final failure)) {
      return Result.err(failure);
    }

    final created = await _api.createPlaylist(
      name,
      (seedIds as Ok<List<String>>).value,
    );
    if (created case Err<String>(:final failure)) return Result.err(failure);

    final itemId = (created as Ok<String>).value;
    if (itemId.isEmpty) {
      // The playlist may well exist; what does not exist is anything to
      // navigate to. Saying so beats handing back an id of nothing.
      return const Result.err(
        UnexpectedFailure(
          'The playlist was created but the server did not say where.',
        ),
      );
    }
    return Result.ok(MediaId(serverId: serverId, itemId: itemId));
  }

  @override
  Future<Result<void>> rename(MediaId playlistId, String name) async {
    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.renamePlaylist((itemId as Ok<String>).value, name);
  }

  @override
  Future<Result<void>> delete(MediaId playlistId) async {
    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.deleteItem((itemId as Ok<String>).value);
  }

  @override
  Future<Result<void>> removeEntries(
    MediaId playlistId,
    List<String> entryIds,
  ) async {
    if (entryIds.isEmpty) return const Result.ok(null);
    final itemId = _api.localItemId(playlistId);
    if (itemId case Err<String>(:final failure)) return Result.err(failure);
    return _api.removePlaylistItems((itemId as Ok<String>).value, entryIds);
  }

  /// Every id resolved against the signed-in server, or the first reason
  /// one could not be — an id from another saved server must not be
  /// silently dropped from a playlist the user thinks they just filled.
  Result<List<String>> _localIds(List<MediaId> ids) {
    final resolved = <String>[];
    for (final id in ids) {
      final local = _api.localItemId(id);
      if (local case Err<String>(:final failure)) return Result.err(failure);
      resolved.add((local as Ok<String>).value);
    }
    return Result.ok(resolved);
  }
}
