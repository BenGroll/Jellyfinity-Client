import 'package:equatable/equatable.dart';

import 'QueueEntry.dart';
import 'repeat_mode.dart';

/// Jellyfinity's own queue — application state, not state hidden inside
/// [PlaybackEngine] (`CONTEXT.md`). Pure data plus the play-order logic:
/// no engine, no I/O, which is what makes shuffle/repeat/reorder testable
/// without a fake player.
///
/// [entries] is always the user's own order (the order things were added
/// in, or an album's track order) — shuffle never rewrites it. Instead
/// [shuffleOrder] is a separate permutation of indices into [entries],
/// generated whenever shuffle turns on or the entry list changes
/// structurally, and always keeping the current entry first so toggling
/// shuffle mid-track never restarts it. Turning shuffle off simply drops
/// [shuffleOrder]; [entries] was never touched, so nothing needs
/// restoring.
class PlaybackQueue extends Equatable {
  const PlaybackQueue({
    this.entries = const [],
    this.currentIndex,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.shuffleOrder,
  });

  static const PlaybackQueue empty = PlaybackQueue();

  final List<QueueEntry> entries;

  /// Index into [entries] of the current entry, or `null` exactly when
  /// [entries] is empty.
  final int? currentIndex;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  /// Indices into [entries] in actual play order. `null` when shuffle is
  /// off, meaning the play order is [entries]' own order.
  final List<int>? shuffleOrder;

  bool get isEmpty => entries.isEmpty;

  QueueEntry? get currentEntry {
    final index = currentIndex;
    if (index == null || index < 0 || index >= entries.length) return null;
    return entries[index];
  }

  /// [entries]' indices in the order they actually play.
  List<int> get playOrder =>
      shuffleOrder ?? [for (var i = 0; i < entries.length; i++) i];

  /// Entries after the current one, in play order — a queue screen's
  /// "up next".
  List<QueueEntry> get upNext {
    final order = playOrder;
    final index = currentIndex;
    final position = index == null ? -1 : order.indexOf(index);
    if (position < 0) return const [];
    return [for (final i in order.skip(position + 1)) entries[i]];
  }

  /// Replaces the whole queue, starting at [startIndex] — the result of
  /// `playNow`.
  PlaybackQueue withEntries(
    List<QueueEntry> newEntries, {
    required int startIndex,
  }) {
    return PlaybackQueue(
      entries: newEntries,
      currentIndex: newEntries.isEmpty ? null : startIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      shuffleOrder: shuffleEnabled
          ? _shuffled(newEntries.length, pinned: startIndex)
          : null,
    );
  }

  /// Inserts [entry] right after the current one (`Play Next`) or at the
  /// end (`Add to Queue`).
  PlaybackQueue withEntryAdded(QueueEntry entry, {bool playNext = false}) {
    final insertAt = playNext && currentIndex != null
        ? currentIndex! + 1
        : entries.length;
    final newEntries = [
      ...entries.sublist(0, insertAt),
      entry,
      ...entries.sublist(insertAt),
    ];
    final newCurrent = currentIndex == null
        ? 0
        : (insertAt <= currentIndex! ? currentIndex! + 1 : currentIndex);
    return _rebuilt(entries: newEntries, currentIndex: newCurrent);
  }

  /// Removes the entry at [index]. If it was the current entry, the
  /// entry that shifts into its place becomes current (or `null` if that
  /// was the last entry) — `PlaybackCubit` is what decides whether to
  /// actually skip the engine there.
  PlaybackQueue withEntryRemoved(int index) {
    if (index < 0 || index >= entries.length) return this;
    final newEntries = [...entries]..removeAt(index);
    int? newCurrent = currentIndex;
    if (currentIndex != null) {
      if (index < currentIndex!) {
        newCurrent = currentIndex! - 1;
      } else if (index == currentIndex!) {
        newCurrent = newEntries.isEmpty
            ? null
            : currentIndex!.clamp(0, newEntries.length - 1);
      }
    }
    return _rebuilt(entries: newEntries, currentIndex: newCurrent);
  }

  /// Moves the entry at [oldIndex] to [newIndex] (both indices into
  /// [entries], the canonical order — matching `ReorderableListView`'s
  /// own convention).
  PlaybackQueue withReordered(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= entries.length ||
        newIndex < 0 ||
        newIndex >= entries.length) {
      return this;
    }
    final newEntries = [...entries];
    final moved = newEntries.removeAt(oldIndex);
    newEntries.insert(newIndex, moved);

