import 'package:jellyfinity/domain/connected_playback/CommandAcknowledgement.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedDevice.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/DeviceCapabilities.dart';
import 'package:jellyfinity/domain/connected_playback/PlaybackTransfer.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteCommand.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackController.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackSnapshot.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackTarget.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteQueueEntry.dart';
import 'package:jellyfinity/domain/connected_playback/command_outcome.dart';
import 'package:jellyfinity/domain/connected_playback/envelope_kind.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';

import 'FakeConnectedPlaybackNetwork.dart';
import 'FakeElapsedClock.dart';

/// Two Jellyfinity clients talking to each other over
/// [FakeConnectedPlaybackNetwork], with no Flutter, no audio backend and
/// no Jellyfin server.
///
/// This is what v0.5.1's definition of done asks for, built as a harness
/// rather than repeated per test: "the complete discovery, control,
/// synchronization, and handoff conversation can be exercised in pure
/// tests". Each node wires one of the two pure services —
/// [RemotePlaybackTarget] on the device that plays, [RemotePlaybackController]
/// on the device that drives — to the envelope codec, and does nothing
/// else. Everything a test then asserts is behaviour of the production
/// classes, not of the harness.

/// The device producing audio.
class FakeTargetNode {
  FakeTargetNode({
    required this.sessionId,
    required this.network,
    required this.clock,
    required ConnectedPlaybackScope scope,
    RemotePlaybackSnapshot? initialState,
    DeviceCapabilities? capabilities,
  }) : target = RemotePlaybackTarget(
         initialState:
             initialState ??
             RemotePlaybackSnapshot.idle(scope: scope, sessionId: sessionId),
         clock: clock,
         capabilities: capabilities,
       ) {
    network.connect(sessionId, scope: scope, onEnvelope: _onEnvelope);
  }

  final String sessionId;
  final FakeConnectedPlaybackNetwork network;
  final FakeElapsedClock clock;
  final RemotePlaybackTarget target;

  /// Commands held on arrival instead of processed — used to open the
  /// window between arrival and processing that expiry is measured in.
  final List<HeldCommand> pending = [];

  /// Whether arriving commands are held in [pending] rather than acted on
  /// immediately.
  bool holdCommands = false;

  /// How this device answers a [TransferOffer]. The default accepts
  /// everything; a test that needs a refusal replaces it.
  TransferReadiness Function(TransferOffer offer) prepare = (offer) =>
      TransferReadiness.ready(
        transferId: offer.transferId,
        targetSessionId: offer.targetSessionId,
      );

  /// Acknowledgements this node has sent, in order.
  final List<CommandAcknowledgement> sent = [];

  int _messages = 0;

  RemotePlaybackSnapshot get snapshot => target.snapshot;

  /// Processes everything held, in arrival order.
  void drain() {
    final held = [...pending];
    pending.clear();
    for (final entry in held) {
      _answer(target.process(entry.command), to: entry.sender);
    }
  }

  void publishSnapshot({required String to}) {
    network.send(
      ConnectedPlaybackEnvelope.outgoing(
        messageId: '$sessionId-m${_messages++}',
        scope: snapshot.scope,
        senderSessionId: sessionId,
        kind: EnvelopeKind.snapshot,
        payload: snapshot.toPayload(),
      ),
      to: to,
    );
  }

  void _onEnvelope(ConnectedPlaybackEnvelope envelope) {
    switch (envelope.kind) {
      case EnvelopeKind.command:
        final decoding = decodeRemoteCommand(
          envelope.payload,
          scope: envelope.scope,
        );
        switch (decoding) {
          case DecodedRemoteCommand(:final command):
            final received = target.receive(command);
            if (holdCommands) {
              pending.add(
                HeldCommand(
                  command: received,
                  sender: envelope.senderSessionId,
                ),
              );
              return;
            }
            _answer(target.process(received), to: envelope.senderSessionId);
          case UnsupportedRemoteCommand(:final commandId):
            _send(
              envelope.senderSessionId,
              EnvelopeKind.acknowledgement,
              CommandAcknowledgement.refused(
                commandId: commandId,
                sessionId: sessionId,
                outcome: CommandOutcome.unsupported,
                revision: snapshot.revision,
              ).toPayload(),
            );
          case UnreadableRemoteCommand():
            // Nothing to answer — there is no command id to answer
            // about. The controller's own timeout covers it.
            return;
        }
      case EnvelopeKind.transferOffer:
        final offer = _offerFrom(envelope);
        if (offer == null) return;
        final readiness = prepare(offer);
        _send(envelope.senderSessionId, EnvelopeKind.transferReadiness, {
          'transferId': readiness.transferId,
          'ready': readiness.isReady,
          if (readiness.refusal != null) 'refusal': readiness.refusal!.name,
          'unresolvable': [
            for (final item in readiness.unresolvable)
              {'id': item.id, 'reason': item.reason, 'position': item.position},
          ],
        });
      case EnvelopeKind.transferCommit:
        final transferId = envelope.payload['transferId'];
        final offer = _lastOffer;
        if (transferId is! String || offer == null) return;
        final positionMs = envelope.payload['positionMs'];
        target.publishLocalChange(
          (current) => current.copyWith(
            queue: offer.entries,
            currentIndex: offer.startIndex,
            position: positionMs is int
                ? Duration(milliseconds: positionMs)
                : offer.startPosition,
            shuffleEnabled: offer.shuffleEnabled,
            repeatMode: offer.repeatMode,
            originName: offer.originName,
            status: PlaybackStatus.playing,
          ),
        );
        _send(envelope.senderSessionId, EnvelopeKind.transferResult, {
          'transferId': transferId,
          'accepted': true,
          'revision': snapshot.revision.value,
        });
      case EnvelopeKind.acknowledgement:
      case EnvelopeKind.snapshot:
      case EnvelopeKind.presence:
      case EnvelopeKind.transferReadiness:
      case EnvelopeKind.transferResult:
        return;
    }
  }

