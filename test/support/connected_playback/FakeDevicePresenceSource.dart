import 'dart:async';

import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/DevicePresenceSource.dart';
import 'package:jellyfinity/domain/connected_playback/connection_state.dart';

import 'connected_playback_fixtures.dart';

/// The "this device" row a real [DevicePresenceSource] always reports for
/// whatever scope becomes active, once advertised — [FakeDevicePresenceSource]'s
/// default so a test never has to build one by hand just to see it.
ConnectedDevice fakeThisDevice(ConnectedPlaybackScope scope) => device(
  scope: scope,
  deviceId: 'test-device',
  sessionId: 'test-device',
  name: 'This device',
  isThisDevice: true,
);

/// A [DevicePresenceSource] a test drives by hand — no network, no
/// registry, just whatever device list and connection state the test
/// pushes. Exists for presentation-layer tests (the device picker,
/// v0.5.5) that need a presence read model but are not testing presence
/// itself; [JellyfinSessionTransport]/`DevicePresenceRegistry` already
/// have their own tests for that.
///
/// The default constructor's [thisDeviceBuilder] mirrors the one thing
/// every real presence source does that a bare fake would otherwise
/// miss: reporting this device's own row automatically, for whichever
/// scope a caller actually asks about. This fake cannot know that scope
/// in advance (a test's saved account/server ids are usually generated
/// fresh), so the row is built lazily from whatever [ConnectedPlaybackScope]
/// [devices] is first asked for — on the first subscription, and again
/// prepended to every [emitDevices] call. Use [FakeDevicePresenceSource
/// .empty] for a test that wants to drive presence with no self row at
/// all, exactly as given.
class FakeDevicePresenceSource implements DevicePresenceSource {
  FakeDevicePresenceSource({
    ConnectedDevice Function(ConnectedPlaybackScope scope)? thisDeviceBuilder,
  }) : thisDeviceBuilder = thisDeviceBuilder ?? fakeThisDevice;

  /// A fake with no self row — every emission is exactly what a test
  /// gives [emitDevices], nothing prepended.
  FakeDevicePresenceSource.empty() : thisDeviceBuilder = null;

  final ConnectedDevice Function(ConnectedPlaybackScope scope)?
  thisDeviceBuilder;

  final _controllers =
      <ConnectedPlaybackScope, StreamController<List<ConnectedDevice>>>{};
  final _current = <ConnectedPlaybackScope, List<ConnectedDevice>>{};
  final _connection = StreamController<ConnectedPlaybackConnection>.broadcast();

  /// Replaces the device list for [scope] with this device's own row (if
  /// [thisDeviceBuilder] is set) followed by [others] — a full snapshot,
  /// exactly like a real [DevicePresenceSource] re-emits.
  void emitDevices(ConnectedPlaybackScope scope, List<ConnectedDevice> others) {
    final self = thisDeviceBuilder?.call(scope);
    final full = [?self, ...others];
    _current[scope] = full;
    _controllerFor(scope).add(full);
  }

  void emitConnection(ConnectedPlaybackConnection value) =>
      _connection.add(value);

  StreamController<List<ConnectedDevice>> _controllerFor(
    ConnectedPlaybackScope scope,
  ) => _controllers.putIfAbsent(scope, () {
    late final StreamController<List<ConnectedDevice>> controller;
    controller = StreamController<List<ConnectedDevice>>.broadcast(
      onListen: () {
        final existing = _current[scope];
        if (existing != null) {
          controller.add(existing);
          return;
        }
        final self = thisDeviceBuilder?.call(scope);
        if (self == null) return;
        _current[scope] = [self];
        controller.add([self]);
      },
    );
    return controller;
  });

  @override
  Stream<List<ConnectedDevice>> devices(ConnectedPlaybackScope scope) =>
      _controllerFor(scope).stream;

  @override
  Stream<ConnectedPlaybackConnection> get connection => _connection.stream;

  @override
  Future<Result<List<ConnectedDevice>>> refresh(
    ConnectedPlaybackScope scope,
  ) async => const Result.ok([]);

  @override
  Future<Result<void>> advertise(ConnectedPlaybackScope scope) async =>
      const Result.ok(null);

  @override
  Future<void> clear(ConnectedPlaybackScope scope) async {}

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await _connection.close();
  }
}
