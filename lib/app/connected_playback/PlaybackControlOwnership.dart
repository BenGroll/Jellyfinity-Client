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
  PlaybackControlOwnership(this._control, [this._syncPlay]);

  final PlaybackControlCubit _control;
  final SyncPlayGroupCubit? _syncPlay;

  SyncPlayGroupCubit? get _group {
    if (_syncPlay != null) return _syncPlay;
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
}
