import 'dart:async';

import 'package:jellyfinity/domain/connected_playback/CommandAcknowledgement.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackFailures.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackTransport.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteCommand.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackSnapshot.dart';
import 'package:jellyfinity/domain/connected_playback/envelope_kind.dart';
import 'package:jellyfinity/core/result/result.dart';

import 'FakeConnectedPlaybackNetwork.dart';

/// A [ConnectedPlaybackTransport] for one node of
/// [FakeConnectedPlaybackNetwork] — the async, ack-completing contract
/// application code depends on, backed by the same deterministic fault
/// injection (duplicate/reorder/drop/hold) the pure domain tests already
/// trust (v0.5.1).
///
/// [JellyfinSessionTransport] is the production implementation of this
/// same contract; this is the "in-memory fake the contract tests drive"
/// its own class doc promises, generalized so `ConnectedPlaybackTargetLink`
/// and `ConnectedPlaybackControllerSession` (v0.5.3) can be exercised two
/// nodes at a time without a simulated Jellyfin server.
class FakeConnectedPlaybackTransport implements ConnectedPlaybackTransport {
  FakeConnectedPlaybackTransport({
    required this.network,
    required String sessionId,
    required ConnectedPlaybackScope scope,
    this.watchers = const [],
    this.acknowledgementTimeout =
        ConnectedPlaybackLimits.acknowledgementTimeout,
  }) : _sessionId = sessionId,
       _scope = scope {
    network.connect(_sessionId, scope: _scope, onEnvelope: _onEnvelope);
  }

  final FakeConnectedPlaybackNetwork network;
  final ConnectedPlaybackScope _scope;
  String _sessionId;

  /// This node's session id. Mutable so a test can simulate a
  /// reconnection landing a new one, exactly as a real transport's
  /// `localSessionId` changes underneath a live object — re-registering
  /// with [network] under the new id, so a message still addressed to
  /// the old one no longer reaches this node (matching a real
  /// reconnect's `wrongTarget` behaviour) while one addressed to the new
  /// id now does.
  String get sessionId => _sessionId;

  set sessionId(String value) {
    if (value == _sessionId) return;
    network.disconnect(_sessionId);
    _sessionId = value;
    network.connect(_sessionId, scope: _scope, onEnvelope: _onEnvelope);
  }

  /// Other sessions to broadcast a snapshot to — this fake's stand-in for
  /// the real transport's "every session that can control" server query.
  List<String> watchers;

  final Duration acknowledgementTimeout;

  final StreamController<ConnectedPlaybackEnvelope> _envelopes =
      StreamController<ConnectedPlaybackEnvelope>.broadcast();
  final Map<String, Completer<CommandAcknowledgement>> _pendingAcks = {};
  int _messages = 0;

  @override
  String? get localSessionId => sessionId;

  @override
  Stream<ConnectedPlaybackEnvelope> envelopes(ConnectedPlaybackScope scope) =>
      _envelopes.stream.where((envelope) => envelope.scope == scope);

  @override
  Future<Result<void>> send(
    ConnectedPlaybackEnvelope envelope, {
    required String targetSessionId,
  }) async {
    network.send(envelope, to: targetSessionId);
    return const Result.ok(null);
  }

  @override
  Future<Result<CommandAcknowledgement>> sendCommand(
    RemoteCommand command,
  ) async {
    final completer = Completer<CommandAcknowledgement>();
    _pendingAcks[command.id] = completer;
    await send(
      ConnectedPlaybackEnvelope.outgoing(
        messageId: '$sessionId-m${_messages++}',
        scope: command.scope,
        senderSessionId: sessionId,
        kind: EnvelopeKind.command,
        payload: command.toPayload(),
      ),
      targetSessionId: command.targetSessionId,
    );
    try {
      final acknowledgement = await completer.future.timeout(
        acknowledgementTimeout,
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
    for (final watcher in watchers) {
      await send(
        ConnectedPlaybackEnvelope.outgoing(
          messageId: '$sessionId-m${_messages++}',
          scope: snapshot.scope,
          senderSessionId: sessionId,
          kind: EnvelopeKind.snapshot,
          payload: snapshot.toPayload(),
        ),
        targetSessionId: watcher,
      );
    }
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> resynchronize(ConnectedPlaybackScope scope) async =>
      const Result.ok(null);

  void _onEnvelope(ConnectedPlaybackEnvelope envelope) {
    if (envelope.kind == EnvelopeKind.acknowledgement) {
      final acknowledgement = CommandAcknowledgement.tryDecode(
        envelope.payload,
      );
      if (acknowledgement == null) return;
      _pendingAcks.remove(acknowledgement.commandId)?.complete(acknowledgement);
      return;
    }
    _envelopes.add(envelope);
  }
}
