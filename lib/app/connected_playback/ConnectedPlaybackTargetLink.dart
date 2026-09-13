import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/Logger.dart';
import '../../domain/connected_playback/CommandAcknowledgement.dart';
import '../../domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../domain/connected_playback/ElapsedClock.dart';
import '../../domain/connected_playback/RemoteCommand.dart';
import '../../domain/connected_playback/RemotePlaybackSnapshot.dart';
import '../../domain/connected_playback/RemotePlaybackTarget.dart';
import '../../domain/connected_playback/StateRevision.dart';
import '../../domain/connected_playback/command_outcome.dart';
import '../../domain/connected_playback/envelope_kind.dart';
import '../../domain/connected_playback/remote_command_kind.dart';
import '../playback/PlaybackCubit.dart';
import '../playback/PlaybackUiState.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import 'ConnectedPlaybackScopeOf.dart';
import 'RemoteQueueProjection.dart';
import 'SupportedRemoteCommands.dart';

/// The target half of v0.5.3: keeps a [RemotePlaybackTarget] in step with
/// this device's *real* playback, and turns an accepted command into a
/// real `PlaybackCubit` call.
///
/// Two independent things feed it, and both can create or refresh the
/// target:
///
/// - [_onPlaybackChanged] fires on every `PlaybackCubit` state change,
///   including position ticks while something plays — the "high-rate
///   position updates" this version has to survive, and simultaneously
///   the mechanism a genuinely local change (someone pressing pause at
///   the player itself) reaches the network through.
/// - [_onEnvelope] fires on every arriving command, processed one at a
///   time through [_tail] — "serialize simultaneous controllers at the
///   target" restated as a promise that this device's own effects apply
///   in arrival order, not however their futures happen to resolve.
///
/// Both call [_target] lazily rather than reacting to a separate
/// reconnect signal. `ConnectedPlaybackTransport`'s session id is a
/// plain, ungated getter (`RemotePlaybackTarget` and
/// `RemotePlaybackController` are the pure conversation; the transport is
/// only "send this, and here is what arrived"), so the only reliable
/// place to notice it changed is right before it matters — about to
/// answer a command, or about to publish a snapshot. Recreating the
/// target there, with a fresh revision baseline, is exactly what a new
/// session means (`StateRevision`'s per-session promise).
///
/// A remote command's real effect and its acknowledgement travel two
/// separate paths on purpose. The acknowledgement carries the *domain*
/// prediction of the resulting revision immediately, as
/// `RemotePlaybackController.knownRevision`'s own doc describes
/// ("answers a queue edit immediately, publishes the new state a moment
/// later"); the real `PlaybackCubit` effect is awaited right after and
/// its eventual, independent state change republishes on its own through
/// [_onPlaybackChanged]. Two snapshot broadcasts for one command is the
/// accepted cost of never inventing a second, PlaybackCubit-shaped
/// prediction path that could disagree with the one that actually plays
/// the music.
@lazySingleton
class ConnectedPlaybackTargetLink {
  ConnectedPlaybackTargetLink(
    this._playback,
    this._transport,
    this._session,
    this._logger,
  );

  final PlaybackCubit _playback;
  final ConnectedPlaybackTransport _transport;
  final SessionCubit _session;
  final Logger _logger;

  @visibleForTesting
  ElapsedClock clock = StopwatchElapsedClock();

  @visibleForTesting
  String Function() newMessageId = () => const Uuid().v4();

  StreamSubscription<PlaybackUiState>? _playbackSub;
  StreamSubscription<SessionState>? _sessionSub;
  StreamSubscription<ConnectedPlaybackEnvelope>? _envelopeSub;

  ConnectedPlaybackScope? _scope;
  RemotePlaybackTarget? _target;

  /// Chains command handling so two envelopes arriving close together are
  /// answered — and applied to `PlaybackCubit` — in arrival order, never
  /// interleaved.
  Future<void> _tail = Future<void>.value();

  bool _started = false;

