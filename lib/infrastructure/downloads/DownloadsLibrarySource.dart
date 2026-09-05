import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
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

  /// The downloaded identity of one artist — an explicit
  /// `downloaded_collections` row, or, failing that, reconstructed from
  /// any completed track that credits [id] (v0.2.3). A [RecoverableFailure]
  /// when the profile has nothing downloaded for it, so a caller falling
  /// back here treats "no downloads" the same as "server unreachable".
  Future<Result<Artist>> artist(MediaId id) async {
    final named = await _namedCollection(DownloadOwnerKind.artist, id);
    if (named != null) return Result.ok(named.toArtist());

    final completed = await _completedRecords();
    if (completed case Err<List<TrackDownload>>(:final failure)) {
      return Result.err(failure);
    }
    for (final record in (completed as Ok<List<TrackDownload>>).value) {
      for (final credit in record.artists) {
        if (credit.id == id && credit.name.isNotEmpty) {
          return Result.ok(
            Artist(
              id: id,
              name: credit.name,
              availability: MediaAvailability.localAndRemote,
            ),
          );
        }
      }
    }
    return _notDownloaded<Artist>();
  }

  /// The downloaded identity of one album — an explicit collection row, or
  /// reconstructed from any completed track on it (v0.2.3).
  Future<Result<Album>> album(MediaId id) async {
    final named = await _namedCollection(DownloadOwnerKind.album, id);
    if (named != null) return Result.ok(named.toAlbum());

    final completed = await _completedRecords();
    if (completed case Err<List<TrackDownload>>(:final failure)) {
      return Result.err(failure);
    }
    for (final record in (completed as Ok<List<TrackDownload>>).value) {
      final name = record.albumName;
      if (record.albumId == id && name != null && name.isNotEmpty) {
        return Result.ok(
          Album(
            id: id,
            name: name,
            availability: MediaAvailability.localAndRemote,
            image: record.image,
          ),
        );
      }
    }
    return _notDownloaded<Album>();
  }

  /// The downloaded identity of one playlist. Unlike an artist or album a
  /// playlist is never implied by a loose track, so this is the explicit
  /// collection row or nothing (v0.2.3).
  Future<Result<Playlist>> playlist(MediaId id) async {
    final named = await _namedCollection(DownloadOwnerKind.playlist, id);
    return named != null
        ? Result.ok(named.toPlaylist())
        : _notDownloaded<Playlist>();
  }

  /// One window of an album's completed downloaded tracks, in disc/track
  /// order (v0.2.3). When [knownTrackCount] is given — the caller read it
  /// from a cached album header — and exceeds what is on the device, the
  /// last window carries the shortfall as [offlineUnavailableReason]
  /// entries so the screen can say "N songs not available offline".
  Future<Result<Page<Track>>> albumTracks(
    MediaId albumId, {
    PageRequest page = const PageRequest.first(),
    int? knownTrackCount,
  }) async {
    final completed = await _completedRecords();
    if (completed case Err<List<TrackDownload>>(:final failure)) {
      return Result.err(failure);
    }
    final records =
        [
          for (final record in (completed as Ok<List<TrackDownload>>).value)
            if (record.albumId == albumId) record,
        ]..sort(_byDiscAndTrack);
    return Result.ok(
      _window<Track>(
        [for (final record in records) record.toTrack()],
        page: page,
        knownTotal: knownTrackCount,
      ),
    );
  }

  /// One window of an artist's albums, reconstructed from that artist's
  /// completed downloaded tracks (v0.2.3). [knownAlbumCount], when the
  /// caller has it from a cached discography, drives the "N albums not
  /// available offline" line the same way [albumTracks] does for songs.
  Future<Result<Page<Album>>> artistAlbums(
    MediaId artistId, {
    PageRequest page = const PageRequest.first(),
    int? knownAlbumCount,
  }) async {
    final completed = await _completedRecords();
    if (completed case Err<List<TrackDownload>>(:final failure)) {
      return Result.err(failure);
    }
    final byId = <MediaId, Album>{};
    for (final record in (completed as Ok<List<TrackDownload>>).value) {
      if (!record.artists.any((credit) => credit.id == artistId)) continue;
      final albumId = record.albumId;
      final name = record.albumName;
      if (albumId == null || name == null || name.isEmpty) continue;
      byId.putIfAbsent(
        albumId,
        () => Album(
          id: albumId,
          name: name,
          availability: MediaAvailability.localAndRemote,
          image: record.image,
        ),
      );
    }
    final albums = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Result.ok(
      _window<Album>(albums, page: page, knownTotal: knownAlbumCount),
    );
  }

  static Result<T> _notDownloaded<T>() =>
      const Result.err(RecoverableFailure('Not on this device.'));

  int _byDiscAndTrack(TrackDownload a, TrackDownload b) {
    final disc = (a.discNumber ?? 0).compareTo(b.discNumber ?? 0);
    if (disc != 0) return disc;
    final track = (a.trackNumber ?? 1 << 30).compareTo(b.trackNumber ?? 1 << 30);
    return track != 0
        ? track
        : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  Future<DownloadedCollection?> _namedCollection(
    DownloadOwnerKind kind,
    MediaId id,
  ) async {
    var request = const PageRequest.first();
    while (true) {
      final result = await _store.collections(kind: kind, page: request);
      if (result case Ok<Page<DownloadedCollection>>(:final value)) {
        for (final collection in value.items) {
          if (collection.id == id) return collection;
        }
        final next = value.nextRequest();
        if (next == null) return null;
        request = next;
      } else {
        return null;
      }
    }
  }

  Future<Result<List<TrackDownload>>> _completedRecords() async {
    final all = await _store.all();
    if (all case Err<List<TrackDownload>>(:final failure)) {
      return Result.err(failure);
    }
    return Result.ok([
      for (final record in (all as Ok<List<TrackDownload>>).value)
        if (record.state == DownloadState.completed) record,
    ]);
  }

  /// Windows [all] to [page] and, when [knownTotal] exceeds what is on the
  /// device, tags the last window with the shortfall as
  /// [offlineUnavailableReason] entries.
  Page<T> _window<T>(
    List<T> all, {
    required PageRequest page,
    int? knownTotal,
  }) {
    final start = page.startIndex.clamp(0, all.length);
    final end = (start + page.limit).clamp(0, all.length);
    final total = (knownTotal != null && knownTotal > all.length)
        ? knownTotal
        : all.length;
    final gap = end >= all.length ? total - all.length : 0;
    return Page<T>(
      content: Partial(
        available: all.sublist(start, end),
        unavailable: [
          for (var i = 0; i < gap; i++)
            UnavailableItem(
              id: 'offline-gap-$i',
              reason: offlineUnavailableReason,
            ),
        ],
      ),
      startIndex: start,
      totalCount: total,
      source: PageSource.cache,
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
    final completed = await _completedRecords();
    if (completed case Err<List<TrackDownload>>(:final failure)) {
      return Result.err(failure);
    }
    fromTracks((completed as Ok<List<TrackDownload>>).value, byId);

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
