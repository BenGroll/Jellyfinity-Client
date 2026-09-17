import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../../domain/connected_playback/RemotePlaybackOwnership.dart';
import '../../domain/connected_playback/sync_play_group_status.dart';
import '../../domain/media/Track.dart';
import '../../domain/playback/QueueOrigin.dart';
import 'PlaybackControlCubit.dart';
import 'SyncPlayGroupCubit.dart';

/// Routes a local selection to the active shared playback destination.
///
/// [SyncPlayGroupCubit] cannot be a normal constructor dependency here:
/// it itself depends on [PlaybackCubit], which depends on this seam. The
/// optional test dependency keeps this class direct and testable, while
/// production resolves the already-registered lazy singleton only when a
/// selection is actually made.
@LazySingleton(as: RemotePlaybackOwnership)
class PlaybackControlOwnership implements RemotePlaybackOwnership {
  PlaybackControlOwnership(this._control);

  final PlaybackControlCubit _control;

  /// Stands in for the lazily-resolved group cubit in tests.
  ///
  /// Deliberately not a constructor parameter: injectable fills optional
  /// positional parameters when it can, and doing so here would wire
  /// `SyncPlayGroupCubit` in eagerly, closing the very cycle the lazy
  /// lookup below exists to avoid — `PlaybackCubit` depends on this
  /// class, and `SyncPlayGroupCubit` depends on `PlaybackCubit`.
  @visibleForTesting
  SyncPlayGroupCubit? debugSyncPlay;

  SyncPlayGroupCubit? get _group {
    final override = debugSyncPlay;
    if (override != null) return override;
    final locator = GetIt.instance;
    if (!locator.isRegistered<SyncPlayGroupCubit>()) return null;
    return locator<SyncPlayGroupCubit>();
  }

  @override
  Future<bool> redirect(
    List<Track> tracks, {
    required int startIndex,
    bool shuffle = false,
    QueueOrigin? origin,
  }) async {
    final group = _group;
    if (group?.state.status == SyncPlayGroupStatus.joined) {
      await group!.playSelection(
        tracks,
        startIndex: startIndex,
        shuffle: shuffle,
        origin: origin,
      );
      return true;
    }
    if (_control.state.isControlling) {
      await _control.playTracks(
        tracks,
        startIndex: startIndex,
        shuffle: shuffle,
        origin: origin,
      );
      return true;
    }
    return false;
  }

  @override
  Future<bool> enqueue(List<Track> tracks, {bool playNext = false}) async {
    if (tracks.isEmpty) return false;
    // A SyncPlay group owns its queue through the server, and this build
    // has no append for it; the group's own queue update path still
    // applies the change here, so local is the honest destination.
    if (_control.state.isControlling) {
      await _control.appendTracks(tracks, playNext: playNext);
      return true;
    }
    return false;
  }
}
