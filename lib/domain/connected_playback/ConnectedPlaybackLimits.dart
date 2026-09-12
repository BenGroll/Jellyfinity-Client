/// The bounds every connected-playback participant enforces.
///
/// These are stated once, in the domain, because both ends have to agree
/// on them: a source that will happily send a 40,000-entry queue and a
/// target that refuses one above 1,000 produce a transfer that fails
/// *after* the source has stopped playing. The source checks the same
/// numbers before it offers, so the refusal is a clear "this queue is too
/// long to transfer" while the music is still playing.
///
/// They are also Jellyfinity's answer to `CONTEXT.md`'s scale rule.
/// 130k songs is normal; a queue built by "play all songs" is therefore
/// normal too, and it is not something to push through a WebSocket.
/// Handing over a bounded queue and refusing an unbounded one honestly is
/// better than an unbounded transfer that times out halfway.
abstract final class ConnectedPlaybackLimits {
  /// The most queue entries one transfer or queue-replacing command may
  /// carry.
  ///
  /// Chosen to comfortably cover every queue a listener builds on purpose
  /// — the longest album, the longest playlist, a full artist discography
  /// — while excluding "everything in the library".
  static const int maxQueueEntries = 1000;

  /// The most bytes one encoded envelope payload may occupy.
  ///
  /// Jellyfin's WebSocket is a general-purpose control channel shared
  /// with every other message the server sends this session; connected
  /// playback must not be the reason it stalls.
  static const int maxPayloadBytes = 256 * 1024;

  /// How long a command stays actionable at its target once it arrives.
  ///
  /// Long enough to survive a target that is busy resolving a source,
  /// short enough that a "pause" delivered after a reconnect is discarded
  /// rather than pausing music the listener has since restarted.
  static const Duration commandLifetime = Duration(seconds: 10);

  /// How long a controller waits for an acknowledgement before treating a
  /// command as lost and resynchronizing.
  ///
  /// Deliberately longer than [commandLifetime]: the command may expire
  /// at the target and still be acknowledged as expired, and hearing that
  /// is more useful than guessing.
  static const Duration acknowledgementTimeout = Duration(seconds: 15);

  /// How long each side of a handoff waits for the next step before
  /// giving up and restoring the source.
  ///
  /// A handoff involves resolving a queue and starting audio on the
  /// target, which is slower than answering a transport command.
  static const Duration handoffStepTimeout = Duration(seconds: 20);

  /// How many recently seen command ids a target remembers for duplicate
  /// suppression.
  ///
  /// A bounded window rather than a growing set: duplicates arrive from a
  /// retry or a socket replay within seconds, so remembering the last few
  /// hundred is enough, and it cannot leak memory in a session that runs
  /// for days.
  static const int commandHistoryLength = 256;
}
