import '../../core/result/result.dart';
import 'MediaId.dart';
import 'PlaybackProgress.dart';

/// Reading and setting how far the user has got through an item.
///
/// Progress arrives attached to items as they are browsed, so this
/// contract is for the cases where it is needed on its own: refreshing a
/// resume position after playback, and marking something played or
/// unplayed from a context menu.
///
/// Reporting a *position* mid-playback needs a play session and belongs
/// with the player (v0.0.9); it is deliberately not on this interface
/// yet.
abstract class PlaybackProgressRepository {
  /// The stored progress for [id], or [PlaybackProgress.none] when the
  /// user has never played it.
  Future<Result<PlaybackProgress>> forItem(MediaId id);

  /// Marks [id] as fully played.
  Future<Result<void>> markPlayed(MediaId id);

  /// Clears the played flag and any stored position for [id].
  Future<Result<void>> markUnplayed(MediaId id);
}
