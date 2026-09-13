import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../app/connected_playback/ConnectedPlaybackScopeOf.dart';
import '../../../app/connected_playback/ConnectedPlaybackTargetLink.dart';
import '../../../app/connected_playback/PlaybackControlCubit.dart';
import '../../../app/playback/PlaybackCubit.dart';
import '../../../app/playback/PlaybackUiState.dart';
import '../../../app/session/SessionCubit.dart';
import '../../../app/session/SessionState.dart';
import '../../../core/result/result.dart';
import '../../../domain/connected_playback/ConnectedDevice.dart';
import '../../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../../domain/connected_playback/DevicePresenceSource.dart';
import '../../../domain/connected_playback/connection_state.dart';

/// How a transfer this cubit started is going, for whichever device it
/// targets — there is only ever one in flight, since [DevicePickerCubit
/// .transferTo] refuses a second call while [phase] is
/// [DeviceTransferPhase.inProgress].
enum DeviceTransferPhase { idle, inProgress, succeeded, failed }

class DeviceTransferProgress extends Equatable {
  const DeviceTransferProgress({
    required this.phase,
    this.deviceSessionId,
    this.message,
  });

  const DeviceTransferProgress.idle() : this(phase: DeviceTransferPhase.idle);

  const DeviceTransferProgress.inProgress(String deviceSessionId)
    : this(
        phase: DeviceTransferPhase.inProgress,
        deviceSessionId: deviceSessionId,
      );

  const DeviceTransferProgress.succeeded(String deviceSessionId)
    : this(
        phase: DeviceTransferPhase.succeeded,
        deviceSessionId: deviceSessionId,
      );

  const DeviceTransferProgress.failed(String deviceSessionId, String message)
    : this(
        phase: DeviceTransferPhase.failed,
        deviceSessionId: deviceSessionId,
        message: message,
      );

  final DeviceTransferPhase phase;

  /// The device this progress is about — the session id of the row the
  /// picker should show a spinner, success mark, or failure message on.
  final String? deviceSessionId;

  /// Set only when [phase] is [DeviceTransferPhase.failed].
  final String? message;

  @override
  List<Object?> get props => [phase, deviceSessionId, message];
}

class DevicePickerState extends Equatable {
  const DevicePickerState({
    this.connection = ConnectedPlaybackConnection.idle,
    this.devices = const [],
    this.localHasQueue = false,
    this.localIsPlaying = false,
    this.transfer = const DeviceTransferProgress.idle(),
    this.controllingSessionId,
  });

  /// This device's own link to the shared server — what a picker shows
  /// instead of an empty device list (v0.5.2's "three different empty
  /// screens").
  final ConnectedPlaybackConnection connection;

  /// Every device presence knows about for the active scope, including
  /// this one (`ConnectedDevice.isThisDevice`). Empty rather than absent
  /// when nothing is signed in or nothing else has been seen yet.
  final List<ConnectedDevice> devices;

  final bool localHasQueue;
  final bool localIsPlaying;

  final DeviceTransferProgress transfer;

  /// The session id of the device `PlaybackControlCubit` (v0.5.6) is
  /// currently controlling, or `null` while this device controls nothing
  /// — mirrored here so a row can show "Controlling" without the picker
  /// reading that cubit directly.
  final String? controllingSessionId;

  DevicePickerState copyWith({
    ConnectedPlaybackConnection? connection,
    List<ConnectedDevice>? devices,
    bool? localHasQueue,
    bool? localIsPlaying,
    DeviceTransferProgress? transfer,
    String? controllingSessionId,
    bool clearControllingSessionId = false,
  }) => DevicePickerState(
    connection: connection ?? this.connection,
    devices: devices ?? this.devices,
    localHasQueue: localHasQueue ?? this.localHasQueue,
    localIsPlaying: localIsPlaying ?? this.localIsPlaying,
    transfer: transfer ?? this.transfer,
    controllingSessionId: clearControllingSessionId
        ? null
        : (controllingSessionId ?? this.controllingSessionId),
  );

  @override
  List<Object?> get props => [
    connection,
    devices,
    localHasQueue,
    localIsPlaying,
    transfer,
    controllingSessionId,
  ];
}

/// Backs the device picker (v0.5.5): where playback is now, who else is
/// reachable, and moving it between "this device" and one of them.
///
/// Deliberately screen-scoped like `NowPlayingDetailsCubit` rather than a
/// singleton — presence is only worth subscribing to while a listener is
/// actually looking at the picker.
///
/// Two things this class never does, on purpose:
///
/// - It never offers "this device" itself as a [transferTo] target.
///   `ConnectedDevice.canReceiveTransfer` already refuses one's own row,
///   because [ConnectedPlaybackTargetLink.transferTo] hands over *this*
///   device's local queue — sending it to itself is not a handoff.
/// - It never asks a remote device to transfer to this one.
///   [PlaybackHandoffCoordinator] has no such message: only the device
///   producing audio may decide to let go of it. [bringBackToThisDevice]
///   is therefore an ordinary local resume, not a handoff — this device's
///   own queue survives a handoff away exactly as it was, paused
///   (`ConnectedPlaybackTargetLink._applyDecision`'s `stopLocalPlayback`
///   never clears it), so there is always something to resume once
///   nothing else is using it. `ConnectedDevice.isPlaying`'s own doc
///   accepts that this can transiently show two devices "playing" at
///   once — the moment a listener notices and finishes the move
///   themselves, exactly the symptom a handoff exists to make visible
///   rather than hide.
@injectable
class DevicePickerCubit extends Cubit<DevicePickerState> {
  DevicePickerCubit(
    this._presence,
    this._session,
    this._playback,
    this._handoff,
    this._control,
  ) : super(
        DevicePickerState(
          localHasQueue: _playback.state.hasQueue,
          localIsPlaying: _playback.state.isPlaying,
          controllingSessionId: _control.state.device?.sessionId,
        ),
      ) {
    _sessionSub = _session.stream.listen(_onSession);
    _playbackSub = _playback.stream.listen(_onPlayback);
    _connectionSub = _presence.connection.listen(_onConnection);
    _controlSub = _control.stream.listen(_onControl);
    _onSession(_session.state);
  }

