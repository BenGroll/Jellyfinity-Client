import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/Logger.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/connected_playback/CommandAcknowledgement.dart';
import '../../../domain/connected_playback/ConnectedDevice.dart';
import '../../../domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import '../../../domain/connected_playback/ConnectedPlaybackFailures.dart';
import '../../../domain/connected_playback/ConnectedPlaybackLimits.dart';
import '../../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../../domain/connected_playback/DeviceAdvertisement.dart';
import '../../../domain/connected_playback/DeviceCapabilities.dart';
import '../../../domain/connected_playback/DevicePresenceRegistry.dart';
import '../../../domain/connected_playback/DevicePresenceSource.dart';
import '../../../domain/connected_playback/ElapsedClock.dart';
import '../../../domain/connected_playback/RemoteCommand.dart';
import '../../../domain/connected_playback/RemotePlaybackSnapshot.dart';
import '../../../domain/connected_playback/connection_state.dart';
import '../../../domain/connected_playback/envelope_ignore_reason.dart';
import '../../../domain/connected_playback/envelope_kind.dart';
import '../../../domain/media/MediaImage.dart';
import '../identity/JellyfinClientIdentity.dart';
import 'ConnectedSessionFailureMapper.dart';
import 'JellyfinSessionApi.dart';
import 'JellyfinSessionDto.dart';
import 'JellyfinSocketConnection.dart';

