import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/partial.dart';
import '../../core/result/result.dart';
import '../../domain/connectivity/OfflineMode.dart';
import '../../domain/downloads/download_state.dart';
import '../../domain/downloads/DownloadStore.dart';
import '../../domain/downloads/PlaylistDownload.dart';
import '../../domain/downloads/TrackDownload.dart';
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
///
/// When even that cache has been evicted, a *downloaded* playlist
/// (v0.2.1) still answers from its durable membership snapshot — the
/// order is the one recorded at download time, without the unmappable
/// entries the metadata cache would have kept.
@LazySingleton(as: PlaylistRepository)
class CachedPlaylistRepository implements PlaylistRepository {
  CachedPlaylistRepository(
    this._remote,
    this._cache,
    this._context,
    this._downloads,
    this._offline,
  );

  final JellyfinPlaylistRepository _remote;
  final MediaCacheStore _cache;
  final JellyfinSessionContext _context;

  /// Working offline (v0.2.3): a read answers from the saved copy — or, for
  /// a downloaded playlist, its durable snapshot — without reaching for a
  /// server that will not answer.
  final OfflineMode _offline;

  static Result<T> _offlineFailure<T>() =>
      const Result.err(RecoverableFailure('You are offline.'));

  /// The last resort when the server is unreachable and the metadata
  /// cache has been evicted: a downloaded playlist's snapshot is durable
  /// local media (v0.2.1), so its members still play offline even when
  /// nothing else remembers the list.
  final DownloadStore _downloads;

  @override
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  }) async {
    final isSearch = searchTerm != null && searchTerm.trim().isNotEmpty;
    final result = _offline.status.isOffline
        ? _offlineFailure<Page<Playlist>>()
        : await _remote.playlists(page: page, searchTerm: searchTerm);

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
    final result = _offline.status.isOffline
        ? _offlineFailure<Page<Track>>()
        : await _remote.tracks(playlistId, page: page);

    switch (result) {
      case Ok<Page<Track>>(:final value):
        await _cache.savePage(key, value);
        return result;
      case Err<Page<Track>>(:final failure):
        if (!canServeFromCache(failure)) return result;
        final saved = await _saved<Track>(key, page);
        if (saved != null) return saved.map(_positioned);
        return await _downloaded(playlistId, page) ?? result;
    }
  }

  /// The saved window with every readable row told where it sits in the
  /// playlist (v0.4.2).
  ///
  /// The cache keeps each window's order, unreadable entries included, so
  /// the true position of a readable row is simply the next slot no
  /// unreadable entry has claimed. Restoring it here rather than in
  /// [MediaCacheStore] keeps the store collection-agnostic: a playlist is
  /// the one collection whose members' indices are part of what they are.
  ///
  /// The rows come back as [PlaylistTrack]s with no entry id, which is
  /// the honest answer offline — numbered like the playlist, playable,
  /// and not editable (ADR-0024's rule, carried forward).
  Page<Track> _positioned(Page<Track> page) {
    final reserved = {
      for (final missing in page.unavailable)
        if (missing.position != null) missing.position!,
    };
    var position = page.startIndex;
    final tracks = <Track>[];
    for (final track in page.items) {
      while (reserved.contains(position)) {
        position++;
      }
      tracks.add(_asPlaylistTrack(track, position++));
    }
    return Page<Track>(
      content: Partial(available: tracks, unavailable: page.unavailable),
      startIndex: page.startIndex,
      totalCount: page.totalCount,
      source: page.source,
    );
  }

  static PlaylistTrack _asPlaylistTrack(Track track, int position) =>
      PlaylistTrack(
        position: position,
        id: track.id,
        name: track.name,
        artists: track.artists,
        albumId: track.albumId,
        albumName: track.albumName,
        trackNumber: track.trackNumber,
        discNumber: track.discNumber,
        duration: track.duration,
        normalizationGain: track.normalizationGain,
        isFavorite: track.isFavorite,
        availability: track.availability,
        image: track.image,
      );

  /// A window of [playlistId]'s downloaded snapshot, or `null` when the
  /// playlist has not been downloaded. Marked [PageSource.cache] like any
  /// other offline answer; a member whose record has gone is skipped.
  Future<Result<Page<Track>>?> _downloaded(
    MediaId playlistId,
    PageRequest page,
  ) async {
    final membersResult = await _downloads.playlistMembers(playlistId);
    if (membersResult is! Ok<List<PlaylistDownloadMember>>) return null;
    final members = membersResult.value;
    if (members.isEmpty) return null;

    final start = page.startIndex.clamp(0, members.length);
    final end = (start + page.limit).clamp(0, members.length);
    final tracks = <Track>[];
    // A member of this window whose file never finished downloading is
    // part of the playlist the user built but cannot play offline — shown
    // as "N not available offline" rather than dropped (v0.2.3). Both it
    // and the members around it keep their place in the snapshot's order,
    // which is the playlist's order (v0.4.2).
    final gaps = <UnavailableItem>[];
    for (var i = start; i < end; i++) {
      final member = members[i];
      final record = await _downloads.find(member.trackId);
      if (record case Ok<TrackDownload?>(
        :final value?,
      ) when value.state == DownloadState.completed) {
        tracks.add(_asPlaylistTrack(value.toTrack(), i));
      } else {
        gaps.add(
          UnavailableItem(
            id: 'offline-gap-$i',
            reason: offlineUnavailableReason,
            position: i,
          ),
        );
      }
    }

    return Result.ok(
      Page<Track>(
        content: Partial(available: tracks, unavailable: gaps),
        startIndex: start,
        totalCount: members.length,
        source: PageSource.cache,
      ),
    );
  }

  // ---- Writes ----
  //
  // Writes, not reads: nothing here to cache or fall back to. When the
  // server cannot be reached the caller sees that failure directly, same
  // as every other mutation in this codebase — a playlist edit is an
  // instruction to the server, and pretending one succeeded offline would
  // be inventing state.
  //
  // Nor is the saved copy invalidated here. A mutation that succeeded
  // means the server is reachable, so the caller reloads the list it just
  // changed, and that read overwrites the cached page on its way through.
  // Invalidating as well would only widen the window in which an offline
  // reader sees nothing instead of something slightly stale.

  @override
  Future<Result<void>> addTracks(MediaId playlistId, List<MediaId> trackIds) =>
      _remote.addTracks(playlistId, trackIds);

  @override
  Future<Result<MediaId>> create(
    String name, {
    List<MediaId> trackIds = const [],
  }) => _remote.create(name, trackIds: trackIds);

  @override
  Future<Result<void>> rename(MediaId playlistId, String name) =>
      _remote.rename(playlistId, name);

  @override
  Future<Result<void>> delete(MediaId playlistId) => _remote.delete(playlistId);

  @override
  Future<Result<void>> removeEntries(
    MediaId playlistId,
    List<String> entryIds,
  ) => _remote.removeEntries(playlistId, entryIds);

  @override
  Future<Result<void>> moveEntry(
    MediaId playlistId,
    String entryId,
    int newIndex,
  ) => _remote.moveEntry(playlistId, entryId, newIndex);

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
