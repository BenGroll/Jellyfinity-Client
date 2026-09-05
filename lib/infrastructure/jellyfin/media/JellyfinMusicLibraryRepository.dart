import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';
import 'base_item_dto.dart';
import 'BaseItemMapper.dart';
import 'ItemsResponseDto.dart';
import 'jellyfin_media_api.dart';

/// [MusicLibraryRepository] backed by the active session's Jellyfin
/// server.
///
/// Every method is one server-side query: the sort, the filter and the
/// window are all the server's work, because the development library has
/// 130k songs in it and none of them may be narrowed down in Dart
/// (`PHILOSOPHY.md` §11).
///
/// The result is domain entities. Nothing above this class knows that
/// `Audio`, `AlbumArtistIds` or `RunTimeTicks` exist — which is what
/// v0.0.7 is for.
///
/// Since v0.0.8 this is the *remote half* of the contract rather than the
/// whole of it: `CachedMusicLibraryRepository` is what resolves for
/// `MusicLibraryRepository`, and it wraps this one. That is why this class
/// is registered as itself.
@lazySingleton
class JellyfinMusicLibraryRepository implements MusicLibraryRepository {
  JellyfinMusicLibraryRepository(this._api);

  final JellyfinMediaApi _api;

  @override
  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final mapperResult = _api.mapper();
    if (mapperResult case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final mapper = (mapperResult as Ok<BaseItemMapper>).value;

    final response = await _api.queryItems(
      path: JellyfinMediaApi.albumArtistsPath,
      searchTerm: searchTerm,
      sortBy: const ['SortName'],
      page: page,
      recursive: false,
    );

    return response.map(
      (dto) => mapper.toPage(
        dto,
        request: page,
        map: mapper.toArtist,
        reason: 'This artist could not be read.',
      ),
    );
  }

