/// Where one requested download currently stands.
///
/// The vocabulary the UI branches on, and the only download state the
/// rest of the application knows about. `CONTEXT.md`'s first product
/// invariant is that a user is never left guessing, so every state a
/// download can actually reach is nameable here rather than being
/// collapsed into "working" and "broken".
enum DownloadState {
  /// Requested, waiting for the engine. Nothing has been transferred yet
  /// (or a previous attempt left a partial file that will be resumed).
  queued,

  /// Being transferred right now. Exactly one download is in this state
  /// at a time — see `DownloadEngine` for why the queue is serial.
  downloading,

  /// Stopped by the user, with its partial transfer kept. Resuming picks
  /// up where it left off rather than starting over.
  paused,

  /// Held back because the current network does not satisfy the user's
  /// Wi-Fi-only preference (v0.2.2). Not a failure and not something the
  /// user stopped: the request is intact and the engine picks it up on
  /// its own once an unmetered connection is available or the preference
  /// is turned off. `ROADMAP.md` v0.2.2: "retain it as a clearly paused
  /// request rather than reporting a permanent failure."
  waitingForNetwork,

  /// The whole file is on the device and playable without the server.
  completed,

  /// The attempt ended in a failure the user can act on. The reason is
  /// carried separately, in [DownloadFailureReason].
  failed;

  /// Whether the engine still has work to do for this download.
  bool get isPending => this == queued || this == downloading;

  /// Whether asking again is a sensible thing to offer.
  bool get isRetryable => this == paused || this == failed;
}

/// Why a download stopped, in terms a user can be told about.
///
/// Deliberately coarser than the transport's `Failure` hierarchy: a
/// download only needs to say what the person looking at it should do
/// next, and every distinction here changes that answer.
enum DownloadFailureReason {
  /// The server could not be reached, or the transfer was cut off.
  network,

  /// The session is not (or no longer) allowed to fetch this file.
  unauthorized,

  /// The device has no room left for the rest of the file.
  insufficientStorage,

  /// The file could not be written or moved into place, for a reason
  /// other than running out of room.
  storage,

  /// The server answered, but this item is not available from it any
  /// more.
  unavailable,

  /// Something else went wrong. Retrying is still worth offering.
  unknown;

  /// A short line to show beside a failed download.
  String get message => switch (this) {
    network => 'Could not reach the server.',
    unauthorized => 'Sign in again to download this.',
    insufficientStorage => 'Not enough storage left on this device.',
    storage => 'Could not save the file to this device.',
    unavailable => 'This is no longer available on the server.',
    unknown => 'The download did not finish.',
  };
}
