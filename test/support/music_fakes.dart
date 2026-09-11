import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/partial.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/media/media.dart';
import 'package:jellyfinity/features/favorites/presentation/favorites_cubits.dart';
import 'package:jellyfinity/features/home/presentation/HomeFavoritesCubit.dart';
import 'package:jellyfinity/features/home/presentation/RecentlyAddedCubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/artist_stats_cubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/media_detail_cubit.dart';
import 'package:jellyfinity/features/music/presentation/detail/related_media_cubits.dart';
import 'package:jellyfinity/features/music/presentation/library/music_collection_cubits.dart';
import 'package:jellyfinity/features/music/presentation/search/music_search_cubit.dart';
import 'package:jellyfinity/infrastructure/downloads/DownloadsLibrarySource.dart';

import 'offline_fakes.dart';

const String testServerId = 'server-1';

MediaId mediaId(String itemId) =>
    MediaId(serverId: testServerId, itemId: itemId);

Artist testArtist(String id, {String? name, bool isFavorite = false}) =>
    Artist(id: mediaId(id), name: name ?? 'Artist $id', isFavorite: isFavorite);

Album testAlbum(
  String id, {
  String? name,
  List<ArtistRef>? artists,
  bool isFavorite = false,
}) => Album(
  id: mediaId(id),
  name: name ?? 'Album $id',
  artists: artists ?? [const ArtistRef(name: 'Miles Davis')],
  productionYear: 1959,
  trackCount: 5,
  isFavorite: isFavorite,
);

Track testTrack(
  String id, {
  String? name,
  String? albumId,
  int? trackNumber,
  bool isFavorite = false,
  MediaAvailability availability = MediaAvailability.remoteOnly,
}) => Track(
  id: mediaId(id),
  name: name ?? 'Song $id',
  artists: const [ArtistRef(name: 'Miles Davis')],
  albumId: albumId == null ? null : mediaId(albumId),
  albumName: albumId == null ? null : 'Album $albumId',
  trackNumber: trackNumber,
  duration: const Duration(minutes: 3, seconds: 42),
  isFavorite: isFavorite,
  availability: availability,
);

Playlist testPlaylist(String id, {String? name}) =>
    Playlist(id: mediaId(id), name: name ?? 'Playlist $id', itemCount: 3);

/// A track as a playlist read returns it — carrying its true position in
/// the playlist (v0.4.2) and the entry id that makes the row editable
/// (v0.1.2's completion).
///
/// [position] defaults to the index the caller is most likely building
/// with; pass it explicitly whenever unreadable entries sit in the list,
/// because that is the case every position bug hides in. `entryId: null`
/// stands in for a row read from the saved copy or a download snapshot.
PlaylistTrack testPlaylistTrack(
  String id, {
  String? entryId = _defaultEntryId,
  String? name,
  int position = 0,
}) => PlaylistTrack(
  position: position,
  entryId: entryId == _defaultEntryId ? 'entry-$id' : entryId,
  id: mediaId(id),
  name: name ?? 'Song $id',
  artists: const [ArtistRef(name: 'Miles Davis')],
);

