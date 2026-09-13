import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/connected_playback/ConnectedDevice.dart';
import '../../domain/connected_playback/ConnectedPlaybackFailures.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../domain/connected_playback/DevicePresenceSource.dart';
import '../../domain/connected_playback/RemotePlaybackSnapshot.dart';
import '../../domain/connected_playback/device_reachability.dart';
import '../../domain/connected_playback/remote_command_kind.dart';
import '../../domain/playback/PlaybackQueue.dart';
import '../../domain/playback/QueueEntry.dart';
import '../../domain/playback/playback_status.dart';
import '../../domain/playback/repeat_mode.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import 'ConnectedPlaybackControllerSession.dart';
import 'ConnectedPlaybackScopeOf.dart';

/// How this device's control of [PlaybackControlState.device] is going,
/// beyond the target's own playback status.
enum PlaybackControlConnection {
  /// The projection is current and structural commands may be composed.
  synced,

  /// A command answer implied the projection is wrong
  /// ([RemotePlaybackController.needsResync]); a fresh snapshot has been
  /// asked for and is expected shortly.
  resynchronizing,

  /// Presence still lists the device, but it cannot receive commands right
  /// now (a dropped socket, `DeviceReachability.presenceOnly`/`stale`) —
  /// worth naming rather than presenting the last known state as live.
  reconnecting,

  /// Presence no longer lists this device at all, or it is no longer
  /// controllable for a permanent reason (incompatible/not permitted).
  /// The screen this state backs offers a route back to device selection;
  /// it does not guess that the device will return.
  targetEnded,
}

/// What the mini-player, Now Playing and the queue show while this device
/// is controlling another one (v0.5.6) — the "one presentation contract"
/// `Roadmap to v0.6.md` asks for, on the remote side of it.
///
/// [device] is `null` exactly when this device is not controlling anything,
/// which is the ordinary state every screen already handles by reading
/// `PlaybackCubit` directly; nothing here ever touches that cubit or its
/// persisted queue (ADR-0037's ownership invariant, restated for the UI:
/// a controller's own dormant queue must never be overwritten by a
/// projection it is only looking at).
class PlaybackControlState extends Equatable {
  const PlaybackControlState({
    this.device,
    this.queue = PlaybackQueue.empty,
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.connection = PlaybackControlConnection.synced,
    this.availableCommands = const {},
    this.pendingCommand,
    this.commandError,
    this.originName,
  });

  /// The device being controlled, or `null` when this device is not
  /// controlling anything.
  final ConnectedDevice? device;

  /// A read-only, display-shaped projection of the target's queue, built
  /// the same way `PlaybackCubit.adoptTransferredQueue` builds one from a
  /// handoff's resolved tracks: [RemotePlaybackSnapshot.queue] is already
  /// in play order, so its entries are pinned as play order here too
  /// (`PlaybackQueue.withRestoredShuffleOrder`) rather than left for
  /// `PlaybackQueue` to reshuffle. Never persisted, never merged into the
  /// controller's own `QueueRepository`.
  final PlaybackQueue queue;

  final PlaybackStatus status;

  /// Extrapolated from the last snapshot's position using this device's
  /// own clock while [status] is playing — the same technique
  /// `RemotePlaybackSnapshot.position`'s own doc describes for a
  /// controller, rather than polling for a fresh snapshot every second.
  final Duration position;

  final PlaybackControlConnection connection;

  /// The commands negotiated against the target's advertised capabilities
  /// (`RemotePlaybackController.availableCommands`) — a control whose kind
  /// is missing here is disabled or omitted, never shown failing.
  final Set<RemoteCommandKind> availableCommands;

  /// The command currently awaiting an acknowledgement, if any — what a
  /// control shows a brief pending/spinner state for.
  final RemoteCommandKind? pendingCommand;

  /// The most recent command failure's message, transient like
  /// `PlaybackUiState.lastFailure`.
  final String? commandError;

  final String? originName;

  bool get isControlling => device != null;

  bool get hasQueue => !queue.isEmpty;

  bool get isPlaying =>
      status == PlaybackStatus.playing || status == PlaybackStatus.buffering;

  QueueEntry? get currentEntry => queue.currentEntry;

  Duration? get duration => currentEntry?.duration;

  bool commandAvailable(RemoteCommandKind kind) =>
      availableCommands.contains(kind);

