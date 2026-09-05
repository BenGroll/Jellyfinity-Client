import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/partial.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';
import 'BaseItemMapper.dart';
import 'ItemsResponseDto.dart';
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

  /// A playlist with no owner of record reports `ChildCount: 0` — see
  /// [tracks] — so a row can look empty when it is not. Ask its own
  /// contents (which [tracks] can now read regardless) for the playlists
  /// that came back that way.
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
    final id = (itemId as Ok<String>).value;

    final response = await _api.queryItems(
      path: JellyfinMediaApi.playlistItemsPath(id),
      // No sort: a playlist's order is the user's own.
      page: page,
    );

    final resolved = switch (response) {
      Err<ItemsResponseDto>(failure: UnauthorizedFailure()) =>
        // Some playlists predate Jellyfin's per-user ownership model and
        // its dedicated `/Playlists/{id}/Items` route refuses everyone,
        // even the account that "owns" them in spirit — that route
        // requires an `OwnerUserId`/share match these playlists were
        // never given. The generic item listing isn't gated the same
        // way, though it can't supply a `PlaylistItemId`, so entries
        // read this way can't be reordered or removed.
        await _api.queryItems(parentId: id, page: page),
      _ => response,
    };

    return resolved.map(
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
