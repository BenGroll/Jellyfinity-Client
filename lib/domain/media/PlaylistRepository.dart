import '../../core/result/result.dart';
import 'MediaId.dart';
import 'page.dart';
import 'Playlist.dart';
import 'Track.dart';

/// Reading the user's playlists and their contents.
///
/// Separate from [MusicLibraryRepository] because a playlist is the
/// user's own arrangement rather than part of the library, and because
/// editing playlists (post-v0.1.0, `OUTLOOK.md` §6) belongs here and
/// nowhere near library browsing.
abstract class PlaylistRepository {
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
  });

  /// A playlist's tracks, in the playlist's own order.
  ///
  /// A playlist can contain items that are not tracks, and items that
  /// have since disappeared from the library; both come back as
  /// `unavailable` entries in the page rather than being dropped, so the
  /// numbering a user sees matches the playlist they made.
  Future<Result<Page<Track>>> tracks(
    MediaId playlistId, {
    PageRequest page = const PageRequest.first(),
  });
}
