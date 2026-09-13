import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSessionApi.dart';
import 'package:jellyfinity/infrastructure/jellyfin/connected/JellyfinSessionTransport.dart';
import 'package:jellyfinity/infrastructure/jellyfin/http/JellyfinHttpClient.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/auth_token_provider.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinClientIdentity.dart';
import 'package:jellyfinity/infrastructure/jellyfin/identity/JellyfinSessionContext.dart';

import '../FakeDioAdapter.dart';
import '../FakeSessionContext.dart';
import '../TestLogger.dart';
import 'FakeElapsedClock.dart';
import 'FakeJellyfinSocket.dart';

/// This install, as `JellyfinClientIdentity` reports it everywhere else.
const JellyfinClientIdentity thisDevice = JellyfinClientIdentity(
  clientName: 'Jellyfinity',
  clientVersion: 'test',
  deviceName: 'Jellyfinity',
  deviceId: 'device-local',
);

/// One `/Sessions` row.
Map<String, Object?> sessionJson({
  required String id,
  required String deviceId,
  String name = 'Jellyfinity',
  String client = 'Jellyfinity',
  String userId = 'user-1',
  bool supportsRemoteControl = true,
  bool playing = false,
}) => {
  'Id': id,
  'DeviceId': deviceId,
  'DeviceName': name,
  'Client': client,
  'UserId': userId,
  'SupportsRemoteControl': supportsRemoteControl,
  if (playing) 'NowPlayingItem': {'Id': 'track-1'},
};

/// This device's own session, as the server reports it back.
Map<String, Object?> get localSession =>
    sessionJson(id: 'session-local', deviceId: 'device-local');

/// A second Jellyfinity install on the same profile.
Map<String, Object?> get tvSession =>
    sessionJson(id: 'session-tv', deviceId: 'device-tv', name: 'Living Room');

/// Jellyfin's own `GeneralCommandType`, as of the 10.11 servers
/// Jellyfinity supports — the only vocabulary
/// `/Sessions/Capabilities/Full` accepts for `SupportedCommands`.
///
/// Transcribed rather than derived because it is the server's list, not
/// Jellyfinity's: it is here so a test can hold the capability post to
/// the same standard the server does.
const Set<String> generalCommandTypes = {
  'MoveUp',
  'MoveDown',
  'MoveLeft',
  'MoveRight',
  'PageUp',
  'PageDown',
  'PreviousLetter',
  'NextLetter',
  'ToggleOsd',
  'ToggleContextMenu',
  'Select',
  'Back',
  'TakeScreenshot',
  'SendKey',
  'SendString',
  'GoHome',
  'GoToSettings',
  'VolumeUp',
  'VolumeDown',
  'Mute',
  'Unmute',
  'ToggleMute',
  'SetVolume',
  'SetAudioStreamIndex',
  'SetSubtitleStreamIndex',
  'ToggleFullscreen',
  'DisplayContent',
  'GoToSearch',
  'DisplayMessage',
  'SetRepeatMode',
  'ChannelUp',
  'ChannelDown',
  'Guide',
  'ToggleStats',
  'PlayMediaSource',
  'PlayTrailers',
  'SetShuffleQueue',
  'PlayState',
  'PlayNext',
  'ToggleOsdMenu',
  'Play',
  'SetMaxStreamingBitrate',
  'SetPlaybackOrder',
};

/// A Jellyfin answering only the three endpoints connected playback uses.
class FakeJellyfinServer {
  FakeJellyfinServer({List<Map<String, Object?>>? sessions})
    : sessions = sessions ?? [localSession, tvSession];

  List<Map<String, Object?>> sessions;

  /// Forces a status for an exact request path — a 403 on `/Sessions`,
  /// say, leaving the capability post working.
  final Map<String, int> statusOverrides = {};

  /// Every envelope the client delivered, with the session it was sent
  /// to.
  final List<({String target, ConnectedPlaybackEnvelope envelope})> delivered =
      [];

  int capabilityPosts = 0;
  int sessionReads = 0;

  late final FakeDioAdapter adapter = FakeDioAdapter(_answer);

  Future<ResponseBody> _answer(RequestOptions options) async {
    final path = options.path;
    for (final entry in statusOverrides.entries) {
      if (path == entry.key) throw _status(options, entry.value);
    }

    if (path == JellyfinSessionApi.capabilitiesPath) {
      capabilityPosts++;
      if (!_isClientCapabilitiesDto(options.data)) {
        // What the real endpoint does with a body it cannot bind: its
        // `ClientCapabilitiesDto` is `[FromBody, Required]` and its list
        // fields are enum arrays. A fake that accepted anything let a
        // capability post that no Jellyfin would take look healthy.
        throw _status(options, 400);
      }
      return textResponseBody('', statusCode: 204);
    }
    if (path == JellyfinSessionApi.sessionsPath) {
      sessionReads++;
      return jsonResponseBody(sessions);
    }
    if (path.endsWith('/Command')) {
      _record(path, options.data as Map<String, Object?>);
      return textResponseBody('', statusCode: 204);
    }
    throw _status(options, 404);
  }

