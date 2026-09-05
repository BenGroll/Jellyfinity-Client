import 'package:injectable/injectable.dart';

import '../../core/result/partial.dart';
import '../../core/result/result.dart';
import '../../domain/downloads/download_state.dart';
import '../../domain/downloads/DownloadedCollection.dart';
import '../../domain/downloads/DownloadOwner.dart';
import '../../domain/downloads/DownloadStore.dart';
import '../../domain/downloads/TrackDownload.dart';
import '../../domain/media/Album.dart';
import '../../domain/media/artist.dart';
import '../../domain/media/media_availability.dart';
import '../../domain/media/MediaId.dart';
import '../../domain/media/MediaItem.dart';
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

  /// Every artist the profile can play offline (v0.2.3): the ones
  /// downloaded whole (an explicit `downloaded_collections` row), plus any
  /// artist credited on a track that was downloaded on its own or as part
  /// of an album — a single kept song is enough to make its artist
  /// browsable offline.
  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) => _derived<Artist>(
    kind: DownloadOwnerKind.artist,
    page: page,
    searchTerm: searchTerm,
    fromCollection: (c) => c.toArtist(),
    fromTracks: (records, into) {
      for (final record in records) {
        for (final credit in record.artists) {
          final id = credit.id;
          if (id == null || credit.name.isEmpty) continue;
          into.putIfAbsent(
            id,
            () => Artist(
              id: id,
              name: credit.name,
              availability: MediaAvailability.localAndRemote,
            ),
          );
        }
      }
    },
  );

  /// Every album the profile can play offline (v0.2.3): downloaded whole,
  /// or with at least one downloaded track.
  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) => _derived<Album>(
    kind: DownloadOwnerKind.album,
    page: page,
    searchTerm: searchTerm,
    fromCollection: (c) => c.toAlbum(),
    fromTracks: (records, into) {
      for (final record in records) {
        final id = record.albumId;
        final name = record.albumName;
        if (id == null || name == null || name.isEmpty) continue;
        into.putIfAbsent(
          id,
          () => Album(
            id: id,
            name: name,
            availability: MediaAvailability.localAndRemote,
            image: record.image,
          ),
        );
      }
    },
  );

  /// Downloaded playlists. Unlike artists and albums a playlist is never
  /// implied by a loose track — it exists only as an explicit download —
  /// so this reads the collection identities straight through.
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final result = await _store.collections(
      kind: DownloadOwnerKind.playlist,
      searchTerm: searchTerm,
      page: page,
    );
    return result.map(
      (window) => Page<Playlist>(
        content: Partial(
          available: [for (final c in window.items) c.toPlaylist()],
        ),
        startIndex: window.startIndex,
        totalCount: window.totalCount,
        source: PageSource.cache,
      ),
    );
  }

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

  /// Builds one page of downloaded artists or albums by merging the
  /// explicit collection identities with the ones reconstructed from
  /// completed track records, then filtering and windowing in memory.
  ///
  /// In memory is fine here where it would not be for the server library:
  /// a profile's downloads are bounded by what the user chose to keep, not
  /// by the 130k-song scale the paged repositories are built for.
  Future<Result<Page<T>>> _derived<T extends MediaItem>({
    required DownloadOwnerKind kind,
    required PageRequest page,
    required String? searchTerm,
    required T Function(DownloadedCollection) fromCollection,
    required void Function(List<TrackDownload> completed, Map<MediaId, T> into)
    fromTracks,
  }) async {
    final byId = <MediaId, T>{};

    // Explicit collections first — they carry the best name and artwork.
    var request = const PageRequest.first();
    while (true) {
      final result = await _store.collections(kind: kind, page: request);
      if (result case Err<Page<DownloadedCollection>>(:final failure)) {
        return Result.err(failure);
      }
      final window = (result as Ok<Page<DownloadedCollection>>).value;
      for (final collection in window.items) {
        final entity = fromCollection(collection);
        byId[entity.id] = entity;
      }
      final next = window.nextRequest();
      if (next == null) break;
      request = next;
    }

    // Then anything a loose completed track implies.
    final all = await _store.all();
    if (all case Err<List<TrackDownload>>(:final failure)) {
      return Result.err(failure);
    }
    final completed = [
      for (final record in (all as Ok<List<TrackDownload>>).value)
        if (record.state == DownloadState.completed) record,
    ];
    fromTracks(completed, byId);

    final term = searchTerm?.trim().toLowerCase();
    final items = [
      for (final entity in byId.values)
        if (term == null ||
            term.isEmpty ||
            entity.name.toLowerCase().contains(term))
          entity,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final start = page.startIndex.clamp(0, items.length);
    final end = (start + page.limit).clamp(0, items.length);
    return Result.ok(
      Page<T>(
        content: Partial(available: items.sublist(start, end)),
        startIndex: start,
        totalCount: items.length,
        source: PageSource.cache,
      ),
    );
  }
}
