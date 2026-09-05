import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/media/media.dart';

/// Everything a playlist-curation screen needs beyond a single
/// `PlaylistEditor` call: gathering every track id out of a whole album,
/// artist or playlist before adding it elsewhere, and merging playlists
/// together.
///
/// Kept out of `PlaylistEditor` itself (ADR-0016) because these are
/// application-level workflows built out of several repository/editor
/// calls, not a single Jellyfin request the way every `PlaylistEditor`
/// method is — the same reason `PlaybackCubit`, not a repository, is what
/// resolves a queue.
@lazySingleton
class PlaylistCurationService {
  PlaylistCurationService(this._editor, this._playlists, this._music);

  final PlaylistEditor _editor;
  final PlaylistRepository _playlists;
  final MusicLibraryRepository _music;

  /// Large enough that a full artist discography still pages in a handful
  /// of requests, small enough that one window decodes quickly.
  static const int _pageSize = 200;

  Future<Result<MediaId>> createPlaylist(String name) =>
      _editor.create(name: name);

  Future<Result<void>> renamePlaylist(MediaId playlistId, String name) =>
      _editor.rename(playlistId, name);

  Future<Result<void>> deletePlaylist(MediaId playlistId) =>
      _editor.delete(playlistId);

  Future<Result<void>> addTrack(MediaId playlistId, MediaId trackId) =>
      _editor.addTracks(playlistId, [trackId]);

  /// Adds every track of [albumId] to [playlistId], in disc/track order.
  Future<Result<void>> addAlbum(MediaId playlistId, MediaId albumId) =>
      _addAllTracks(
        playlistId,
        (page) => _music.tracks(albumId: albumId, page: page),
      );

  /// Adds every track credited to [artistId] to [playlistId].
  Future<Result<void>> addArtist(MediaId playlistId, MediaId artistId) =>
      _addAllTracks(
        playlistId,
        (page) => _music.tracks(artistId: artistId, page: page),
      );

  /// Copies every track of [sourcePlaylistId] into [playlistId], in the
  /// source's own order.
  Future<Result<void>> addPlaylist(
    MediaId playlistId,
    MediaId sourcePlaylistId,
  ) => _addAllTracks(
    playlistId,
    (page) => _playlists.tracks(sourcePlaylistId, page: page),
  );

  /// Creates a new playlist named [name] holding every track of
  /// [sourcePlaylistIds], each source copied in full before the next
  /// starts. When [deleteSources] is set, a source is only ever deleted
  /// *after* it has been fully copied, so a failure partway through never
  /// loses a source playlist — at worst the merge is incomplete and can
  /// be retried.
  Future<Result<MediaId>> mergePlaylists({
    required String name,
    required List<MediaId> sourcePlaylistIds,
    bool deleteSources = false,
  }) async {
    final created = await _editor.create(name: name);
    if (created case Err<MediaId>(:final failure)) return Result.err(failure);
    final target = (created as Ok<MediaId>).value;

    for (final source in sourcePlaylistIds) {
      final added = await addPlaylist(target, source);
      if (added case Err<void>(:final failure)) return Result.err(failure);
    }

    if (deleteSources) {
      for (final source in sourcePlaylistIds) {
        await _editor.delete(source);
      }
    }

    return Result.ok(target);
  }

  Future<Result<void>> _addAllTracks(
    MediaId playlistId,
    Future<Result<Page<Track>>> Function(PageRequest page) fetch,
  ) async {
    final ids = await _allTrackIds(fetch);
    if (ids case Err<List<MediaId>>(:final failure)) return Result.err(failure);
    return _editor.addTracks(playlistId, (ids as Ok<List<MediaId>>).value);
  }

  /// Every available track id [fetch] pages through, start to end.
  ///
  /// Rows a page could not read (a movie sitting in a playlist, a track
  /// the library no longer has) are skipped rather than failing the whole
  /// operation — a bulk add should still add what it can, the same
  /// partial-success discipline every other read in the app already
  /// follows.
  Future<Result<List<MediaId>>> _allTrackIds(
    Future<Result<Page<Track>>> Function(PageRequest page) fetch,
  ) async {
    final ids = <MediaId>[];
    PageRequest? request = const PageRequest.first(limit: _pageSize);

    while (request != null) {
      final result = await fetch(request);
      if (result case Err<Page<Track>>(:final failure)) {
        return Result.err(failure);
      }
      final page = (result as Ok<Page<Track>>).value;
      ids.addAll(page.items.map((track) => track.id));
      request = page.nextRequest(limit: _pageSize);
    }

    return Result.ok(ids);
  }
}
