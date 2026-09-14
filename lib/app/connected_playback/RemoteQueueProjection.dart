import 'dart:math' as math;

import '../../domain/connected_playback/ConnectedPlaybackLimits.dart';
import '../../domain/connected_playback/RemotePlaybackSnapshot.dart';
import '../../domain/connected_playback/RemoteQueueEntry.dart';
import '../../domain/playback/PlaybackQueue.dart';
import '../playback/PlaybackUiState.dart';

/// Translates between `PlaybackCubit`'s own queue model and the bounded,
/// revisioned projection a target publishes (v0.5.3).
///
/// [PlaybackQueue.playOrder] is unbounded — `CONTEXT.md` treats a queue
/// built from "play all songs" as normal, and nothing here may forget
/// that. [RemotePlaybackSnapshot.queue] must stay under
/// [ConnectedPlaybackLimits.maxPayloadBytes] once encoded, so an
/// oversized queue is windowed rather than sent whole and silently
/// dropped by the receiver's own size guard.
///
/// The window always starts at the current play position when trimming is
/// needed — a remote control's job is "what's playing and what's next",
/// not a full history — which is also why the trimmed snapshot's
/// `currentIndex` is always `0`. [apply] and [resolveEntriesIndex] must
/// agree on exactly this rule, because a `jumpToQueueEntry` command names
/// a position in the *last published* window and has to be resolved back
/// against the same one — see the class-level note on why that is safe.
abstract final class RemoteQueueProjection {
  /// Builds the next published snapshot from `PlaybackCubit`'s current
  /// state, preserving [current]'s scope, session and revision (the
  /// caller bumps the revision — see
  /// `RemotePlaybackTarget.publishLocalChange`).
  static RemotePlaybackSnapshot apply(
    RemotePlaybackSnapshot current,
    PlaybackUiState state,
  ) {
    final queue = state.queue;
    final (window, windowStart) = _window(queue);
    final currentPosition = queue.currentPlayPosition;
    return current.copyWith(
      status: state.status,
      queue: [
        for (final entriesIndex in window)
          RemoteQueueEntry.fromQueueEntry(queue.entries[entriesIndex]),
      ],
      currentIndex: currentPosition < 0 ? null : currentPosition - windowStart,
      clearCurrentIndex: currentPosition < 0,
      position: state.position,
      shuffleEnabled: queue.shuffleEnabled,
      repeatMode: queue.repeatMode,
      originName: queue.origin?.name,
      clearOrigin: queue.origin == null,
      // `copyWith`'s `volume ?? this.volume` already keeps the last known
      // level when this platform hasn't answered yet (or never will) —
      // exactly right here too: a fresh publish with volume still
      // unknown must not overwrite one this target already reported.
      volume: state.systemVolume,
    );
  }

  /// Reverses a `jumpToQueueEntry` command's index — a position in the
  /// window [apply] would publish for [queue] right now — back into an
  /// index of [PlaybackQueue.entries] that `PlaybackCubit.playAt` takes.
  ///
  /// Recomputing the window fresh here rather than remembering the one a
  /// controller actually saw is safe *because* `jumpToQueueEntry` is a
  /// structural command: `RemotePlaybackTarget.process` already refused
  /// it unless the queue's revision still matches what the controller
  /// composed against, and nothing but this command's own execution
  /// changes the local queue between one revision and the next — so the
  /// window a controller was shown is exactly the window this recomputes.
  ///
  /// Returns `null` for an index outside the current window or queue.
  static int? resolveEntriesIndex(PlaybackQueue queue, int windowIndex) {
    if (windowIndex < 0) return null;
    final (window, _) = _window(queue);
    if (windowIndex >= window.length) return null;
    return window[windowIndex];
  }

  /// The play-order indices to publish, and where that window starts in
  /// the real play order — `0` unless the queue exceeds the bound, in
  /// which case the window starts at the current position and only
  /// "up next" survives.
  static (List<int> window, int start) _window(PlaybackQueue queue) {
    final order = queue.playOrder;
    if (order.length <= ConnectedPlaybackLimits.maxQueueEntries) {
      return (order, 0);
    }
    final start = math.max(0, queue.currentPlayPosition);
    final end = math.min(
      order.length,
      start + ConnectedPlaybackLimits.maxQueueEntries,
    );
    return (order.sublist(start, end), start);
  }
}