  @override
  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    MediaId? artistId,
    String? searchTerm,
  }) async {
    final mapperResult = _api.mapper();
    if (mapperResult case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final mapper = (mapperResult as Ok<BaseItemMapper>).value;

    String? albumArtistId;
    if (artistId != null) {
      final id = _api.localItemId(artistId);
      if (id case Err<String>(:final failure)) return Result.err(failure);
      albumArtistId = (id as Ok<String>).value;
    }

    final response = await _api.queryItems(
      includeItemTypes: const [BaseItemMapper.albumType],
      albumArtistId: albumArtistId,
      searchTerm: searchTerm,
      // A discography reads chronologically; a whole library reads
      // alphabetically.
      sortBy: albumArtistId == null
          ? const ['SortName']
          : const ['ProductionYear', 'SortName'],
      fields: JellyfinMediaApi.detailFields,
      page: page,
    );

    return response.map(
      (dto) => mapper.toPage(
        dto,
        request: page,
        map: mapper.toAlbum,
        reason: 'This album could not be read.',
      ),
    );
  }

  @override
  Future<Result<Page<Track>>> tracks({
    PageRequest page = const PageRequest.first(),
    MediaId? albumId,
    MediaId? artistId,
    String? searchTerm,
  }) async {
    final mapperResult = _api.mapper();
    if (mapperResult case Err<BaseItemMapper>(:final failure)) {
      return Result.err(failure);
    }
    final mapper = (mapperResult as Ok<BaseItemMapper>).value;

    String? parentId;
    if (albumId != null) {
      final id = _api.localItemId(albumId);
      if (id case Err<String>(:final failure)) return Result.err(failure);
      parentId = (id as Ok<String>).value;
    }

    String? trackArtistId;
    if (artistId != null) {
      final id = _api.localItemId(artistId);
      if (id case Err<String>(:final failure)) return Result.err(failure);
      trackArtistId = (id as Ok<String>).value;
    }

    final response = await _api.queryItems(
      includeItemTypes: const [BaseItemMapper.trackType],
      parentId: parentId,
      artistId: trackArtistId,
      searchTerm: searchTerm,
      sortBy: switch ((parentId, trackArtistId)) {
        // An album plays in disc/track order, not alphabetically.
        (final String _, _) => const ['ParentIndexNumber', 'IndexNumber'],
        (_, final String _) => const [
          'Album',
          'ParentIndexNumber',
          'IndexNumber',
        ],
        _ => const ['SortName'],
      },
      page: page,
    );

    return response.map(
      (dto) => mapper.toPage(
        dto,
        request: page,
        map: mapper.toTrack,
        reason: 'This song is unavailable.',
      ),
    );
  }

  @override
  Future<Result<Artist>> artist(MediaId id) =>
      _single(id, (mapper, dto) => mapper.toArtist(dto), 'artist');

  @override
  Future<Result<Album>> album(MediaId id) =>
      _single(id, (mapper, dto) => mapper.toAlbum(dto), 'album');

  @override
  Future<Result<ArtistStats>> artistStats(MediaId artistId) async {
    final idResult = _api.localItemId(artistId);
    if (idResult case Err<String>(:final failure)) return Result.err(failure);
    final id = (idResult as Ok<String>).value;

    final albumCountResult = await _api.queryItems(
      includeItemTypes: const [BaseItemMapper.albumType],
      albumArtistId: id,
      page: const PageRequest(limit: 1),
    );
    if (albumCountResult case Err<ItemsResponseDto>(:final failure)) {
      return Result.err(failure);
    }
    final albumCount =
        (albumCountResult as Ok<ItemsResponseDto>).value.totalRecordCount ?? 0;

    final songCountResult = await _api.queryItems(
      includeItemTypes: const [BaseItemMapper.trackType],
      artistId: id,
      page: const PageRequest(limit: 1),
    );
    if (songCountResult case Err<ItemsResponseDto>(:final failure)) {
      return Result.err(failure);
    }
    final songCount =
        (songCountResult as Ok<ItemsResponseDto>).value.totalRecordCount ?? 0;

    return Result.ok(
      ArtistStats(
        albumCount: albumCount,
        songCount: songCount,
        totalDuration:
            songCount == 0 || songCount > ArtistStats.durationSumLimit
            ? null
            : await _sumDurations(id, songCount),
      ),
    );
  }

  /// Sums [songCount] tracks' running time, page by page — bounded by
  /// [ArtistStats.durationSumLimit] at the call site, so this never reads
  /// more of the library than one artist's own discography.
  Future<Duration?> _sumDurations(String artistItemId, int songCount) async {
    const pageSize = 200;
    var total = Duration.zero;
    var startIndex = 0;

    while (startIndex < songCount) {
      final page = await _api.queryItems(
        includeItemTypes: const [BaseItemMapper.trackType],
        artistId: artistItemId,
        fields: JellyfinMediaApi.durationOnlyFields,
        page: PageRequest(startIndex: startIndex, limit: pageSize),
      );
      if (page case Err<ItemsResponseDto>()) return null;
      final items = (page as Ok<ItemsResponseDto>).value.items ?? const [];
      if (items.isEmpty) break;
      for (final item in items) {
        final ticks = item.runTimeTicks;
        if (ticks != null && ticks > 0) {
          total += Duration(microseconds: ticks ~/ 10);
        }
      }
      startIndex += items.length;
    }
    return total;
  }

  /// Fetches one item and maps it, turning "not there" and "not what we
  /// asked for" into the same honest failure.
  Future<Result<T>> _single<T extends MediaItem>(
    MediaId id,
    T? Function(BaseItemMapper mapper, BaseItemDto dto) map,
    String label,
  ) async {
    final scope = _api.scopeFor(id);
    if (scope case Err<MediaScope>(:final failure)) return Result.err(failure);
    final (:mapper, :itemId) = (scope as Ok<MediaScope>).value;

    final response = await _api.item(itemId);
    if (response case Err<BaseItemDto?>(:final failure)) {
      return Result.err(failure);
    }

    final dto = (response as Ok<BaseItemDto?>).value;
    final item = dto == null ? null : map(mapper, dto);
    if (item == null) {
      return Result.err(
        UnavailableFailure('That $label is no longer in your library.'),
      );
    }
    return Result.ok(item);
  }
}