  void _record(String path, Map<String, Object?> body) {
    final arguments = body['Arguments'] as Map<String, Object?>;
    final raw = arguments[JellyfinSessionApi.envelopeArgumentName] as String;
    // Decoded against whatever scope it names, so a test can assert that
    // a message went out for the scope it expected rather than having the
    // fake silently drop it.
    final decoding = ConnectedPlaybackEnvelope.decode(
      raw,
      localScope:
          ConnectedPlaybackScope.tryParse(
            (jsonDecode(raw) as Map)['scope'] as String?,
          ) ??
          const ConnectedPlaybackScope(serverId: 'server-1', userId: 'user-1'),
      localSessionId: 'never-matches',
    );
    if (decoding is DecodedEnvelope) {
      delivered.add((target: path.split('/')[2], envelope: decoding.envelope));
    }
  }

  /// Whether [data] is a body Jellyfin's `/Sessions/Capabilities/Full`
  /// could actually bind: an object with the four fields it reads, the
  /// two list fields as arrays, and every command a real
  /// `GeneralCommandType`.
  static bool _isClientCapabilitiesDto(Object? data) {
    if (data is! Map) return false;
    final media = data['PlayableMediaTypes'];
    final commands = data['SupportedCommands'];
    if (media is! List || commands is! List) return false;
    if (data['SupportsMediaControl'] is! bool) return false;
    if (data['SupportsPersistentIdentifier'] is! bool) return false;
    return commands.every(generalCommandTypes.contains);
  }

  DioException _status(RequestOptions options, int status) => DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: options, statusCode: status),
  );
}

/// The REST half alone, answered by [server] — what a test that is about
/// the requests themselves needs, rather than the whole transport.
JellyfinSessionApi testSessionApi(
  FakeJellyfinServer server, {
  JellyfinSessionContext? context,
}) {
  return JellyfinSessionApi(
      context ?? FakeSessionContext(),
      thisDevice,
      const StaticAuthToken('token-1'),
      TestLogger(),
    )
    ..httpClientFactory = (baseUrl) => JellyfinHttpClient(
      baseUrl: baseUrl,
      identity: thisDevice,
      authTokenProvider: const NoAuthTokenProvider(),
      logger: TestLogger(),
      dio: Dio()..httpClientAdapter = server.adapter,
      maxRetries: 0,
    );
}

/// A transport wired to [server], with a socket the test drives and
/// backoff short enough to watch.
///
/// [sockets] collects every socket opened and [socketUrls] every address
/// tried, so a test can see attempts that never produced a socket.
JellyfinSessionTransport testSessionTransport(
  FakeJellyfinServer server, {
  required List<FakeJellyfinSocket> sockets,
  required List<Uri> socketUrls,
  JellyfinSessionContext? context,
  Object? Function()? socketError,
}) {
  final api = testSessionApi(server, context: context);

  return JellyfinSessionTransport(api, thisDevice, TestLogger())
    ..clock = FakeElapsedClock()
    ..reconnectInitialDelay = const Duration(milliseconds: 10)
    ..reconnectMaxDelay = const Duration(milliseconds: 40)
    ..presencePollInterval = const Duration(milliseconds: 15)
    ..connector = (url) async {
      socketUrls.add(url);
      final error = socketError?.call();
      if (error != null) throw error;
      final socket = FakeJellyfinSocket();
      sockets.add(socket);
      return socket;
    };
}

/// A token provider that always has the same token.
class StaticAuthToken implements AuthTokenProvider {
  const StaticAuthToken(this._token);

  final String _token;

  @override
  Future<String?> currentToken() async => _token;
}

/// Waits until [condition] holds, or fails the test after [timeout].
///
/// The transport does its work asynchronously and several of its triggers
/// are deliberately fire-and-forget — a lifecycle callback cannot be
/// awaited, and a reconnect is a timer. Asserting after a fixed sleep
/// makes those tests pass on an idle machine and fail on a busy one, so
/// they wait for the outcome instead of for the clock. A fixed sleep is
/// still right for asserting that something does *not* happen.
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        reason == null
            ? 'timed out waiting for a connected-playback condition'
            : 'timed out waiting for $reason',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
