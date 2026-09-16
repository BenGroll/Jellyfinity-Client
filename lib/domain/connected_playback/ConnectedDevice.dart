import 'package:equatable/equatable.dart';

import 'ConnectedPlaybackScope.dart';
import 'DeviceCapabilities.dart';
import 'ProtocolVersion.dart';
import 'device_reachability.dart';

/// One Jellyfinity install, seen through the Jellyfin server it shares
/// with this one.
///
/// The identity here is deliberately two-part, because `Roadmap to
/// v0.6.md` is explicit that the session id, the saved account, the user
/// and the device are not interchangeable — the same distinction
/// `CONTEXT.md` already draws for `Server`/`User`/session/account:
///
/// - [deviceId] is the stable Jellyfinity install identity (the one
///   `DeviceIdentityStore` persists and every request already reports).
///   It survives a logout, a restart and a reconnect. It is what "my
///   living room TV" means, and what a remembered last-used target is
///   keyed by.
/// - [sessionId] is the *current* Jellyfin session for that install. It
///   is ephemeral: the same device reconnecting is a new session id. It
///   is what a command is addressed to, because it is what the server can
///   route.
///
/// Conflating them produces both of the obvious bugs at once — a command
/// addressed to a device id the server cannot route, and a "last used
/// device" that is forgotten every time the app restarts.
///
/// [scope] rides along rather than being implied: see
/// [ConnectedPlaybackScope] for why a message that outlives an account
/// switch must name the profile it was built for.
class ConnectedDevice extends Equatable {
  const ConnectedDevice({
    required this.scope,
    required this.deviceId,
    required this.sessionId,
    required this.name,
    required this.protocolVersion,
    required this.capabilities,
    required this.reachability,
    required this.lastSeen,
    this.nameHint,
    this.isThisDevice = false,
    this.isPlaying = false,
    this.nowPlayingTitle,
    this.nowPlayingArtist,
  });

  final ConnectedPlaybackScope scope;

  /// The stable install identity.
  final String deviceId;

  /// The ephemeral Jellyfin session id commands are addressed to.
  final String sessionId;

  /// The device's friendly name, as it advertises it.
  final String name;

  /// A short distinguishing suffix for duplicate [name]s — "Living Room
  /// (Fire TV)", "Living Room (Windows)".
  ///
  /// Two identical rows in a picker are unusable, and Jellyfinity cannot
  /// rename the listener's devices for them. The hint is computed where
  /// the duplicate is *observed* (a name is only ambiguous relative to
  /// the other names on screen), which is why it is a nullable field on
  /// the read model rather than part of what a device advertises.
  final String? nameHint;

  final ProtocolVersion protocolVersion;
  final DeviceCapabilities capabilities;
  final DeviceReachability reachability;

  /// When this device was last heard from, on the *observer's* monotonic
  /// clock — see `ElapsedClock` for why this is an elapsed reading rather
  /// than a wall-clock timestamp.
  final Duration lastSeen;

  /// Whether this row is the device doing the looking. Listed, because a
  /// picker has to show where sound is coming out *now*, but never a
  /// transfer target for itself.
  final bool isThisDevice;

  /// Whether this device is currently producing audio for this profile.
  ///
  /// Only one device in a scope should report this at a time — that is
  /// the ownership invariant — but the read model does not enforce it,
  /// because a moment where two devices claim it is exactly the symptom a
  /// handoff is supposed to make visible rather than hide.
  final bool isPlaying;

  /// Display metadata the peer included in its latest presence message.
  final String? nowPlayingTitle;
  final String? nowPlayingArtist;

  /// The label a picker shows.
  String get displayName => nameHint == null ? name : '$name ($nameHint)';

  /// Whether this device may be offered as a handoff destination.
  bool get canReceiveTransfer =>
      !isThisDevice &&
      reachability.canReceiveCommands &&
      protocolVersion.isCompatibleWith(ProtocolVersion.current) &&
      capabilities.canReceiveTransfer;

  /// Whether this device may be driven from here.
  bool get canBeControlled =>
      !isThisDevice &&
      reachability.canReceiveCommands &&
      protocolVersion.isCompatibleWith(ProtocolVersion.current) &&
      capabilities.canPlay;

  ConnectedDevice copyWith({
    String? sessionId,
    String? name,
    String? nameHint,
    ProtocolVersion? protocolVersion,
    DeviceCapabilities? capabilities,
    DeviceReachability? reachability,
    Duration? lastSeen,
    bool? isThisDevice,
    bool? isPlaying,
    String? nowPlayingTitle,
    String? nowPlayingArtist,
  }) {
    return ConnectedDevice(
      scope: scope,
      deviceId: deviceId,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      nameHint: nameHint ?? this.nameHint,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      capabilities: capabilities ?? this.capabilities,
      reachability: reachability ?? this.reachability,
      lastSeen: lastSeen ?? this.lastSeen,
      isThisDevice: isThisDevice ?? this.isThisDevice,
      isPlaying: isPlaying ?? this.isPlaying,
      nowPlayingTitle: nowPlayingTitle ?? this.nowPlayingTitle,
      nowPlayingArtist: nowPlayingArtist ?? this.nowPlayingArtist,
    );
  }

  @override
  List<Object?> get props => [
    scope,
    deviceId,
    sessionId,
    name,
    nameHint,
    protocolVersion,
    capabilities,
    reachability,
    lastSeen,
    isThisDevice,
    isPlaying,
    nowPlayingTitle,
    nowPlayingArtist,
  ];
}
