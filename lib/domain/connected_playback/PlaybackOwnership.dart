import 'package:equatable/equatable.dart';

import 'ConnectedPlaybackScope.dart';

/// Who, within one server-and-profile scope, owns playback right now.
///
/// This is the arc's central invariant expressed as a value: "only a
/// device producing audio owns the authoritative live queue. A controller
/// holds a revisioned projection and must not merge it into its unrelated
/// local persisted queue."
///
/// The second half is the part that is easy to get wrong in code, because
/// the natural instinct when a snapshot arrives is to apply it. Doing
/// that would overwrite the listener's own queue on the device they are
/// holding — their place in a different album, gone, because they glanced
/// at what the TV is playing. [ownsLocalQueue] is the question every
/// piece of code that is about to write to `PlaybackQueue` or
/// `QueueRepository` has to ask first, and the answer is `false` for the
/// whole time this device is a controller.
class PlaybackOwnership extends Equatable {
  const PlaybackOwnership({
    required this.scope,
    required this.localSessionId,
    this.ownerSessionId,
    this.ownerDeviceName,
  });

  /// Nothing is playing anywhere in this scope, so this device's own
  /// queue is its own business — the ordinary state, and the state every
  /// release before this arc was always in.
  factory PlaybackOwnership.unclaimed({
    required ConnectedPlaybackScope scope,
    required String localSessionId,
  }) => PlaybackOwnership(scope: scope, localSessionId: localSessionId);

  /// This device is the player.
  factory PlaybackOwnership.local({
    required ConnectedPlaybackScope scope,
    required String localSessionId,
  }) => PlaybackOwnership(
    scope: scope,
    localSessionId: localSessionId,
    ownerSessionId: localSessionId,
  );

  final ConnectedPlaybackScope scope;
  final String localSessionId;

  /// The session producing audio, or `null` when none is.
  final String? ownerSessionId;

  /// The owner's display name, for "Playing on Living Room". Held here so
  /// a mini-player can say where the sound is without joining against the
  /// device list on every rebuild.
  final String? ownerDeviceName;

  bool get isUnclaimed => ownerSessionId == null;

  bool get isLocal => ownerSessionId == localSessionId;

  /// True exactly when another device in this scope is the player, and
  /// therefore when this device is a controller.
  bool get isRemote =>
      ownerSessionId != null && ownerSessionId != localSessionId;

  /// Whether this device may write to its own persistent queue.
  ///
  /// The guard described in the class comment. `true` while nothing is
  /// claimed — a device with no connected session behaves exactly as it
  /// did before this arc existed — and `false` for as long as another
  /// device owns playback.
  bool get ownsLocalQueue => !isRemote;

  /// Whether this device should be showing remote controls rather than
  /// its own transport.
  bool get shouldShowRemoteControls => isRemote;

  PlaybackOwnership claimedBy(String sessionId, {String? deviceName}) =>
      PlaybackOwnership(
        scope: scope,
        localSessionId: localSessionId,
        ownerSessionId: sessionId,
        ownerDeviceName: deviceName,
      );

  PlaybackOwnership released() =>
      PlaybackOwnership(scope: scope, localSessionId: localSessionId);

  @override
  List<Object?> get props => [
    scope,
    localSessionId,
    ownerSessionId,
    ownerDeviceName,
  ];
}
