import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/result/result.dart';
import '../../domain/connected_playback/CommandAcknowledgement.dart';
import '../../domain/connected_playback/ConnectedDevice.dart';
import '../../domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import '../../domain/connected_playback/ConnectedPlaybackFailures.dart';
import '../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../domain/connected_playback/RemoteCommand.dart';
import '../../domain/connected_playback/RemotePlaybackController.dart';
import '../../domain/connected_playback/RemotePlaybackSnapshot.dart';
import '../../domain/playback/repeat_mode.dart';
import '../../domain/connected_playback/envelope_kind.dart';

/// The controller half of v0.5.3: drives a [RemotePlaybackController]
/// against one chosen [ConnectedDevice], over the real transport.
///
/// Deliberately not a `@lazySingleton` and not started at the
/// composition root — unlike [ConnectedPlaybackTargetLink], which every
/// signed-in device runs continuously because any of them might be
/// controlled, nothing in this build yet *chooses* a device to drive
/// (that is v0.5.5's picker). This class exists so that choice, whenever
/// something makes it, has a tested, correct thing to construct; a
/// headless test is exactly such a caller today.
///
/// It never touches `PlaybackCubit`, `PlaybackQueue` or Jellyfin's
/// progress-reporting endpoint. That is not a guard to remember to keep —
/// there is nothing here to touch them *with* — which is what makes "a
/// controller never reports a second play session for music it is not
/// producing" true by construction rather than by discipline.
///
/// A failed [sendCommand] is treated the same whether the command never
/// left (an immediate transport error) or was sent and never answered (a
/// true timeout): both mark [RemotePlaybackController.needsResync]. The
/// two are not equally likely to have changed the target's state, but
/// refusing to compose another structural edit until a fresh snapshot
/// confirms otherwise is the safe default either way, and the domain
/// layer's own command-id dedup is what makes a future retry safe even
/// when this was too cautious.
class ConnectedPlaybackControllerSession {
  ConnectedPlaybackControllerSession({
    required ConnectedPlaybackTransport transport,
    required ConnectedDevice target,
    required String localSessionId,
  }) : _transport = transport,
       controller = RemotePlaybackController(
         localSessionId: localSessionId,
         target: target,
         commandIds: _defaultCommandIds(localSessionId),
       ) {
    _envelopeSub = transport.envelopes(target.scope).listen(_onEnvelope);
  }

  final ConnectedPlaybackTransport _transport;
  final RemotePlaybackController controller;

  late final StreamSubscription<ConnectedPlaybackEnvelope> _envelopeSub;
  final StreamController<RemotePlaybackSnapshot> _snapshots =
      StreamController<RemotePlaybackSnapshot>.broadcast();

  /// Every snapshot this controller has accepted into
  /// [RemotePlaybackController.projection], in arrival order.
  Stream<RemotePlaybackSnapshot> get snapshots => _snapshots.stream;

  RemotePlaybackSnapshot? get projection => controller.projection;

  /// Follows the target through a reconnection — called once whatever
  /// tracks presence (v0.5.5's device list) sees this device's session id
  /// change.
  void retarget(ConnectedDevice target) => controller.retarget(target);

  Future<Result<void>> play() => _send(controller.play());

  Future<Result<void>> pause() => _send(controller.pause());

  Future<Result<void>> playPause() => _send(controller.playPause());

  Future<Result<void>> stop() => _send(controller.stop());

  Future<Result<void>> next() => _send(controller.next());

  Future<Result<void>> previous() => _send(controller.previous());

  Future<Result<void>> seek(Duration position) =>
      _send(controller.seek(position));

  Future<Result<void>> setVolume(double volume) =>
      _send(controller.setVolume(volume));

  Future<Result<void>> removeQueueEntry(int index) =>
      _send(controller.removeQueueEntry(index));

  Future<Result<void>> moveQueueEntry(int fromIndex, int toIndex) =>
      _send(controller.moveQueueEntry(fromIndex, toIndex));

  Future<Result<void>> setShuffle(bool enabled) =>
      _send(controller.setShuffle(enabled));

  Future<Result<void>> setRepeat(RepeatMode mode) =>
      _send(controller.setRepeat(mode));

  Future<Result<void>> jumpToQueueEntry(int index) =>
      _send(controller.jumpToQueueEntry(index));

  Future<Result<void>> requestSnapshot() => _send(controller.requestSnapshot());

  Future<Result<void>> joinSyncGroup(String groupId) =>
      _send(controller.joinSyncGroup(groupId));

  Future<void> dispose() async {
    await _envelopeSub.cancel();
    await _snapshots.close();
  }

  Future<Result<void>> _send(Result<RemoteCommand> composed) async {
    if (composed case Err<RemoteCommand>(:final failure)) {
      return Result.err(failure);
    }
    final command = (composed as Ok<RemoteCommand>).value;
    final acknowledged = await _transport.sendCommand(command);
    if (acknowledged case Err<CommandAcknowledgement>(:final failure)) {
      controller.onTimeout();
      return Result.err(failure);
    }
    final ack = (acknowledged as Ok<CommandAcknowledgement>).value;
    controller.onAcknowledgement(ack);
    if (!ack.isAccepted) {
      return Result.err(ConnectedPlaybackFailures.fromAcknowledgement(ack));
    }
    return const Result.ok(null);
  }

  void _onEnvelope(ConnectedPlaybackEnvelope envelope) {
    if (envelope.kind != EnvelopeKind.snapshot) return;
    if (envelope.senderSessionId != controller.target.sessionId) return;
    final snapshot = RemotePlaybackSnapshot.tryDecode(
      envelope.payload,
      scope: envelope.scope,
    );
    if (snapshot == null) return;
    if (controller.onSnapshot(snapshot)) _snapshots.add(snapshot);
  }

  static String Function() _defaultCommandIds(String sessionId) {
    var next = 0;
    return () => '$sessionId-${const Uuid().v4()}-${next++}';
  }
}