/// Distinguishes "caller said nothing" from an explicit `entryId: null`.
const String _defaultEntryId = '\u0000default';

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

  /// What [recentlyAddedAlbums] answers with — its own list so a test can
  /// give Home's "Recently added" strip (v0.3.3) something different from
  /// the alphabetical [albumList], or leave it empty so the section is
  /// simply absent.
  List<Album> recentlyAddedList = [];

  /// What the favorites reads answer with (v0.3.4). Their own lists so a
  /// test can star a subset without touching [artistList]/[albumList]/
  /// [trackList], or leave them empty so the Favorites destination and its
  /// Home section are simply absent.
  List<Artist> favoriteArtistList = [];
  List<Album> favoriteAlbumList = [];
  List<Track> favoriteTrackList = [];

  /// What [relatedArtists] and [similarAlbums] answer with (v0.3.5) —
  /// their own lists so a test can give the detail-page "you might also
  /// like" strips something, or leave them empty so the section is simply
  /// absent.
  List<Artist> relatedArtistList = [];
  List<Album> similarAlbumList = [];

  /// Fails only the similarity reads — the shape of a server that answers
  /// queries but has no `/Similar` endpoint (older-but-supported).
  Failure? similarityFailure;

  /// Per-album and per-artist track lists, consulted before [trackList]
  /// when a scoped `tracks` read names one — lets a test give an album
  /// and an artist different track sets in the same case.
  final Map<String, List<Track>> tracksByAlbum = {};
  final Map<String, List<Track>> tracksByArtist = {};

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
  Future<Result<Page<Album>>> recentlyAddedAlbums({
    PageRequest page = const PageRequest.first(),
  }) async {
    calls.add((method: 'recentlyAddedAlbums', page: page, searchTerm: null));
    await _pause();
    final failed = failure;
    if (failed != null) return Result.err(failed);
    final window = windowOf(
      recentlyAddedList,
      page,
      unavailable: unavailable,
      source: source,
    );
    // The real repository reports this bounded list as complete, never as
    // a window into every album — mirror that so paging logic that reads
    // `hasMore` behaves the same against the fake.
    return Result.ok(
      Page<Album>(
        content: window.content,
        startIndex: window.startIndex,
        totalCount: window.startIndex + window.consumed,
        source: window.source,
      ),
    );
  }

  @override
  Future<Result<Page<Artist>>> favoriteArtists({
    PageRequest page = const PageRequest.first(),
  }) async {
    calls.add((method: 'favoriteArtists', page: page, searchTerm: null));
    await _pause();
    return _answer(favoriteArtistList, page, null, (a) => a.name);
  }

  @override
  Future<Result<Page<Album>>> favoriteAlbums({
    PageRequest page = const PageRequest.first(),
  }) async {
    calls.add((method: 'favoriteAlbums', page: page, searchTerm: null));
    await _pause();
    return _answer(favoriteAlbumList, page, null, (a) => a.name);
  }

  @override
  Future<Result<Page<Track>>> favoriteTracks({
    PageRequest page = const PageRequest.first(),
  }) async {
    calls.add((method: 'favoriteTracks', page: page, searchTerm: null));
    await _pause();
    return _answer(favoriteTrackList, page, null, (t) => t.name);
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
    final scoped = albumId != null
        ? tracksByAlbum[albumId.itemId]
        : artistId != null
        ? tracksByArtist[artistId.itemId]
        : null;
    return _answer(scoped ?? trackList, page, searchTerm, (t) => t.name);
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

  @override
  Future<Result<List<Artist>>> relatedArtists(
    MediaId artistId, {
    int limit = 12,
  }) async {
    calls.add((
      method: 'relatedArtists',
      page: const PageRequest.first(),
      searchTerm: null,
    ));
    await _pause();
    final failed = similarityFailure ?? failure;
    if (failed != null) return Result.err(failed);
    return Result.ok(relatedArtistList.take(limit).toList());
  }

  @override
  Future<Result<List<Album>>> similarAlbums(
    MediaId albumId, {
    int limit = 12,
  }) async {
    calls.add((
      method: 'similarAlbums',
      page: const PageRequest.first(),
      searchTerm: null,
    ));
    await _pause();
    final failed = similarityFailure ?? failure;
    if (failed != null) return Result.err(failed);
    return Result.ok(similarAlbumList.take(limit).toList());
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

  /// The source every returned window reports — flip to
  /// [PageSource.cache] to stand in for an offline read served from the
  /// saved copy.
  PageSource source = PageSource.server;

  /// Per-playlist track lists, consulted before [trackList] when the
  /// requested playlist has an entry — lets one test drive several
  /// playlists at once.
  final Map<String, List<Track>> tracksByPlaylist = {};

  @override
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final failed = failure;
    if (failed != null) return Result.err(failed);
    return Result.ok(windowOf(playlistList, page, source: source));
  }

  /// How many times a playlist's tracks have been read — how a test sees
  /// that an edit reloaded the list it changed.
  int trackReads = 0;

  @override
  Future<Result<Page<Track>>> tracks(
    MediaId playlistId, {
    PageRequest page = const PageRequest.first(),
  }) async {
    trackReads++;
    final failed = failure;
    if (failed != null) return Result.err(failed);
    final list = tracksByPlaylist[playlistId.itemId] ?? trackList;
    return Result.ok(
      windowOf(list, page, unavailable: unavailable, source: source),
    );
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

  /// Every curation call, in order, for a test to assert against
  /// (v0.1.2's completion).
  final List<({String name, List<MediaId> trackIds})> createCalls = [];
  final List<({MediaId playlistId, String name})> renameCalls = [];
  final List<MediaId> deleteCalls = [];
  final List<({MediaId playlistId, List<String> entryIds})> removeEntryCalls =
      [];
  final List<({MediaId playlistId, String entryId, int newIndex})> moveCalls =
      [];

  /// Set to make the next [moveEntry] fail, the way a server rejecting a
  /// move does.
  Failure? moveFailure;

  /// The id [create] answers with. A test that cares where the new
  /// playlist went sets this.
  MediaId createdId = const MediaId(serverId: 'server-1', itemId: 'new-pl');

  /// Set to fail only the writes, leaving reads working — the shape of a
  /// server that answers queries but refuses a mutation.
  Failure? writeFailure;

  Result<T> _write<T>(T value) {
    final failed = writeFailure ?? failure;
    return failed != null ? Result.err(failed) : Result.ok(value);
  }

  @override
  Future<Result<MediaId>> create(
    String name, {
    List<MediaId> trackIds = const [],
  }) async {
    createCalls.add((name: name, trackIds: trackIds));
    return _write(createdId);
  }

  @override
  Future<Result<void>> rename(MediaId playlistId, String name) async {
    renameCalls.add((playlistId: playlistId, name: name));
    return _write(null);
  }

  @override
  Future<Result<void>> moveEntry(
    MediaId playlistId,
    String entryId,
    int newIndex,
  ) async {
    moveCalls.add((
      playlistId: playlistId,
      entryId: entryId,
      newIndex: newIndex,
    ));
    final failed = moveFailure;
    if (failed != null) return Result.err(failed);
    return _write(null);
  }

  @override
  Future<Result<void>> delete(MediaId playlistId) async {
    deleteCalls.add(playlistId);
    return _write(null);
  }

  @override
  Future<Result<void>> removeEntries(
    MediaId playlistId,
    List<String> entryIds,
  ) async {
    removeEntryCalls.add((playlistId: playlistId, entryIds: entryIds));
    return _write(null);
  }
}

/// A [FavoritesRepository] a test controls, recording every call.
///
/// Pass [library] to have a successful toggle also move the item in and
/// out of that repository's favorite lists — so a heart tapped on a detail
/// screen actually changes what the Favorites destination reads back,
/// which is what "favoriting reflects in the destination" needs.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository({this.library});

  final FakeMusicLibraryRepository? library;
  Failure? failure;
  final List<({MediaId id, bool favorite, MediaKind? kind})> calls = [];

  @override
  Future<Result<void>> setFavorite(
    MediaId id, {
    required bool favorite,
    MediaKind? kind,
  }) async {
    calls.add((id: id, favorite: favorite, kind: kind));
    final failed = failure;
    if (failed != null) return Result.err(failed);
    _applyToLibrary(id, favorite: favorite, kind: kind);
    return const Result.ok(null);
  }

  void _applyToLibrary(MediaId id, {required bool favorite, MediaKind? kind}) {
    final lib = library;
    if (lib == null) return;
    switch (kind) {
      case MediaKind.artist:
        lib.favoriteArtistList.removeWhere((a) => a.id == id);
        if (favorite) {
          lib.favoriteArtistList.addAll(
            lib.artistList.where((a) => a.id == id),
          );
        }
      case MediaKind.album:
        lib.favoriteAlbumList.removeWhere((a) => a.id == id);
        if (favorite) {
          lib.favoriteAlbumList.addAll(lib.albumList.where((a) => a.id == id));
        }
      case MediaKind.track:
        lib.favoriteTrackList.removeWhere((t) => t.id == id);
        if (favorite) {
          lib.favoriteTrackList.addAll(lib.trackList.where((t) => t.id == id));
        }
      case _:
        break;
    }
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
/// A [DownloadsLibrarySource] that answers from lists a test sets, so the
/// "Downloaded" filter and the offline-search fallback can be exercised
/// without a real download store.
class FakeDownloadsLibrarySource implements DownloadsLibrarySource {
  List<Artist> artistList = [];
  List<Album> albumList = [];
  List<Track> trackList = [];
  List<Playlist> playlistList = [];

  Page<T> _page<T extends MediaItem>(List<T> all, String? term) {
    final matches = term == null || term.trim().isEmpty
        ? all
        : all
              .where(
                (item) =>
                    item.name.toLowerCase().contains(term.trim().toLowerCase()),
              )
              .toList();
    return Page<T>(
      content: Partial(available: matches),
      startIndex: 0,
      totalCount: matches.length,
      source: PageSource.cache,
    );
  }

  @override
  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async => Result.ok(_page(artistList, searchTerm));

  @override
  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async => Result.ok(_page(albumList, searchTerm));

  @override
  Future<Result<Page<Track>>> tracks({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async => Result.ok(_page(trackList, searchTerm));

  @override
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async => Result.ok(_page(playlistList, searchTerm));

  @override
  Future<Result<Artist>> artist(MediaId id) async {
    for (final artist in artistList) {
      if (artist.id == id) return Result.ok(artist);
    }
    return const Result.err(RecoverableFailure('Not on this device.'));
  }

  @override
  Future<Result<Album>> album(MediaId id) async {
    for (final album in albumList) {
      if (album.id == id) return Result.ok(album);
    }
    return const Result.err(RecoverableFailure('Not on this device.'));
  }

  @override
  Future<Result<Playlist>> playlist(MediaId id) async {
    for (final playlist in playlistList) {
      if (playlist.id == id) return Result.ok(playlist);
    }
    return const Result.err(RecoverableFailure('Not on this device.'));
  }

  @override
  Future<Result<Page<Track>>> albumTracks(
    MediaId albumId, {
    PageRequest page = const PageRequest.first(),
    int? knownTrackCount,
  }) async => Result.ok(
    _page(trackList.where((t) => t.albumId == albumId).toList(), null),
  );

  @override
  Future<Result<Page<Album>>> artistAlbums(
    MediaId artistId, {
    PageRequest page = const PageRequest.first(),
    int? knownAlbumCount,
  }) async => Result.ok(_page(albumList, null));
}

/// Mirrors `registerAuthCubits`; call it before pumping.
void registerMusicCubits({
  required FakeMusicLibraryRepository music,
  FakePlaylistRepository? playlists,
  FakeMediaMetadataRepository? metadata,
  FakeFavoritesRepository? favorites,
  FakeDownloadsLibrarySource? downloads,
  FakeOfflineMode? offline,
}) {
  final getIt = GetIt.instance;
  final playlistRepository = playlists ?? FakePlaylistRepository();
  final metadataRepository = metadata ?? FakeMediaMetadataRepository();
  final favoritesRepository = favorites ?? FakeFavoritesRepository();
  final downloadsSource = downloads ?? FakeDownloadsLibrarySource();
  final offlineMode = offline ?? FakeOfflineMode();

  getIt
    ..registerFactory<ArtistsCubit>(
      () => ArtistsCubit(music, downloadsSource, offlineMode),
    )
    ..registerFactory<AlbumsCubit>(
      () => AlbumsCubit(music, downloadsSource, offlineMode),
    )
    ..registerFactory<SongsCubit>(
      () => SongsCubit(music, downloadsSource, offlineMode),
    )
    ..registerFactory<PlaylistsCubit>(
      () => PlaylistsCubit(playlistRepository, downloadsSource, offlineMode),
    )
    ..registerFactory<PlaylistTracksCubit>(
      () => PlaylistTracksCubit(playlistRepository, offlineMode),
    )
    ..registerFactory<ArtistDetailCubit>(
      () => ArtistDetailCubit(music, offlineMode),
    )
    ..registerFactory<ArtistStatsCubit>(
      () => ArtistStatsCubit(music, offlineMode),
    )
    ..registerFactory<RelatedArtistsCubit>(
      () => RelatedArtistsCubit(music, offlineMode),
    )
    ..registerFactory<AlbumDetailCubit>(
      () => AlbumDetailCubit(music, offlineMode),
    )
    ..registerFactory<SimilarAlbumsCubit>(
      () => SimilarAlbumsCubit(music, offlineMode),
    )
    ..registerFactory<PlaylistDetailCubit>(
      () => PlaylistDetailCubit(metadataRepository, offlineMode),
    )
    ..registerFactory<MusicSearchCubit>(
      () => MusicSearchCubit(
        music,
        playlistRepository,
        downloadsSource,
        offlineMode,
      ),
    )
    // Home's "Recently added" strip (v0.3.3) reads this straight from
    // getIt, and Home is the app's first route.
    ..registerFactory<RecentlyAddedCubit>(() => RecentlyAddedCubit(music))
    // The Favorites destination and Home's "Favorites" strip (v0.3.4).
    ..registerFactory<FavoriteArtistsCubit>(
      () => FavoriteArtistsCubit(music, offlineMode),
    )
    ..registerFactory<FavoriteAlbumsCubit>(
      () => FavoriteAlbumsCubit(music, offlineMode),
    )
    ..registerFactory<FavoriteTracksCubit>(
      () => FavoriteTracksCubit(music, offlineMode),
    )
    ..registerFactory<HomeFavoritesCubit>(() => HomeFavoritesCubit(music))
    ..registerSingleton<PlaylistRepository>(playlistRepository)
    ..registerSingleton<FavoritesRepository>(favoritesRepository);
  addTearDown(getIt.reset);
}

/// Registers a fake [RecentlyAddedCubit] factory into `getIt` — Home is
/// the app's first route, so every [pumpApp] test reaches it and needs
/// this. Guarded against a test that already registered one (a music
/// screen test calls `registerMusicCubits`, which does). [pumpApp] calls
/// it by default; pass [music] to control what "Recently added" shows.
void registerRecentlyAddedCubit({FakeMusicLibraryRepository? music}) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<RecentlyAddedCubit>()) return;
  final repository = music ?? FakeMusicLibraryRepository();
  getIt.registerFactory<RecentlyAddedCubit>(
    () => RecentlyAddedCubit(repository),
  );
  addTearDown(getIt.reset);
}

/// Registers the favorites cubits (v0.3.4) into `getIt` — Home's
/// "Favorites" strip reads [HomeFavoritesCubit] straight from it, and the
/// Favorites destination reads the three paged cubits. Guarded like
/// [registerRecentlyAddedCubit]; [pumpApp] calls it by default. Pass
/// [music] to control what favorites show.
void registerFavoritesCubits({FakeMusicLibraryRepository? music}) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<HomeFavoritesCubit>()) return;
  final repository = music ?? FakeMusicLibraryRepository();
  final offlineMode = FakeOfflineMode();
  getIt
    ..registerFactory<HomeFavoritesCubit>(() => HomeFavoritesCubit(repository))
    ..registerFactory<FavoriteArtistsCubit>(
      () => FavoriteArtistsCubit(repository, offlineMode),
    )
    ..registerFactory<FavoriteAlbumsCubit>(
      () => FavoriteAlbumsCubit(repository, offlineMode),
    )
    ..registerFactory<FavoriteTracksCubit>(
      () => FavoriteTracksCubit(repository, offlineMode),
    );
  addTearDown(getIt.reset);
}
