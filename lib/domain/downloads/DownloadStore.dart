import '../../core/result/result.dart';
import '../media/MediaId.dart';
import '../media/page.dart';
import 'DownloadedCollection.dart';
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
///
/// From v0.2.3 every method reads and writes **only the active profile's**
/// records: the store scopes itself to the signed-in Jellyfin user, so a
/// second profile on the same server keeps a separate collection and
/// neither can see the other's. With no profile signed in, reads are
/// empty and writes are no-ops.
abstract class DownloadStore {
  /// Every download record for the active profile, oldest request first.
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

  // ---- Downloaded-collection identity (v0.2.3) ----

  /// Records or refreshes [collection]'s stored identity — its name and
  /// artwork pointer — so the Downloads screen and the offline library
  /// can render it with the server switched off.
  Future<Result<void>> saveCollection(DownloadedCollection collection);

  /// Forgets [owner]'s stored identity, called alongside dropping its
  /// owner rows when a collection download is removed.
  Future<Result<void>> deleteCollection(DownloadOwner owner);

  /// The active profile's downloaded collections, optionally narrowed to
  /// one [kind] and/or matching [searchTerm]. Ordered by name and paged,
  /// like every library read.
  Future<Result<Page<DownloadedCollection>>> collections({
    DownloadOwnerKind? kind,
    String? searchTerm,
    PageRequest page = const PageRequest.first(),
  });

  // ---- Offline discovery (v0.2.3) ----

  /// The active profile's *completed* track downloads whose title
  /// matches [searchTerm] — all of them when it is blank — ordered by
  /// title and paged. This is what the library and search fall back to
  /// when the server cannot be reached, and what the "Downloaded" filter
  /// reads directly, so it offers only what can actually play.
  Future<Result<Page<TrackDownload>>> searchTrackDownloads({
    String? searchTerm,
    PageRequest page = const PageRequest.first(),
  });

  // ---- Migration to per-profile downloads (v0.2.3) ----

  /// Assigns every record left unscoped by the schema-v6 upgrade to the
  /// active profile, and returns how many moved. A one-time step: before
  /// v0.2.3 downloads were one shared bucket, so the first profile to
  /// open the app after the upgrade adopts them. A no-op with no profile
  /// signed in, or once nothing unscoped remains.
  Future<Result<int>> claimLegacyDownloads();
}