  PlaybackControlState copyWith({
    PlaybackQueue? queue,
    PlaybackStatus? status,
    Duration? position,
    PlaybackControlConnection? connection,
    Set<RemoteCommandKind>? availableCommands,
    RemoteCommandKind? pendingCommand,
    bool clearPendingCommand = false,
    String? commandError,
    bool clearCommandError = false,
    String? originName,
    bool clearOrigin = false,
  }) => PlaybackControlState(
    device: device,
    queue: queue ?? this.queue,
    status: status ?? this.status,
    position: position ?? this.position,
    connection: connection ?? this.connection,
    availableCommands: availableCommands ?? this.availableCommands,
    pendingCommand: clearPendingCommand
        ? null
        : (pendingCommand ?? this.pendingCommand),
    commandError: clearCommandError
        ? null
        : (commandError ?? this.commandError),
    originName: clearOrigin ? null : (originName ?? this.originName),
  );

  @override
  List<Object?> get props => [
    device,
    queue,
    status,
    position,
    connection,
    availableCommands,
    pendingCommand,
    commandError,
    originName,
  ];
}

/// The commands this build ever asks a target to negotiate down from — the
/// controller-side mirror of `SupportedRemoteCommands`. Deliberately a
/// subset of `RemoteCommandKind.values`: `stop`, `setVolume`,
/// `appendToQueue`, `removeQueueEntry` and `moveQueueEntry` are not part of
/// any version's required deliverables (`SupportedRemoteCommands`'s own
/// doc), so they are never desired in the first place rather than desired
/// and then always negotiated away.
const Set<RemoteCommandKind> _desiredRemoteCommands = {
  RemoteCommandKind.play,
  RemoteCommandKind.pause,
  RemoteCommandKind.playPause,
  RemoteCommandKind.previous,
  RemoteCommandKind.next,
  RemoteCommandKind.seek,
  RemoteCommandKind.setShuffle,
  RemoteCommandKind.setRepeat,
  RemoteCommandKind.jumpToQueueEntry,
};

/// Chooses which device this app is controlling, and binds the mini-player,
/// Now Playing and the queue to it (v0.5.6).
///
/// A `@lazySingleton` like `ConnectedPlaybackTargetLink`, not screen-scoped
/// like `DevicePickerCubit`: whichever device the listener picked has to
/// stay controlled while they navigate between the mini-player, Now
/// Playing and the queue screen, not just while one sheet is open.
///
/// [ConnectedPlaybackControllerSession] (v0.5.3) is constructed here and
/// only here — ADR-0039 deliberately left the device picker without one,
/// naming this class's job as "first constructs a
/// `ConnectedPlaybackControllerSession` for a chosen device and binds it
/// into the mini-player/Now Playing/queue."
@lazySingleton
class PlaybackControlCubit extends Cubit<PlaybackControlState> {
  PlaybackControlCubit(this._transport, this._presence, this._session)
    : super(const PlaybackControlState()) {
    _sessionSub = _session.stream.listen(_onSession);
    _onSession(_session.state);
  }

  final ConnectedPlaybackTransport _transport;
  final DevicePresenceSource _presence;
  final SessionCubit _session;

  StreamSubscription<SessionState>? _sessionSub;
  StreamSubscription<RemotePlaybackSnapshot>? _snapshotSub;
  StreamSubscription<List<ConnectedDevice>>? _devicesSub;
  Timer? _ticker;

  ConnectedPlaybackScope? _scope;
  ConnectedPlaybackControllerSession? _controlSession;

  /// Bumped every time controlling starts or stops, so a snapshot,
  /// device-list update or command answer that was already in flight when
  /// that happened is dropped instead of updating a session this cubit no
  /// longer owns.
  int _generation = 0;

  /// The position/clock-time pair [position] was last computed from —
  /// either a fresh snapshot or an optimistic [seek] — so [_tick] always
  /// extrapolates from a real reading instead of compounding rounding
  /// error onto its own last tick.
  Duration _basePosition = Duration.zero;
  DateTime _baseAt = DateTime.now();

  void _onSession(SessionState sessionState) {
    final scope = connectedPlaybackScopeOf(sessionState);
    if (scope == _scope) return;
    _scope = scope;
    // A signed-out or switched profile ends whatever this device was
    // controlling — the same isolation rule presence and the target link
    // already apply to themselves.
    unawaited(stop());
  }

