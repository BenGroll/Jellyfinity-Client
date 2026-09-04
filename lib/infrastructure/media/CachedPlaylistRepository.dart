import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/media/media.dart';
import '../jellyfin/identity/JellyfinSessionContext.dart';
import '../jellyfin/media/JellyfinPlaylistRepository.dart';
import '../persistence/media/media_cache_store.dart';
import '../persistence/media/MediaCollectionKey.dart';
import 'cache_fallback.dart';

/// [PlaylistRepository] with the local copy behind the server, on the
/// same terms as [CachedMusicLibraryRepository].
///
/// A playlist is the user's own arrangement, so keeping it readable when
/// the server is down matters more here than anywhere else in the music
/// library: the cache stores each playlist's order, including the entries
/// Jellyfinity could not map, so the list offline is the list the user
/// built.
@LazySingleton(as: PlaylistRepository)
class CachedPlaylistRepository implements PlaylistRepository {
  CachedPlaylistRepository(this._remote, this._cache, this._context);

  final JellyfinPlaylistRepository _remote;
  final MediaCacheStore _cache;
  final JellyfinSessionContext _context;

  @override
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final isSearch = searchTerm != null && searchTerm.trim().isNotEmpty;
    final result = await _remote.playlists(page: page, searchTerm: searchTerm);

    switch (result) {
      case Ok<Page<Playlist>>(:final value):
        if (!isSearch) {
          await _cache.savePage(MediaCollectionKey.playlists, value);
        }
        return result;
      case Err<Page<Playlist>>(:final failure):
        if (isSearch || !canServeFromCache(failure)) return result;
        return await _saved<Playlist>(MediaCollectionKey.playlists, page) ??
            result;
    }
  }

  @override
  Future<Result<Page<Track>>> tracks(
    MediaId playlistId, {
    PageRequest page = const PageRequest.first(),
  }) async {
    final key = MediaCollectionKey.tracksOfPlaylist(playlistId.itemId);
    final result = await _remote.tracks(playlistId, page: page);

    switch (result) {
      case Ok<Page<Track>>(:final value):
        await _cache.savePage(key, value);
        return result;
      case Err<Page<Track>>(:final failure):
        if (!canServeFromCache(failure)) return result;
        return await _saved<Track>(key, page) ?? result;
    }
  }

  /// The saved window, or `null` when there is nothing saved to show —
  /// in which case the caller returns the server's failure, because an
  /// empty list would claim the collection is empty.
  Future<Result<Page<T>>?> _saved<T extends MediaItem>(
    String collectionKey,
    PageRequest page,
  ) async {
    final serverId = _context.serverId;
    if (serverId == null) return null;
    final saved = await _cache.readPage<T>(serverId, collectionKey, page);
    return saved == null ? null : Result.ok(saved);
  }
}
