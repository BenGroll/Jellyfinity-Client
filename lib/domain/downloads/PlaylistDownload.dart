import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';

/// One entry of a downloaded playlist's ordered membership snapshot
/// (v0.2.1).
///
/// A playlist download is a *snapshot*, not a live view: `ROADMAP.md`
/// v0.2.1 asks that an already downloaded track be reused, that a later
/// server-side edit reconcile against what was kept rather than rewrite
/// it, and that offline playback follow the order the user arranged. The
/// owner set on `TrackDownload` answers "is this file still wanted"; this
/// answers "in what order", which the owner set cannot carry.
///
/// [position] is the entry's index among the playlist's *downloadable*
/// tracks, in the playlist's own order — a non-track entry, or one the
/// server could not describe, has nothing to download and takes no
/// position here. The browse view (`PlaylistRepository.tracks`) keeps the
/// full numbering; this list is what plays offline.
typedef PlaylistDownloadMember = ({int position, MediaId trackId});

/// What a reconcile against the server changed for a downloaded playlist
/// (v0.2.1).
///
/// `ROADMAP.md` v0.2.1: a refresh must "report what changed" rather than
/// silently re-snapshotting. Every field is a plain count so a screen can
/// say "2 added, 1 removed" without holding the ids itself.
class PlaylistDownloadChange extends Equatable {
  const PlaylistDownloadChange({
    this.added = 0,
    this.removed = 0,
    this.removedButKept = 0,
  });

  static const PlaylistDownloadChange none = PlaylistDownloadChange();

  /// Members the server now lists that were not in the snapshot. These
  /// are queued for download by the reconcile.
  final int added;

  /// Members the snapshot held that the server no longer lists. Their
  /// playlist claim is dropped; a file another download still owns
  /// survives (counted again in [removedButKept]).
  final int removed;

  /// Of [removed], how many files stayed on the device because a track
  /// or album download still wants them.
  final int removedButKept;

  bool get isEmpty => added == 0 && removed == 0;

  @override
  List<Object?> get props => [added, removed, removedButKept];
}
