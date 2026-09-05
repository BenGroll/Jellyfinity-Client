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
  }) {
    return _collection(
      page: page,
      searchTerm: searchTerm,
      collectionKey: artistId == null
          ? MediaCollectionKey.albums
          : MediaCollectionKey.albumsOfArtist(artistId.itemId),
      read: () => _remote.albums(
        page: page,
        artistId: artistId,
        searchTerm: searchTerm,
      ),
      downloadsFallback: artistId == null
          ? null
          : () => _artistAlbumsOffline(artistId, page),
    );
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

  Future<Result<Page<T>>> _collection<T extends MediaItem>({
    required PageRequest page,
    required String? searchTerm,
    required String collectionKey,
    required Future<Result<Page<T>>> Function() read,
    Future<Result<Page<T>>> Function()? downloadsFallback,
  }) async {
    final isSearch = searchTerm != null && searchTerm.trim().isNotEmpty;
    final result = _offline.status.isOffline
        ? _offlineFailure<Page<T>>()
        : await read();

    switch (result) {
      case Ok<Page<T>>(:final value):
        if (!isSearch) await _cache.savePage(collectionKey, value);
        return result;
      case Err<Page<T>>(:final failure):
        if (isSearch || !canServeFromCache(failure)) return result;
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
    final result = _offline.status.isOffline ? _offlineFailure<T>() : await read();

    switch (result) {
      case Ok<T>(:final value):
        await _cache.saveItem(value);
        return result;
      case Err<T>(:final failure):
        if (!canServeFromCache(failure)) return result;
        final saved = await _cache.readItem(id);
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
