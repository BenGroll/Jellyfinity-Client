import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../domain/connected_playback/ConnectedDevice.dart';
import '../../domain/connected_playback/ConnectedPlaybackFailures.dart';
import '../../domain/connected_playback/ConnectedPlaybackLimits.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../domain/connected_playback/ConnectedPlaybackTransport.dart';
import '../../domain/connected_playback/DevicePresenceSource.dart';
import '../../domain/connected_playback/RemotePlaybackSnapshot.dart';
import '../../domain/connected_playback/RemoteQueueEntry.dart';
import '../../domain/connected_playback/device_reachability.dart';
import '../../domain/connected_playback/remote_command_kind.dart';
import '../../domain/media/Track.dart';
import '../../domain/playback/PlaybackQueue.dart';
import '../../domain/playback/QueueEntry.dart';
import '../../domain/playback/QueueOrigin.dart';
import '../../domain/playback/playback_status.dart';
import '../../domain/playback/repeat_mode.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import 'ConnectedPlaybackControllerSession.dart';
import 'ConnectedPlaybackScopeOf.dart';

/// How this device's control of [PlaybackControlState.device] is going,
/// beyond the target's own playback status.
enum PlaybackControlCommandStatus { pending, applied, rejected, timedOut }

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
    this.volume,
    this.connection = PlaybackControlConnection.synced,
    this.availableCommands = const {},
    this.pendingCommand,
    this.commandStatus,
    this.commandError,
    this.originName,
    this.syncGroupId,
    this.controlledBy,
  });

  /// The device being controlled, or `null` when this device is not
  /// controlling anything.
  final ConnectedDevice? device;

  /// The device currently driving *this* one, or `null` when nobody is.
  ///
  /// Read from presence rather than from any command that arrives: a
  /// controller advertises what it is driving
  /// (`DeviceAdvertisement.controllingSessionId`), so a target knows it is
  /// being controlled even before the first command reaches it, and knows
  /// the moment the controller lets go. A device is one or the other —
  /// never both — which is the rule that stopped two devices each
  /// believing they were controlling the other.
  final ConnectedDevice? controlledBy;

  bool get isBeingControlled => controlledBy != null;

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

  final double? volume;

  final PlaybackControlConnection connection;

  /// The commands negotiated against the target's advertised capabilities
  /// (`RemotePlaybackController.availableCommands`) — a control whose kind
  /// is missing here is disabled or omitted, never shown failing.
  final Set<RemoteCommandKind> availableCommands;

  /// The command currently awaiting an acknowledgement, if any — what a
  /// control shows a brief pending/spinner state for.
  final RemoteCommandKind? pendingCommand;

  final PlaybackControlCommandStatus? commandStatus;

  /// The most recent command failure's message, transient like
  /// `PlaybackUiState.lastFailure`.
  final String? commandError;

  final String? originName;
  final String? syncGroupId;

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
    double? volume,
    bool clearVolume = false,
    PlaybackControlConnection? connection,
    Set<RemoteCommandKind>? availableCommands,
    RemoteCommandKind? pendingCommand,
    PlaybackControlCommandStatus? commandStatus,
    bool clearPendingCommand = false,
    String? commandError,
    bool clearCommandError = false,
    String? originName,
    bool clearOrigin = false,
    String? syncGroupId,
    bool clearSyncGroupId = false,
    ConnectedDevice? controlledBy,
    bool clearControlledBy = false,
  }) => PlaybackControlState(
    device: device,
    controlledBy: clearControlledBy
        ? null
        : (controlledBy ?? this.controlledBy),
    queue: queue ?? this.queue,
    status: status ?? this.status,
    position: position ?? this.position,
    volume: clearVolume ? null : (volume ?? this.volume),
    connection: connection ?? this.connection,
    availableCommands: availableCommands ?? this.availableCommands,
    pendingCommand: clearPendingCommand
        ? null
        : (pendingCommand ?? this.pendingCommand),
    commandStatus: commandStatus ?? this.commandStatus,
    commandError: clearCommandError
        ? null
        : (commandError ?? this.commandError),
    originName: clearOrigin ? null : (originName ?? this.originName),
    syncGroupId: clearSyncGroupId ? null : (syncGroupId ?? this.syncGroupId),
  );

  @override
  List<Object?> get props => [
    device,
    queue,
    status,
    position,
    volume,
    connection,
    availableCommands,
    pendingCommand,
    commandStatus,
    commandError,
    originName,
    syncGroupId,
    controlledBy,
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
  RemoteCommandKind.setQueue,
  RemoteCommandKind.setVolume,
  RemoteCommandKind.removeQueueEntry,
  RemoteCommandKind.moveQueueEntry,
  RemoteCommandKind.takeControl,
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

  /// Presence for as long as this profile is signed in, independently of
  /// whether this device is controlling anything — see [_onPresence].
  StreamSubscription<List<ConnectedDevice>>? _presenceSub;
  List<ConnectedDevice> _knownDevices = const [];
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
    unawaited(_presenceSub?.cancel());
    _presenceSub = null;
    _knownDevices = const [];
    if (state.isBeingControlled) {
      emit(state.copyWith(clearControlledBy: true));
    }
    if (scope == null) return;
    // Watched for the whole signed-in session, not just while controlling
    // something: being controlled is a state this device can enter without
    // doing anything at all, and it has to be able to notice.
    _presenceSub = _presence.devices(scope).listen(_onPresence);
  }

  void _onPresence(List<ConnectedDevice> devices) {
    _knownDevices = devices;

    // A device that has taken control of something is no longer a device
    // this one may drive. Whoever acted most recently wins, which makes
    // "control that device" on either end a complete instruction rather
    // than half of a state both ends have to agree on.
    final target = state.device;
    if (target != null) {
      for (final device in devices) {
        if (device.deviceId == target.deviceId &&
            device.controllingSessionId != null) {
          unawaited(stop());
          return;
        }
      }
    }

    final localSessionId = _transport.localSessionId;
    ConnectedDevice? controller;
    if (localSessionId != null) {
      for (final device in devices) {
        if (!device.isThisDevice &&
            device.controllingSessionId == localSessionId) {
          controller = device;
          break;
        }
      }
    }
    final known = state.controlledBy;
    if (controller?.deviceId == known?.deviceId &&
        controller?.displayName == known?.displayName) {
      return;
    }
    emit(
      state.copyWith(
        controlledBy: controller,
        clearControlledBy: controller == null,
      ),
    );
  }

  /// Starts controlling whichever known device answers to [sessionId].
  ///
  /// The entry point for `RemoteCommandKind.takeControl`: a device that
  /// has just handed its playback over asks the device that took it to
  /// become its remote, and names itself by the session id the command
  /// arrived from.
  Future<void> controlDeviceWithSession(String sessionId) async {
    for (final device in _knownDevices) {
      if (device.sessionId == sessionId && !device.isThisDevice) {
        await control(device);
        return;
      }
    }
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
        // Acting wins: this device is now a controller, so it is not also
        // something being controlled. The peer driving it reads the same
        // conclusion from the advertisement this change publishes.
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
    // Being controlled is not something this device chose and not
    // something letting go of its own target ends.
    if (state.isControlling) {
      emit(PlaybackControlState(controlledBy: state.controlledBy));
    }
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
    final result = await session.requestSnapshot();
    if (session != _controlSession || result.isOk) return;
    final error = result.failureOrNull?.message;
    emit(
      state.copyWith(
        connection: PlaybackControlConnection.reconnecting,
        commandError: error ?? "Could not read that device.",
      ),
    );
  }

  void _onSnapshot(int generation, RemotePlaybackSnapshot snapshot) {
    if (generation != _generation) return;
    final session = _controlSession;
    if (session == null) return;

    // A snapshot was sampled before it was sent, so its position is
    // always a little behind this device's own extrapolation. Snapping to
    // every one of them is what made the timeline jitter with the
    // network. Correct only what cannot be explained by latency: a real
    // seek, a track change, or a target that stopped.
    final projected = _projectedPosition();
    final drift = (snapshot.position - projected).abs();
    final changedTrack =
        snapshot.currentIndex != state.queue.currentPlayPosition ||
        snapshot.status != state.status;
    final correctPosition =
        changedTrack || drift > ConnectedPlaybackLimits.positionDriftTolerance;
    if (correctPosition) {
      _basePosition = snapshot.position;
      _baseAt = DateTime.now();
    }
    emit(
      state.copyWith(
        queue: _projectQueue(snapshot),
        status: snapshot.status,
        position: correctPosition ? snapshot.position : projected,
        volume: snapshot.volume,
        clearVolume: snapshot.volume == null,
        connection: session.controller.needsResync
            ? PlaybackControlConnection.resynchronizing
            : PlaybackControlConnection.synced,
        availableCommands: session.controller.availableCommands(
          _desiredRemoteCommands,
        ),
        originName: snapshot.originName,
        clearOrigin: snapshot.originName == null,
        syncGroupId: snapshot.syncGroupId,
        clearSyncGroupId: snapshot.syncGroupId == null,
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
    emit(state.copyWith(position: _projectedPosition()));
  }

  /// Where the target should be now, extrapolated from the last reading
  /// this controller trusted — the value the timeline actually runs on
  /// between snapshots.
  Duration _projectedPosition() {
    if (!state.isPlaying) return _basePosition;
    var position = _basePosition + DateTime.now().difference(_baseAt);
    if (position < Duration.zero) position = Duration.zero;
    final duration = state.duration;
    if (duration != null && position > duration) position = duration;
    return position;
  }

  // ---- Transport (v0.5.6) ----

  /// Replaces the controlled device's queue as if the selection happened
  /// on that device. The queue is built into its actual play order first,
  /// so shuffled selections preserve the same starting song and order on
  /// the target as they do locally.
  Future<Result<void>> playTracks(
    List<Track> tracks, {
    required int startIndex,
    bool shuffle = false,
    QueueOrigin? origin,
  }) {
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) {
      return Future.value(
        const Result.err(
          UnavailableFailure('There is no playable selection to send.'),
        ),
      );
    }
    final sourceEntries = [
      for (final track in tracks) QueueEntry.fromTrack(track),
    ];
    final sourceQueue = PlaybackQueue.empty
        .withShuffle(shuffle)
        .withRepeatMode(state.queue.repeatMode)
        .withEntries(sourceEntries, startIndex: startIndex, origin: origin);
    final entries = [
      for (final index in sourceQueue.playOrder)
        RemoteQueueEntry.fromQueueEntry(sourceQueue.entries[index]),
    ];
    final remoteStartIndex = sourceQueue.currentPlayPosition;
    final previousBasePosition = _basePosition;
    final previousBaseAt = _baseAt;
    _basePosition = Duration.zero;
    _baseAt = DateTime.now();
    var optimisticQueue = PlaybackQueue.empty
        .withShuffle(shuffle)
        .withRepeatMode(sourceQueue.repeatMode)
        .withEntries(
          [for (final entry in entries) entry.toQueueEntry()],
          startIndex: remoteStartIndex,
          origin: origin,
        );
    if (shuffle) {
      optimisticQueue = optimisticQueue.withRestoredShuffleOrder([
        for (var i = 0; i < entries.length; i++) i,
      ]);
    }
    return _send(
      RemoteCommandKind.setQueue,
      (session) => session.setQueue(
        entries: entries,
        startIndex: remoteStartIndex,
        shuffleEnabled: shuffle,
        repeatMode: sourceQueue.repeatMode,
        originName: origin?.name,
        startPlaying: true,
      ),
      optimistic: (current) => current.copyWith(
        queue: optimisticQueue,
        status: PlaybackStatus.playing,
        position: Duration.zero,
        originName: origin?.name,
        clearOrigin: origin == null,
      ),
    ).then((result) {
      if (result.isErr && _controlSession != null) {
        _basePosition = previousBasePosition;
        _baseAt = previousBaseAt;
      }
      return result;
    });
  }

  Future<Result<void>> play() => _send(
    RemoteCommandKind.play,
    (session) => session.play(),
    optimistic: (current) => current.copyWith(status: PlaybackStatus.playing),
  );

  Future<Result<void>> pause() => _send(
    RemoteCommandKind.pause,
    (session) => session.pause(),
    optimistic: (current) => current.copyWith(status: PlaybackStatus.paused),
  );

  Future<Result<void>> togglePlayPause() => _send(
    RemoteCommandKind.playPause,
    (session) => session.playPause(),
    optimistic: (current) => current.copyWith(
      status: current.isPlaying
          ? PlaybackStatus.paused
          : PlaybackStatus.playing,
    ),
  );

  Future<Result<void>> previous() => _send(
    RemoteCommandKind.previous,
    (session) => session.previous(),
    optimistic: (current) =>
        _optimisticQueueIndex(current, current.queue.previousIndex()),
  );

  Future<Result<void>> next() => _send(
    RemoteCommandKind.next,
    (session) => session.next(),
    optimistic: (current) =>
        _optimisticQueueIndex(current, current.queue.manualNextIndex()),
  );

  Future<Result<void>> toggleShuffle() => _send(
    RemoteCommandKind.setShuffle,
    (session) => session.setShuffle(!state.queue.shuffleEnabled),
    optimistic: (current) => current.copyWith(
      queue: current.queue.withShuffle(!current.queue.shuffleEnabled),
    ),
  );

  Future<Result<void>> setRepeatMode(RepeatMode mode) => _send(
    RemoteCommandKind.setRepeat,
    (session) => session.setRepeat(mode),
    optimistic: (current) =>
        current.copyWith(queue: current.queue.withRepeatMode(mode)),
  );

  Future<Result<void>> jumpToQueueEntry(int entriesIndex) {
    final previousBasePosition = _basePosition;
    final previousBaseAt = _baseAt;
    _basePosition = Duration.zero;
    _baseAt = DateTime.now();
    return _send(
      RemoteCommandKind.jumpToQueueEntry,
      (session) => session.jumpToQueueEntry(entriesIndex),
      optimistic: (current) => _optimisticQueueIndex(
        current,
        entriesIndex >= 0 && entriesIndex < current.queue.entries.length
            ? entriesIndex
            : null,
      ),
    ).then((result) {
      if (result.isErr && _controlSession != null) {
        _basePosition = previousBasePosition;
        _baseAt = previousBaseAt;
      }
      return result;
    });
  }

  Future<Result<void>> removeQueueEntry(int entriesIndex) => _send(
    RemoteCommandKind.removeQueueEntry,
    (session) => session.removeQueueEntry(entriesIndex),
  );

  Future<Result<void>> moveQueueEntry(int fromIndex, int toIndex) => _send(
    RemoteCommandKind.moveQueueEntry,
    (session) => session.moveQueueEntry(fromIndex, toIndex),
  );

  Future<Result<void>> setVolume(double volume) {
    final normalized = volume.clamp(0.0, 1.0);
    return _send(
      RemoteCommandKind.setVolume,
      (session) => session.setVolume(normalized),
      optimistic: (current) => current.copyWith(volume: normalized),
    );
  }

  Future<Result<void>> seek(Duration position) {
    final previousBasePosition = _basePosition;
    final previousBaseAt = _baseAt;
    _basePosition = position;
    _baseAt = DateTime.now();
    return _send(
      RemoteCommandKind.seek,
      (session) => session.seek(position),
      optimistic: (current) => current.copyWith(position: position),
    ).then((result) {
      if (result.isErr && _controlSession != null) {
        _basePosition = previousBasePosition;
        _baseAt = previousBaseAt;
      }
      return result;
    });
  }

  PlaybackControlState _optimisticQueueIndex(
    PlaybackControlState current,
    int? index,
  ) {
    if (index == null || index < 0 || index >= current.queue.entries.length) {
      return current;
    }
    return current.copyWith(
      queue: current.queue.withCurrentIndex(index),
      position: Duration.zero,
    );
  }

  /// Requests the controlled peer join [groupId]. SyncPlay owns the shared
  /// queue and transport; this command only bridges device membership.
  Future<Result<void>> joinSyncGroup(String groupId) => _send(
    RemoteCommandKind.joinSyncGroup,
    (session) => session.joinSyncGroup(groupId),
  );

  /// Asks the controlled device to become this device's controller — the
  /// role swap behind "play on this device" (see
  /// `RemoteCommandKind.takeControl`).
  Future<Result<void>> handControlBack(String localSessionId) => _send(
    RemoteCommandKind.takeControl,
    (session) => session.takeControl(localSessionId),
  );

  Future<Result<void>> _send(
    RemoteCommandKind kind,
    Future<Result<void>> Function(ConnectedPlaybackControllerSession session)
    run, {
    PlaybackControlState Function(PlaybackControlState)? optimistic,
  }) async {
    final session = _controlSession;
    if (session == null) {
      return Result.err(ConnectedPlaybackFailures.notReachable());
    }
    final generation = _generation;
    final rollback = state;
    if (optimistic != null) {
      emit(optimistic(rollback));
      _updateTicker();
    }
    emit(
      state.copyWith(
        pendingCommand: kind,
        commandStatus: PlaybackControlCommandStatus.pending,
        clearCommandError: true,
      ),
    );
    final result = await run(session);
    if (generation != _generation) return result;

    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            clearPendingCommand: true,
            commandStatus: PlaybackControlCommandStatus.applied,
            availableCommands: session.controller.availableCommands(
              _desiredRemoteCommands,
            ),
          ),
        );
      case Err(:final failure):
        final base = optimistic == null ? state : rollback;
        // A recoverable failure means "compose that again once you have
        // looked": the projection is refreshed below and nothing is
        // broken. Telling the listener about it leaves a warning sitting
        // on screen for something they neither caused nor can act on,
        // which is most of what made this feature feel unreliable.
        final transient = failure is RecoverableFailure;
        emit(
          base.copyWith(
            clearPendingCommand: true,
            commandStatus:
                failure.message == ConnectedPlaybackFailures.timedOut().message
                ? PlaybackControlCommandStatus.timedOut
                : PlaybackControlCommandStatus.rejected,
            commandError: transient ? null : failure.message,
            clearCommandError: transient,
            availableCommands: session.controller.availableCommands(
              _desiredRemoteCommands,
            ),
          ),
        );
        _updateTicker();
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
    await _presenceSub?.cancel();
    await _teardown();
    return super.close();
  }
}
