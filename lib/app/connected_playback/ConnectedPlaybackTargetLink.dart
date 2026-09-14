import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/Logger.dart';
import '../../core/result/failure.dart';
import '../../core/result/partial.dart';
import '../../core/result/result.dart';
import '../../domain/connected_playback/CommandAcknowledgement.dart';
import '../../domain/connected_playback/ConnectedDevice.dart';
import '../../domain/connected_playback/ConnectedPlaybackEnvelope.dart';
import '../../domain/connected_playback/ConnectedPlaybackFailures.dart';
import '../../domain/connected_playback/ConnectedPlaybackLimits.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../domain/connected_playback/ElapsedClock.dart';
import '../../domain/connected_playback/PlaybackHandoff.dart';
import '../../domain/connected_playback/PlaybackHandoffCoordinator.dart';
import '../../domain/connected_playback/PlaybackTransfer.dart';
import '../../domain/connected_playback/RemoteCommand.dart';
import '../../domain/connected_playback/RemotePlaybackSnapshot.dart';
import '../../domain/connected_playback/RemotePlaybackTarget.dart';
import '../../domain/connected_playback/RemoteQueueEntry.dart';
import '../../domain/connected_playback/StateRevision.dart';
import '../../domain/connected_playback/command_outcome.dart';
import '../../domain/connected_playback/envelope_kind.dart';
import '../../domain/connected_playback/remote_command_kind.dart';
import '../../domain/connected_playback/transfer_refusal.dart';
import '../../domain/media/MusicLibraryRepository.dart';
import '../../domain/media/Track.dart';
import '../playback/PlaybackCubit.dart';
import '../playback/PlaybackUiState.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import 'ConnectedPlaybackScopeOf.dart';
import 'RemoteQueueProjection.dart';
import 'SyncPlayGroupCubit.dart';
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
class ConnectedPlaybackTargetLink implements PlaybackHandoffCoordinator {
  ConnectedPlaybackTargetLink(
    this._playback,
    this._transport,
    this._session,
    this._library,
    this._logger, [
    SyncPlayGroupCubit? syncPlay,
  ]) : _syncPlay = syncPlay;

  final PlaybackCubit _playback;
  final ConnectedPlaybackTransport _transport;
  final SessionCubit _session;
  final MusicLibraryRepository _library;
  final Logger _logger;
  final SyncPlayGroupCubit? _syncPlay;
  @visibleForTesting
  ElapsedClock clock = StopwatchElapsedClock();

  @visibleForTesting
  String Function() newMessageId = () => const Uuid().v4();

  /// How long this device, as a handoff source, waits for each step's
  /// answer before giving up (v0.5.4). A real `ConnectedPlaybackLimits
  /// .handoffStepTimeout` is 20 seconds; overridable so a test proving a
  /// timeout path does not have to wait for one.
  @visibleForTesting
  Duration handoffStepTimeout = ConnectedPlaybackLimits.handoffStepTimeout;

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

  /// The offer this device most recently said it was ready for, still
  /// waiting on a commit — the target half of one handoff in flight
  /// (v0.5.4). Only one at a time: a second offer arriving before this
  /// one commits or expires is refused [TransferRefusal.busy], the same
  /// rule a source enforces on itself in `PlaybackHandoff`.
  _PreparedTransfer? _prepared;

  /// The handoff this device is currently driving as the *source*, when
  /// one is in flight (v0.5.4). `null` the rest of the time — including
  /// while this device is a target, which never touches this field.
  _OutgoingTransfer? _outgoing;

  /// The target's current snapshot, or `null` before this device has ever
  /// had a scope to publish for. Exposed for tests; nothing in this class
  /// itself needs to read it back.
  @visibleForTesting
  RemotePlaybackSnapshot? get snapshot => _target?.snapshot;

