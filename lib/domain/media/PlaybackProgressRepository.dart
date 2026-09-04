import '../../core/result/result.dart';
import 'MediaId.dart';
import 'PlaybackProgress.dart';

/// Reading and setting how far the user has got through an item.
///
/// Progress arrives attached to items as they are browsed, so this
/// contract is for the cases where it is needed on its own: refreshing a
/// resume position after playback, marking something played or unplayed
/// from a context menu, and — since v0.0.9 — reporting a live playback
/// session so Jellyfin's own resume/played tracking agrees with what
/// Jellyfinity actually played.
abstract class PlaybackProgressRepository {
  /// The stored progress for [id], or [PlaybackProgress.none] when the
  /// user has never played it.
  Future<Result<PlaybackProgress>> forItem(MediaId id);

  /// Marks [id] as fully played.
  Future<Result<void>> markPlayed(MediaId id);

  /// Clears the played flag and any stored position for [id].
  Future<Result<void>> markUnplayed(MediaId id);

  /// Tells the server [id] has started playing, from position zero.
  /// `PlaybackCubit` calls this once per track, when the engine's
  /// current source changes.
  Future<Result<void>> reportStart(MediaId id);

  /// Reports the live playback position of [id]. Called on a timer while
  /// a track plays, so it must be cheap enough to call every few
  /// seconds.
  Future<Result<void>> reportProgress(
    MediaId id, {
    required Duration position,
    required bool isPaused,
  });

  /// Tells the server playback of [id] ended at [position] — either it
  /// finished, or the user moved on before it did.
  Future<Result<void>> reportStop(MediaId id, {required Duration position});
}
