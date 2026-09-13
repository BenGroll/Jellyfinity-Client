/// Why an arriving envelope was not acted on.
///
/// The arc requires unknown versions and commands to be "ignored safely
/// and surfaced as incompatible rather than crashing either client", and
/// these are the two halves of that sentence kept apart. Ignoring is not
/// one behaviour: a message for another profile is a silent drop worth a
/// log line, while a message from an incompatible peer is something the
/// listener should see explained in the device list.
enum EnvelopeIgnoreReason {
  /// Not valid JSON, not a map, or missing a field every envelope must
  /// have. Logged; never shown.
  malformed,

  /// For a different server or profile — see `ConnectedPlaybackScope`.
  /// Dropped without inspection, which is the invariant: Jellyfinity does
  /// not read another profile's playback state even when the server would
  /// let it.
  outOfScope,

  /// From a peer speaking a different protocol major version. The one
  /// reason that is surfaced: the device is listed as incompatible so the
  /// listener knows which install to update.
  incompatibleProtocol,

  /// Over `ConnectedPlaybackLimits.maxPayloadBytes`. Dropped before
  /// parsing, so an oversized message costs nothing to refuse.
  tooLarge,

  /// A message kind this build does not know — a newer peer using a
  /// feature added after this version. Harmless by design.
  unknownKind,

  /// This device's own message, echoed back by the server. Jellyfin
  /// broadcasts to sessions including the sender; a device that acted on
  /// its own commands would double-apply every one of them.
  fromSelf;

  /// Whether the listener should be told about the peer that sent this.
  bool get isUserVisible => this == incompatibleProtocol;
}
