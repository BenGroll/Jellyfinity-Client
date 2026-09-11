import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/connectivity/OfflineMode.dart';
import '../../domain/media/media.dart';
import '../downloads/DownloadsLibrarySource.dart';
import '../jellyfin/identity/JellyfinSessionContext.dart';
import '../jellyfin/media/JellyfinMusicLibraryRepository.dart';
import '../persistence/media/media_cache_store.dart';
import '../persistence/media/MediaCollectionKey.dart';
import 'cache_fallback.dart';

/// The [MusicLibraryRepository] the rest of Jellyfinity actually uses:
/// the server, with the local copy behind it.
///
/// This is ADR-0010's local/remote repository convention, written once
/// against a real caller as that ADR said it should be. The contract is
/// unchanged, so no screen, cubit or test above it knows there are two
/// sources — it only knows, from [PageSource], whether what it is holding
/// is current.
///
/// ## What it does
///
/// A read goes to the server. If it succeeds, the window is saved exactly
/// as the server ordered it and returned. If the server does not answer
/// ([canServeFromCache]), the saved window is returned instead, marked
/// [PageSource.cache] and with its media reported unreachable. If there
/// is nothing saved, the original failure is returned — an error state is
/// better than an empty list that implies the library is empty.
///
/// ## What it deliberately does not do
///
/// It does not serve the cache first and refresh behind it. That reads
/// well on paper and badly in a list: a window that changes under the
/// user's scroll position is worse than one that arrives a moment later,
/// and every screen here already renders its structure before its data.
///
/// It does not cache searches. ADR-0010 files search results under
/// "temporary cache": they go stale the moment the library changes, they
/// are cheap to ask for again, and saving them would fill the cache with
/// windows nobody browses twice. Offline, a search reports that it needs
/// the server rather than quietly searching a fraction of the library.
@LazySingleton(as: MusicLibraryRepository)
class CachedMusicLibraryRepository implements MusicLibraryRepository {
  CachedMusicLibraryRepository(
    this._remote,
    this._cache,
    this._context,
    this._offline,
    this._downloads,
  );

  final JellyfinMusicLibraryRepository _remote;
  final MediaCacheStore _cache;
  final JellyfinSessionContext _context;

  /// When Jellyfinity is working offline (v0.2.3), a read never leaves the
  /// device: it goes straight to the same saved-copy fallback an
  /// unreachable server would take, without the network round-trip and
  /// timeout first.
  final OfflineMode _offline;

  /// The last resort behind the metadata cache (v0.2.3): an artist or
  /// album the user never browsed online has nothing saved, but a single
  /// downloaded track of it is enough to reconstruct the header and the
  /// part of the track/album list that plays offline. The rest is
  /// reported unavailable, not hidden.
  final DownloadsLibrarySource _downloads;

  /// The failure a read is short-circuited with while offline — a
  /// [RecoverableFailure] so [canServeFromCache] serves the local copy,
  /// exactly as it does for a real timeout.
  static Result<T> _offlineFailure<T>() =>
      const Result.err(RecoverableFailure('You are offline.'));

