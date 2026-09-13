import '../../core/result/result.dart';
import 'ConnectedDevice.dart';
import 'ConnectedPlaybackScope.dart';
import 'connection_state.dart';

/// Where the list of compatible devices comes from.
///
/// A contract rather than a class because v0.5.1 has to be testable
/// without a server (`Roadmap to v0.6.md`: the whole conversation is
/// exercised "in pure tests without a Flutter widget, audio backend, or
/// live Jellyfin server"), and because the arc's transport is a decision
/// worth being able to revisit. Today it is the authenticated Jellyfin
/// session API plus its WebSocket. It is deliberately *not* mDNS, a
/// Jellyfinity cloud service, or a direct socket between devices — the
/// server both devices already trust is the relay.
///
/// Everything here is scoped. There is no "list all devices": a caller
/// cannot ask a question whose answer would cross profiles.
abstract class DevicePresenceSource {
  /// The live device list for [scope], re-emitted whenever presence,
  /// capabilities or reachability change.
  ///
  /// Emits the empty list rather than closing when nothing is found;
  /// "no other devices" is an answer, not an absence of one.
  Stream<List<ConnectedDevice>> devices(ConnectedPlaybackScope scope);

  /// This device's own link state, for the screens that have to explain
  /// an empty list.
  Stream<ConnectedPlaybackConnection> get connection;

  /// Forces a full read of current sessions — the REST half of the
  /// reconcile that must follow any socket interruption.
  Future<Result<List<ConnectedDevice>>> refresh(ConnectedPlaybackScope scope);

  /// Publishes this device's capabilities for [scope], making it
  /// discoverable by its peers.
  Future<Result<void>> advertise(ConnectedPlaybackScope scope);

  /// Stops advertising and forgets everything known about [scope].
  ///
  /// Called on logout, account switch and server removal. Not a
  /// disconnect: the point is that another profile's session must never
  /// inherit the previous one's device list, however briefly.
  Future<void> clear(ConnectedPlaybackScope scope);
}
