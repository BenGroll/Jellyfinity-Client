import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/music/presentation/detail/artist_stats_cubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/search/music_search_cubit.dart';

const String testServerId = 'server-1';

MediaId mediaId(String itemId) =>
    MediaId(serverId: testServerId, itemId: itemId);

Artist testArtist(String id, {String? name}) =>
    Artist(id: mediaId(id), name: name ?? 'Artist $id');

Album testAlbum(String id, {String? name, List<ArtistRef>? artists}) => Album(
  id: mediaId(id),
  name: name ?? 'Album $id',
  artists: artists ?? [const ArtistRef(name: 'Miles Davis')],
  productionYear: 1959,
  trackCount: 5,
);

Track testTrack(
  String id, {
  String? name,
  String? albumId,
  int? trackNumber,
  MediaAvailability availability = MediaAvailability.remoteOnly,
}) => Track(
  id: mediaId(id),
  name: name ?? 'Song $id',
  artists: const [ArtistRef(name: 'Miles Davis')],
  albumId: albumId == null ? null : mediaId(albumId),
  albumName: albumId == null ? null : 'Album $albumId',
  trackNumber: trackNumber,
  duration: const Duration(minutes: 3, seconds: 42),
  availability: availability,
);

Playlist testPlaylist(String id, {String? name}) =>
    Playlist(id: mediaId(id), name: name ?? 'Playlist $id', itemCount: 3);

/// One window of [all], as the repositories would return it.
Page<T> windowOf<T extends MediaItem>(
  List<T> all,
  PageRequest request, {
  List<UnavailableItem> unavailable = const [],
  PageSource source = PageSource.server,
}) {
  final start = request.startIndex.clamp(0, all.length);
  final end = (start + request.limit).clamp(0, all.length);
  return Page<T>(
    content: Partial(
      available: all.sublist(start, end),
      unavailable: start == 0 ? unavailable : const [],
    ),
    startIndex: start,
    totalCount: all.length + unavailable.length,
    source: source,
  );
}

/// A [MusicLibraryRepository] a widget or cubit test fully controls.
///
/// Holds whole lists and windows them on request, so a test can say "there
/// are 250 songs" and the paging behaviour under test is real.
class FakeMusicLibraryRepository implements MusicLibraryRepository {
  List<Artist> artistList = [];
  List<Album> albumList = [];
  List<Track> trackList = [];

  List<UnavailableItem> unavailable = const [];
  PageSource source = PageSource.server;

  /// When set, every read fails with it.
  Failure? failure;

  /// How long a read takes. Non-zero lets a widget test observe the
  /// loading frame before the answer arrives.
  Duration responseDelay = Duration.zero;

  /// Fails only reads after the first — the "next window failed" case.
  Failure? failureAfterFirstPage;

  /// Every request that reached the repository, in order.
  final List<({String method, PageRequest page, String? searchTerm})> calls =
      [];

  @override
  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    calls.add((method: 'artists', page: page, searchTerm: searchTerm));
    await _pause();
    return _answer(artistList, page, searchTerm, (a) => a.name);
  }

  @override
  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    MediaId? artistId,
    String? searchTerm,
  }) async {
    calls.add((method: 'albums', page: page, searchTerm: searchTerm));
    await _pause();
    return _answer(albumList, page, searchTerm, (a) => a.name);
  }

  @override
  Future<Result<Page<Track>>> tracks({
    PageRequest page = const PageRequest.first(),
    MediaId? albumId,
    MediaId? artistId,
    String? searchTerm,
  }) async {
    calls.add((method: 'tracks', page: page, searchTerm: searchTerm));
    await _pause();
    return _answer(trackList, page, searchTerm, (t) => t.name);
  }

  @override
  Future<Result<Artist>> artist(MediaId id) async {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    for (final artist in artistList) {
      if (artist.id == id) return Result.ok(artist);
    }
    return const Result.err(UnavailableFailure('No such artist.'));
  }

  @override
  Future<Result<Album>> album(MediaId id) async {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    for (final album in albumList) {
      if (album.id == id) return Result.ok(album);
    }
    return const Result.err(UnavailableFailure('No such album.'));
  }

  /// What [artistStats] answers next; `null` (the default) fails with
  /// [UnavailableFailure] so a test must opt in to a value.
  ArtistStats? stats;
  Failure? statsFailure;

  @override
  Future<Result<ArtistStats>> artistStats(MediaId artistId) async {
    final failed = statsFailure ?? failure;
    if (failed != null) return Result.err(failed);
    final value = stats;
    if (value == null) {
      return const Result.err(UnavailableFailure('No stats set.'));
    }
    return Result.ok(value);
  }

  /// Lets a widget test see the loading frame before the answer lands.
  Future<void> _pause() async {
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
  }

  Result<Page<T>> _answer<T extends MediaItem>(
    List<T> all,
    PageRequest page,
    String? searchTerm,
    String Function(T item) nameOf,
  ) {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    if (page.startIndex > 0 && failureAfterFirstPage != null) {
      return Result.err(failureAfterFirstPage!);
    }

    // The real repositories match server-side; the fake matches here
    // only so a test can say what a search returns.
    final matching = searchTerm == null || searchTerm.trim().isEmpty
        ? all
        : all
              .where(
                (item) => nameOf(
                  item,
                ).toLowerCase().contains(searchTerm.toLowerCase()),
              )
              .toList();

    return Result.ok(
      windowOf(matching, page, unavailable: unavailable, source: source),
    );
  }
}

