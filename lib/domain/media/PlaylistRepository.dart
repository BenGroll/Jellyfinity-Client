import '../../core/result/result.dart';
import 'MediaId.dart';
import 'page.dart';
import 'Playlist.dart';
import 'PlaylistTrack.dart';
import 'Track.dart';

/// Reading the user's playlists and their contents.
///
/// Separate from [MusicLibraryRepository] because a playlist is the
/// user's own arrangement rather than part of the library, and because
/// editing playlists (post-v0.1.0, `OUTLOOK.md` §6) belongs here and
/// nowhere near library browsing.
abstract class PlaylistRepository {
  /// The user's playlists, optionally narrowed by [searchTerm] so a
  /// music search can offer them as their own result category.
  Future<Result<Page<Playlist>>> playlists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  });

  /// A playlist's tracks, in the playlist's own order.
  ///
  /// A playlist can contain items that are not tracks, and items that
  /// have since disappeared from the library; both come back as
  /// `unavailable` entries in the page rather than being dropped, so the
  /// numbering a user sees matches the playlist they made.
  ///
  /// Every row that came from a source knowing the playlist's order is a
  /// [PlaylistTrack] carrying its true [PlaylistTrack.position] — the
  /// index Jellyfin itself counts in, with unreadable entries still
  /// occupying their slots. A read that reached the server also carries
  /// the [PlaylistTrack.entryId] that [removeEntries] and [moveEntry]
  /// name a row by; one served from the offline cache or a download
  /// snapshot does not, because neither stores entry ids and editing a
  /// playlist needs the server regardless (v0.4.2).
  Future<Result<Page<Track>>> tracks(
    MediaId playlistId, {
    PageRequest page = const PageRequest.first(),
  });

  /// Appends [trackIds] to the end of [playlistId].
  Future<Result<void>> addTracks(MediaId playlistId, List<MediaId> trackIds);

  /// Creates a playlist called [name], optionally holding [trackIds], and
  /// answers with the id of the playlist that now exists.
  ///
  /// The id comes back because creating a playlist is almost always the
  /// first half of something else — opening it, or adding the track the
  /// user was looking at when they made it.
  Future<Result<MediaId>> create(
    String name, {
    List<MediaId> trackIds = const [],
  });

  /// Renames [playlistId] to [name]. Its contents are untouched.
  Future<Result<void>> rename(MediaId playlistId, String name);

  /// Deletes [playlistId] from the server.
  ///
  /// Deletes the *playlist*, never the music in it — the tracks stay in
  /// the library exactly as they were. This is the one destructive write
  /// in this contract, and a caller is expected to have asked first.
  Future<Result<void>> delete(MediaId playlistId);

  /// Removes the rows named by [entryIds] from [playlistId].
  ///
  /// Keyed on [PlaylistTrack.entryId] rather than on track ids, because a
  /// playlist can list the same track more than once and "remove that
  /// song" would not say which appearance. Removes rows from the
  /// playlist; the tracks stay in the library.
  Future<Result<void>> removeEntries(MediaId playlistId, List<String> entryIds);

  /// Moves the row [entryId] to [newIndex] within [playlistId].
  ///
  /// [newIndex] is an **absolute, zero-based index into the whole
  /// playlist** — where the row ends up once it has been lifted out of
  /// where it was, which is how Jellyfin's move endpoint reads it. It
  /// counts every entry the playlist holds, including the ones
  /// Jellyfinity could not read: the caller takes it from
  /// [PlaylistTrack.position], never from a row's place on screen.
  ///
  /// Keyed on the entry id for the same reason [removeEntries] is — a
  /// playlist may list the same song three times, and only the entry id
  /// says which appearance is moving.
  Future<Result<void>> moveEntry(
    MediaId playlistId,
    String entryId,
    int newIndex,
  );
}