  /// The target's current snapshot, or `null` before this device has ever
  /// had a scope to publish for. Exposed for tests; nothing in this class
  /// itself needs to read it back.
  @visibleForTesting
  RemotePlaybackSnapshot? get snapshot => _target?.snapshot;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _playbackSub = _playback.stream.listen(_onPlaybackChanged);
    _sessionSub = _session.stream.listen(_onSession);
    _onSession(_session.state);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _playbackSub?.cancel();
    _playbackSub = null;
    await _sessionSub?.cancel();
    _sessionSub = null;
    await _envelopeSub?.cancel();
    _envelopeSub = null;
    _scope = null;
    _target = null;
  }

  void _onSession(SessionState state) {
    final scope = connectedPlaybackScopeOf(state);
    if (scope == _scope) return;
    _scope = scope;
    _target = null;
    unawaited(_envelopeSub?.cancel());
    _envelopeSub = scope == null
        ? null
        : _transport.envelopes(scope).listen(_onEnvelope);
  }

  void _onPlaybackChanged(PlaybackUiState state) {
    final target = _ensureTarget();
    if (target == null) return;
    final updated = target.publishLocalChange(
      (current) => RemoteQueueProjection.apply(current, state),
    );
    unawaited(_transport.publishSnapshot(updated));
  }

  void _onEnvelope(ConnectedPlaybackEnvelope envelope) {
    if (envelope.kind != EnvelopeKind.command) return;
    _tail = _tail.then((_) => _handleCommand(envelope)).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _logger.error(
        'Failed handling a connected-playback command',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  Future<void> _handleCommand(ConnectedPlaybackEnvelope envelope) async {
    final target = _ensureTarget();
    if (target == null) return;

    final decoding = decodeRemoteCommand(
      envelope.payload,
      scope: envelope.scope,
    );
    switch (decoding) {
      case DecodedRemoteCommand(:final command):
        final ack = target.process(target.receive(command));
        await _acknowledge(target, ack, to: envelope.senderSessionId);
        if (ack.outcome == CommandOutcome.applied) {
          await _execute(command);
          await _transport.publishSnapshot(target.snapshot);
        }
      case UnsupportedRemoteCommand(:final commandId):
        await _acknowledge(
          target,
          CommandAcknowledgement.refused(
            commandId: commandId,
            sessionId: target.snapshot.sessionId,
            outcome: CommandOutcome.unsupported,
            revision: target.snapshot.revision,
          ),
          to: envelope.senderSessionId,
        );
      case UnreadableRemoteCommand():
        // Nothing to answer — there is no command id to answer about.
        // The controller's own timeout covers it.
        return;
    }
  }

  Future<void> _acknowledge(
    RemotePlaybackTarget target,
    CommandAcknowledgement ack, {
    required String to,
  }) => _transport.send(
    ConnectedPlaybackEnvelope.outgoing(
      messageId: newMessageId(),
      scope: target.snapshot.scope,
      senderSessionId: target.snapshot.sessionId,
      kind: EnvelopeKind.acknowledgement,
      payload: ack.toPayload(),
    ),
    targetSessionId: to,
  );

  /// Applies [command]'s real effect through `PlaybackCubit`'s own public
  /// methods — never the engine directly, so there is exactly one control
  /// path into it whether the listener is standing at the player or
  /// driving it from another device.
  Future<void> _execute(RemoteCommand command) async {
    switch (command.kind) {
      case RemoteCommandKind.play:
        await _playback.play();
      case RemoteCommandKind.pause:
        await _playback.pause();
      case RemoteCommandKind.playPause:
        await _playback.togglePlayPause();
      case RemoteCommandKind.next:
        await _playback.next();
      case RemoteCommandKind.previous:
        await _playback.previous();
      case RemoteCommandKind.seek:
        await _playback.seek((command as SeekCommand).position);
      case RemoteCommandKind.setShuffle:
        final enabled = (command as SetShuffleCommand).enabled;
        if (_playback.state.queue.shuffleEnabled != enabled) {
          await _playback.toggleShuffle();
        }
      case RemoteCommandKind.setRepeat:
        await _playback.setRepeatMode((command as SetRepeatCommand).repeatMode);
      case RemoteCommandKind.jumpToQueueEntry:
        final index = (command as JumpToQueueEntryCommand).index;
        final entriesIndex = RemoteQueueProjection.resolveEntriesIndex(
          _playback.state.queue,
          index,
        );
        if (entriesIndex != null) await _playback.playAt(entriesIndex);
      case RemoteCommandKind.requestSnapshot:
        // No local effect — the caller republishes the current snapshot.
        return;
      case RemoteCommandKind.stop:
      case RemoteCommandKind.setVolume:
      case RemoteCommandKind.setQueue:
      case RemoteCommandKind.appendToQueue:
      case RemoteCommandKind.removeQueueEntry:
      case RemoteCommandKind.moveQueueEntry:
        // Never advertised as accepted (see SupportedRemoteCommands), so
        // RemotePlaybackTarget refuses these before _execute is reached.
        return;
    }
  }

  /// The current target, creating or refreshing it against
  /// `PlaybackCubit`'s real state when there is a scope to publish for
  /// but no target yet, or the transport's session has moved on.
  RemotePlaybackTarget? _ensureTarget() {
    final scope = _scope;
    final sessionId = _transport.localSessionId;
    if (scope == null || sessionId == null) return null;

    final current = _target;
    if (current != null &&
        current.snapshot.scope == scope &&
        current.snapshot.sessionId == sessionId) {
      return current;
    }

    final fresh = RemotePlaybackTarget(
      initialState: RemoteQueueProjection.apply(
        RemotePlaybackSnapshot.idle(
          scope: scope,
          sessionId: sessionId,
          revision: StateRevision.initial,
        ),
        _playback.state,
      ),
      clock: clock,
      capabilities: supportedRemoteCommands,
    );
    _target = fresh;
    return fresh;
  }
}
