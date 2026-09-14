import 'dart:async';

import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackScope.dart';
import 'package:jellyfinity/domain/connected_playback/RemoteQueueEntry.dart';
import 'package:jellyfinity/domain/connected_playback/SyncPlayGroupUpdate.dart';
import 'package:jellyfinity/domain/connected_playback/SyncPlayTransport.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';

/// A [SyncPlayTransport] a test drives by hand — no server, no socket,
/// just calls recorded and updates pushed on demand. `SyncPlayGroupCubit`'s
/// own tests exercise its state machine against this; wire decoding has
/// its own coverage in `jellyfin_sync_play_api_test.dart`.
class FakeSyncPlayTransport implements SyncPlayTransport {
  final _updates = StreamController<SyncPlayGroupUpdate>.broadcast();

  /// Every call made, in order — what a test asserts "and nothing else"
  /// against, the same convention `FakePlaybackEngine.calls` uses.
  final List<String> calls = [];

  /// Set to make the next `createGroup`/`joinGroup`/`leaveGroup`/`setQueue`
  /// call answer `Err` instead of `Ok` — simulating the request itself
  /// never reaching the server, distinct from the server answering with a
  /// [SyncPlayJoinDenied] pushed through [emit].
  bool nextCallFails = false;

  Result<void> get _result {
    if (!nextCallFails) return const Result.ok(null);
    nextCallFails = false;
    return const Result.err(
      UnavailableFailure('Could not reach the server.'),
    );
  }

  @override
  Stream<SyncPlayGroupUpdate> groupUpdates(ConnectedPlaybackScope scope) =>
      _updates.stream;

  /// Pushes [update] as if the server had sent it.
  void emit(SyncPlayGroupUpdate update) => _updates.add(update);

  @override
  Future<Result<void>> createGroup(ConnectedPlaybackScope scope) async {
    calls.add('createGroup');
    return _result;
  }

  @override
  Future<Result<void>> joinGroup(
    ConnectedPlaybackScope scope,
    String groupId,
  ) async {
    calls.add('joinGroup($groupId)');
    return _result;
  }

  @override
  Future<Result<void>> leaveGroup(ConnectedPlaybackScope scope) async {
    calls.add('leaveGroup');
    return _result;
  }

  @override
  Future<Result<void>> setQueue(
    ConnectedPlaybackScope scope, {
    required List<RemoteQueueEntry> entries,
    required int startIndex,
    required bool shuffleEnabled,
    required RepeatMode repeatMode,
    Duration startPosition = Duration.zero,
  }) async {
    calls.add('setQueue(${entries.length}, startIndex: $startIndex)');
    return _result;
  }

  @override
  Future<Result<void>> play(ConnectedPlaybackScope scope) async {
    calls.add('play');
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> pause(ConnectedPlaybackScope scope) async {
    calls.add('pause');
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> seek(
    ConnectedPlaybackScope scope,
    Duration position,
  ) async {
    calls.add('seek($position)');
    return const Result.ok(null);
  }

  Future<void> dispose() => _updates.close();
}
