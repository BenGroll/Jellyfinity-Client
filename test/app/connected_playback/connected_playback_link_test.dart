import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/ConnectedPlaybackLink.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/session/SessionCubit.dart';
import 'package:jellyfinity/app/session/SessionState.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/connection_state.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/domain/session/JellyfinAccount.dart';
import 'package:jellyfinity/domain/session/JellyfinServer.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';

import '../../support/FakeSessionContext.dart';
import '../../support/FakeTelevisionPlatform.dart';
import '../../support/TestLogger.dart';
import '../../support/connected_playback/FakeJellyfinServer.dart';
import '../../support/connected_playback/FakeJellyfinSocket.dart';
import '../../support/playback_fakes.dart';
import '../../support/session_fakes.dart';

/// The profile the link should discover for: the saved server's *local*
/// id and the account's Jellyfin user id.
const ConnectedPlaybackScope signedInScope = ConnectedPlaybackScope(
  serverId: 'server-1',
  userId: 'user-1',
);

const ConnectedPlaybackScope secondScope = ConnectedPlaybackScope(
  serverId: 'server-1',
  userId: 'user-2',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJellyfinServer server;
  late FakeSessionContext context;
  late JellyfinSessionTransport transport;
  late SessionCubit session;
  late FakePlaybackEngine engine;
  late PlaybackCubit playback;
  late ConnectedPlaybackLink link;
  late List<FakeJellyfinSocket> sockets;

  /// A fixed pause, used only where the point is that nothing happens.
  /// Everywhere else the tests wait for the outcome — see [waitUntil].
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() {
    server = FakeJellyfinServer();
    context = FakeSessionContext();
    sockets = [];
    transport = testSessionTransport(
      server,
      sockets: sockets,
      socketUrls: [],
      context: context,
    );
    session = fakeSessionCubit();
    engine = FakePlaybackEngine();
    playback = fakePlaybackCubit(engine: engine);
    link = ConnectedPlaybackLink(transport, session, playback, TestLogger());
  });

  tearDown(() async {
    await link.stop();
    await transport.dispose();
    await session.close();
    await playback.close();
  });

  /// A signed-in state for [userId] on the saved server the fake context
  /// describes.
  SessionState signedInAs(String userId) => SessionState.signedIn(
    fakeAuthSession(
      server: const JellyfinServer(
        id: 'server-1',
        baseUrl: 'https://media.example.com',
        name: 'Home',
        reportedVersion: '10.11.6',
      ),
      account: JellyfinAccount(
        id: 'account-$userId',
        serverId: 'server-1',
        userId: userId,
        username: userId,
      ),
    ),
  );

  test('links the profile that is already signed in at startup', () async {
    session.emit(signedInAs('user-1'));

    await link.start();

    expect(transport.connectionState, ConnectedPlaybackConnection.connected);
    expect(await transport.devices(signedInScope).first, isNotEmpty);
  });

  test('does nothing at all while signed out', () async {
    await link.start();

    expect(transport.connectionState, ConnectedPlaybackConnection.idle);
    expect(server.capabilityPosts, 0);
  });

  test('links a profile that signs in afterwards', () async {
    await link.start();

    session.emit(signedInAs('user-1'));
    await waitUntil(
      () => transport.connectionState == ConnectedPlaybackConnection.connected,
      reason: 'the profile that signed in to be linked',
    );
  });

  test('signing out forgets the profile immediately', () async {
    session.emit(signedInAs('user-1'));
    await link.start();

    session.emit(const SessionState.signedOut());
    await waitUntil(
      () => transport.connectionState == ConnectedPlaybackConnection.idle,
      reason: 'the profile to be forgotten',
    );

    expect(await transport.devices(signedInScope).first, isEmpty);
    expect(transport.connectionState, ConnectedPlaybackConnection.idle);
    expect(sockets.single.closed, isTrue);
  });

  test(
    'switching account never lets the new profile inherit the old list',
    () async {
      session.emit(signedInAs('user-1'));
      await link.start();

      context.userId = 'user-2';
      server.sessions = [
        sessionJson(
          id: 'session-local-2',
          deviceId: 'device-local',
          userId: 'user-2',
        ),
      ];
      session.emit(signedInAs('user-2'));

      // Waited for on the *new* scope's stream rather than on the link
      // state, which is already `connected` from the previous profile
      // and would let this assert before the switch had happened.
      final devices = await transport
          .devices(secondScope)
          .firstWhere((devices) => devices.isNotEmpty)
          .timeout(const Duration(seconds: 5));

      expect(devices.map((device) => device.deviceId), ['device-local']);
      expect(await transport.devices(signedInScope).first, isEmpty);
    },
  );

  test(
    'leaving the foreground releases the socket and returning restores it',
    () async {
      session.emit(signedInAs('user-1'));
      await link.start();

      link.didChangeAppLifecycleState(AppLifecycleState.paused);
      await waitUntil(
        () => sockets.single.closed,
        reason: 'the socket to be released',
      );
      expect(
        transport.connectionState,
        ConnectedPlaybackConnection.reconnecting,
      );

      link.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await waitUntil(
        () => sockets.length == 2,
        reason: 'the socket to be re-established',
      );
      expect(transport.connectionState, ConnectedPlaybackConnection.connected);
    },
  );

  test(
    'a backgrounded device that is still playing stays reachable',
    () async {
      session.emit(signedInAs('user-1'));
      await link.start();
      engine.emitStatus(PlaybackStatus.playing);
      await waitUntil(
        () => playback.state.isPlaying,
        reason: 'the cubit to report playing before backgrounding',
      );

      link.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();

      expect(sockets.single.closed, isFalse);
      expect(transport.connectionState, ConnectedPlaybackConnection.connected);
    },
  );

  test(
    'playback ending while backgrounded releases the socket',
    () async {
      session.emit(signedInAs('user-1'));
      await link.start();
      engine.emitStatus(PlaybackStatus.playing);
      await waitUntil(
        () => playback.state.isPlaying,
        reason: 'the cubit to report playing before backgrounding',
      );
      link.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();
      expect(sockets.single.closed, isFalse);

      engine.emitStatus(PlaybackStatus.paused);
      await waitUntil(
        () => sockets.single.closed,
        reason: 'the socket to be released once nothing is playing',
      );
      expect(
        transport.connectionState,
        ConnectedPlaybackConnection.reconnecting,
      );
    },
  );

  test(
    'playback starting while already backgrounded restores the socket',
    () async {
      session.emit(signedInAs('user-1'));
      await link.start();

      link.didChangeAppLifecycleState(AppLifecycleState.paused);
      await waitUntil(
        () => sockets.single.closed,
        reason: 'the socket to be released while nothing plays',
      );

      engine.emitStatus(PlaybackStatus.playing);
      await waitUntil(
        () => sockets.length == 2,
        reason: 'the socket to be re-established once playback starts',
      );
      expect(transport.connectionState, ConnectedPlaybackConnection.connected);
    },
  );

  test('a transient inactive state does not cost the socket', () async {
    session.emit(signedInAs('user-1'));
    await link.start();

    link.didChangeAppLifecycleState(AppLifecycleState.inactive);
    link.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await settle();

    expect(sockets.single.closed, isFalse);
    expect(transport.connectionState, ConnectedPlaybackConnection.connected);
  });

  test(
    'a server that cannot be reached does not stop the app starting',
    () async {
      server.statusOverrides['/Sessions'] = 500;
      session.emit(signedInAs('user-1'));

      await link.start();

      expect(transport.connectionState, ConnectedPlaybackConnection.offline);
    },
  );

  test('stopping releases the link', () async {
    session.emit(signedInAs('user-1'));
    await link.start();

    await link.stop();

    expect(await transport.devices(signedInScope).first, isEmpty);
    expect(transport.connectionState, ConnectedPlaybackConnection.idle);
  });

  group('on a television (v0.5.9)', () {
    late FakeTelevisionPlatform television;

    setUp(() => television = FakeTelevisionPlatform());
    tearDown(() => television.dispose());

    test(
      'falling asleep expires the target even while still playing, and '
      'waking restores it',
      () async {
        session.emit(signedInAs('user-1'));
        await link.start();
        engine.emitStatus(PlaybackStatus.playing);
        await waitUntil(
          () => playback.state.isPlaying,
          reason: 'the cubit to report playing before the screen sleeps',
        );

        television.screenOff();
        await waitUntil(
          () => sockets.single.closed,
          reason: 'an asleep television to expire promptly even while playing',
        );
        expect(
          transport.connectionState,
          ConnectedPlaybackConnection.reconnecting,
        );

        television.screenOn();
        await waitUntil(
          () => sockets.length == 2,
          reason: 'waking to restore the target',
        );
        expect(transport.connectionState, ConnectedPlaybackConnection.connected);
      },
    );

    test(
      'falling asleep while already backgrounded and not playing stays '
      'expired once it wakes',
      () async {
        session.emit(signedInAs('user-1'));
        await link.start();

        link.didChangeAppLifecycleState(AppLifecycleState.paused);
        await waitUntil(
          () => sockets.single.closed,
          reason: 'the socket to be released while backgrounded and idle',
        );

        television.screenOff();
        await settle();
        expect(sockets.length, 1, reason: 'still just the one closed socket');

        television.screenOn();
        await settle();
        expect(
          sockets.length,
          1,
          reason:
              'still backgrounded and not playing, so waking defers to '
              'that rule rather than reconnecting unconditionally',
        );
      },
    );
  });
}
