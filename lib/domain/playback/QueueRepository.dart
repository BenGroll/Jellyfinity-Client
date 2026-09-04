import '../../core/result/result.dart';
import 'PlaybackQueue.dart';

/// A saved queue together with how far into the current entry playback
/// had got — [PlaybackQueue] itself has no notion of position, which is a
/// live engine concept, not a queue-structure one.
typedef RestoredQueue = ({PlaybackQueue queue, Duration position});

/// Persisting [PlaybackQueue] across restarts.
///
/// Split into a structural write and a cheap positional one because they
/// happen at very different rates: [replace] runs on every add/remove/
/// reorder/clear, [savePosition] runs on a debounced timer while a track
/// plays. Folding both into one "save the whole queue" call would mean
/// rewriting every queue row every few seconds.
abstract class QueueRepository {
  /// The saved queue and last known position, or an empty queue at
  /// [Duration.zero] if nothing was saved.
  Future<Result<RestoredQueue>> load();

  /// Persists the whole queue — entries, current index, shuffle, repeat.
  Future<Result<void>> replace(PlaybackQueue queue);

  /// Persists just the current index and position, for a queue whose
  /// entries have not changed.
  Future<Result<void>> savePosition({
    required int? currentIndex,
    required Duration position,
  });
}
