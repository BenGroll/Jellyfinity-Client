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

  /// How long a peer may go unheard before its row stops being trusted.
  ///
  /// Comfortably longer than the server's own session keep-alive, so an
  /// idle device that is perfectly fine is never accused of having gone
  /// away; short enough that a device that actually left stops being
  /// offered within a listener's attention span.
  static const Duration presenceStaleAfter = Duration(seconds: 90);

  /// How long a stale peer stays in the read model before it is dropped.
  ///
  /// The gap between this and [presenceStaleAfter] is deliberate:
  /// `DeviceReachability.stale` exists so a device that blinked is
  /// labelled rather than made to vanish and reappear under the
  /// listener's finger. Only after this does it stop being a row at all.
  static const Duration presenceDropAfter = Duration(minutes: 5);

  /// How recently a Jellyfin session must have been active to count as a
  /// device at all.
  ///
  /// Jellyfin remembers a session long after the app behind it is gone —
  /// its device list is a history, not a roster — so a read without this
  /// bound answers with every install that ever signed in, including the
  /// ones that were replaced, reinstalled or wiped. Those never answer a
  /// presence message, so they sit in the picker as "Connecting…" for
  /// ever and bury the devices the listener actually owns.
  ///
  /// Generous on purpose: a Jellyfinity that is merely open refreshes its
  /// session through the socket keep-alive and the presence poll, both
  /// far quicker than this, so the bound only ever excludes an app that
  /// is genuinely no longer running.
  static const Duration sessionActiveWithin = Duration(minutes: 10);

  /// How often presence is re-read over REST while the socket is not
  /// carrying `Sessions` updates.
  ///
  /// Bounded polling is what keeps a device listed as `presenceOnly`
  /// during a reconnect instead of disappearing; it is not a substitute
  /// for the socket, so it is slow on purpose.
  static const Duration presencePollInterval = Duration(seconds: 20);

  /// Background polling is quieter while the Android connectivity service
  /// keeps the process alive with the app locked.
  static const Duration backgroundPresencePollInterval = Duration(seconds: 60);

  /// Allows the slower cadence without declaring a healthy target stale.
  static const Duration backgroundPresenceStaleAfter = Duration(minutes: 4);

  /// The first delay after a socket interruption, doubling up to
  /// [reconnectMaxDelay].
  ///
  /// Not zero: an immediate reconnect against a server that is
  /// restarting, or a proxy that is refusing upgrades, is a tight loop
  /// dressed up as resilience.
  static const Duration reconnectInitialDelay = Duration(seconds: 2);

  /// The longest the backoff ever waits between reconnect attempts.
  ///
  /// Attempts never stop: a listener who fixes their network should not
  /// have to restart the app, and a two-minute ceiling costs nothing
  /// while being far too slow to matter as load.
  static const Duration reconnectMaxDelay = Duration(minutes: 2);

  /// How many recently seen command ids a target remembers for duplicate
  /// suppression.
  ///
  /// A bounded window rather than a growing set: duplicates arrive from a
  /// retry or a socket replay within seconds, so remembering the last few
  /// hundred is enough, and it cannot leak memory in a session that runs
  /// for days.
  static const int commandHistoryLength = 256;
}
