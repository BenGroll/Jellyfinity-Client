import 'package:injectable/injectable.dart';

import '../../../core/logging/Logger.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import '../../../domain/connected_playback/ConnectedPlaybackFailures.dart';
import '../../../domain/connected_playback/ConnectedPlaybackLimits.dart';
import '../http/JellyfinHttpClient.dart';
import '../identity/auth_token_provider.dart';
import '../identity/JellyfinClientIdentity.dart';
import '../identity/JellyfinSessionContext.dart';
import '../server/MinimumServerVersionPolicy.dart';
import '../server/ServerVersion.dart';
import 'JellyfinSessionDto.dart';

/// Builds the session-scoped HTTP client. Injected for the same reason
/// `MediaHttpClientFactory` is: tests answer from a fake adapter.
typedef SessionHttpClientFactory = JellyfinHttpClient Function(String baseUrl);

/// The REST half of connected playback: Jellyfin's authenticated session
/// endpoints.
///
/// Three jobs, and each is the answer to a question the WebSocket cannot
/// answer on its own — what this client can do, which sessions exist, and
/// delivering a message to one of them. The socket pushes changes; this
/// establishes the truth those changes are deltas against, which is why
/// every reconnect ends in a full read here rather than resuming the
/// stream where it stopped.
///
/// Failures come back raw from the HTTP layer and are normalized by
/// `ConnectedSessionFailureMapper` rather than here, because the same
/// four categories have to be recovered from socket errors too and one
/// classifier that both halves share is the only way they can agree.
/// The single exception is the server-version floor, which is checked
/// here because this is where the saved version is in hand.
@lazySingleton
class JellyfinSessionApi {
  JellyfinSessionApi(
    this._context,
    this._identity,
    this._authTokenProvider,
    this._logger,
  );

  final JellyfinSessionContext _context;
  final JellyfinClientIdentity _identity;
  final AuthTokenProvider _authTokenProvider;
  final Logger _logger;

  /// Overrides how the HTTP client is built. `null` in production.
  SessionHttpClientFactory? httpClientFactory;

  JellyfinHttpClient? _client;
  String? _clientBaseUrl;

  static const String sessionsPath = '/Sessions';
  static const String capabilitiesPath = '/Sessions/Capabilities/Full';

  /// The `GeneralCommand` Jellyfinity envelopes travel inside.
  ///
  /// Jellyfin has no client-defined message: `GeneralCommandType` is a
  /// server-side enum and `ClientCapabilities` validates everything it
  /// accepts against one, so an envelope has to ride in an existing
  /// command's free-form argument. `SendString` is the one whose
  /// argument is exactly that — a single opaque string with no display
  /// or playback meaning attached to it — and it is only ever addressed
  /// to a session that identifies itself as Jellyfinity, so no other
  /// client can be handed one.
  static const String envelopeCommandName = 'SendString';
  static const String envelopeArgumentName = 'String';

  static String commandPath(String sessionId) => '/Sessions/$sessionId/Command';

