import '../../core/result/result.dart';
import '../media/MediaId.dart';
import 'DownloadOwner.dart';
import 'PlaylistDownload.dart';
import 'TrackDownload.dart';

/// Durable storage for what has been asked for and how far it got.
///
/// The records outlive the process: a download interrupted by the app
/// being killed is still a download when it starts again, which is what
/// makes restart recovery possible at all. Ordering is the store's job
/// too — [all] returns records oldest request first, so the engine works
/// through them in the order they were asked for.
abstract class DownloadStore {
  /// Every download record, oldest request first.
  Future<Result<List<TrackDownload>>> all();

  /// One record, or `null` when [id] has never been requested.
  Future<Result<TrackDownload?>> find(MediaId id);

  /// Writes [download] and its owner set, replacing any existing record
  /// for the same id.
  Future<Result<void>> save(TrackDownload download);

  /// Removes the record and its owners entirely. Deleting the *file* is
  /// `DownloadEngine.discard`'s job; this only forgets the record.
  Future<Result<void>> delete(MediaId id);

  /// The ids every record owned by [owner] refers to — "which tracks did
  /// downloading this album ask for".
  Future<Result<List<MediaId>>> ownedBy(DownloadOwner owner);

  // ---- Playlist membership snapshots (v0.2.1) ----

  /// Replaces the ordered membership snapshot for [playlistId] with
  /// [members]. An empty list clears it — the same call
  /// [deletePlaylistMembers] makes, kept separate only for intent.
  ///
  /// The snapshot is the durable record of *order*, alongside the
  /// per-track owner rows that record *why a file is kept*: a
  /// server-side edit reconciles against this rather than rewriting the
  /// owner set blind.
  Future<Result<void>> savePlaylistMembers(
    MediaId playlistId,
    List<PlaylistDownloadMember> members,
  );

  /// The ordered snapshot for [playlistId], or an empty list when the
  /// playlist has not been downloaded.
  Future<Result<List<PlaylistDownloadMember>>> playlistMembers(
    MediaId playlistId,
  );

  /// Every playlist's snapshot, keyed by playlist id — read once at
  /// startup so the catalog knows which playlists are downloaded without
  /// a query per screen.
  Future<Result<Map<MediaId, List<PlaylistDownloadMember>>>>
  allPlaylistMembers();

  /// Forgets [playlistId]'s snapshot. Dropping the owner rows and
  /// deleting now-ownerless files is the caller's job, the same split
  /// [delete] already uses.
  Future<Result<void>> deletePlaylistMembers(MediaId playlistId);
}
