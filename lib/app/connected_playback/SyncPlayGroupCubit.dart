import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/logging/Logger.dart';
import '../../core/result/result.dart';
import '../../domain/connected_playback/ConnectedPlaybackScope.dart';
import '../../domain/connected_playback/RemoteQueueEntry.dart';
import '../../domain/connected_playback/SyncPlayGroupUpdate.dart';
import '../../domain/connected_playback/SyncPlayTransport.dart';
import '../../domain/connected_playback/sync_play_group_status.dart';
import '../../domain/media/MusicLibraryRepository.dart';
import '../../domain/media/Track.dart';
import '../../domain/playback/repeat_mode.dart';
import '../playback/PlaybackCubit.dart';
import '../session/SessionCubit.dart';
import '../session/SessionState.dart';
import 'ConnectedPlaybackScopeOf.dart';
import 'SyncPlayGroupState.dart';

/// "Play on all devices" (v0.6.0, ADR-0045): this device's membership in
/// at most one SyncPlay group, and the one path that turns the group's
/// shared queue/transport state into real local playback.
///
/// Same architectural slot as `PlaybackControlCubit`/`ActiveRemotePlaybackWatcher`
/// — a `@lazySingleton` at the composition root, started once and kept in
/// step with sign-in. Unlike `PlaybackControlCubit`, which drives a
/// *different* device, this class drives this device's own `PlaybackCubit`
/// directly, the same single control path
/// `ConnectedPlaybackTargetLink._execute`'s own doc insists on: every
/// group effect on local playback goes through `PlaybackCubit`'s public
/// methods, never the engine.
///
/// Deliberately has no code path into `PlaybackCubit.setSystemVolume` or
/// anything volume-shaped — ADR-0045's invariant ("volume never travels
/// with a group") is enforced by this class simply never touching it,
/// not by a runtime guard that could be bypassed by a future edit.
@lazySingleton
class SyncPlayGroupCubit extends Cubit<SyncPlayGroupState> {
  SyncPlayGroupCubit(this._syncPlay, this._playback, this._library, this._session)
    : super(const SyncPlayGroupState()) {
    _sessionSub = _session.stream.listen(_onSession);
    _onSession(_session.state);
  }

  final SyncPlayTransport _syncPlay;
  final PlaybackCubit _playback;
  final MusicLibraryRepository _library;
  final SessionCubit _session;

  StreamSubscription<SessionState>? _sessionSub;
  StreamSubscription<SyncPlayGroupUpdate>? _updatesSub;
  ConnectedPlaybackScope? _scope;

  @visibleForTesting
  Logger? logger;

  void _onSession(SessionState sessionState) {
    final scope = connectedPlaybackScopeOf(sessionState);
    if (scope == _scope) return;
    _scope = scope;
    unawaited(_updatesSub?.cancel());
    _updatesSub = null;
    if (!isClosed) emit(const SyncPlayGroupState());
    if (scope != null) {
      _updatesSub = _syncPlay.groupUpdates(scope).listen(_onUpdate);
    }
  }

  /// Creates a new group spanning this profile's devices — the picker's
  /// "play on all devices" when this device is not already in one.
  /// Success arrives asynchronously as a [SyncPlayGroupJoined] on
  /// [groupUpdates]; this call only starts that request.
  Future<void> createGroup() => _requestJoin((scope) => _syncPlay.createGroup(scope));

  /// Joins a group this device already knows the id of — used both from
  /// a picker listing an existing group and to rejoin one this device
  /// dropped out of (ADR-0045's "survives a member dropping and
  /// rejoining").
  Future<void> joinGroup(String groupId) =>
      _requestJoin((scope) => _syncPlay.joinGroup(scope, groupId));

  Future<void> _requestJoin(
    Future<Result<void>> Function(ConnectedPlaybackScope scope) request,
  ) async {
    final scope = _scope;
    if (scope == null || state.status == SyncPlayGroupStatus.joining) return;
    emit(
      state.copyWith(status: SyncPlayGroupStatus.joining, clearFailure: true),
    );
    final result = await request(scope);
    // An `Err` here means the request itself could not reach the server
    // — a genuine `GroupJoined`/`JoinGroupDenied` answer arrives on the
    // socket instead, whichever the server decides, and takes precedence
    // over this fallback if it arrives first.
    if (result.isErr && state.status == SyncPlayGroupStatus.joining) {
      emit(
        const SyncPlayGroupState.failed(
          'Could not reach the server to start a group.',
        ),
      );
    }
  }

