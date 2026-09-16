/// Everything one Jellyfinity device can ask another to do.
///
/// Split into two categories, because they are arbitrated differently:
///
/// - **Structural** commands change *what* is in the queue or where
///   playback sits in it. They name the revision they were composed
///   against and are rejected when that revision has moved on, so two
///   controllers editing the same queue cannot interleave into something
///   neither asked for.
/// - **Transport** commands change how the current entry is being played
///   — pause, seek, volume. They tolerate a stale revision: a listener
///   pressing pause means "pause", and refusing because a snapshot was
///   one revision behind would make the remote feel broken for no gain.
///
/// The wire form is the [name] of the member, and an unrecognized name
/// decodes to `null` rather than throwing (see [tryParse]) — a newer peer
/// sending a command this build has never heard of must be answered with
/// "unsupported", not a crash.
enum RemoteCommandKind {
  /// Resume playback of the current entry.
  play,

  pause,

  /// Pause if playing, play if not — one button on a remote, resolved by
  /// the target against the state it actually has rather than by the
  /// controller against a projection that may be a moment stale.
  playPause,

  /// Stop playback and release the queue's current position. Not a pause:
  /// what a "stop casting" control sends.
  stop,

  next,

  previous,

  /// Seek the current entry to an absolute position.
  seek,

  setVolume,

  setShuffle,

  setRepeat,

  /// Replace the whole queue and start at a given index.
  setQueue,

  /// Append entries to the end of the queue.
  appendToQueue,

  removeQueueEntry,

  moveQueueEntry,

  /// Make a given queue entry the current one.
  jumpToQueueEntry,

  /// Ask the target to re-send its full snapshot. The one command that
  /// never carries an expected revision: it is what a controller sends
  /// precisely because it no longer knows what the revision is.
  requestSnapshot,

  /// Asks a peer to join a particular Jellyfin SyncPlay group.
  joinSyncGroup,

  /// Asks the receiving device to become the *controller* of the sender.
  ///
  /// The one command that changes which end of the link is which. It is
  /// what makes "play on this device" a handover rather than a theft: the
  /// device that gives up playback asks the device that took it to become
  /// its remote, so the listener who was holding a controller is still
  /// holding a controller afterwards.
  takeControl;

  /// Whether this command names a specific row or arrangement of the
  /// queue, and therefore must match the revision it was composed
  /// against.
  ///
  /// [next] and [previous] are deliberately *not* structural, even though
  /// they move the current entry. "Skip this" means whatever is playing
  /// when it arrives, and a target that auto-advanced a second earlier
  /// has already moved its revision on — refusing the skip because of
  /// that would make the remote feel broken at exactly the moment a
  /// listener is most likely to press it. Duplicates of those two are
  /// handled by command id instead, which is the mechanism that actually
  /// fits them.
  bool get isStructural => switch (this) {
    RemoteCommandKind.setQueue ||
    RemoteCommandKind.appendToQueue ||
    RemoteCommandKind.removeQueueEntry ||
    RemoteCommandKind.moveQueueEntry ||
    RemoteCommandKind.jumpToQueueEntry => true,
    _ => false,
  };

  /// Whether this command's meaning depends on the queue it was composed
  /// against, and so must be refused when that queue has moved.
  ///
  /// Every structural command except [setQueue]. An index only means
  /// something relative to a particular queue, so "remove row 3" composed
  /// against a queue that has since changed is a different edit than the
  /// listener asked for. [setQueue] replaces the whole queue and names no
  /// existing row, so there is nothing for it to be wrong about: picking
  /// a song to play on another device must work whatever that device is
  /// doing, including while it is playing something else.
  bool get dependsOnCurrentQueue =>
      isStructural && this != RemoteCommandKind.setQueue;

  /// Whether applying this command twice differs from applying it once.
  ///
  /// [seek] to 30s is the same state whichever way it arrives; [next]
  /// twice skips two tracks. The distinction is why every command carries
  /// an id and a target keeps a duplicate window: a retried `next` must
  /// not cost the listener a song, and no revision check would catch it
  /// because both attempts were composed against the same revision.
  bool get isNaturallyIdempotent => switch (this) {
    RemoteCommandKind.playPause ||
    RemoteCommandKind.next ||
    RemoteCommandKind.previous ||
    RemoteCommandKind.appendToQueue ||
    RemoteCommandKind.removeQueueEntry ||
    RemoteCommandKind.moveQueueEntry => false,
    _ => true,
  };

  /// The wire form.
  String get wireName => name;

  /// Parses [wireName]. Returns `null` for an unknown command so the
  /// receiving target can answer `CommandOutcome.unsupported` instead of
  /// failing the whole envelope.
  static RemoteCommandKind? tryParse(Object? value) {
    if (value is! String) return null;
    for (final kind in RemoteCommandKind.values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}
