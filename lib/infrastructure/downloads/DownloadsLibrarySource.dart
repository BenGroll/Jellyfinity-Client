import 'package:injectable/injectable.dart';

import '../../core/result/partial.dart';
import '../../core/result/result.dart';
import '../../domain/downloads/DownloadedCollection.dart';
import '../../domain/downloads/DownloadOwner.dart';
import '../../domain/downloads/DownloadStore.dart';
import '../../domain/media/Album.dart';
import '../../domain/media/artist.dart';
import '../../domain/media/page.dart';
import '../../domain/media/Playlist.dart';
import '../../domain/media/Track.dart';

/// The signed-in profile's downloads, read as ordinary library windows
/// (v0.2.3).
///
/// This is what makes downloaded music discoverable through the familiar
/// screens when the server is unavailable, and what the "Downloaded"
/// filter reads directly: it turns the per-track records and the
/// downloaded-collection identities into the same `Page<Artist>` /
/// `Page<Album>` / `Page<Track>` / `Page<Playlist>` the library cubits
/// already render, marked [PageSource.cache] so a screen still shows that
/// what it holds is the local copy.
///
/// It is deliberately not a `MusicLibraryRepository` implementation: it
/// answers a narrower question ("what has this profile downloaded"), it
/// is only ever a fallback or an explicit filter, and folding it into the
/// repository contract would force every caller to reason about a third
/// source. `CachedMusicLibraryRepository` and the library cubits reach
/// for it explicitly instead.
@lazySingleton
class DownloadsLibrarySource {
  DownloadsLibrarySource(this._store);

  final DownloadStore _store;

  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) => _collections(
    DownloadOwnerKind.artist,
    page,
    searchTerm,
    (collection) => collection.toArtist(),
  );

  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) => _collections(
    DownloadOwnerKind.album,
    page,
    searchTerm,
    (collection) => collection.toAlbum(),
  );

  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) => _collections(
    DownloadOwnerKind.playlist,
    page,
    searchTerm,
    (collection) => collection.toPlaylist(),
  );

  Future<Result<Page<Track>>> tracks({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final result = await _store.searchTrackDownloads(
      searchTerm: searchTerm,
      page: page,
    );
    return result.map(
      (window) => Page<Track>(
        content: Partial(
          available: [for (final record in window.items) record.toTrack()],
        ),
        startIndex: window.startIndex,
        totalCount: window.totalCount,
        source: PageSource.cache,
      ),
    );
  }

  Future<Result<Page<T>>> _collections<T>(
    DownloadOwnerKind kind,
    PageRequest page,
    String? searchTerm,
    T Function(DownloadedCollection) toEntity,
  ) async {
    final result = await _store.collections(
      kind: kind,
      searchTerm: searchTerm,
      page: page,
    );
    return result.map(
      (window) => Page<T>(
        content: Partial(
          available: [for (final collection in window.items) toEntity(collection)],
        ),
        startIndex: window.startIndex,
        totalCount: window.totalCount,
        source: PageSource.cache,
      ),
    );
  }
}