  /// Starts controlling [device] — constructing a fresh
  /// `ConnectedPlaybackControllerSession` for it, requesting its current
  /// snapshot immediately (a controller's projection starts empty), and
  /// following presence for [device]'s reconnects or disappearance.
  ///
  /// A no-op for the device already being controlled; controlling a
  /// different one tears the previous session down first.
  Future<void> control(ConnectedDevice device) async {
    if (state.device?.deviceId == device.deviceId &&
        state.device?.sessionId == device.sessionId) {
      return;
    }
    await _teardown();
    final localSessionId = _transport.localSessionId;
    if (localSessionId == null) {
      emit(
        const PlaybackControlState(
          commandError: 'Connecting to other devices needs your server.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    final controlSession = ConnectedPlaybackControllerSession(
      transport: _transport,
      target: device,
      localSessionId: localSessionId,
    );
    _controlSession = controlSession;
    _basePosition = Duration.zero;
    _baseAt = DateTime.now();
    emit(
      PlaybackControlState(
        device: device,
        availableCommands: controlSession.controller.availableCommands(
          _desiredRemoteCommands,
        ),
      ),
    );
    _snapshotSub = controlSession.snapshots.listen(
      (snapshot) => _onSnapshot(generation, snapshot),
    );
    _devicesSub = _presence
        .devices(device.scope)
        .listen((devices) => _onDevices(generation, device.deviceId, devices));
    unawaited(_requestSnapshot());
  }

  /// Stops controlling, without touching local playback — the "deliberate
  /// action to stop controlling without stopping the player" the roadmap
  /// asks for. Every screen bound to this cubit falls back to showing
  /// local `PlaybackCubit` state once this completes.
  Future<void> stop() async {
    await _teardown();
    if (state.isControlling) emit(const PlaybackControlState());
  }

  Future<void> _teardown() async {
    _generation++;
    _ticker?.cancel();
    _ticker = null;
    await _snapshotSub?.cancel();
    _snapshotSub = null;
    await _devicesSub?.cancel();
    _devicesSub = null;
    final session = _controlSession;
    _controlSession = null;
    await session?.dispose();
  }

  Future<void> _requestSnapshot() async {
    final session = _controlSession;
    if (session == null) return;
    await session.requestSnapshot();
  }

  void _onSnapshot(int generation, RemotePlaybackSnapshot snapshot) {
    if (generation != _generation) return;
    final session = _controlSession;
    if (session == null) return;
    _basePosition = snapshot.position;
    _baseAt = DateTime.now();
    emit(
      state.copyWith(
        queue: _projectQueue(snapshot),
        status: snapshot.status,
        position: snapshot.position,
        connection: session.controller.needsResync
            ? PlaybackControlConnection.resynchronizing
            : PlaybackControlConnection.synced,
        availableCommands: session.controller.availableCommands(
          _desiredRemoteCommands,
        ),
        originName: snapshot.originName,
        clearOrigin: snapshot.originName == null,
      ),
    );
    _updateTicker();
  }

  void _onDevices(
    int generation,
    String deviceId,
    List<ConnectedDevice> devices,
  ) {
    if (generation != _generation) return;
    final session = _controlSession;
    if (session == null) return;

    ConnectedDevice? match;
    for (final candidate in devices) {
      if (candidate.deviceId == deviceId) match = candidate;
    }
    if (match == null) {
      emit(state.copyWith(connection: PlaybackControlConnection.targetEnded));
      return;
    }
    if (match.sessionId != session.controller.target.sessionId) {
      // The same device reconnected under a new session — follow it, the
      // same way `DevicePickerCubit`'s doc says a picker would, then ask
      // for a fresh snapshot: revisions are per-session, so the old
      // projection means nothing against the new one.
      session.retarget(match);
      emit(
        state.copyWith(
          connection: PlaybackControlConnection.resynchronizing,
          availableCommands: session.controller.availableCommands(
            _desiredRemoteCommands,
          ),
        ),
      );
      unawaited(_requestSnapshot());
      return;
    }
    switch (match.reachability) {
      case DeviceReachability.incompatible:
      case DeviceReachability.notPermitted:
        // Permanent for this pairing (`DeviceReachability`'s own doc):
        // never comes back on its own, so this ends control rather than
        // waiting for a reconnect that will not happen.
        emit(state.copyWith(connection: PlaybackControlConnection.targetEnded));
      case DeviceReachability.offline:
      case DeviceReachability.presenceOnly:
      case DeviceReachability.stale:
        emit(
          state.copyWith(connection: PlaybackControlConnection.reconnecting),
        );
      case DeviceReachability.ready:
        if (state.connection != PlaybackControlConnection.synced &&
            !session.controller.needsResync) {
          emit(state.copyWith(connection: PlaybackControlConnection.synced));
        }
    }
  }

  void _updateTicker() {
    final shouldTick = state.isControlling && state.isPlaying;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!shouldTick && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _tick() {
    if (!state.isControlling) return;
    var position = _basePosition + DateTime.now().difference(_baseAt);
    final duration = state.duration;
    if (duration != null && position > duration) position = duration;
    emit(state.copyWith(position: position));
  }

  // ---- Transport (v0.5.6) ----

  Future<Result<void>> play() =>
      _send(RemoteCommandKind.play, (session) => session.play());

  Future<Result<void>> pause() =>
      _send(RemoteCommandKind.pause, (session) => session.pause());

  Future<Result<void>> togglePlayPause() =>
      _send(RemoteCommandKind.playPause, (session) => session.playPause());

  Future<Result<void>> previous() =>
      _send(RemoteCommandKind.previous, (session) => session.previous());

  Future<Result<void>> next() =>
      _send(RemoteCommandKind.next, (session) => session.next());

  Future<Result<void>> toggleShuffle() {
    final enabled = !state.queue.shuffleEnabled;
    return _send(
      RemoteCommandKind.setShuffle,
      (session) => session.setShuffle(enabled),
    );
  }

  Future<Result<void>> setRepeatMode(RepeatMode mode) =>
      _send(RemoteCommandKind.setRepeat, (session) => session.setRepeat(mode));

  /// Jumps to [entriesIndex] of [PlaybackControlState.queue]'s own entries
  /// — a tap on a remote queue row. Names the same window index the target
  /// published it at (`RemoteQueueProjection`'s own doc), which is exactly
  /// what this projection's entries are built from, in order.
  Future<Result<void>> jumpToQueueEntry(int entriesIndex) => _send(
    RemoteCommandKind.jumpToQueueEntry,
    (session) => session.jumpToQueueEntry(entriesIndex),
  );

  /// Seeks the target, optimistically moving the displayed position first
  /// — "acknowledged target state corrects optimistic motion, especially
  /// seek position" from the roadmap. The next snapshot (or an outright
  /// failure) is what actually corrects it if this guess was wrong.
  Future<Result<void>> seek(Duration position) {
    _basePosition = position;
    _baseAt = DateTime.now();
    emit(state.copyWith(position: position));
    return _send(RemoteCommandKind.seek, (session) => session.seek(position));
  }

  Future<Result<void>> _send(
    RemoteCommandKind kind,
    Future<Result<void>> Function(ConnectedPlaybackControllerSession session)
    run,
  ) async {
    final session = _controlSession;
    if (session == null) {
      return Result.err(ConnectedPlaybackFailures.notReachable());
    }
    final generation = _generation;
    emit(state.copyWith(pendingCommand: kind, clearCommandError: true));
    final result = await run(session);
    if (generation != _generation) return result;

    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            clearPendingCommand: true,
            availableCommands: session.controller.availableCommands(
              _desiredRemoteCommands,
            ),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            clearPendingCommand: true,
            commandError: failure.message,
            availableCommands: session.controller.availableCommands(
              _desiredRemoteCommands,
            ),
          ),
        );
    }
    if (session.controller.needsResync) {
      emit(
        state.copyWith(connection: PlaybackControlConnection.resynchronizing),
      );
      unawaited(_requestSnapshot());
    }
    return result;
  }

