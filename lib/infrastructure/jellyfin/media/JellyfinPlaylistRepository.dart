import 'package:injectable/injectable.dart';

import '../../../core/result/partial.dart';
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

    final mapped = response.map(
      (dto) => mapper.toPage(
        dto,
        request: page,
        map: mapper.toPlaylist,
        reason: 'This playlist could not be read.',
      ),
    );
    if (mapped case Err<Page<Playlist>>()) return mapped;
    return Result.ok(
      await _withRealCounts((mapped as Ok<Page<Playlist>>).value),
    );
  }

  /// Jellyfin only computes a playlist's `ChildCount` against the current
  /// user's own ownership of it: a playlist another client created — even
  /// one shared with this user — reports `ChildCount: 0` in the list
  /// response, though its contents are still readable. Rather than show
  /// a wrong "0 songs", ask the playlist's own items route (which isn't
  /// subject to that per-owner quirk) for playlists that came back empty.
  Future<Page<Playlist>> _withRealCounts(Page<Playlist> page) async {
    final zeroCount = page.items.where(
      (playlist) => (playlist.itemCount ?? 0) == 0,
    );
    if (zeroCount.isEmpty) return page;

    final counted = await Future.wait(
      zeroCount.map((playlist) async {
        final real = await tracks(
          playlist.id,
          page: const PageRequest(limit: 1),
        );
        return switch (real) {
          Ok<Page<Track>>(:final value) when value.totalCount > 0 => (
            playlist.id,
            value.totalCount,
          ),
          _ => null,
        };
      }),
    );
    final realCounts = {
      for (final entry in counted)
        if (entry != null) entry.$1: entry.$2,
    };
    if (realCounts.isEmpty) return page;

    return Page<Playlist>(
      content: Partial(
        available: [
          for (final playlist in page.items)
            if (realCounts[playlist.id] case final count?)
              Playlist(
                id: playlist.id,
                name: playlist.name,
                itemCount: count,
                duration: playlist.duration,
                availability: playlist.availability,
                image: playlist.image,
              )
            else
              playlist,
        ],
        unavailable: page.unavailable,
      ),
      startIndex: page.startIndex,
      totalCount: page.totalCount,
      source: page.source,
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
