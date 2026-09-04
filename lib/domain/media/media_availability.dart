/// Where a piece of media can currently be played from.
///
/// `PHILOSOPHY.md` §5: offline is not a separate application mode, it is a
/// property of the media. The same album is the same conceptual entity
/// whether it streams from the server, comes from local metadata, or plays
/// from a download — only its availability differs.
///
/// Downloads do not exist yet (post-v0.1.0), so in practice v0.0.7 and
/// v0.0.8 produce [remoteOnly] and [partiallyAvailable]. The vocabulary
/// exists now so the UI branches on availability from its first screen
/// rather than being retrofitted for it later.
enum MediaAvailability {
  /// On the server; nothing stored on this device. Needs a reachable
  /// server to play.
  remoteOnly,

  /// Downloaded *and* still on the server.
  localAndRemote,

  /// Downloaded, but no longer on the server — Jellyfinity keeps it and
  /// shows it as "Only on Device" rather than making it disappear.
  localOnly,

  /// Known to Jellyfinity (its metadata is cached) but not currently
  /// obtainable: the server is unreachable, or the item is gone from the
  /// library. Visible, clearly marked, and not playable.
  remoteUnavailable,

  /// A collection that is usable but incomplete — the twelve-track album
  /// with one dead track. Playable; the missing children are marked
  /// individually.
  partiallyAvailable;

  /// Whether playback can be attempted at all.
  bool get isPlayable => this != remoteUnavailable;

  /// Whether a copy exists on this device.
  bool get isOnDevice => this == localAndRemote || this == localOnly;

  /// Whether playing this needs the server to be reachable.
  bool get requiresServer => !isOnDevice;

  /// Whether something about this item is missing and should be shown as
  /// such.
  bool get isDegraded =>
      this == remoteUnavailable || this == partiallyAvailable;
}