  final DevicePresenceSource _presence;
  final SessionCubit _session;
  final PlaybackCubit _playback;
  final ConnectedPlaybackTargetLink _handoff;

  /// Owns the actual controller session (v0.5.6) — this cubit only chooses
  /// a device and mirrors which one, for the picker's own "Controlling"
  /// row state.
  final PlaybackControlCubit _control;

  StreamSubscription<SessionState>? _sessionSub;
  StreamSubscription<PlaybackUiState>? _playbackSub;
  StreamSubscription<ConnectedPlaybackConnection>? _connectionSub;
  StreamSubscription<List<ConnectedDevice>>? _devicesSub;
  StreamSubscription<PlaybackControlState>? _controlSub;

  ConnectedPlaybackScope? _scope;

  void _onSession(SessionState sessionState) {
    final scope = connectedPlaybackScopeOf(sessionState);
    if (scope == _scope) return;
    _scope = scope;
    unawaited(_devicesSub?.cancel());
    _devicesSub = scope == null
        ? null
        : _presence.devices(scope).listen(_onDevices);
    if (scope == null) emit(state.copyWith(devices: const []));
  }

  void _onDevices(List<ConnectedDevice> devices) => emit(
    state.copyWith(
      devices: List<ConnectedDevice>.of(devices)..sort(_byRelevance),
    ),
  );

  void _onConnection(ConnectedPlaybackConnection connection) =>
      emit(state.copyWith(connection: connection));

  void _onPlayback(PlaybackUiState playback) => emit(
    state.copyWith(
      localHasQueue: playback.hasQueue,
      localIsPlaying: playback.isPlaying,
    ),
  );

  /// Hands this device's local queue to [device] — the picker's "transfer
  /// playback" action. Refuses a second call while one is already in
  /// flight rather than letting two taps race.
  Future<void> transferTo(ConnectedDevice device) async {
    if (state.transfer.phase == DeviceTransferPhase.inProgress) return;

    final snapshot = _handoff.localSnapshot;
    if (snapshot == null) {
      emit(
        state.copyWith(
          transfer: DeviceTransferProgress.failed(
            device.sessionId,
            'Nothing is playing on this device to send.',
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        transfer: DeviceTransferProgress.inProgress(device.sessionId),
      ),
    );
    final result = await _handoff.transferTo(
      target: device,
      snapshot: snapshot,
    );
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            transfer: DeviceTransferProgress.succeeded(device.sessionId),
          ),
        );
      case Err(:final failure):
        // transferTo only ever returns Err before the source has stopped
        // (PlaybackHandoffCoordinator's doc), so playback is still local.
        emit(
          state.copyWith(
            transfer: DeviceTransferProgress.failed(
              device.sessionId,
              failure.message,
            ),
          ),
        );
    }
  }

  /// Resumes this device's own queue — the picker's "bring it back to
  /// this device" action. A no-op unless there is a paused local queue
  /// to resume; see the class doc for why this is a plain local resume
  /// rather than a handoff.
  Future<void> bringBackToThisDevice() => _playback.play();

  /// Starts controlling [device]'s active playback (v0.5.6) — binding the
  /// mini-player, Now Playing and the queue to its projection until
  /// [stopControlling] is called or a different device is chosen.
  Future<void> control(ConnectedDevice device) => _control.control(device);

  /// Stops controlling whatever device this app is currently driving,
  /// without affecting its playback — the picker's route back to "just
  /// looking", distinct from [transferTo] or [bringBackToThisDevice].
  Future<void> stopControlling() => _control.stop();

  void _onControl(PlaybackControlState controlState) => emit(
    state.copyWith(
      controllingSessionId: controlState.device?.sessionId,
      clearControllingSessionId: controlState.device == null,
    ),
  );

  /// "This device" first, then whoever is actually producing audio, then
  /// everything else usable, then everything else — so the picker's most
  /// relevant rows never depend on however presence happened to order
  /// them.
  static int _byRelevance(ConnectedDevice a, ConnectedDevice b) {
    int rank(ConnectedDevice device) {
      if (device.isThisDevice) return 0;
      if (device.isPlaying) return 1;
      if (device.reachability.canReceiveCommands) return 2;
      return 3;
    }

    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.displayName.compareTo(b.displayName);
  }

  @override
  Future<void> close() async {
    await _sessionSub?.cancel();
    await _playbackSub?.cancel();
    await _connectionSub?.cancel();
    await _controlSub?.cancel();
    await _devicesSub?.cancel();
    return super.close();
  }
}