  /// Publishes this client's full playback capabilities.
  ///
  /// Sent on every connect rather than once at sign-in: a session is
  /// ephemeral, and capabilities belong to the session, so a reconnect
  /// that skipped this would leave the server describing a device that
  /// accepts nothing.
  ///
  /// The one request connected playback cannot survive failing, which is
  /// why its shape is spelled out here. `/Sessions/Capabilities/Full`
  /// takes a `ClientCapabilitiesDto` as a **required JSON body**, not
  /// query parameters (those belong to the older `/Sessions/Capabilities`
  /// route), and since the array change every list field is a JSON array
  /// rather than a comma-joined string. Sent the wrong way the server
  /// refuses the request, `SupportsMediaControl` stays false, and
  /// `/Sessions?ControllableByUserId=` — which returns only sessions with
  /// remote control — hides this install from every other device *and*
  /// from itself, leaving a picker that can only ever say it found
  /// nothing.
  Future<Result<void>> advertiseCapabilities({
    required bool supportsMediaControl,
  }) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    final result = await client.send(
      capabilitiesPath,
      method: 'POST',
      body: {
        'PlayableMediaTypes': const ['Audio'],
        'SupportedCommands': _supportedCommandNames,
        'SupportsMediaControl': supportsMediaControl,
        'SupportsPersistentIdentifier': true,
      },
    );
    return result;
  }

  /// Reads every session this profile may control, reduced to the
  /// Jellyfinity peers among them.
  ///
  /// Narrowed three times on purpose. `ControllableByUserId` lets the
  /// server do the filtering (`PHILOSOPHY.md` §11), and the local check
  /// repeats it because an administrator's `/Sessions` can legitimately
  /// include every other person signed in to the server — and the scope
  /// invariant is Jellyfinity's answer to "whose devices are these", not
  /// the server's answer to "what may you control".
  ///
  /// `ActiveWithinSeconds` is the third, and it is about a different
  /// mistake: Jellyfin's session list is a history rather than a roster,
  /// so without a bound it answers with every install that ever signed
  /// in. See [ConnectedPlaybackLimits.sessionActiveWithin].
  Future<Result<List<JellyfinSessionDto>>> peers() async {
    final client = _clientOrNull();
    final userId = _context.userId;
    if (client == null || userId == null) return Result.err(_signedOut());

    final unsupported = serverTooOld();
    if (unsupported != null) return Result.err(unsupported);

    final result = await client.getJsonList<JellyfinSessionDto>(
      sessionsPath,
      queryParameters: {
        'ControllableByUserId': userId,
        'ActiveWithinSeconds':
            ConnectedPlaybackLimits.sessionActiveWithin.inSeconds,
      },
      parse: JellyfinSessionDto.tryParse,
    );
    return result.map(
      (sessions) => sessions
          .where((session) => session.isJellyfinityPeerOf(userId))
          .toList(),
    );
  }

  /// Delivers one envelope to one session.
  ///
  /// An `Ok` means the *server* accepted it for relay, never that the
  /// target did anything with it — the distinction
  /// `ConnectedPlaybackTransport.send` is explicit about.
  Future<Result<void>> deliver(
    ConnectedPlaybackEnvelope envelope, {
    required String targetSessionId,
  }) async {
    final client = _clientOrNull();
    if (client == null) return Result.err(_signedOut());
    final encoded = envelope.encode();
    final result = await client.send(
      commandPath(targetSessionId),
      method: 'POST',
      body: {
        'Name': envelopeCommandName,
        'Arguments': {envelopeArgumentName: encoded},
      },
    );
    return result;
  }

  /// The WebSocket address for the active session, or `null` when signed
  /// out.
  ///
  /// The device id rides along because Jellyfin keys the socket to the
  /// session the same identity header established, so a socket opened
  /// without it belongs to nothing.
  Future<Uri?> socketUrl() async {
    final baseUrl = _context.baseUrl;
    final token = await _authTokenProvider.currentToken();
    if (baseUrl == null || token == null || token.isEmpty) return null;
    final base = Uri.tryParse(baseUrl);
    if (base == null) return null;
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${_trimTrailingSlash(base.path)}/socket',
      queryParameters: {'api_key': token, 'deviceId': _identity.deviceId},
    );
  }

  /// Releases the session-scoped client. Called when the active server
  /// changes; harmless otherwise.
  void close() {
    _client?.close();
    _client = null;
    _clientBaseUrl = null;
  }

  /// The server's saved version measured against Jellyfinity's floor, or
  /// `null` when it is new enough — or when its version string was
  /// unreadable, which is not evidence of anything. The sign-in probe is
  /// where a server is vetted; refusing to look for devices because a
  /// version string was odd would be a worse answer than trying and
  /// failing honestly.
  Failure? serverTooOld() {
    final reported = _context.serverVersion;
    if (reported == null) return null;
    final version = ServerVersion.tryParse(reported);
    if (version == null) return null;
    if (MinimumServerVersionPolicy.current.isSupported(version)) return null;
    return ConnectedPlaybackFailures.serverTooOld(reported);
  }

  Failure _signedOut() =>
      const UnauthorizedFailure('Sign in to see your other devices.');

  JellyfinHttpClient? _clientOrNull() {
    final baseUrl = _context.baseUrl;
    if (baseUrl == null) return null;
    final cached = _client;
    if (cached != null && _clientBaseUrl == baseUrl) return cached;
    close();
    final client = (httpClientFactory ?? _defaultClient)(baseUrl);
    _client = client;
    _clientBaseUrl = baseUrl;
    return client;
  }

  JellyfinHttpClient _defaultClient(String baseUrl) {
    _logger.debug('Opening a connected-playback client for this server.');
    return JellyfinHttpClient(
      baseUrl: baseUrl,
      identity: _identity,
      authTokenProvider: _authTokenProvider,
      logger: _logger,
    );
  }

  /// The Jellyfin command names this client tells the server it accepts.
  ///
  /// Only the ones Jellyfin itself defines: the server's own remote
  /// controls (a web client pressing pause on this device) go through
  /// these, while Jellyfinity-to-Jellyfinity commands travel inside
  /// [envelopeCommandName] and are negotiated by `DeviceCapabilities`
  /// instead. Two vocabularies, because only one of them is Jellyfin's
  /// to define.
  ///
  /// Every entry must be a member of Jellyfin's `GeneralCommandType`, or
  /// the server cannot bind the list and refuses the whole capability
  /// post. That is a narrower vocabulary than it looks: pause, unpause,
  /// stop, next, previous and seek are `PlaystateCommand` values, not
  /// general commands, and a session declares it accepts all of them by
  /// naming the single `PlayState` entry that carries them. `SetVolume`
  /// is left out on purpose, for the reason `supportedRemoteCommands`
  /// gives: no Jellyfinity platform exposes a settable output volume
  /// yet, and claiming one produces a control that does nothing.
  static const List<String> _supportedCommandNames = [
    'Play',
    'PlayState',
    'SetRepeatMode',
    'SetShuffleQueue',
    envelopeCommandName,
  ];

  static String _trimTrailingSlash(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}