  /// This device's own snapshot, scoped and revisioned exactly as it
  /// would publish it — what the device picker (v0.5.5) reads to call
  /// [transferTo] without reaching into this class's session bookkeeping.
  /// `null` before there is a signed-in scope to publish for.
  RemotePlaybackSnapshot? get localSnapshot => _ensureTarget()?.snapshot;

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
    _prepared = null;
    _outgoing?.cancel(TransferRefusal.cancelled);
    _outgoing = null;
  }

  void _onSession(SessionState state) {
    final scope = connectedPlaybackScopeOf(state);
    if (scope == _scope) return;
    _scope = scope;
    _target = null;
    // A prepared-but-uncommitted offer, or a transfer this device was
    // driving, belongs to the profile that was active when it started;
    // an account switch mid-handoff must not let either survive to be
    // committed against, or answered on behalf of, the new one.
    _prepared = null;
    _outgoing?.cancel(TransferRefusal.cancelled);
    _outgoing = null;
    unawaited(_envelopeSub?.cancel());
    _envelopeSub = scope == null
        ? null
        : _transport.envelopes(scope).listen(_onEnvelope);
  }

  void _onPlaybackChanged(PlaybackUiState state) {
    final target = _ensureTarget();
    if (target == null) return;
    final updated = target.publishLocalChange(
      (current) => RemoteQueueProjection.apply(current, state).copyWith(
        syncGroupId: _syncPlay?.state.groupId,
        clearSyncGroupId: _syncPlay?.state.groupId == null,
      ),
    );
    unawaited(_transport.publishSnapshot(updated));
  }

  void _onEnvelope(ConnectedPlaybackEnvelope envelope) {
    switch (envelope.kind) {
      case EnvelopeKind.command:
        _chain(() => _handleCommand(envelope));
      case EnvelopeKind.transferOffer:
        // Answering an offer resolves entries against the library, which
        // is slow — chained like a command so it cannot interleave with
        // one, but not awaited here so a slow prepare cannot stall
        // command handling behind it.
        _chain(() => _handleTransferOffer(envelope));
      case EnvelopeKind.transferCommit:
        _chain(() => _handleTransferCommit(envelope));
      case EnvelopeKind.transferReadiness:
        _onTransferReadiness(envelope);
      case EnvelopeKind.transferResult:
        _onTransferResult(envelope);
      case EnvelopeKind.acknowledgement:
      case EnvelopeKind.snapshot:
      case EnvelopeKind.presence:
        return;
    }
  }

  /// Chains [operation] onto [_tail] so envelopes this device answers are
  /// handled — and their effects applied to `PlaybackCubit` — strictly in
  /// arrival order, whether they are commands, transfer offers or
  /// transfer commits.
  void _chain(Future<void> Function() operation) {
    _tail = _tail.then((_) => operation()).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _logger.error(
        'Failed handling a connected-playback message',
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
      case DecodedRemoteCommand(:final JoinSyncGroupCommand command):
        final syncPlay = _syncPlay;
        final acknowledgement = syncPlay == null
            ? CommandAcknowledgement.refused(
                commandId: command.id,
                sessionId: target.snapshot.sessionId,
                outcome: CommandOutcome.unsupported,
                revision: target.snapshot.revision,
              )
            : CommandAcknowledgement.applied(
                commandId: command.id,
                sessionId: target.snapshot.sessionId,
                revision: target.snapshot.revision,
              );
        if (syncPlay != null) await syncPlay.joinGroup(command.groupId);
        await _acknowledge(
          target,
          acknowledgement,
          to: envelope.senderSessionId,
        );
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
      case RemoteCommandKind.setQueue:
        await _executeSetQueue(command as SetQueueCommand);
      case RemoteCommandKind.removeQueueEntry:
        final entriesIndex = RemoteQueueProjection.resolveEntriesIndex(
          _playback.state.queue,
          (command as RemoveQueueEntryCommand).index,
        );
        if (entriesIndex != null) await _playback.removeAt(entriesIndex);
      case RemoteCommandKind.moveQueueEntry:
        final move = command as MoveQueueEntryCommand;
        await _playback.reorderPlayOrder(move.fromIndex, move.toIndex);
      case RemoteCommandKind.setVolume:
        // Per-device state, deliberately not part of the queue this
        // command shares a channel with (v0.6.0) — see
        // PlaybackCubit.setSystemVolume and the invariant on
        // RemotePlaybackSnapshot.volume's own doc comment.
        await _playback.setSystemVolume((command as SetVolumeCommand).volume);
      case RemoteCommandKind.joinSyncGroup:
        return;
      case RemoteCommandKind.stop:
      case RemoteCommandKind.appendToQueue:
        return;
    }
  }

  /// Applies an accepted [SetQueueCommand] — the one queue-editing command
  /// this build carries out (v0.5.4).
  ///
  /// `RemotePlaybackTarget.process` has already arbitrated and
  /// acknowledged this as *structurally* valid — bounds, revision — before
  /// `_execute` is ever reached; whether every entry can actually be
  /// resolved on this device is a separate question with no readiness
  /// step to ask first, unlike a handoff's offer/readiness. Rather than
  /// commit a queue with entries silently missing or reordered around a
  /// gap, an unresolvable entry leaves the current queue exactly as it
  /// was — the sender's next snapshot shows that nothing changed, which
  /// is the honest answer to a command that could not be carried out in
  /// full.
  Future<void> _executeSetQueue(SetQueueCommand command) async {
    final tracks = await _resolveAll(command.entries);
    if (tracks == null) {
      _logger.info(
        'Accepted a remote queue of ${command.entries.length} songs but '
        'could not resolve all of them; leaving the queue unchanged.',
      );
      return;
    }
    await _playback.adoptTransferredQueue(
      tracks,
      startIndex: command.startIndex,
      shuffleEnabled: command.shuffleEnabled,
      repeatMode: command.repeatMode,
      startPosition: command.startPosition,
      startPlaying: command.startPlaying,
    );
  }

  /// Resolves every one of [entries] against [_library], fresh — never the
  /// sender's own availability or source (v0.5.4). `null` the moment any
  /// one entry cannot be resolved: never a queue with some entries
  /// silently missing.
  Future<List<Track>?> _resolveAll(List<RemoteQueueEntry> entries) async {
    final tracks = <Track>[];
    for (final entry in entries) {
      final result = await _library.track(entry.id);
      switch (result) {
        case Ok<Track>(:final value):
          tracks.add(value);
        case Err<Track>():
          return null;
      }
    }
    return tracks;
  }

  // ---- Handoff: target role (v0.5.4) ----

  Future<void> _handleTransferOffer(ConnectedPlaybackEnvelope envelope) async {
    final target = _ensureTarget();
    if (target == null) return;
    final offer = TransferOfferCodec.tryDecode(
      envelope.payload,
      scope: envelope.scope,
      sourceSessionId: envelope.senderSessionId,
    );
    if (offer == null || offer.targetSessionId != target.snapshot.sessionId) {
      return;
    }

    final readiness = await prepare(offer);
    await _sendEnvelope(
      scope: offer.scope,
      senderSessionId: target.snapshot.sessionId,
      targetSessionId: envelope.senderSessionId,
      kind: EnvelopeKind.transferReadiness,
      payload: readiness.toPayload(),
    );
  }

  Future<void> _handleTransferCommit(ConnectedPlaybackEnvelope envelope) async {
    final target = _ensureTarget();
    if (target == null) return;
    final commit = TransferCommitCodec.tryDecode(
      envelope.payload,
      sourceSessionId: envelope.senderSessionId,
      targetSessionId: target.snapshot.sessionId,
    );
    if (commit == null) return;

    final result = await accept(commit);
    await _sendEnvelope(
      scope: envelope.scope,
      senderSessionId: target.snapshot.sessionId,
      targetSessionId: envelope.senderSessionId,
      kind: EnvelopeKind.transferResult,
      payload: result.toPayload(),
    );
  }

  /// Answers a [TransferOffer] by checking whether this device can play
  /// [offer]'s queue *in full* — the arc's "never partially ready" rule.
  ///
  /// Only one offer is held at a time: a second one arriving before this
  /// one commits or expires is refused [TransferRefusal.busy], the
  /// receiving half of the same rule a source enforces on itself.
  @override
  Future<TransferReadiness> prepare(TransferOffer offer) async {
    final existing = _prepared;
    if (existing != null) {
      if (existing.offer.transferId == offer.transferId) {
        // A retried offer: answer the same way rather than resolving
        // again, so a lost readiness message costs a round trip, not a
        // second server read.
        return TransferReadiness.ready(
          transferId: offer.transferId,
          targetSessionId: offer.targetSessionId,
        );
      }
      return TransferReadiness.refused(
        transferId: offer.transferId,
        targetSessionId: offer.targetSessionId,
        refusal: TransferRefusal.busy,
      );
    }
    if (offer.entries.length > supportedRemoteCommands.maxQueueEntries) {
      return TransferReadiness.refused(
        transferId: offer.transferId,
        targetSessionId: offer.targetSessionId,
        refusal: TransferRefusal.queueTooLarge,
      );
    }

    final resolved = await _resolveEntries(offer.entries);
    if (resolved.unresolvable.isNotEmpty) {
      return TransferReadiness.refused(
        transferId: offer.transferId,
        targetSessionId: offer.targetSessionId,
        refusal: TransferRefusal.localOnlyItems,
        unresolvable: resolved.unresolvable,
      );
    }

    _prepared = _PreparedTransfer(offer: offer, tracks: resolved.tracks);
    return TransferReadiness.ready(
      transferId: offer.transferId,
      targetSessionId: offer.targetSessionId,
    );
  }

  /// Takes ownership after the source has yielded it.
  ///
  /// Uses exactly the tracks [prepare] already resolved for this
  /// [TransferCommit.transferId] rather than resolving again: the source
  /// stopped on the strength of that readiness, and re-resolving here
  /// could disagree with it for no reason the listener caused.
  @override
  Future<TransferResult> accept(TransferCommit commit) async {
    final prepared = _prepared;
    if (prepared == null || prepared.offer.transferId != commit.transferId) {
      return TransferResult.failed(
        transferId: commit.transferId,
        targetSessionId: commit.targetSessionId,
        refusal: TransferRefusal.playbackFailed,
        message: 'This device was not expecting that transfer.',
      );
    }
    _prepared = null;
    final offer = prepared.offer;

    try {
      await _playback.adoptTransferredQueue(
        prepared.tracks,
        startIndex: offer.startIndex,
        shuffleEnabled: offer.shuffleEnabled,
        repeatMode: offer.repeatMode,
        startPosition: commit.position,
        startPlaying: offer.startPlaying,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to accept a playback handoff',
        error: error,
        stackTrace: stackTrace,
      );
      return TransferResult.failed(
        transferId: commit.transferId,
        targetSessionId: commit.targetSessionId,
        refusal: TransferRefusal.playbackFailed,
      );
    }

    final target = _ensureTarget();
    if (target == null) {
      return TransferResult.failed(
        transferId: commit.transferId,
        targetSessionId: commit.targetSessionId,
        refusal: TransferRefusal.playbackFailed,
      );
    }
    // The same local-change path an ordinary press of play at this device
    // would take — see the class doc. It bumps the revision immediately,
    // which is what [TransferResult.revision] reports; `_onPlaybackChanged`
    // publishes the same snapshot again a moment later, the accepted cost
    // v0.5.3 already took for one command producing two broadcasts.
    final updated = target.publishLocalChange(
      (current) => RemoteQueueProjection.apply(current, _playback.state),
    );
    unawaited(_transport.publishSnapshot(updated));
    return TransferResult.playing(
      transferId: commit.transferId,
      targetSessionId: commit.targetSessionId,
      revision: updated.revision,
    );
  }

  /// Resolves every one of [entries] against [_library], fresh — never
  /// the sender's own availability or source (v0.5.4): this device's own
  /// download can replace a stream, and its own stream-quality settings
  /// apply. Keeps both what resolved and exactly which entries did not,
  /// with their position in the offer, so a refusal can name them.
  Future<_ResolvedEntries> _resolveEntries(
    List<RemoteQueueEntry> entries,
  ) async {
    final tracks = <Track>[];
    final unresolvable = <UnavailableItem>[];
    for (var position = 0; position < entries.length; position++) {
      final entry = entries[position];
      final result = await _library.track(entry.id);
      switch (result) {
        case Ok<Track>(:final value):
          tracks.add(value);
        case Err<Track>(:final failure):
          unresolvable.add(
            UnavailableItem(
              id: entry.id.key,
              reason: failure.message,
              position: position,
            ),
          );
      }
    }
    return _ResolvedEntries(tracks: tracks, unresolvable: unresolvable);
  }

  // ---- Handoff: source role (v0.5.4) ----

  /// Hands the current local queue to [target], leaving this device a
  /// controller — the source half of a handoff, driving the pure
  /// [PlaybackHandoff] state machine against the real transport and
  /// `PlaybackCubit`.
  ///
  /// Local playback is untouched until the target says it is ready; an
  /// [Err] before that point means the music is still playing here. Only
  /// one outgoing transfer runs at a time — a second call while one is in
  /// flight is refused [TransferRefusal.busy] without sending anything.
  @override
  Future<Result<TransferResult>> transferTo({
    required ConnectedDevice target,
    required RemotePlaybackSnapshot snapshot,
  }) async {
    final inFlight = _outgoing;
    if (inFlight != null && inFlight.handoff.stage.isInFlight) {
      return Result.err(_failureFor(TransferRefusal.busy));
    }
    final sourceSessionId = _transport.localSessionId;
    if (sourceSessionId == null) {
      return Result.err(ConnectedPlaybackFailures.offline());
    }
    if (!target.canReceiveTransfer) {
      return Result.err(ConnectedPlaybackFailures.notReachable());
    }

    final playbackState = _playback.state;
    final queue = playbackState.queue;
    final order = queue.playOrder;
    final currentIndex = queue.currentIndex;
    final currentPlayPosition = queue.currentPlayPosition;
    if (order.isEmpty || currentIndex == null || currentPlayPosition < 0) {
      return const Result.err(
        UnavailableFailure('Nothing is playing to send to another device.'),
      );
    }
    final entries = [
      for (final entriesIndex in order)
        RemoteQueueEntry.fromQueueEntry(queue.entries[entriesIndex]),
    ];
    if (entries.length > target.capabilities.maxQueueEntries) {
      return Result.err(_failureFor(TransferRefusal.queueTooLarge));
    }

    final offer = TransferOffer(
      transferId: newMessageId(),
      scope: snapshot.scope,
      sourceSessionId: sourceSessionId,
      targetSessionId: target.sessionId,
      entries: entries,
      startIndex: currentPlayPosition,
      startPosition: playbackState.position,
      shuffleEnabled: queue.shuffleEnabled,
      repeatMode: queue.repeatMode,
      originName: queue.origin?.name,
      startPlaying: playbackState.isPlaying,
    );
    final resumeState = HandoffResumeState(
      currentIndex: currentIndex,
      position: playbackState.position,
      wasPlaying: playbackState.isPlaying,
    );

    final handoff = PlaybackHandoff(
      clock: clock,
      stepTimeout: handoffStepTimeout,
    );
    final outgoing = _OutgoingTransfer(
      handoff: handoff,
      targetSessionId: target.sessionId,
    );
    // Kept beyond this call's own lifetime rather than cleared in a
    // `finally`: a [TransferResult] that arrives after this method has
    // already given up and resumed still has to reach
    // [PlaybackHandoff.onLateResult], the branch that stops this device
    // again if the target started after all. It is replaced, not
    // re-entered — [inFlight] above refuses a second call while it is
    // still live.
    _outgoing = outgoing;
    return _driveHandoff(handoff, outgoing, offer, resumeState, target);
  }

  Future<Result<TransferResult>> _driveHandoff(
    PlaybackHandoff handoff,
    _OutgoingTransfer outgoing,
    TransferOffer offer,
    HandoffResumeState resumeState,
    ConnectedDevice target,
  ) async {
    final begin = handoff.begin(offer, resumeState);
    if (begin.action != HandoffAction.sendOffer) {
      return Result.err(_failureFor(begin.refusal ?? TransferRefusal.busy));
    }

    final offered = await _sendEnvelope(
      scope: offer.scope,
      senderSessionId: offer.sourceSessionId,
      targetSessionId: target.sessionId,
      kind: EnvelopeKind.transferOffer,
      payload: offer.toPayload(),
    );
    if (offered.isErr) {
      await _applyDecision(handoff.onTimeout());
      return Result.err(ConnectedPlaybackFailures.notReachable());
    }

    final readinessCompleter = Completer<TransferReadiness>();
    outgoing.pendingReadiness = readinessCompleter;
    final readiness = await _await(readinessCompleter, handoffStepTimeout);
    outgoing.pendingReadiness = null;
    if (readiness == null) {
      await _applyDecision(handoff.onTimeout());
      return Result.err(ConnectedPlaybackFailures.timedOut());
    }
    final readinessDecision = handoff.onReadiness(readiness);
    if (readinessDecision.action != HandoffAction.commit) {
      await _applyDecision(readinessDecision);
      return Result.err(
        _failureFor(readiness.refusal ?? TransferRefusal.playbackFailed),
      );
    }

    // The only transition that costs the listener their audio here —
    // see PlaybackHandoff.commit.
    await _applyDecision(handoff.commit());

    final commit = TransferCommit(
      transferId: offer.transferId,
      sourceSessionId: offer.sourceSessionId,
      targetSessionId: target.sessionId,
      position: _playback.state.position,
    );
    final committed = await _sendEnvelope(
      scope: offer.scope,
      senderSessionId: offer.sourceSessionId,
      targetSessionId: target.sessionId,
      kind: EnvelopeKind.transferCommit,
      payload: commit.toPayload(),
    );
    if (committed.isErr) {
      await _applyDecision(handoff.onTimeout());
      return Result.err(ConnectedPlaybackFailures.notReachable());
    }

    final resultCompleter = Completer<TransferResult>();
    outgoing.pendingResult = resultCompleter;
    final result = await _await(resultCompleter, handoffStepTimeout);
    outgoing.pendingResult = null;
    if (result == null) {
      await _applyDecision(handoff.onTimeout());
      return Result.err(ConnectedPlaybackFailures.timedOut());
    }
    final resultDecision = handoff.onResult(result);
    await _applyDecision(resultDecision);
    if (resultDecision.action == HandoffAction.becomeController) {
      return Result.ok(result);
    }
    return Result.err(
      _failureFor(result.refusal ?? TransferRefusal.playbackFailed),
    );
  }

  /// Carries out one [HandoffDecision] against the real `PlaybackCubit` —
  /// the only two actions a source-side decision ever asks this class to
  /// perform itself; `becomeController`, `sendOffer`, `commit` and `none`
  /// are handled by their own call sites or need nothing further.
  Future<void> _applyDecision(HandoffDecision decision) async {
    switch (decision.action) {
      case HandoffAction.stopLocalPlayback:
        await _playback.pause();
      case HandoffAction.resumeLocalPlayback:
        // The queue was never torn down, only paused in `commit()` above
        // — resuming is picking playback back up where it was, not
        // reconstructing a queue that is still sitting there.
        if (decision.resumeState?.wasPlaying ?? false) {
          await _playback.play();
        }
      case HandoffAction.becomeController:
      case HandoffAction.sendOffer:
      case HandoffAction.commit:
      case HandoffAction.none:
        return;
    }
  }

  void _onTransferReadiness(ConnectedPlaybackEnvelope envelope) {
    final outgoing = _outgoing;
    if (outgoing == null ||
        envelope.senderSessionId != outgoing.targetSessionId) {
      return;
    }
    final readiness = TransferReadinessCodec.tryDecode(
      envelope.payload,
      targetSessionId: envelope.senderSessionId,
    );
    if (readiness == null ||
        readiness.transferId != outgoing.handoff.offer?.transferId) {
      return;
    }
    final pending = outgoing.pendingReadiness;
    if (pending != null && !pending.isCompleted) pending.complete(readiness);
  }

  void _onTransferResult(ConnectedPlaybackEnvelope envelope) {
    final outgoing = _outgoing;
    if (outgoing == null ||
        envelope.senderSessionId != outgoing.targetSessionId) {
      return;
    }
    final result = TransferResultCodec.tryDecode(
      envelope.payload,
      targetSessionId: envelope.senderSessionId,
    );
    if (result == null ||
        result.transferId != outgoing.handoff.offer?.transferId) {
      return;
    }
    final pending = outgoing.pendingResult;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
      return;
    }
    // The wait already gave up and this device resumed — the other half
    // of PlaybackHandoff.onTimeout's committing-stage branch: the target
    // did start after all, so this device, having resumed, is the one
    // that must stop.
    final decision = outgoing.handoff.onLateResult(result);
    unawaited(_applyDecision(decision));
  }

  Future<Result<void>> _sendEnvelope({
    required ConnectedPlaybackScope scope,
    required String senderSessionId,
    required String targetSessionId,
    required EnvelopeKind kind,
    required Map<String, Object?> payload,
  }) => _transport.send(
    ConnectedPlaybackEnvelope.outgoing(
      messageId: newMessageId(),
      scope: scope,
      senderSessionId: senderSessionId,
      kind: kind,
      payload: payload,
    ),
    targetSessionId: targetSessionId,
  );

  Future<T?> _await<T>(Completer<T> completer, Duration timeout) async {
    try {
      return await completer.future.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Failure _failureFor(TransferRefusal refusal) => switch (refusal) {
    TransferRefusal.localOnlyItems ||
    TransferRefusal.unsupportedMedia => const UnavailableFailure(
      'That device cannot play some of what is queued here.',
    ),
    TransferRefusal.serverUnreachable => ConnectedPlaybackFailures.offline(),
    TransferRefusal.queueTooLarge => ConnectedPlaybackFailures.tooLarge(
      'This queue is too long to send to that device.',
    ),
    TransferRefusal.notPermitted => ConnectedPlaybackFailures.notPermitted(),
    TransferRefusal.incompatible =>
      ConnectedPlaybackFailures.incompatibleProtocol(),
    TransferRefusal.busy => const UnavailableFailure(
      'That device is already receiving a transfer.',
    ),
    TransferRefusal.timedOut => ConnectedPlaybackFailures.timedOut(),
    TransferRefusal.playbackFailed => const UnavailableFailure(
      'That device could not start playing.',
    ),
    TransferRefusal.cancelled => const UnavailableFailure(
      'The transfer was cancelled.',
    ),
  };

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

/// An offer this device has said it is ready for, and what [prepare]
/// resolved to answer it — held until [accept] commits it or a newer
/// offer replaces it (v0.5.4).
class _PreparedTransfer {
  const _PreparedTransfer({required this.offer, required this.tracks});

  final TransferOffer offer;

  /// Resolved in the same order as [offer]'s entries — [accept] plays
  /// these directly rather than re-resolving by id.
  final List<Track> tracks;
}

/// What [_resolveEntries] found — what this device can play, and exactly
/// which entries it could not, with their position in the offer (v0.5.4).
class _ResolvedEntries {
  const _ResolvedEntries({required this.tracks, required this.unresolvable});

  final List<Track> tracks;
  final List<UnavailableItem> unresolvable;
}

/// One handoff this device is driving as the source — the [PlaybackHandoff]
/// state machine plus the wiring [ConnectedPlaybackTargetLink] needs to
/// feed it real network events (v0.5.4).
///
/// A plain holder, not a service of its own: every decision is
/// [PlaybackHandoff]'s, this only carries the [Completer]s that let an
/// arriving envelope resolve whichever step is currently being awaited,
/// and stays alive after that step finishes so a late [TransferResult] —
/// see [PlaybackHandoff.onLateResult] — still has somewhere to arrive.
class _OutgoingTransfer {
  _OutgoingTransfer({required this.handoff, required this.targetSessionId});

  final PlaybackHandoff handoff;

  /// The session this transfer was addressed to — checked against every
  /// arriving readiness and result so a reply from anyone else, including
  /// that same device's *previous* session, is never mistaken for this
  /// conversation's answer.
  final String targetSessionId;

  Completer<TransferReadiness>? pendingReadiness;
  Completer<TransferResult>? pendingResult;

  /// Releases whatever this device is currently waiting on — the app is
  /// stopping, or the signed-in profile just changed — so the wait in
  /// [ConnectedPlaybackTargetLink._driveHandoff] resolves immediately
  /// instead of running out its full timeout for no reason.
  void cancel(TransferRefusal refusal) {
    final readiness = pendingReadiness;
    if (readiness != null && !readiness.isCompleted) {
      readiness.completeError(StateError(refusal.name));
    }
    final result = pendingResult;
    if (result != null && !result.isCompleted) {
      result.completeError(StateError(refusal.name));
    }
  }
}
