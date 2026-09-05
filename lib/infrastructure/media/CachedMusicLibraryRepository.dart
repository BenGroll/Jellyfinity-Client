import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/media/media.dart';
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
  CachedMusicLibraryRepository(this._remote, this._cache, this._context);

  final JellyfinMusicLibraryRepository _remote;
  final MediaCacheStore _cache;
  final JellyfinSessionContext _context;

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
  }) async {
    final isSearch = searchTerm != null && searchTerm.trim().isNotEmpty;
    final result = await read();

    switch (result) {
      case Ok<Page<T>>(:final value):
        if (!isSearch) await _cache.savePage(collectionKey, value);
        return result;
      case Err<Page<T>>(:final failure):
        if (isSearch || !canServeFromCache(failure)) return result;
        final serverId = _context.serverId;
        if (serverId == null) return result;
        final saved = await _cache.readPage<T>(serverId, collectionKey, page);
        return saved == null ? result : Result.ok(saved);
    }
  }

  Future<Result<T>> _item<T extends MediaItem>(
    MediaId id,
    Future<Result<T>> Function() read,
  ) async {
    final result = await read();

    switch (result) {
      case Ok<T>(:final value):
        await _cache.saveItem(value);
        return result;
      case Err<T>(:final failure):
        if (!canServeFromCache(failure)) return result;
        final saved = await _cache.readItem(id);
        return saved is T ? Result.ok(saved) : result;
    }
  }
}
