/// How usable one discovered device is right now.
///
/// `CONTEXT.md`'s first product invariant is never to leave users
/// guessing, and a device picker is where that is easiest to get wrong: a
/// greyed-out row with no explanation is the same as no row at all. Every
/// state below is one the listener can act on differently, which is why
/// they are separate members rather than a single `isAvailable` flag.
enum DeviceReachability {
  /// Advertising, compatible, and commands are being delivered. The only
  /// state in which a device may be offered as a handoff target.
  ready,

  /// Present and compatible, but command delivery is not currently
  /// working — the socket dropped and only bounded polling is keeping the
  /// session visible.
  ///
  /// The arc's invariant is explicit that such a device "is not presented
  /// as a ready handoff target": it can be listed, honestly labelled, and
  /// not chosen.
  presenceOnly,

  /// Last seen too long ago to be trusted. Kept listed briefly so a
  /// device that blinked does not vanish and reappear under the
  /// listener's finger, then dropped.
  stale,

  /// Speaks a different protocol major version. Not a transient failure:
  /// listed, explained, never offered.
  incompatible,

  /// The server reports the session, but the profile lacks permission to
  /// control it.
  notPermitted,

  /// This device knows about the peer but cannot reach the server at all
  /// — the local session is offline. Local playback continues; connected
  /// playback does not.
  offline;

  /// Whether a handoff may target a device in this state.
  bool get canReceiveCommands => this == ready;

  /// Whether the device should still appear in a picker, labelled.
  bool get isListable => this != stale;
}
