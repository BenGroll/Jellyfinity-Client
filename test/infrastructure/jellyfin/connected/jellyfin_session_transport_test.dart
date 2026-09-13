import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceAdvertisement.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/ProtocolVersion.dart';
import 'package:jellyfinity/domain/connected_playback/connection_state.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/domain/connected_playback/envelope_kind.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';

import '../../../support/FakeSessionContext.dart';
import '../../../support/connected_playback/FakeJellyfinServer.dart';
import '../../../support/connected_playback/FakeJellyfinSocket.dart';
import '../../../support/connected_playback/connected_playback_fixtures.dart';

void main() {
  late FakeJellyfinServer server;
  late FakeSessionContext context;
  late JellyfinSessionTransport transport;
  late List<FakeJellyfinSocket> sockets;
  late List<Uri> socketUrls;
  Object? socketError;

  /// A fixed pause, for the assertions whose point is that nothing
  /// happens in a window. Everywhere else these tests wait for the
  /// outcome with [waitUntil], so a busy machine cannot fail them.
  Future<void> settle([Duration by = const Duration(milliseconds: 50)]) =>
      Future<void>.delayed(by);

  /// The devices for [testScope] once [condition] holds of them.
  Future<List<ConnectedDevice>> devicesWhen(
    bool Function(List<ConnectedDevice> devices) condition,
  ) => transport
      .devices(testScope)
      .firstWhere(condition)
      .timeout(const Duration(seconds: 5));

  setUp(() {
    server = FakeJellyfinServer();
    context = FakeSessionContext();
    sockets = [];
    socketUrls = [];
    socketError = null;

    transport = testSessionTransport(
      server,
      sockets: sockets,
      socketUrls: socketUrls,
      context: context,
      socketError: () => socketError,
    );
  });

  tearDown(() async {
    await transport.dispose();
  });

  String presenceFrom({
    required String sessionId,
    required String deviceId,
    String name = 'Living Room',
    String? platform,
    ConnectedPlaybackScope scope = testScope,
    ProtocolVersion version = ProtocolVersion.current,
    bool replyRequested = false,
  }) {
    final advertisement = DeviceAdvertisement(
      deviceId: deviceId,
      name: name,
      platform: platform,
      capabilities: DeviceCapabilities.fullPlayer(),
    );
    return ConnectedPlaybackEnvelope(
      messageId: 'message-$sessionId',
      protocolVersion: version,
      scope: scope,
      senderSessionId: sessionId,
      kind: EnvelopeKind.presence,
      payload: {
        ...advertisement.toPayload(),
        if (replyRequested) 'reply': true,
      },
    ).encode();
  }

  ConnectedDevice deviceNamed(List<ConnectedDevice> devices, String deviceId) =>
      devices.singleWhere((device) => device.deviceId == deviceId);

  group('discovery', () {
    test(
      'publishes capabilities, reads the roster and opens the socket',
      () async {
        final result = await transport.advertise(testScope);

        expect(result.isOk, isTrue);
        expect(server.capabilityPosts, 1);
        expect(server.sessionReads, 1);
        expect(sockets.single.subscribedToSessions, isTrue);
        expect(
          transport.connectionState,
          ConnectedPlaybackConnection.connected,
        );
      },
    );

    test(
      'binds this install to the ephemeral session the server gave it',
      () async {
        await transport.advertise(testScope);

        expect(transport.localSessionId, 'session-local');
      },
    );

    test('a peer is present before it answers and ready once it has', () async {
      await transport.advertise(testScope);

      var devices = await transport.devices(testScope).first;
      expect(
        deviceNamed(devices, 'device-tv').reachability,
        DeviceReachability.presenceOnly,
      );

      sockets.single.emitEnvelope(
        presenceFrom(sessionId: 'session-tv', deviceId: 'device-tv'),
      );

      devices = await devicesWhen(
        (devices) =>
            deviceNamed(devices, 'device-tv').reachability ==
            DeviceReachability.ready,
      );
      expect(deviceNamed(devices, 'device-tv').canReceiveTransfer, isTrue);
    });

    test('introduces itself to every peer it finds', () async {
      await transport.advertise(testScope);

      final introductions = server.delivered
          .where((sent) => sent.envelope.kind == EnvelopeKind.presence)
          .toList();
      expect(introductions, hasLength(1));
      expect(introductions.single.target, 'session-tv');
      final advertisement = DeviceAdvertisement.tryDecode(
        introductions.single.envelope.payload,
      );
      expect(advertisement!.deviceId, 'device-local');
      expect(advertisement.capabilities.canPlay, isTrue);
    });

    test(
      'answers a peer that asked to be introduced to, without asking back',
      () async {
        await transport.advertise(testScope);
        server.delivered.clear();

        sockets.single.emitEnvelope(
          presenceFrom(
            sessionId: 'session-tv',
            deviceId: 'device-tv',
            replyRequested: true,
          ),
        );
        await waitUntil(
          () => server.delivered.isNotEmpty,
          reason: 'the introduction to be answered',
        );

        final replies = server.delivered
            .where((sent) => sent.envelope.kind == EnvelopeKind.presence)
            .toList();
        expect(replies, hasLength(1));
        expect(replies.single.envelope.payload['reply'], isNull);
      },
    );

    test('a session pushed over the socket joins the list', () async {
      await transport.advertise(testScope);

      sockets.single.emitSessions([
        localSession,
        tvSession,
        sessionJson(
          id: 'session-phone',
          deviceId: 'device-phone',
          name: 'Phone',
        ),
      ]);

      final devices = await devicesWhen((devices) => devices.length == 3);
      expect(
        devices.map((device) => device.deviceId),
        containsAll(['device-local', 'device-tv', 'device-phone']),
      );
    });

    test('a refresh re-reads the roster over REST', () async {
      await transport.advertise(testScope);
      server.sessions = [localSession];

      final refreshed = await transport.refresh(testScope);

      expect(refreshed.isOk, isTrue);
      expect(refreshed.valueOrNull!.map((device) => device.deviceId), [
        'device-local',
      ]);
      expect(server.sessionReads, 2);
    });

    test('duplicate device names are distinguished on screen', () async {
      server.sessions = [
        localSession,
        sessionJson(id: 'session-tv', deviceId: 'device-aaaa'),
        sessionJson(id: 'session-desk', deviceId: 'device-bbbb'),
      ];
      await transport.advertise(testScope);

      sockets.single
        ..emitEnvelope(
          presenceFrom(
            sessionId: 'session-tv',
            deviceId: 'device-aaaa',
            name: 'Jellyfinity',
            platform: 'Fire TV',
          ),
        )
        ..emitEnvelope(
          presenceFrom(
            sessionId: 'session-desk',
            deviceId: 'device-bbbb',
            name: 'Jellyfinity',
            platform: 'Windows',
          ),
        );

      final devices = await devicesWhen(
        (devices) => deviceNamed(devices, 'device-bbbb').nameHint == 'Windows',
      );
      expect(
        deviceNamed(devices, 'device-aaaa').displayName,
        'Jellyfinity (Fire TV)',
      );
      expect(
        deviceNamed(devices, 'device-bbbb').displayName,
        'Jellyfinity (Windows)',
      );
    });
  });

  group('isolation', () {
    test('another profile on the same server is never listed', () async {
      server.sessions = [
        localSession,
        tvSession,
        sessionJson(
          id: 'session-other',
          deviceId: 'device-other',
          userId: 'user-2',
        ),
      ];

      await transport.advertise(testScope);

      final devices = await transport.devices(testScope).first;
      expect(
        devices.map((device) => device.deviceId),
        isNot(contains('device-other')),
      );
    });

    test('a session that is not Jellyfinity is never listed', () async {
      server.sessions = [
        localSession,
        sessionJson(
          id: 'session-web',
          deviceId: 'device-web',
          client: 'Jellyfin Web',
        ),
      ];

      await transport.advertise(testScope);

      final devices = await transport.devices(testScope).first;
      expect(devices.map((device) => device.deviceId), ['device-local']);
    });

    test('a message built for another profile is dropped unread', () async {
      await transport.advertise(testScope);

      sockets.single.emitEnvelope(
        presenceFrom(
          sessionId: 'session-tv',
          deviceId: 'device-tv',
          scope: otherProfileScope,
        ),
      );
      await settle();

      final devices = await transport.devices(testScope).first;
      expect(
        deviceNamed(devices, 'device-tv').reachability,
        DeviceReachability.presenceOnly,
      );
    });

    test(
      'a watcher of another scope never sees this one, even empty-handed',
      () async {
        final seen = <List<ConnectedDevice>>[];
        final subscription = transport
            .devices(otherProfileScope)
            .listen(seen.add);

        await transport.advertise(testScope);
        await settle();
        await subscription.cancel();

        expect(seen.every((devices) => devices.isEmpty), isTrue);
      },
    );

    test('signing out forgets the profile and closes the socket', () async {
      await transport.advertise(testScope);
      final seen = <List<ConnectedDevice>>[];
      final subscription = transport.devices(testScope).listen(seen.add);
      await settle();

      await transport.clear(testScope);
      await settle();

      expect(seen.last, isEmpty);
      expect(transport.localSessionId, isNull);
      expect(transport.connectionState, ConnectedPlaybackConnection.idle);
      expect(sockets.single.closed, isTrue);
      await subscription.cancel();
    });

    test('switching profile tears the old scope down first', () async {
      await transport.advertise(testScope);
      context.userId = 'user-2';
      server.sessions = [
        sessionJson(
          id: 'session-local-2',
          deviceId: 'device-local',
          userId: 'user-2',
        ),
      ];

      await transport.advertise(otherProfileScope);

      expect(await transport.devices(testScope).first, isEmpty);
      final devices = await transport.devices(otherProfileScope).first;
      expect(devices.map((device) => device.deviceId), ['device-local']);
      expect(devices.single.scope, otherProfileScope);
    });
  });

  group('incompatible peers', () {
    test('are listed and explained rather than ignored', () async {
      await transport.advertise(testScope);

      sockets.single.emitEnvelope(
        presenceFrom(
          sessionId: 'session-tv',
          deviceId: 'device-tv',
          version: const ProtocolVersion(2, 0),
        ),
      );

      final tv = deviceNamed(
        await devicesWhen(
          (devices) =>
              deviceNamed(devices, 'device-tv').reachability ==
              DeviceReachability.incompatible,
        ),
        'device-tv',
      );
      expect(tv.reachability, DeviceReachability.incompatible);
      expect(tv.protocolVersion, const ProtocolVersion(2, 0));
    });
  });

  group('failures', () {
    test(
      'a socket a proxy will not upgrade is reported as unsupported',
      () async {
        socketError = const WebSocketException('not upgraded to websocket');

        final result = await transport.advertise(testScope);

        expect(result.failureOrNull, isA<UnsupportedServerFailure>());
        expect(result.failureOrNull!.message, contains('reverse proxy'));
        expect(
          transport.connectionState,
          ConnectedPlaybackConnection.unsupported,
        );
      },
    );

    test('an unsupported transport is not retried in a loop', () async {
      socketError = const WebSocketException('not upgraded to websocket');
      await transport.advertise(testScope);
      final attempts = socketUrls.length;

      await settle(const Duration(milliseconds: 80));

      expect(socketUrls.length, attempts);
    });

    test('presence survives a socket that never opened', () async {
      socketError = const WebSocketException('not upgraded to websocket');
      await transport.advertise(testScope);

      final devices = await transport.devices(testScope).first;
      expect(
        deviceNamed(devices, 'device-tv').reachability,
        DeviceReachability.presenceOnly,
      );
    });

    test('a rejected token asks for a sign-in rather than a retry', () async {
      server.statusOverrides['/Sessions'] = 401;

      final result = await transport.advertise(testScope);

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
      expect(transport.connectionState, ConnectedPlaybackConnection.idle);
      expect(sockets, isEmpty);
    });

    test('a profile without remote control is told so specifically', () async {
      server.statusOverrides['/Sessions'] = 403;

      final result = await transport.advertise(testScope);

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
      expect(
        result.failureOrNull!.message,
        contains('not allowed to control other devices'),
      );
      expect(
        transport.connectionState,
        ConnectedPlaybackConnection.notPermitted,
      );
    });

    test(
      'a server below the supported version never reaches the network',
      () async {
        context.serverVersion = '10.9.0';

        final result = await transport.advertise(testScope);

        expect(result.failureOrNull, isA<UnsupportedServerFailure>());
        expect(result.failureOrNull!.message, contains('10.9.0'));
        expect(server.sessionReads, 0);
      },
    );

    test('an unreachable server says local playback is unaffected', () async {
      server.statusOverrides['/Sessions'] = 500;

      final result = await transport.advertise(testScope);

      expect(result.failureOrNull, isA<UnavailableFailure>());
      expect(
        result.failureOrNull!.message,
        contains('Playback on this device is unaffected'),
      );
      expect(transport.connectionState, ConnectedPlaybackConnection.offline);
    });
  });

  group('reconnection', () {
    test('a dropped socket reconnects and resynchronizes over REST', () async {
      await transport.advertise(testScope);
      final readsBefore = server.sessionReads;

      await sockets.single.drop();
      await waitUntil(
        () => sockets.length > 1,
        reason: 'the socket to be re-established',
      );

      expect(server.sessionReads, greaterThan(readsBefore));
      expect(transport.connectionState, ConnectedPlaybackConnection.connected);
    });

    test(
      'backoff grows rather than hammering a server that is still down',
      () async {
        server.statusOverrides['/Sessions'] = 500;
        await transport.advertise(testScope);

        await settle(const Duration(milliseconds: 100));

        // Ten initial delays' worth of time, counted in reconnect attempts
        // (only a connect publishes capabilities; the presence poll does
        // not). A flat retry would have made about ten in it; doubling to a
        // 40ms ceiling makes four.
        expect(server.capabilityPosts, greaterThan(1));
        expect(server.capabilityPosts, lessThan(6));
      },
    );

    test('presence is polled while the socket is down', () async {
      await transport.advertise(testScope);
      final readsWhenDropped = server.sessionReads;
      await sockets.single.drop();

      await waitUntil(
        () => server.sessionReads > readsWhenDropped,
        reason: 'presence to be re-read while the socket is down',
      );
    });

    test('a peer stays listed, unoffered, across the interruption', () async {
      await transport.advertise(testScope);
      sockets.single.emitEnvelope(
        presenceFrom(sessionId: 'session-tv', deviceId: 'device-tv'),
      );
      await settle();

      server.statusOverrides['/Sessions'] = 500;
      await sockets.first.drop();

      final tv = deviceNamed(
        await devicesWhen(
          (devices) =>
              deviceNamed(devices, 'device-tv').reachability ==
              DeviceReachability.presenceOnly,
        ),
        'device-tv',
      );
      expect(tv.reachability, DeviceReachability.presenceOnly);
      expect(tv.canReceiveTransfer, isFalse);
    });
  });

  group('lifecycle', () {
    test(
      'suspending drops the socket without forgetting the profile',
      () async {
        await transport.advertise(testScope);

        await transport.suspend();

        expect(sockets.single.closed, isTrue);
        expect(
          transport.connectionState,
          ConnectedPlaybackConnection.reconnecting,
        );
        final devices = await transport.devices(testScope).first;
        expect(devices, isNotEmpty);
        expect(
          deviceNamed(devices, 'device-tv').reachability,
          DeviceReachability.presenceOnly,
        );
      },
    );

    test('a suspended link does not reconnect on its own', () async {
      await transport.advertise(testScope);
      await transport.suspend();
      final socketsWhenSuspended = sockets.length;

      await settle(const Duration(milliseconds: 60));

      expect(sockets.length, socketsWhenSuspended);
    });

    test('resuming re-establishes the session and the socket', () async {
      await transport.advertise(testScope);
      await transport.suspend();

      final resumed = await transport.resume();

      expect(resumed.isOk, isTrue);
      expect(sockets.length, 2);
      expect(sockets.last.subscribedToSessions, isTrue);
      expect(transport.connectionState, ConnectedPlaybackConnection.connected);
    });
  });

  group('the socket address', () {
    test('carries the session token and this install\'s device id', () async {
      await transport.advertise(testScope);

      final url = socketUrls.single;
      expect(url.scheme, 'wss');
      expect(url.path, endsWith('/socket'));
      expect(url.queryParameters['api_key'], 'token-1');
      expect(url.queryParameters['deviceId'], 'device-local');
    });
  });

  group('frames it has no use for', () {
    test('are ignored rather than treated as corruption', () async {
      await transport.advertise(testScope);

      sockets.single
        ..emit('not json at all')
        ..emit({'MessageType': 'UserDataChanged', 'Data': <String, Object?>{}})
        ..emit({'MessageType': 'ForceKeepAlive', 'Data': 60})
        ..emitEnvelope('{')
        ..emitEnvelope(jsonEncode({'v': 'nonsense'}));
      await settle();

      expect(transport.connectionState, ConnectedPlaybackConnection.connected);
      expect(await transport.devices(testScope).first, isNotEmpty);
    });
  });
}