  @override
  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) {
    return _collection(
      page: page,
      searchTerm: searchTerm,
      collectionKey: MediaCollectionKey.artists,
      read: () => _remote.artists(page: page, searchTerm: searchTerm),
    );
  }

  @override
  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    MediaId? artistId,
    String? searchTerm,
    String? genre,
    int? decadeStart,
  }) {
    // A genre or decade browse is live only (ADR-0034), the same reasoning
    // ADR-0010 gave search: nothing about it is saved, so `_collection`
    // is told to treat it like one — no cache write on success, no cache
    // or downloads fallback on failure, and working offline answers with
    // a failure straight away.
    final isFiltered = genre != null || decadeStart != null;
    return _collection(
      page: page,
      searchTerm: searchTerm,
      live: isFiltered,
      collectionKey: artistId == null
          ? MediaCollectionKey.albums
          : MediaCollectionKey.albumsOfArtist(artistId.itemId),
      read: () => _remote.albums(
        page: page,
        artistId: artistId,
        searchTerm: searchTerm,
        genre: genre,
        decadeStart: decadeStart,
      ),
      downloadsFallback: (artistId == null || isFiltered)
          ? null
          : () => _artistAlbumsOffline(artistId, page),
    );
  }

  @override
  Future<Result<Page<Album>>> recentlyAddedAlbums({
    PageRequest page = const PageRequest.first(),
  }) {
    // Cached like any other browse read (ADR-0010): a served answer is
    // saved, an unreachable server is answered from the saved copy marked
    // [PageSource.cache]. Whether that saved copy is honest to *show* — a
    // server fact presented offline — is the caller's call, not this
    // layer's; see ADR-0027.
    return _collection(
      page: page,
      searchTerm: null,
      collectionKey: MediaCollectionKey.recentlyAddedAlbums,
      read: () => _remote.recentlyAddedAlbums(page: page),
    );
  }

  @override
  Future<Result<Page<Artist>>> favoriteArtists({
    PageRequest page = const PageRequest.first(),
  }) => _favorites(
    MediaKind.artist,
    page,
    () => _remote.favoriteArtists(page: page),
  );

  @override
  Future<Result<Page<Album>>> favoriteAlbums({
    PageRequest page = const PageRequest.first(),
  }) => _favorites(
    MediaKind.album,
    page,
    () => _remote.favoriteAlbums(page: page),
  );

  @override
  Future<Result<Page<Track>>> favoriteTracks({
    PageRequest page = const PageRequest.first(),
  }) => _favorites(
    MediaKind.track,
    page,
    () => _remote.favoriteTracks(page: page),
  );

  /// Favorites are cached per profile (ADR-0028), not per server like every
  /// other browse read: favoriting is the signed-in Jellyfin user's, and
  /// two profiles on one server keep different favorites. A served
  /// first-window read replaces that profile's cached favorites of the
  /// kind wholesale; an unreachable (or deliberately-offline) server is
  /// answered from that saved copy. A profile whose favorites were never
  /// read online has nothing saved, and the failure is the honest answer —
  /// an empty list would say "you have no favorites".
  Future<Result<Page<T>>> _favorites<T extends MediaItem>(
    MediaKind kind,
    PageRequest page,
    Future<Result<Page<T>>> Function() read,
  ) async {
    final accountKey = _accountKey;
    final result = _offline.status.isOffline
        ? _offlineFailure<Page<T>>()
        : await read();

    switch (result) {
      case Ok<Page<T>>(:final value):
        // Only a first-window read is a whole list to replace with; later
        // windows page live but are not cached (offline favorites are the
        // first window, as the metadata cache is "what was browsed").
        if (accountKey != null && value.startIndex == 0) {
          await _cache.replaceFavorites(accountKey, kind, value.items);
        }
        return result;
      case Err<Page<T>>(:final failure):
        if (accountKey == null || !canServeFromCache(failure)) return result;
        final saved = await _cache.readFavorites<T>(accountKey, kind, page);
        if (saved != null) return Result.ok(saved);
        return result;
    }
  }

  /// `server_id/user_id`, or `null` with nobody signed in — the profile a
  /// favorites read and its cache belong to.
  String? get _accountKey {
    final serverId = _context.serverId;
    final userId = _context.userId;
    if (serverId == null || userId == null) return null;
    return '$serverId/$userId';
  }

  @override
  Future<Result<Page<Track>>> tracks({
    PageRequest page = const PageRequest.first(),
    MediaId? albumId,
    MediaId? artistId,
    String? searchTerm,
  }) {
    return _collection(
      page: page,
      searchTerm: searchTerm,
      collectionKey: switch ((albumId, artistId)) {
        (final MediaId album, _) => MediaCollectionKey.tracksOfAlbum(
          album.itemId,
        ),
        (_, final MediaId artist) => MediaCollectionKey.tracksOfArtist(
          artist.itemId,
        ),
        _ => MediaCollectionKey.tracks,
      },
      read: () => _remote.tracks(
        page: page,
        albumId: albumId,
        artistId: artistId,
        searchTerm: searchTerm,
      ),
      downloadsFallback: albumId == null
          ? null
          : () => _albumTracksOffline(albumId, page),
    );
  }

  @override
  Future<Result<Artist>> artist(MediaId id) =>
      _item(id, () => _remote.artist(id));

  @override
  Future<Result<Album>> album(MediaId id) => _item(id, () => _remote.album(id));

  /// Live only, like every write and every derived-not-browsed read in
  /// this repository: nothing here for the cache fallback to serve, so an
  /// unreachable server surfaces its failure directly and the artist page
  /// hides the stats section (`ArtistStats`'s doc comment).
  @override
  Future<Result<ArtistStats>> artistStats(MediaId artistId) =>
      _remote.artistStats(artistId);

  /// Live only, like [artistStats]: similarity is the server's answer and
  /// nothing here caches it. Working offline (v0.2.3) there is genuinely
  /// nothing to attempt, so the read is short-circuited to a
  /// [RecoverableFailure] rather than left to time out — either way the
  /// caller's section is absent (ADR-0029).
  @override
  Future<Result<List<Artist>>> relatedArtists(
    MediaId artistId, {
    int limit = 12,
  }) async {
    if (_offline.status.isOffline) return _offlineFailure<List<Artist>>();
    return _remote.relatedArtists(artistId, limit: limit);
  }

  @override
  Future<Result<List<Album>>> similarAlbums(
    MediaId albumId, {
    int limit = 12,
  }) async {
    if (_offline.status.isOffline) return _offlineFailure<List<Album>>();
    return _remote.similarAlbums(albumId, limit: limit);
  }

  /// Live only, on the same terms as [relatedArtists] (v0.4.4, ADR-0034):
  /// nothing about a genre or a decade is cached, so working offline is
  /// short-circuited rather than left to time out. The caller shows the
  /// entry point as unavailable rather than absent — unlike a related-
  /// media strip, this is a primary way into the library, not a bonus.
  @override
  Future<Result<List<String>>> genres() async {
    if (_offline.status.isOffline) return _offlineFailure<List<String>>();
    return _remote.genres();
  }

  @override
  Future<Result<List<int>>> decades() async {
    if (_offline.status.isOffline) return _offlineFailure<List<int>>();
    return _remote.decades();
  }

  /// Working offline, "random" draws from the signed-in profile's
  /// downloads instead of asking the unreachable server — the one place
  /// in this repository where offline is a different *scope* rather than
  /// a fallback to a saved copy, because there is no saved copy of "the
  /// whole library" to fall back to and a suggestion that cannot play
  /// would be worse than none (v0.4.4, ADR-0034).
  @override
  Future<Result<Album>> randomAlbum() => _offline.status.isOffline
      ? _downloads.randomAlbum()
      : _remote.randomAlbum();

  @override
  Future<Result<Artist>> randomArtist() => _offline.status.isOffline
      ? _downloads.randomArtist()
      : _remote.randomArtist();

  Future<Result<Page<T>>> _collection<T extends MediaItem>({
    required PageRequest page,
    required String? searchTerm,
    required String collectionKey,
    required Future<Result<Page<T>>> Function() read,
    Future<Result<Page<T>>> Function()? downloadsFallback,
    bool live = false,
  }) async {
    final isSearch = searchTerm != null && searchTerm.trim().isNotEmpty;
    final skipsCache = isSearch || live;
    final result = _offline.status.isOffline
        ? _offlineFailure<Page<T>>()
        : await read();

    switch (result) {
      case Ok<Page<T>>(:final value):
        if (!skipsCache) await _cache.savePage(collectionKey, value);
        return result;
      case Err<Page<T>>(:final failure):
        if (skipsCache || !canServeFromCache(failure)) return result;
        final serverId = _context.serverId;
        if (serverId != null) {
          final saved = await _cache.readPage<T>(serverId, collectionKey, page);
          if (saved != null) return Result.ok(saved);
        }
        // Nothing was ever browsed here, but a downloaded track of it can
        // still stand in for the part that plays offline (v0.2.3).
        if (downloadsFallback != null) {
          final derived = await downloadsFallback();
          if (derived.isOk) return derived;
        }
        return result;
    }
  }

  Future<Result<T>> _item<T extends MediaItem>(
    MediaId id,
    Future<Result<T>> Function() read,
  ) async {
    final result = _offline.status.isOffline
        ? _offlineFailure<T>()
        : await read();

    switch (result) {
      case Ok<T>(:final value):
        await _cache.saveItem(value);
        // A freshly-fetched header carries live favorite state; fold it
        // into the per-profile favorites cache so an un-favorite made on
        // another client is caught the next time the item is opened here
        // (ADR-0028). The list read is the full reconcile; this keeps the
        // set from drifting between them.
        final accountKey = _accountKey;
        final favorite = switch (value) {
          Artist(:final isFavorite) => isFavorite,
          Album(:final isFavorite) => isFavorite,
          Track(:final isFavorite) => isFavorite,
          _ => null,
        };
        if (accountKey != null && favorite != null) {
          await _cache.setFavorite(
            accountKey,
            value.id,
            value.kind,
            favorite: favorite,
          );
        }
        return result;
      case Err<T>(:final failure):
        if (!canServeFromCache(failure)) return result;
        final saved = await _cache.readItem(id, accountKey: _accountKey);
        if (saved is T) return Result.ok(saved);
        return await _itemFromDownloads<T>(id) ?? result;
    }
  }

  /// An artist or album header reconstructed from the profile's downloads
  /// when nothing was saved for it (v0.2.3). `null` for any other type, or
  /// when the profile has nothing downloaded for [id].
  Future<Result<T>?> _itemFromDownloads<T extends MediaItem>(MediaId id) async {
    Result<MediaItem>? derived;
    if (T == Artist) {
      derived = await _downloads.artist(id);
    } else if (T == Album) {
      derived = await _downloads.album(id);
    }
    if (derived case Ok<MediaItem>(:final value) when value is T) {
      return Result.ok(value);
    }
    return null;
  }

  Future<Result<Page<Track>>> _albumTracksOffline(
    MediaId albumId,
    PageRequest page,
  ) async {
    final cached = await _cache.readItem(albumId);
    return _downloads.albumTracks(
      albumId,
      page: page,
      knownTrackCount: cached is Album ? cached.trackCount : null,
    );
  }

  Future<Result<Page<Album>>> _artistAlbumsOffline(
    MediaId artistId,
    PageRequest page,
  ) async {
    final serverId = _context.serverId;
    int? knownAlbumCount;
    if (serverId != null) {
      final window = await _cache.readPage<Album>(
        serverId,
        MediaCollectionKey.albumsOfArtist(artistId.itemId),
        const PageRequest.first(),
      );
      knownAlbumCount = window?.totalCount;
    }
    return _downloads.artistAlbums(
      artistId,
      page: page,
      knownAlbumCount: knownAlbumCount,
    );
  }
}