  /// Leaves the current group, if this device is in one. A no-op
  /// otherwise.
  Future<void> leave() async {
    final scope = _scope;
    final groupId = state.groupId;
    if (scope == null || groupId == null) return;
    emit(state.copyWith(status: SyncPlayGroupStatus.leaving));
    await _syncPlay.leaveGroup(scope);
    if (!isClosed) emit(const SyncPlayGroupState());
  }

  /// Hands this device's current local queue to a new group — "play on
  /// all devices" starting from what is already playing here. Creates
  /// the group first when this device is not already in one.
  Future<void> playOnAllDevices() async {
    final scope = _scope;
    final queue = _playback.state.queue;
    final order = queue.playOrder;
    final currentIndex = queue.currentPlayPosition;
    if (scope == null || order.isEmpty || currentIndex < 0) return;

    final entries = [
      for (final entriesIndex in order)
        RemoteQueueEntry.fromQueueEntry(queue.entries[entriesIndex]),
    ];

    if (state.status != SyncPlayGroupStatus.joined) {
      await createGroup();
    }
    await _syncPlay.setQueue(
      scope,
      entries: entries,
      startIndex: currentIndex,
      shuffleEnabled: queue.shuffleEnabled,
      repeatMode: queue.repeatMode,
      startPosition: _playback.state.position,
    );
  }

  void _onUpdate(SyncPlayGroupUpdate update) {
    switch (update) {
      case SyncPlayGroupJoined(
        :final groupId,
        :final groupName,
        :final members,
        :final queue,
        :final queuePosition,
      ):
        emit(
          SyncPlayGroupState.joined(
            groupId: groupId,
            groupName: groupName,
            members: members,
          ),
        );
        if (queue.isNotEmpty) {
          unawaited(
            _adoptQueue(
              queue,
              startIndex: queuePosition,
              startPlaying: true,
            ),
          );
        }
      case SyncPlayGroupLeft():
        if (!isClosed) emit(const SyncPlayGroupState());
      case SyncPlayJoinDenied(:final reason):
        emit(SyncPlayGroupState.failed(reason));
      case SyncPlayUserJoined(:final member):
        if (state.status == SyncPlayGroupStatus.joined) {
          emit(state.copyWith(members: [...state.members, member]));
        }
      case SyncPlayUserLeft(:final sessionId):
        if (state.status == SyncPlayGroupStatus.joined) {
          emit(
            state.copyWith(
              members: [
                for (final member in state.members)
                  if (member.sessionId != sessionId) member,
              ],
            ),
          );
        }
      case SyncPlayQueueUpdated(
        :final entries,
        :final startIndex,
        :final shuffleEnabled,
        :final repeatMode,
        :final startPosition,
        :final startPlaying,
      ):
        unawaited(
          _adoptQueue(
            entries,
            startIndex: startIndex,
            shuffleEnabled: shuffleEnabled,
            repeatMode: repeatMode,
            startPosition: startPosition,
            startPlaying: startPlaying,
          ),
        );
      case SyncPlayTransportUpdated(:final isPlaying, :final position):
        unawaited(_reconcileTransport(isPlaying, position));
      case UnhandledSyncPlayUpdate(:final updateType):
        logger?.debug('Unhandled SyncPlay group update: $updateType');
    }
  }

  /// Reconciles this device's own transport with the group's — play,
  /// pause, or a seek beyond a small tolerance. Never volume: see this
  /// class's own doc.
  Future<void> _reconcileTransport(bool groupIsPlaying, Duration position) async {
    if (state.status != SyncPlayGroupStatus.joined) return;
    final local = _playback.state;
    const tolerance = Duration(seconds: 2);
    if ((local.position - position).abs() > tolerance) {
      await _playback.seek(position);
    }
    if (groupIsPlaying && !local.isPlaying) {
      await _playback.resume();
    } else if (!groupIsPlaying && local.isPlaying) {
      await _playback.pause();
    }
  }

  Future<void> _adoptQueue(
    List<RemoteQueueEntry> entries, {
    required int startIndex,
    bool shuffleEnabled = false,
    RepeatMode? repeatMode,
    Duration startPosition = Duration.zero,
    bool startPlaying = true,
  }) async {
    final tracks = <Track>[];
    for (final entry in entries) {
      final result = await _library.track(entry.id);
      switch (result) {
        case Ok<Track>(:final value):
          tracks.add(value);
        case Err<Track>():
          return;
      }
    }
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) return;
    await _playback.adoptTransferredQueue(
      tracks,
      startIndex: startIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode ?? _playback.state.queue.repeatMode,
      startPosition: startPosition,
      startPlaying: startPlaying,
    );
  }

  @override
  Future<void> close() async {
    await _sessionSub?.cancel();
    await _updatesSub?.cancel();
    return super.close();
  }
}