/// The one lifecycle-aware link between this Jellyfinity install and its
/// peers, through the Jellyfin server they share.
///
/// It implements both of v0.5.1's contracts because they are two views of
/// one connection, not two connections. `DevicePresenceSource` is "who is
/// there"; `ConnectedPlaybackTransport` is "say something to them"; both
/// need the same session, the same socket, the same reconnect and the
/// same local session id, and splitting them would mean two objects
/// racing to establish the same thing.
///
/// The shape of the conversation:
///
/// 1. [advertise] publishes this client's capabilities to the server and
///    opens the link. Called on sign-in and on returning from the
///    background.
/// 2. A full REST read of `/Sessions` establishes the roster and — by
///    matching the stable device id this install always reports — this
///    session's own ephemeral id. Nothing can be addressed until that is
///    known, which is why it comes before the socket rather than after.
/// 3. The socket carries `Sessions` updates and the peers' own presence
///    messages. Jellyfin says which sessions exist; the peers say what
///    they are and what they accept.
/// 4. Any interruption drops back to step 2 after a bounded backoff. A
///    reconnect never resumes mid-conversation: the one thing a dropped
///    socket guarantees is that both sides' idea of the state is
///    unverified.
///
/// Nothing here interprets a command or a snapshot. Envelopes that are
/// not presence or acknowledgement are handed up through [envelopes] for
/// v0.5.3, which is where a command becomes something that happens.
@lazySingleton
class JellyfinSessionTransport
    implements DevicePresenceSource, ConnectedPlaybackTransport {
  JellyfinSessionTransport(this._api, this._identity, this._logger);

  final JellyfinSessionApi _api;
  final JellyfinClientIdentity _identity;
  final Logger _logger;

  bool _localPlaybackInitialized = false;
  bool _localIsPlaying = false;
  String? _localNowPlayingTitle;
  String? _localNowPlayingArtist;
  MediaImage? _localNowPlayingImage;
  String? _localControllingSessionId;

  static const ConnectedSessionFailureMapper _failures =
      ConnectedSessionFailureMapper();

  /// How a socket is opened. Overridden in tests; `null` here would mean
  /// every test needed a server.
  @visibleForTesting
  JellyfinSocketConnector connector = IoJellyfinSocketConnection.connect;

  /// The monotonic clock presence expiry is measured against.
  @visibleForTesting
  ElapsedClock clock = StopwatchElapsedClock();

  @visibleForTesting
  String Function() newMessageId = () => const Uuid().v4();

  /// The backoff schedule and the poll cadence, settable so a test does
  /// not have to wait two real minutes to prove that it doubles.
  @visibleForTesting
  Duration reconnectInitialDelay =
      ConnectedPlaybackLimits.reconnectInitialDelay;

  @visibleForTesting
  Duration reconnectMaxDelay = ConnectedPlaybackLimits.reconnectMaxDelay;

  @visibleForTesting
  Duration presencePollInterval = ConnectedPlaybackLimits.presencePollInterval;

  Duration backgroundPresencePollInterval =
      ConnectedPlaybackLimits.backgroundPresencePollInterval;

  bool _backgrounded = false;

  /// Adjusts presence cadence and expiry while the app is backgrounded.
  void setBackgrounded(bool backgrounded) {
    _backgrounded = backgrounded;
    final registry = _registry;
    if (registry != null) {
      registry.staleAfter = backgrounded
          ? ConnectedPlaybackLimits.backgroundPresenceStaleAfter
          : ConnectedPlaybackLimits.presenceStaleAfter;
    }
    if (_socket == null && _scope != null && !_suspended) _startPolling();
  }

  /// The short platform word shown beside a duplicate device name.
  ///
  /// Defaulted from the host and overridden at composition, because the
  /// one distinction that matters most to a listener — a television
  /// versus a phone — is an Android capability question (ADR-0036) that
  /// only the app layer can ask.
  String platformName = _defaultPlatformName();

  /// What this build tells its peers it will accept. Narrowed by a
  /// composition that knows this install is less than a full player.
  DeviceCapabilities capabilities = DeviceCapabilities.fullPlayer();

  /// Updates the local playback fields included in presence. The app layer
  /// supplies display data so this infrastructure class does not depend on
  /// PlaybackCubit; a fresh presence is sent only when the advertised data
  /// actually changes.
  void updateLocalPlayback({
    required bool isPlaying,
    String? nowPlayingTitle,
    String? nowPlayingArtist,
    MediaImage? nowPlayingImage,
  }) {
    final title = nowPlayingTitle?.trim();
    final artist = nowPlayingArtist?.trim();
    final nextTitle = title == null || title.isEmpty ? null : title;
    final nextArtist = artist == null || artist.isEmpty ? null : artist;
    if (_localPlaybackInitialized &&
        _localIsPlaying == isPlaying &&
        _localNowPlayingTitle == nextTitle &&
        _localNowPlayingArtist == nextArtist &&
        _localNowPlayingImage == nowPlayingImage) {
      return;
    }
    _localPlaybackInitialized = true;
    _localIsPlaying = isPlaying;
    _localNowPlayingTitle = nextTitle;
    _localNowPlayingArtist = nextArtist;
    _localNowPlayingImage = nowPlayingImage;
    unawaited(_announcePresence(replyRequested: false));
  }

  /// Publishes which session this device is currently driving, so peers
  /// can tell that they are being controlled and that this device is not
  /// available to be controlled itself.
  void updateLocalControl(String? controllingSessionId) {
    if (_localControllingSessionId == controllingSessionId) return;
    _localControllingSessionId = controllingSessionId;
    unawaited(_announcePresence(replyRequested: false));
  }

  final StreamController<_ScopedDevices> _deviceUpdates =
      StreamController<_ScopedDevices>.broadcast();
  final StreamController<ConnectedPlaybackConnection> _connectionUpdates =
      StreamController<ConnectedPlaybackConnection>.broadcast();
  final StreamController<ConnectedPlaybackEnvelope> _envelopes =
      StreamController<ConnectedPlaybackEnvelope>.broadcast();

  /// Raw `SyncPlayGroupUpdate` frames (v0.6.0, ADR-0045) — undecoded,
  /// because decoding them into `SyncPlayGroupUpdate` is `JellyfinSyncPlayApi`'s
  /// job, not this transport's; this class only owns the one socket every
  /// connected-playback message, SyncPlay included, actually arrives on.
  final StreamController<_ScopedSyncPlayFrame> _syncPlayFrames =
      StreamController<_ScopedSyncPlayFrame>.broadcast();
  final Map<String, Completer<CommandAcknowledgement>> _pendingAcks = {};

  ConnectedPlaybackScope? _scope;
  DevicePresenceRegistry? _registry;
  String? _sessionId;

  JellyfinSocketConnection? _socket;
  StreamSubscription<String>? _socketMessages;
  Timer? _keepAlive;
  Timer? _reconnect;
  Timer? _poll;
  Duration _nextReconnectDelay = Duration.zero;
  bool _socketEverConnected = false;
  bool _connecting = false;
  bool _suspended = false;

  ConnectedPlaybackConnection _connection = ConnectedPlaybackConnection.idle;

  @override
  String? get localSessionId => _sessionId;

  /// The link state right now, for a caller that needs it synchronously
  /// rather than as a stream.
  ConnectedPlaybackConnection get connectionState => _connection;

  @override
  Stream<ConnectedPlaybackConnection> get connection =>
      _replayed(_connectionUpdates.stream, () => _connection);

  @override
  Stream<List<ConnectedDevice>> devices(ConnectedPlaybackScope scope) {
    return _replayed(
      _deviceUpdates.stream
          .where((update) => update.scope == scope)
          .map((update) => update.devices),
      () => _scope == scope
          ? (_registry?.devices ?? const [])
          : const <ConnectedDevice>[],
    );
  }

  @override
  Stream<ConnectedPlaybackEnvelope> envelopes(ConnectedPlaybackScope scope) =>
      _envelopes.stream.where((envelope) => envelope.scope == scope);

  /// Publishes this device's capabilities for [scope] and brings the link
  /// up.
  ///
  /// Switching scope tears the previous one down completely first. That
  /// is the account-isolation invariant at its most literal: there is no
  /// moment in which a registry built for one profile is still answering
  /// questions asked by the next one.
  @override
  Future<Result<void>> advertise(ConnectedPlaybackScope scope) async {
    final previous = _scope;
    if (previous != null && previous != scope) {
      await clear(previous);
    }
    _scope = scope;
    _registry ??= DevicePresenceRegistry(
      scope: scope,
      clock: clock,
      staleAfter: _backgrounded
          ? ConnectedPlaybackLimits.backgroundPresenceStaleAfter
          : ConnectedPlaybackLimits.presenceStaleAfter,
    );
    _suspended = false;
    return _connect();
  }

  @override
  Future<Result<List<ConnectedDevice>>> refresh(
    ConnectedPlaybackScope scope,
  ) async {
    if (_scope != scope) {
      return const Result.err(
        UnauthorizedFailure('That profile is not signed in.'),
      );
    }
    final result = await _readSessions();
    return result.map((_) => _registry?.devices ?? const []);
  }

  @override
  Future<void> clear(ConnectedPlaybackScope scope) async {
    if (_scope != scope) return;
    _suspended = true;
    await _closeSocket();
    _reconnect?.cancel();
    _reconnect = null;
    _poll?.cancel();
    _poll = null;
    _nextReconnectDelay = Duration.zero;
    _socketEverConnected = false;
    _sessionId = null;
    _failPendingAcks(ConnectedPlaybackFailures.offline());
    _registry?.clear();
    // The last word on this scope is an empty list, so a picker that is
    // still on screen during a sign-out shows nothing rather than the
    // previous profile's devices.
    _deviceUpdates.add(_ScopedDevices(scope, const []));
    _registry = null;
    _scope = null;
    _api.close();
    _setConnection(ConnectedPlaybackConnection.idle);
  }

  /// Lets go of the socket without forgetting anything.
  ///
  /// What the app calls when it is no longer in the foreground and no
  /// longer playing. Distinct from [clear]: the profile has not changed,
  /// so the roster is still true and is still shown — as `presenceOnly`,
  /// because nothing is being delivered — and [resume] costs one REST
  /// read rather than a fresh discovery.
  Future<void> suspend() async {
    if (_scope == null || _suspended) return;
    _suspended = true;
    _reconnect?.cancel();
    _reconnect = null;
    _poll?.cancel();
    _poll = null;
    await _closeSocket();
    _setConnection(ConnectedPlaybackConnection.reconnecting);
    _emitDevices();
  }

  /// Brings the link back up after [suspend], re-establishing the session
  /// and re-reading presence from scratch.
  Future<Result<void>> resume() async {
    final scope = _scope;
    if (scope == null) return const Result.ok(null);
    if (!_suspended && _socket != null) return const Result.ok(null);
    _suspended = false;
    return _connect();
  }

  @override
  Future<Result<void>> send(
    ConnectedPlaybackEnvelope envelope, {
    required String targetSessionId,
  }) async {
    final result = await _api.deliver(
      envelope,
      targetSessionId: targetSessionId,
    );
    if (result.isErr) {
      final failure = result.failureOrNull!;
      // A session the server has never heard of says nothing about this
      // device's link, and treating it as a link problem is how one peer
      // that signed out took the picker down with it: the same 404 that
      // means "no such session" here means "no such route" to
      // [_readSessions], and the shared classifier answered `unsupported`
      // for both. Forget that device instead — the roster read that would
      // have removed it is up to twenty seconds away, and until then it
      // is a row the listener can see and cannot use.
      if (_failures.isMissingTarget(failure)) {
        if (_registry?.forgetSession(targetSessionId) ?? false) {
          _emitDevices();
        }
        return Result.err(ConnectedPlaybackFailures.deviceGone());
      }
      final diagnosis = _failures.fromHttp(failure);
      _applyDiagnosis(diagnosis, retry: false);
      return Result.err(diagnosis.failure);
    }
    return const Result.ok(null);
  }

  @override
  Future<Result<CommandAcknowledgement>> sendCommand(
    RemoteCommand command,
  ) async {
    final scope = _scope;
    final sessionId = _sessionId;
    if (scope == null || sessionId == null || command.scope != scope) {
      return Result.err(ConnectedPlaybackFailures.offline());
    }

    final completer = Completer<CommandAcknowledgement>();
    // Registered before the send, not after: an acknowledgement can
    // arrive while the POST's own response is still in flight, and a
    // completer registered afterwards would miss it and time out on a
    // command that worked.
    _pendingAcks[command.id] = completer;

    _logger.info("Connected playback: sending ${command.kind.name} command.");
    final sent = await send(
      ConnectedPlaybackEnvelope.outgoing(
        messageId: newMessageId(),
        scope: scope,
        senderSessionId: sessionId,
        kind: EnvelopeKind.command,
        payload: command.toPayload(),
      ),
      targetSessionId: command.targetSessionId,
    );
    if (sent.isErr) {
      _pendingAcks.remove(command.id);
      return Result.err(sent.failureOrNull!);
    }

    try {
      final acknowledgement = await completer.future.timeout(
        ConnectedPlaybackLimits.acknowledgementTimeout,
      );
      return Result.ok(acknowledgement);
    } on TimeoutException {
      return Result.err(ConnectedPlaybackFailures.timedOut());
    } finally {
      _pendingAcks.remove(command.id);
    }
  }

  @override
  Future<Result<void>> publishSnapshot(RemotePlaybackSnapshot snapshot) async {
    final scope = _scope;
    final sessionId = _sessionId;
    if (scope == null || sessionId == null || snapshot.scope != scope) {
      return Result.err(ConnectedPlaybackFailures.offline());
    }
    return _broadcast(
      scope: scope,
      sessionId: sessionId,
      kind: EnvelopeKind.snapshot,
      payload: snapshot.toPayload(),
      // A device that cannot drive anything has no use for a snapshot,
      // and sending it one is a message per peer per revision spent on
      // nothing.
      to: (device) => device.capabilities.canControl,
    );
  }

  @override
  Future<Result<void>> resynchronize(ConnectedPlaybackScope scope) async {
    if (_scope != scope) {
      return Result.err(ConnectedPlaybackFailures.offline());
    }
    _setConnection(ConnectedPlaybackConnection.resynchronizing);
    final sessions = await _readSessions();
    if (sessions.isErr) return Result.err(sessions.failureOrNull!);
    await _announcePresence(replyRequested: true);
    _setConnection(
      _socket == null
          ? ConnectedPlaybackConnection.reconnecting
          : ConnectedPlaybackConnection.connected,
    );
    return const Result.ok(null);
  }

  /// Releases everything. The composition root's counterpart to
  /// [advertise]; not part of either contract.
  Future<void> dispose() async {
    final scope = _scope;
    if (scope != null) await clear(scope);
    await _deviceUpdates.close();
    await _connectionUpdates.close();
    await _envelopes.close();
    await _syncPlayFrames.close();
  }

  // --- connection ---------------------------------------------------

  Future<Result<void>> _connect() async {
    final scope = _scope;
    if (scope == null || _connecting) return const Result.ok(null);
    _connecting = true;
    _reconnect?.cancel();
    _reconnect = null;

    try {
      _setConnection(
        _socketEverConnected
            ? ConnectedPlaybackConnection.resynchronizing
            : ConnectedPlaybackConnection.connecting,
      );

      // Capabilities first: the server's own record of what this session
      // accepts has to be right before anything is told the session
      // exists, and it is also the cheapest request that proves the
      // token, the permissions and the server all work.
      final advertised = await _api.advertiseCapabilities(
        supportsMediaControl: capabilities.canPlay,
      );
      if (advertised.isErr) {
        return _fail(_failures.fromHttp(advertised.failureOrNull!));
      }

      final sessions = await _readSessions();
      if (sessions.isErr) return Result.err(sessions.failureOrNull!);

      final socket = await _openSocket();
      // The roster is already established and worth showing even when the
      // socket could not be opened, but the caller is told: a link with no
      // socket delivers nothing, and reporting success for it would make
      // "unsupported" invisible to everything above.
      await _announcePresence(replyRequested: true);
      return socket;
    } finally {
      _connecting = false;
    }
  }

  /// The REST half of a resync: the roster, and this session's own id
  /// within it.
  ///
  /// [rescheduleOnFailure] is false for the presence poll. A poll that
  /// fails is evidence the server is still down, not a new interruption
  /// to back off from, and letting it reschedule the reconnect would let
  /// a fast poll push the slow reconnect over the horizon indefinitely —
  /// presence would keep being attempted and the socket would never be.
  Future<Result<void>> _readSessions({bool rescheduleOnFailure = true}) async {
    final scope = _scope;
    final registry = _registry;
    if (scope == null || registry == null) {
      return Result.err(ConnectedPlaybackFailures.offline());
    }

    final result = await _api.peers();
    if (result.isErr) {
      final diagnosis = _failures.fromHttp(result.failureOrNull!);
      _applyDiagnosis(diagnosis, retry: rescheduleOnFailure);
      return Result.err(diagnosis.failure);
    }

    final sessions = result.valueOrNull!;
    _sessionId = _ownSessionIdIn(sessions);
    final changed = registry.replaceAll(
      sessions.map(
        (session) => session.toObservation(localDeviceId: _identity.deviceId),
      ),
    );
    if (changed || registry.prune()) _emitDevices();
    return const Result.ok(null);
  }

  /// Finds this install's own session among the peers.
  ///
  /// By stable device id, never by name or position: it is the one field
  /// that is the same on both sides of a reconnect, and it is exactly
  /// what the two-part identity exists for. Without it nothing can be
  /// addressed — a peer answers *to a session id*, and this session does
  /// not know its own until the server names it.
  String? _ownSessionIdIn(List<JellyfinSessionDto> sessions) {
    for (final session in sessions) {
      if (session.deviceId == _identity.deviceId) return session.id;
    }
    // The server has not registered this session yet — normal for the
    // first moments after sign-in. The next read finds it.
    return null;
  }

  Future<Result<void>> _openSocket() async {
    final url = await _api.socketUrl();
    if (url == null) {
      return _fail((
        problem: ConnectedSessionProblem.unauthenticated,
        failure: ConnectedPlaybackFailures.unauthenticated(),
        link: ConnectedPlaybackConnection.idle,
      ));
    }

    _logger.info("Connected playback: opening Jellyfin socket.");
    try {
      final socket = await connector(url).timeout(const Duration(seconds: 10));
      _logger.info("Connected playback: Jellyfin socket connected.");
      _socket = socket;
      _socketEverConnected = true;
      _nextReconnectDelay = Duration.zero;
      _poll?.cancel();
      _poll = null;
      _socketMessages = socket.messages.listen(
        _onFrame,
        onError: (Object error) => _onSocketLost(error),
        onDone: () => _onSocketLost(null),
        cancelOnError: true,
      );
      // Ask the server to push session changes. Without this the socket
      // is open and silent, and presence would be whatever the last REST
      // read said until the next poll.
      socket.send(
        jsonEncode({'MessageType': 'SessionsStart', 'Data': '0,1500'}),
      );
      _setConnection(ConnectedPlaybackConnection.connected);
      _emitDevices();
      return const Result.ok(null);
    } catch (error, stackTrace) {
      _logger.warning(
        'The connected-playback socket could not be opened.',
        error: error,
        stackTrace: stackTrace,
      );
      return _fail(
        _failures.fromSocket(error, everConnected: _socketEverConnected),
      );
    }
  }

  void _onFrame(String frame) {
    final Object? decoded;

    try {
      decoded = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;

    switch (decoded['MessageType']) {
      case 'ForceKeepAlive':
        _startKeepAlive(decoded['Data']);
      case 'KeepAlive':
        break;
      case 'Sessions':
        _onSessionsMessage(decoded['Data']);
      case 'GeneralCommand':
        _onGeneralCommand(decoded['Data']);
      case 'SyncPlayGroupUpdate':
        _onSyncPlayGroupUpdate(decoded['Data']);
      default:
        // Every other message on this socket belongs to a different part
        // of Jellyfin. Ignoring them is the normal case, not an error.
        break;
    }
  }

  void _onSessionsMessage(Object? data) {
    final registry = _registry;
    final userId = _scope?.userId;
    if (registry == null || userId == null || data is! List) return;

    final peers = <JellyfinSessionDto>[];
    for (final raw in data) {
      final session = JellyfinSessionDto.tryParse(raw);
      if (session != null && session.isJellyfinityPeerOf(userId)) {
        peers.add(session);
      }
    }
    final previousSessionId = _sessionId;
    _sessionId ??= _ownSessionIdIn(peers);
    final changed = registry.replaceAll(
      peers.map(
        (session) => session.toObservation(localDeviceId: _identity.deviceId),
      ),
    );
    if (changed || registry.prune()) _emitDevices();
    if (previousSessionId == null && _sessionId != null) {
      _logger.info(
        "Connected playback: local session discovered; announcing presence.",
      );
      unawaited(_announcePresence(replyRequested: true));
    }
  }

  void _onGeneralCommand(Object? data) {
    if (data is! Map) return;
    if (data['Name'] != JellyfinSessionApi.envelopeCommandName) return;
    final arguments = data['Arguments'];
    if (arguments is! Map) return;
    final raw = arguments[JellyfinSessionApi.envelopeArgumentName];
    if (raw is! String) return;
    _onEnvelope(raw);
  }

  void _onSyncPlayGroupUpdate(Object? data) {
    final scope = _scope;
    if (scope == null || data is! Map) return;
    _syncPlayFrames.add(
      _ScopedSyncPlayFrame(scope, Map<String, Object?>.from(data)),
    );
  }

  /// Raw `SyncPlayGroupUpdate` payloads for [scope] — `JellyfinSyncPlayApi`'s
  /// own decoding turns these into `SyncPlayGroupUpdate`s; this transport
  /// only owns the socket they arrive on. Not part of
  /// [ConnectedPlaybackTransport]: a SyncPlay group is Jellyfin's own
  /// concept, addressed over REST, not the Jellyfinity envelope protocol.
  Stream<Map<String, Object?>> syncPlayFrames(ConnectedPlaybackScope scope) =>
      _syncPlayFrames.stream
          .where((frame) => frame.scope == scope)
          .map((frame) => frame.data);

  void _onEnvelope(String raw) {
    final scope = _scope;
    final registry = _registry;
    if (scope == null || registry == null) return;

    final decoding = ConnectedPlaybackEnvelope.decode(
      raw,
      localScope: scope,
      // Before the server has named this session, nothing can be
      // self-sent, and the empty string matches no real session id.
      localSessionId: _sessionId ?? '',
    );

    switch (decoding) {
      case IgnoredEnvelope(
        reason: final reason,
        detail: final detail,
        protocolVersion: final version,
        senderSessionId: final sender,
      ):
        if (reason == EnvelopeIgnoreReason.incompatibleProtocol &&
            version != null &&
            sender != null) {
          if (registry.markIncompatible(sender, version)) _emitDevices();
        } else if (reason != EnvelopeIgnoreReason.fromSelf) {
          _logger.debug('Ignored a connected-playback message: $detail');
        }
      case DecodedEnvelope(envelope: final envelope):
        _onDecodedEnvelope(envelope);
    }
  }

  void _onDecodedEnvelope(ConnectedPlaybackEnvelope envelope) {
    final registry = _registry;
    if (registry == null) return;

    switch (envelope.kind) {
      case EnvelopeKind.presence:
        final advertisement = DeviceAdvertisement.tryDecode(envelope.payload);
        if (advertisement == null) return;
        _logger.info('Connected playback: received peer presence.');
        final changed = registry.applyAdvertisement(
          envelope.senderSessionId,
          envelope.protocolVersion,
          advertisement,
        );
        if (changed) _emitDevices();
        // A peer that has just introduced itself is asking to be
        // introduced to in turn. The reply carries no request of its own,
        // which is what stops two devices greeting each other forever.
        if (envelope.payload[_replyRequestedKey] == true) {
          unawaited(
            _sendPresenceTo(envelope.senderSessionId, replyRequested: false),
          );
        }
      case EnvelopeKind.acknowledgement:
        _logger.info("Connected playback: received acknowledgement.");
        final acknowledgement = CommandAcknowledgement.tryDecode(
          envelope.payload,
        );
        if (acknowledgement == null) return;
        final pending = _pendingAcks.remove(acknowledgement.commandId);
        if (pending != null && !pending.isCompleted) {
          pending.complete(acknowledgement);
        }
      case EnvelopeKind.command:
      case EnvelopeKind.snapshot:
      case EnvelopeKind.transferOffer:
      case EnvelopeKind.transferReadiness:
      case EnvelopeKind.transferCommit:
      case EnvelopeKind.transferResult:
        // Delivery ends here. What these mean is v0.5.3's and v0.5.4's
        // to decide.
        _logger.info(
          "Connected playback: received ${envelope.kind.name} envelope.",
        );
        _envelopes.add(envelope);
    }
  }

  void _startKeepAlive(Object? data) {
    final seconds = data is int ? data : (data is num ? data.toInt() : 60);
    _keepAlive?.cancel();
    // Half the server's stated interval, so one missed tick does not cost
    // the socket.
    final period = Duration(seconds: (seconds ~/ 2).clamp(5, 120));
    _keepAlive = Timer.periodic(period, (_) {
      final socket = _socket;
      if (socket == null) return;

      try {
        socket.send(jsonEncode({'MessageType': 'KeepAlive'}));
      } catch (error) {
        _onSocketLost(error);
      }
    });
  }

  void _onSocketLost(Object? error) {
    if (_socket == null) return;
    _logger.info('The connected-playback socket closed; reconnecting.');
    unawaited(_closeSocket());
    _failPendingAcks(ConnectedPlaybackFailures.offline());
    if (_suspended || _scope == null) return;
    _setConnection(ConnectedPlaybackConnection.reconnecting);
    _emitDevices();
    _scheduleReconnect();
    _startPolling();
  }

  Future<void> _closeSocket() async {
    _keepAlive?.cancel();
    _keepAlive = null;
    final subscription = _socketMessages;
    final socket = _socket;
    _socketMessages = null;
    _socket = null;
    await subscription?.cancel();

    try {
      await socket?.close();
    } catch (_) {
      // A socket that is already gone does not need closing politely.
    }
  }

  /// Doubles the wait after each failed attempt, up to
  /// [reconnectMaxDelay], and never stops trying.
  ///
  /// Never stopping is deliberate for the retryable problems: a listener
  /// whose Wi-Fi came back should not have to restart the app. The
  /// problems where retrying cannot help do not get here at all — see
  /// [_fail].
  void _scheduleReconnect() {
    _reconnect?.cancel();
    _nextReconnectDelay = _nextReconnectDelay == Duration.zero
        ? reconnectInitialDelay
        : _nextReconnectDelay * 2;
    if (_nextReconnectDelay > reconnectMaxDelay) {
      _nextReconnectDelay = reconnectMaxDelay;
    }
    _reconnect = Timer(_nextReconnectDelay, () {
      if (_suspended || _scope == null) return;
      unawaited(_connect());
    });
  }

  /// Bounded REST polling while the socket is down.
  ///
  /// Keeps a device listed and honestly labelled rather than letting it
  /// vanish mid-reconnect, which is the difference between a picker that
  /// looks broken and one that says what is happening. Deliberately far
  /// slower than the socket it stands in for.
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      _backgrounded ? backgroundPresencePollInterval : presencePollInterval,
      (_) {
        if (_scope == null || _socket != null) return;
        unawaited(_readSessions(rescheduleOnFailure: false));
      },
    );
  }

  // --- presence -----------------------------------------------------

  /// Introduces this device to every peer the server knows about.
  Future<void> _announcePresence({required bool replyRequested}) async {
    final scope = _scope;
    final sessionId = _sessionId;
    if (scope == null || sessionId == null) return;
    await _broadcast(
      scope: scope,
      sessionId: sessionId,
      kind: EnvelopeKind.presence,
      payload: {
        ..._advertisement().toPayload(),
        if (replyRequested) _replyRequestedKey: true,
      },
      to: (device) => !device.isThisDevice,
    );
  }

  Future<void> _sendPresenceTo(
    String targetSessionId, {
    required bool replyRequested,
  }) async {
    final scope = _scope;
    final sessionId = _sessionId;
    if (scope == null || sessionId == null) return;
    await send(
      ConnectedPlaybackEnvelope.outgoing(
        messageId: newMessageId(),
        scope: scope,
        senderSessionId: sessionId,
        kind: EnvelopeKind.presence,
        payload: {
          ..._advertisement().toPayload(),
          if (replyRequested) _replyRequestedKey: true,
        },
      ),
      targetSessionId: targetSessionId,
    );
  }

  DeviceAdvertisement _advertisement() => DeviceAdvertisement(
    deviceId: _identity.deviceId,
    name: _identity.deviceName,
    capabilities: capabilities,
    platform: platformName,
    isPlaying: _isPlayingLocally,
    nowPlayingTitle: _localNowPlayingTitle,
    nowPlayingArtist: _localNowPlayingArtist,
    nowPlayingImage: _localNowPlayingImage,
    controllingSessionId: _localControllingSessionId,
  );

  /// Whether this device is the one making noise, as the server sees it.
  ///
  /// Read back from the registry rather than from `PlaybackCubit`: this
  /// version does not touch playback, and the server's own record of the
  /// session is already the value every peer is being shown.
  bool get _isPlayingLocally {
    if (_localPlaybackInitialized) return _localIsPlaying;
    for (final device in _registry?.devices ?? const <ConnectedDevice>[]) {
      if (device.isThisDevice) return device.isPlaying;
    }
    return false;
  }

  Future<Result<void>> _broadcast({
    required ConnectedPlaybackScope scope,
    required String sessionId,
    required EnvelopeKind kind,
    required Map<String, Object?> payload,
    required bool Function(ConnectedDevice device) to,
  }) async {
    final targets = (_registry?.devices ?? const <ConnectedDevice>[])
        .where((device) => !device.isThisDevice && to(device))
        .toList();
    _logger.info(
      'Connected playback: broadcasting ${kind.name} to ${targets.length} peer(s).',
    );
    Failure? firstFailure;
    for (final device in targets) {
      final result = await send(
        ConnectedPlaybackEnvelope.outgoing(
          messageId: newMessageId(),
          scope: scope,
          senderSessionId: sessionId,
          kind: kind,
          payload: payload,
        ),
        targetSessionId: device.sessionId,
      );
      // One unreachable peer does not fail the announcement to the
      // others: a device that went away between the roster read and this
      // send is the ordinary case, not a reason to stop talking to
      // everything else.
      firstFailure ??= result.failureOrNull;
    }
    return firstFailure == null
        ? const Result.ok(null)
        : Result.err(firstFailure);
  }

  // --- plumbing -----------------------------------------------------

  Result<void> _fail(ConnectedSessionDiagnosis diagnosis) {
    _applyDiagnosis(diagnosis, retry: true);
    return Result.err(diagnosis.failure);
  }

  void _applyDiagnosis(
    ConnectedSessionDiagnosis diagnosis, {
    required bool retry,
  }) {
    _setConnection(diagnosis.link);
    _emitDevices();
    if (retry && !_suspended && _failures.isRetryable(diagnosis.problem)) {
      _scheduleReconnect();
      _startPolling();
    }
  }

  void _setConnection(ConnectedPlaybackConnection state) {
    if (_connection == state) return;
    _connection = state;
    _registry?.setLink(state);
    if (!_connectionUpdates.isClosed) _connectionUpdates.add(state);
  }

  void _emitDevices() {
    final scope = _scope;
    final registry = _registry;
    if (scope == null || registry == null || _deviceUpdates.isClosed) return;
    _deviceUpdates.add(_ScopedDevices(scope, registry.devices));
  }

  void _failPendingAcks(Failure failure) {
    final pending = _pendingAcks.values.toList();
    _pendingAcks.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(failure);
    }
  }

  /// A stream that hands a new listener the current value before the
  /// updates.
  ///
  /// A device picker opened between two changes must not wait for a third
  /// to have anything to draw. `Stream.multi` rather than an `async*`
  /// wrapper because the latter can lose an update emitted between the
  /// first yield and its own subscription.
  static Stream<T> _replayed<T>(Stream<T> updates, T Function() current) {
    return Stream<T>.multi((controller) {
      controller.add(current());
      final subscription = updates.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// The presence-payload flag asking the recipient to introduce itself
  /// back. Not part of [DeviceAdvertisement]: it says something about
  /// this message, not about the device that sent it.
  static const String _replyRequestedKey = 'reply';

  static String _defaultPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Jellyfinity';
  }
}

/// A device list with the scope it belongs to, so one broadcast stream
/// can serve several scopes without a listener ever seeing another
/// profile's devices.
class _ScopedDevices {
  const _ScopedDevices(this.scope, this.devices);

  final ConnectedPlaybackScope scope;
  final List<ConnectedDevice> devices;
}

/// One raw `SyncPlayGroupUpdate` frame, tagged with whichever scope this
/// socket belonged to when it arrived — the same "tag it going in, filter
/// it coming out" shape [_ScopedDevices] already uses, since Jellyfin's
/// own SyncPlay messages carry no Jellyfinity-specific scope of their own.
class _ScopedSyncPlayFrame {
  const _ScopedSyncPlayFrame(this.scope, this.data);

  final ConnectedPlaybackScope scope;
  final Map<String, Object?> data;
}