    int? newCurrent = currentIndex;
    if (currentIndex == oldIndex) {
      newCurrent = newIndex;
    } else if (currentIndex != null) {
      if (oldIndex < currentIndex! && newIndex >= currentIndex!) {
        newCurrent = currentIndex! - 1;
      } else if (oldIndex > currentIndex! && newIndex <= currentIndex!) {
        newCurrent = currentIndex! + 1;
      }
    }
    return _rebuilt(entries: newEntries, currentIndex: newCurrent);
  }

  PlaybackQueue withCleared() =>
      PlaybackQueue(shuffleEnabled: shuffleEnabled, repeatMode: repeatMode);

  PlaybackQueue withShuffle(bool enabled) {
    return PlaybackQueue(
      entries: entries,
      currentIndex: currentIndex,
      shuffleEnabled: enabled,
      repeatMode: repeatMode,
      shuffleOrder: enabled
          ? _shuffled(entries.length, pinned: currentIndex)
          : null,
    );
  }

  PlaybackQueue withRepeatMode(RepeatMode mode) => PlaybackQueue(
    entries: entries,
    currentIndex: currentIndex,
    shuffleEnabled: shuffleEnabled,
    repeatMode: mode,
    shuffleOrder: shuffleOrder,
  );

  /// Jumps the current pointer to [index] directly — a tap in the queue
  /// screen. Does not touch [shuffleOrder]: the order still names every
  /// entry, only which one is "current" moves.
  PlaybackQueue withCurrentIndex(int? index) => PlaybackQueue(
    entries: entries,
    currentIndex: index,
    shuffleEnabled: shuffleEnabled,
    repeatMode: repeatMode,
    shuffleOrder: shuffleOrder,
  );

  /// Marks the entry at [index] unavailable in place, for a source
  /// [PlaybackEngine.failureStream] reported. The entry stays in the
  /// queue.
  PlaybackQueue withEntryMarkedUnavailable(int index) {
    if (index < 0 || index >= entries.length) return this;
    final newEntries = [...entries];
    newEntries[index] = newEntries[index].markUnavailable();
    return PlaybackQueue(
      entries: newEntries,
      currentIndex: currentIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      shuffleOrder: shuffleOrder,
    );
  }

  /// The index to play once [currentIndex] finishes, honoring
  /// [repeatMode], or `null` when playback should stop.
  int? nextIndexOnCompletion() {
    final index = currentIndex;
    if (entries.isEmpty || index == null) return null;
    if (repeatMode.repeatsCurrentEntry) return index;

    final order = playOrder;
    final position = order.indexOf(index);
    if (position < 0) return null;
    if (position + 1 < order.length) return order[position + 1];
    return repeatMode == RepeatMode.all && order.isNotEmpty
        ? order.first
        : null;
  }

  /// The entry before [currentIndex] in play order, or `null` at the
  /// start. A position-aware "restart the current track instead" rule
  /// belongs to `PlaybackCubit`, which knows the live playback position;
  /// this is only the queue-order answer.
  int? previousIndex() {
    final index = currentIndex;
    if (entries.isEmpty || index == null) return null;
    final order = playOrder;
    final position = order.indexOf(index);
    if (position <= 0) return null;
    return order[position - 1];
  }

  PlaybackQueue _rebuilt({
    required List<QueueEntry> entries,
    required int? currentIndex,
  }) {
    return PlaybackQueue(
      entries: entries,
      currentIndex: currentIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      shuffleOrder: shuffleEnabled
          ? _shuffled(entries.length, pinned: currentIndex)
          : null,
    );
  }

  static List<int>? _shuffled(int length, {int? pinned}) {
    if (length == 0) return const [];
    final indices = [for (var i = 0; i < length; i++) i]..shuffle();
    if (pinned != null && pinned >= 0 && pinned < length) {
      indices
        ..remove(pinned)
        ..insert(0, pinned);
    }
    return indices;
  }

  @override
  List<Object?> get props => [
    entries,
    currentIndex,
    shuffleEnabled,
    repeatMode,
    shuffleOrder,
  ];
}
