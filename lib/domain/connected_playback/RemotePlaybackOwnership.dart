import 'ConnectedDevice.dart';

/// Whether this device is currently remote-controlling another one, as
/// seen from the one place a *new* local playback action needs to know
/// it (v0.6.0): the instant before it would start, never anywhere else.
///
/// Deliberately narrower than `PlaybackControlCubit`'s own state — the
/// same reasoning `ActiveTransportRoute` already applies to hardware/OS
/// transport presses, so `PlaybackCubit`, a foundational class every
/// screen depends on, never needs a hard dependency on the
/// connected-playback cubit that owns the real relationship.
abstract class RemotePlaybackOwnership {
  /// The device this device is currently controlling, or `null` when
  /// nothing here is remote-controlling anything — the ordinary case,
  /// where starting local playback is not a takeover at all.
  ConnectedDevice? get controlledDevice;

  /// Stops [controlledDevice] and releases this device's control
  /// relationship with it — the real effect an explicit takeover
  /// promises the listener before local playback begins (v0.6.0's "the
  /// previous owner stops," never a silent second stream). Best-effort:
  /// a target that has gone unreachable in the meantime must not block
  /// the takeover it can no longer even hear about. A no-op when
  /// [controlledDevice] is already `null`.
  Future<void> releaseForTakeover();
}
