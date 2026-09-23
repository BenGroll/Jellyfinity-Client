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

  /// The same question for a queue addition rather than a selection.
  ///
  /// "Add to queue" while controlling another device means that device's
  /// queue: the one the listener can hear. Editing this device's dormant
  /// queue instead looks from the outside like the button does nothing.
  Future<bool> enqueue(List<Track> tracks, {bool playNext = false});
}
