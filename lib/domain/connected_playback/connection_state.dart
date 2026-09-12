/// The state of this device's own connected-playback link.
///
/// Separate from [DeviceReachability], which describes a *peer*. This
/// describes whether this device is in the conversation at all, and it is
/// what a device picker shows instead of an empty list — "looking for
/// devices", "reconnecting" and "your server is unreachable" are three
/// different empty screens.
enum ConnectedPlaybackConnection {
  /// No session — signed out, or connected playback not started.
  idle,

  /// Establishing the session and advertising capabilities.
  connecting,

  /// Live: presence is current and commands are being delivered.
  connected,

  /// The link dropped and is being re-established with bounded backoff.
  /// Presence may still be polled; structural commands are not sent.
  reconnecting,

  /// Re-established, and performing the full resynchronization that must
  /// precede accepting more structural commands. Brief, and worth showing
  /// rather than presenting stale state as live.
  resynchronizing,

  /// The server cannot be reached. Local playback is unaffected — the
  /// distinction the UI must draw, because the listener's music has not
  /// stopped.
  offline,

  /// The server is reachable but cannot carry this conversation — a
  /// reverse proxy that does not upgrade WebSockets, or a server below
  /// the supported version. Not a transient failure; the listener has to
  /// change something.
  unsupported,

  /// Reached and refused: this profile is not permitted to control
  /// sessions.
  notPermitted;

  /// Whether devices discovered right now can be trusted as current.
  bool get hasLivePresence => this == connected;

  /// Whether structural commands and handoffs may be sent.
  bool get acceptsStructuralCommands => this == connected;
}
