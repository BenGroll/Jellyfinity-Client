import '../../core/result/result.dart';
import '../media/MediaId.dart';
import 'DownloadOwner.dart';
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
}