  TransferOffer? _lastOffer;

  TransferOffer? _offerFrom(ConnectedPlaybackEnvelope envelope) {
    final decoded = decodeTransferOffer(envelope);
    _lastOffer = decoded;
    return decoded;
  }

  void _answer(CommandAcknowledgement acknowledgement, {required String to}) {
    sent.add(acknowledgement);
    _send(to, EnvelopeKind.acknowledgement, acknowledgement.toPayload());
  }

  void _send(String to, EnvelopeKind kind, Map<String, Object?> payload) {
    if (to.isEmpty) return;
    network.send(
      ConnectedPlaybackEnvelope.outgoing(
        messageId: '$sessionId-m${_messages++}',
        scope: snapshot.scope,
        senderSessionId: sessionId,
        kind: kind,
        payload: payload,
      ),
      to: to,
    );
  }
}

/// One arrived-but-not-yet-processed command and who sent it.
class HeldCommand {
  const HeldCommand({required this.command, required this.sender});

  final PendingRemoteCommand command;
  final String sender;
}

/// The device driving another one.
class FakeControllerNode {
  FakeControllerNode({
    required this.sessionId,
    required this.network,
    required ConnectedDevice target,
    required ConnectedPlaybackScope scope,
  }) : controller = RemotePlaybackController(
         localSessionId: sessionId,
         target: target,
         commandIds: _sequentialIds(sessionId),
       ) {
    network.connect(sessionId, scope: scope, onEnvelope: _onEnvelope);
  }

  final String sessionId;
  final FakeConnectedPlaybackNetwork network;
  final RemotePlaybackController controller;

  /// Acknowledgements received, in delivery order.
  final List<CommandAcknowledgement> acknowledgements = [];

  /// Snapshots received, in delivery order — including the ones the
  /// controller then ignored as out of order.
  final List<RemotePlaybackSnapshot> snapshots = [];

  /// Envelopes this node does not handle itself — the handoff messages,
  /// which v0.5.4 will own. A test driving `PlaybackHandoff` over the
  /// network supplies this.
  void Function(ConnectedPlaybackEnvelope envelope)? onOtherEnvelope;

  int _messages = 0;

  void send(RemoteCommand command) {
    network.send(
      ConnectedPlaybackEnvelope.outgoing(
        messageId: '$sessionId-m${_messages++}',
        scope: command.scope,
        senderSessionId: sessionId,
        kind: EnvelopeKind.command,
        payload: command.toPayload(),
      ),
      to: command.targetSessionId,
    );
  }

  void sendEnvelope(EnvelopeKind kind, Map<String, Object?> payload) {
    network.send(
      ConnectedPlaybackEnvelope.outgoing(
        messageId: '$sessionId-m${_messages++}',
        scope: controller.target.scope,
        senderSessionId: sessionId,
        kind: kind,
        payload: payload,
      ),
      to: controller.target.sessionId,
    );
  }

  void _onEnvelope(ConnectedPlaybackEnvelope envelope) {
    switch (envelope.kind) {
      case EnvelopeKind.acknowledgement:
        final acknowledgement = CommandAcknowledgement.tryDecode(
          envelope.payload,
        );
        if (acknowledgement == null) return;
        acknowledgements.add(acknowledgement);
        controller.onAcknowledgement(acknowledgement);
      case EnvelopeKind.snapshot:
        final snapshot = RemotePlaybackSnapshot.tryDecode(
          envelope.payload,
          scope: envelope.scope,
        );
        if (snapshot == null) return;
        snapshots.add(snapshot);
        controller.onSnapshot(snapshot);
      case EnvelopeKind.command:
      case EnvelopeKind.presence:
      case EnvelopeKind.transferOffer:
      case EnvelopeKind.transferReadiness:
      case EnvelopeKind.transferCommit:
      case EnvelopeKind.transferResult:
        onOtherEnvelope?.call(envelope);
        return;
    }
  }

  static String Function() _sequentialIds(String prefix) {
    var next = 0;
    return () => '$prefix-c${next++}';
  }
}

/// Reads a [TransferOffer] back out of an envelope.
///
/// Lives in the harness rather than in `PlaybackTransfer.dart` because
/// v0.5.1 defines the handoff *conversation*; v0.5.4 builds the real
/// coordinator and owns how these messages are framed on the wire. What
/// this version has to prove is that the four-step conversation is
/// exercisable end to end, and this is the smallest thing that does it.
TransferOffer? decodeTransferOffer(ConnectedPlaybackEnvelope envelope) {
  final payload = envelope.payload;
  final transferId = payload['transferId'];
  final target = payload['target'];
  if (transferId is! String || target is! String) return null;
  final rawEntries = payload['entries'];
  if (rawEntries is! List) return null;
  final decoded = <RemoteQueueEntry>[];
  for (final raw in rawEntries) {
    final entry = RemoteQueueEntry.tryDecode(raw);
    if (entry == null) return null;
    decoded.add(entry);
  }
  final startIndex = payload['startIndex'];
  final positionMs = payload['startPositionMs'];
  return TransferOffer(
    transferId: transferId,
    scope: envelope.scope,
    sourceSessionId: envelope.senderSessionId,
    targetSessionId: target,
    entries: decoded,
    startIndex: startIndex is int ? startIndex : 0,
    startPosition: positionMs is int
        ? Duration(milliseconds: positionMs)
        : Duration.zero,
    originName: payload['originName'] as String?,
  );
}
