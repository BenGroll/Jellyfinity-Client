import 'package:equatable/equatable.dart';

import '../media/MediaId.dart';

/// What a download can be requested *for*.
///
/// A downloaded file is shared: the same song can be kept because the
/// user downloaded that song, and because they downloaded the album it
/// is on. Removing one of those reasons must not take the file away
/// while the other still wants it, so a download record holds the set of
/// reasons it exists rather than a single requester.
enum DownloadOwnerKind {
  /// The track itself was downloaded.
  track,

  /// An album the track belongs to was downloaded.
  album,

  /// A playlist the track is a member of was downloaded (v0.2.1). The
  /// playlist's ordered membership at download time is kept separately
  /// as a snapshot — see `DownloadStore.playlistMembers` — so a later
  /// server-side edit reconciles against it rather than silently
  /// rewriting what the user chose to keep.
  playlist;

  static DownloadOwnerKind? tryParse(String? raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

/// One reason a downloaded file is being kept.
///
/// Owners are the v0.2.0 form of the reference counting `ROADMAP.md`
/// makes explicit in v0.2.2: the count is the size of a download's owner
/// set, and "remove this album" means "drop the album owner", not
/// "delete the file". v0.2.1 adds [DownloadOwnerKind.playlist] with no
/// change here; an artist owner (v0.2.2) is the same shape again.
class DownloadOwner extends Equatable {
  const DownloadOwner({required this.kind, required this.id});

  /// The track was asked for on its own.
  const DownloadOwner.track(MediaId id)
    : this(kind: DownloadOwnerKind.track, id: id);

  /// The track is kept because [id]'s album was downloaded.
  const DownloadOwner.album(MediaId id)
    : this(kind: DownloadOwnerKind.album, id: id);

  /// The track is kept because [id]'s playlist was downloaded (v0.2.1).
  const DownloadOwner.playlist(MediaId id)
    : this(kind: DownloadOwnerKind.playlist, id: id);

  final DownloadOwnerKind kind;

  /// The item that wants the file kept — the track itself for
  /// [DownloadOwnerKind.track], the album for [DownloadOwnerKind.album],
  /// the playlist for [DownloadOwnerKind.playlist].
  final MediaId id;

  @override
  List<Object?> get props => [kind, id];

  @override
  String toString() => 'DownloadOwner(${kind.name}:${id.key})';
}