  /// Projects [snapshot] into a display-only `PlaybackQueue`, exactly the
  /// way `PlaybackCubit.adoptTransferredQueue` builds one from a handoff's
  /// resolved tracks: [RemotePlaybackSnapshot.queue] is already in play
  /// order, so that order is pinned in place
  /// (`PlaybackQueue.withRestoredShuffleOrder`) rather than left for a
  /// fresh `withEntries` shuffle to scramble.
  static PlaybackQueue _projectQueue(RemotePlaybackSnapshot snapshot) {
    final currentIndex = snapshot.currentIndex;
    if (snapshot.queue.isEmpty || currentIndex == null) {
      return PlaybackQueue.empty;
    }
    final entries = [for (final entry in snapshot.queue) entry.toQueueEntry()];
    var queue = PlaybackQueue.empty
        .withShuffle(snapshot.shuffleEnabled)
        .withRepeatMode(snapshot.repeatMode)
        .withEntries(entries, startIndex: currentIndex);
    if (snapshot.shuffleEnabled) {
      queue = queue.withRestoredShuffleOrder([
        for (var i = 0; i < entries.length; i++) i,
      ]);
    }
    return queue;
  }

  @override
  Future<void> close() async {
    await _sessionSub?.cancel();
    await _teardown();
    return super.close();
  }
}