/// A [PlaylistRepository] a test controls, on the same terms.
class FakePlaylistRepository implements PlaylistRepository {
  List<Playlist> playlistList = [];
  List<Track> trackList = [];
  List<UnavailableItem> unavailable = const [];
  Failure? failure;

  @override
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    return Result.ok(windowOf(playlistList, page));
  }

  @override
  Future<Result<Page<Track>>> tracks(
    MediaId playlistId, {
    PageRequest page = const PageRequest.first(),
  }) async {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    return Result.ok(windowOf(trackList, page, unavailable: unavailable));
  }

  /// Every `addTracks` call, in order, for a test to assert against.
  final List<({MediaId playlistId, List<MediaId> trackIds})> addTracksCalls =
      [];

  @override
  Future<Result<void>> addTracks(
    MediaId playlistId,
    List<MediaId> trackIds,
  ) async {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    addTracksCalls.add((playlistId: playlistId, trackIds: trackIds));
    return const Result.ok(null);
  }
}

/// A [FavoritesRepository] a test controls, recording every call.
class FakeFavoritesRepository implements FavoritesRepository {
  Failure? failure;
  final List<({MediaId id, bool favorite})> calls = [];

  @override
  Future<Result<void>> setFavorite(MediaId id, {required bool favorite}) async {
    calls.add((id: id, favorite: favorite));
    final failed = failure;
    if (failed != null) return Result.err(failed);
    return const Result.ok(null);
  }
}

/// A [MediaMetadataRepository] that answers from a fixed set of items.
class FakeMediaMetadataRepository implements MediaMetadataRepository {
  List<MediaItem> items = [];
  Failure? failure;

  @override
  Future<Result<MediaItem>> item(MediaId id) async {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    for (final item in items) {
      if (item.id == id) return Result.ok(item);
    }
    return const Result.err(UnavailableFailure('No such item.'));
  }
}

/// Registers the music cubits against fake repositories, for tests that
/// pump real music screens through the router.
///
/// Mirrors `registerAuthCubits`; call it before pumping.
void registerMusicCubits({
  required FakeMusicLibraryRepository music,
  FakePlaylistRepository? playlists,
  FakeMediaMetadataRepository? metadata,
  FakeFavoritesRepository? favorites,
}) {
  final getIt = GetIt.instance;
  final playlistRepository = playlists ?? FakePlaylistRepository();
  final metadataRepository = metadata ?? FakeMediaMetadataRepository();
  final favoritesRepository = favorites ?? FakeFavoritesRepository();

  getIt
    ..registerFactory<ArtistsCubit>(() => ArtistsCubit(music))
    ..registerFactory<AlbumsCubit>(() => AlbumsCubit(music))
    ..registerFactory<SongsCubit>(() => SongsCubit(music))
    ..registerFactory<PlaylistsCubit>(() => PlaylistsCubit(playlistRepository))
    ..registerFactory<PlaylistTracksCubit>(
      () => PlaylistTracksCubit(playlistRepository),
    )
    ..registerFactory<ArtistDetailCubit>(() => ArtistDetailCubit(music))
    ..registerFactory<ArtistStatsCubit>(() => ArtistStatsCubit(music))
    ..registerFactory<AlbumDetailCubit>(() => AlbumDetailCubit(music))
    ..registerFactory<PlaylistDetailCubit>(
      () => PlaylistDetailCubit(metadataRepository),
    )
    ..registerFactory<MusicSearchCubit>(
      () => MusicSearchCubit(music, playlistRepository),
    )
    ..registerSingleton<PlaylistRepository>(playlistRepository)
    ..registerSingleton<FavoritesRepository>(favoritesRepository);
  addTearDown(getIt.reset);
}
