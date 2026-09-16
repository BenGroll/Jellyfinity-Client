import '../media/Track.dart';
import '../playback/QueueOrigin.dart';

/// The narrow playback-selection seam used by [PlaybackCubit].
///
/// The app-layer implementation may consume a selection for a SyncPlay
/// group or a controlled peer. Returning `true` means the selection was
/// consumed remotely and [PlaybackCubit] must not also start local audio;
/// `false` preserves ordinary local playback.
abstract class RemotePlaybackOwnership {
  Future<bool> redirect(
    List<Track> tracks, {
    required int startIndex,
    bool shuffle = false,
    QueueOrigin? origin,
  });
}
