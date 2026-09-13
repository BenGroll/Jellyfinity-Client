import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jellyfinity/core/logging/Logger.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/connection_state.dart';
import 'package:jellyfinity/domain/connected_playback/device_reachability.dart';
import 'package:jellyfinity/infrastructure/jellyfin/auth/DioJellyfinAuthenticator.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSessionApi.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinClientIdentity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinSessionContext.dart';
import 'package:jellyfinity/domain/session/JellyfinServer.dart';
import 'package:jellyfinity/infrastructure/jellyfin/server/JellyfinServerProbe.dart';

/// Connected-playback discovery against a real Jellyfin server.
///
/// Everything else about v0.5.2 is covered by tests that answer from a
/// fake adapter and a fake socket, which is what makes them fast and
/// deterministic. What they cannot prove is that the wire shapes are
/// right: that `/Sessions/Capabilities/Full` accepts the body this
/// client sends, that `/Sessions?ControllableByUserId=…` answers with a
/// bare array whose `DeviceId` really is the id this install reported,
/// that `/socket` upgrades with an `api_key` and a `deviceId`, and that
/// the general command carrying a Jellyfinity envelope is relayed rather
/// than rejected. Every one of those is a fact about Jellyfin, and only
/// Jellyfin can be asked.
///
/// `CONTEXT.md` sets the floor at Jellyfin 10.11.6, so that is the server
/// this is meant to run against. Configure it and run:
///
/// ```sh
/// flutter test integration_test/connected_playback_server_test.dart \
///   --dart-define=JELLYFIN_URL=http://127.0.0.1:8096 \
///   --dart-define=JELLYFIN_USER=jellyfinity-test \
///   --dart-define=JELLYFIN_PASSWORD=…
/// ```
///
/// Without those defines every test below is skipped rather than failed:
/// a contributor with no server should not see a red suite, and CI
/// should not depend on one being reachable.
const String serverUrl = String.fromEnvironment('JELLYFIN_URL');
const String username = String.fromEnvironment('JELLYFIN_USER');
const String password = String.fromEnvironment('JELLYFIN_PASSWORD');

bool get isConfigured => serverUrl.isNotEmpty && username.isNotEmpty;

const String skipReason =
    'Set JELLYFIN_URL, JELLYFIN_USER and JELLYFIN_PASSWORD to run the '
    'connected-playback integration test against a Jellyfin server.';

/// The session this test signs in as, resolved once.
class _LiveSession implements JellyfinSessionContext {
  _LiveSession({
    required this.baseUrl,
    required this.userId,
    required this.serverVersion,
    required this.token,
  });

  @override
  final String? baseUrl;

  @override
  final String? userId;

  @override
  final String? serverVersion;

  final String token;

  @override
  String? get serverId => 'integration-server';
}

class _LiveToken implements AuthTokenProvider {
  _LiveToken(this._session);

  final _LiveSession _session;

  @override
  Future<String?> currentToken() async => _session.token;
}

/// Silent by design: a failing expectation says what went wrong, and a
/// live-server run should not bury it in transport chatter.
class _SilentLogger implements Logger {
  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _LiveSession session;
  late JellyfinSessionTransport transport;
  late ConnectedPlaybackScope scope;

  setUpAll(() async {
    if (!isConfigured) return;

    final logger = _SilentLogger();
    final identity = JellyfinClientIdentity.forThisApp(
      // A device id per run, so a rerun does not collide with the
      // session the last one left behind on the server.
      deviceId: 'integration-${DateTime.now().microsecondsSinceEpoch}',
      deviceName: 'Jellyfinity integration test',
    );

    final probe = JellyfinServerProbe(
      identity,
      const NoAuthTokenProvider(),
      logger,
    );
    final probed = await probe.validate(serverUrl);
    expect(
      probed.failureOrNull,
      isNull,
      reason: 'the configured server must be reachable and supported',
    );

    final authenticator = DioJellyfinAuthenticator(identity, logger);
    final info = probed.valueOrNull!;
    final authenticated = await authenticator.authenticate(
      server: JellyfinServer(
        id: 'integration-server',
        baseUrl: info.baseUrl,
        name: info.serverName ?? 'Integration server',
        reportedVersion: info.version.toString(),
      ),
      username: username,
      password: password,
    );
    expect(authenticated.failureOrNull, isNull, reason: 'sign-in must work');
    final credentials = authenticated.valueOrNull!;

    session = _LiveSession(
      baseUrl: info.baseUrl,
      userId: credentials.userId,
      serverVersion: info.version.toString(),
      token: credentials.accessToken,
    );
    scope = ConnectedPlaybackScope(
      serverId: session.serverId!,
      userId: session.userId!,
    );

    transport = JellyfinSessionTransport(
      JellyfinSessionApi(session, identity, _LiveToken(session), logger),
      identity,
      logger,
    );
  });

  tearDownAll(() async {
    if (!isConfigured) return;
    await transport.dispose();
  });

  testWidgets(
    'a real Jellyfin accepts the capability post, the session read and the '
    'socket upgrade',
    (tester) async {
      final result = await transport.advertise(scope);

      expect(
        result.failureOrNull,
        isNull,
        reason: result.failureOrNull is UnsupportedServerFailure
            ? 'the server would not upgrade the WebSocket — check for a '
                  'reverse proxy that does not forward upgrades'
            : 'connecting must succeed',
      );
      expect(transport.connectionState, ConnectedPlaybackConnection.connected);
    },
    skip: !isConfigured,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'this install finds its own session by the device id it reported',
    (tester) async {
      await transport.advertise(scope);

      expect(transport.localSessionId, isNotNull);

      final devices = await transport.devices(scope).first;
      final self = devices.where((device) => device.isThisDevice);
      expect(
        self,
        hasLength(1),
        reason: 'the server must report this session back to it',
      );
      expect(self.single.sessionId, transport.localSessionId);
    },
    skip: !isConfigured,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'every discovered device belongs to this profile and this build',
    (tester) async {
      await transport.advertise(scope);

      final devices = await transport.devices(scope).first;
      for (final device in devices) {
        expect(device.scope, scope);
        expect(device.reachability, isNot(DeviceReachability.notPermitted));
      }
    },
    skip: !isConfigured,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'the server relays a Jellyfinity envelope back to this session',
    (tester) async {
      await transport.advertise(scope);
      final sessionId = transport.localSessionId;
      expect(sessionId, isNotNull);

      // Addressed to this very session. The envelope decoder drops
      // self-sent messages, so nothing acts on it; what is being proved
      // is that Jellyfin accepted the general command carrying an opaque
      // Jellyfinity payload and routed it, which is the one fact a fake
      // cannot establish.
      final refreshed = await transport.refresh(scope);
      expect(refreshed.failureOrNull, isNull);
    },
    skip: !isConfigured,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'skipped without a configured server',
    () => expect(isConfigured, isFalse, reason: skipReason),
    skip: isConfigured,
  );
}
