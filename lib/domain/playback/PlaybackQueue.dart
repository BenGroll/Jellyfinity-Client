import 'package:equatable/equatable.dart';

import 'QueueEntry.dart';
import 'QueueOrigin.dart';
import 'repeat_mode.dart';

/// Jellyfinity's own queue — application state, not state hidden inside
/// [PlaybackEngine] (`CONTEXT.md`). Pure data plus the play-order logic:
/// no engine, no I/O, which is what makes shuffle/repeat/reorder testable
/// without a fake player.
///
/// [entries] is always the user's own order (the order things were added
/// in, or an album's track order) — shuffle never rewrites it. Instead
/// [shuffleOrder] is a separate permutation of indices into [entries],
/// generated when shuffle turns on and keeping the current entry first so
/// toggling shuffle mid-track never restarts it. Turning shuffle off
/// simply drops [shuffleOrder]; [entries] was never touched, so nothing
/// needs restoring.
///
/// A structural edit *amends* [shuffleOrder] rather than regenerating it
/// (v0.4.1). Rebuilding it meant adding one track re-shuffled everything
/// the listener had not heard yet, and made "play next" land the track
/// wherever the new permutation happened to put it. Every edit below
/// therefore states what it does to play order, and the only thing that
/// reshuffles is [withShuffle].
class PlaybackQueue extends Equatable {
  const PlaybackQueue({
    this.entries = const [],
    this.currentIndex,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.shuffleOrder,
    this.origin,
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

  /// The playlist this queue was started from, or `null` — see
  /// [QueueOrigin] (v0.4.2).
  ///
  /// Set by whatever built the queue and carried through every edit: a
  /// listener who queues one extra song is still listening to the
  /// playlist they started. Only replacing the queue ([withEntries]) or
  /// clearing it ([withCleared]) ends it.
  final QueueOrigin? origin;

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
  List<QueueEntry> get upNext => [for (final i in upNextIndices) entries[i]];

  /// The same entries as [upNext], as indices into [entries].
  ///
  /// A queue screen needs the indices, not just the entries: removing or
  /// reordering a row names it by its position in [entries], while what
  /// the user is looking at is play order. Under shuffle the two differ,
  /// and a duplicate track makes `indexOf` the wrong way to recover one
  /// from the other.
  List<int> get upNextIndices {
    final position = currentPlayPosition;
    if (position < 0) return const [];
    return playOrder.skip(position + 1).toList();
  }

  /// Where [currentIndex] sits in [playOrder], or `-1` when there is no
  /// current entry. This is the position a queue screen counts from.
  int get currentPlayPosition {
    final index = currentIndex;
    if (index == null) return -1;
    return playOrder.indexOf(index);
  }

  /// Whether the current entry is the last one that will play — nothing
  /// follows it, and [repeatMode] will not send playback back to the
  /// start. What a queue screen says "End of queue" under, instead of
  /// leaving the user to discover it when the music simply stops.
  bool get isAtEndOfPlayOrder {
    if (entries.isEmpty || currentIndex == null) return false;
    return manualNextIndex() == null;
  }

  /// Replaces the whole queue, starting at [startIndex] — the result of
  /// `playNow`.
  ///
  /// [origin] replaces the old queue's outright, including with `null`:
  /// the queue that was playing is gone, and so is whatever it was
  /// started from.
  PlaybackQueue withEntries(
    List<QueueEntry> newEntries, {
    required int startIndex,
    QueueOrigin? origin,
  }) {
    return PlaybackQueue(
      entries: newEntries,
      currentIndex: newEntries.isEmpty ? null : startIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      shuffleOrder: shuffleEnabled
          ? _shuffled(newEntries.length, pinned: startIndex)
          : null,
      origin: origin,
    );
  }

  /// Inserts [entry] right after the current one (`Play Next`) or at the
  /// end (`Add to Queue`).
  ///
  /// Under shuffle both mean their *play-order* position, not their
  /// position in [entries]: "play next" that dropped the track somewhere
  /// in the canonical order and left the shuffled order to decide when it
  /// actually plays would not be play-next at all. [shuffleOrder] is
  /// therefore amended in place rather than regenerated — everything the
  /// user has not heard yet stays in the order they were already
  /// promised (v0.4.1).
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

    final order = shuffleOrder;
    List<int>? newOrder;
    if (order != null) {
      // Every index at or past the insertion point moved up one.
      final shifted = [for (final i in order) i >= insertAt ? i + 1 : i];
      final playPosition = playNext && newCurrent != null
          ? shifted.indexOf(newCurrent) + 1
          : shifted.length;
      newOrder = [...shifted]
        ..insert(playPosition.clamp(0, shifted.length), insertAt);
    }
    return _with(
      entries: newEntries,
      currentIndex: newCurrent,
      shuffleOrder: newOrder,
    );
  }

  /// Removes the entry at [index]. If it was the current entry, the
  /// entry that shifts into its place becomes current (or `null` if that
  /// was the last entry) — `PlaybackCubit` is what decides whether to
  /// actually skip the engine there.
  ///
  /// The removed index simply drops out of [shuffleOrder]; the rest keep
  /// the play order they had, so removing one track never re-shuffles the
  /// others (v0.4.1).
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

    final order = shuffleOrder;
    final newOrder = order == null
        ? null
        : [
            for (final i in order)
              if (i != index) i > index ? i - 1 : i,
          ];
    return _with(
      entries: newEntries,
      currentIndex: newCurrent,
      shuffleOrder: newOrder,
    );
  }

  /// Moves the entry at [oldIndex] to [newIndex] (both indices into
  /// [entries], the canonical order — matching `ReorderableListView`'s
  /// own convention).
  ///
  /// Play order is deliberately *unchanged* under shuffle: this reorders
  /// the user's own list, and [shuffleOrder] is remapped onto the new
  /// indices so exactly the same entries still play in exactly the same
  /// sequence. Reordering what plays next is [withPlayOrderReordered].
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

    int remap(int index) {
      if (index == oldIndex) return newIndex;
      final afterRemoval = index > oldIndex ? index - 1 : index;
      return afterRemoval >= newIndex ? afterRemoval + 1 : afterRemoval;
    }

    final order = shuffleOrder;
    return _with(
      entries: newEntries,
      currentIndex: currentIndex == null ? null : remap(currentIndex!),
      shuffleOrder: order == null ? null : [for (final i in order) remap(i)],
    );
  }

  /// Moves the entry at play-order position [oldPosition] to
  /// [newPosition] — a drag on a queue screen, which shows play order
  /// rather than [entries]' order (v0.4.1).
  ///
  /// With shuffle off the two orders are the same thing and this is
  /// [withReordered]. With shuffle on only [shuffleOrder] moves: the
  /// user's own list is not what they were rearranging.
  PlaybackQueue withPlayOrderReordered(int oldPosition, int newPosition) {
    final order = shuffleOrder;
    if (order == null) return withReordered(oldPosition, newPosition);
    if (oldPosition == newPosition ||
        oldPosition < 0 ||
        oldPosition >= order.length ||
        newPosition < 0 ||
        newPosition >= order.length) {
      return this;
    }
    final newOrder = [...order];
    newOrder.insert(newPosition, newOrder.removeAt(oldPosition));
    return _with(
      entries: entries,
      currentIndex: currentIndex,
      shuffleOrder: newOrder,
    );
  }

  /// Empties the queue. The [origin] goes with it: there is no longer a
  /// playlist session to be in the middle of.
  PlaybackQueue withCleared() =>
      PlaybackQueue(shuffleEnabled: shuffleEnabled, repeatMode: repeatMode);

  /// Turns shuffle on — generating a fresh play order pinned to the
  /// current entry — or off, dropping [shuffleOrder] entirely.
  ///
  /// This is the *only* thing that reshuffles. Every structural edit
  /// amends the existing order instead (v0.4.1), so the one way a
  /// listener's up-next list gets rearranged under them is their own
  /// press of the shuffle button.
  PlaybackQueue withShuffle(bool enabled) {
    return PlaybackQueue(
      entries: entries,
      currentIndex: currentIndex,
      shuffleEnabled: enabled,
      repeatMode: repeatMode,
      shuffleOrder: enabled
          ? _shuffled(entries.length, pinned: currentIndex)
          : null,
      origin: origin,
    );
  }

  /// This queue with [origin] as what it was started from (v0.4.2) — how
  /// a restored queue gets its remembered playlist back, and `null` for
  /// one that was not started from a playlist.
  PlaybackQueue withOrigin(QueueOrigin? origin) => PlaybackQueue(
    entries: entries,
    currentIndex: currentIndex,
    shuffleEnabled: shuffleEnabled,
    repeatMode: repeatMode,
    shuffleOrder: shuffleOrder,
    origin: origin,
  );

  /// Restores a previously saved shuffle order (v0.4.1), instead of
  /// generating a new one the way [withShuffle] does.
  ///
  /// [order] is accepted only when it is a genuine permutation of every
  /// index in [entries]; anything else — a saved order from a queue that
  /// has since changed, a truncated or corrupt row — falls back to a
  /// fresh shuffle rather than to a play order that would skip or repeat
  /// entries. Ignored entirely when shuffle is off.
  PlaybackQueue withRestoredShuffleOrder(List<int>? order) {
    if (!shuffleEnabled) return this;
    if (!_isPermutationOfEntries(order)) return this;
    return PlaybackQueue(
      entries: entries,
      currentIndex: currentIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      shuffleOrder: List<int>.unmodifiable(order!),
      origin: origin,
    );
  }

  bool _isPermutationOfEntries(List<int>? order) {
    if (order == null || order.length != entries.length) return false;
    final seen = <int>{};
    for (final index in order) {
      if (index < 0 || index >= entries.length) return false;
      if (!seen.add(index)) return false;
    }
    return true;
  }

  PlaybackQueue withRepeatMode(RepeatMode mode) => PlaybackQueue(
    entries: entries,
    currentIndex: currentIndex,
    shuffleEnabled: shuffleEnabled,
    repeatMode: mode,
    shuffleOrder: shuffleOrder,
    origin: origin,
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
    origin: origin,
  );

  /// Marks the entry at [index] unavailable in place, for a source
  /// [PlaybackEngine.failureStream] reported, carrying [reason] as the
  /// explanation the queue screen shows (v0.4.1). The entry stays in the
  /// queue.
  PlaybackQueue withEntryMarkedUnavailable(int index, {String? reason}) =>
      _withEntryAt(index, (entry) => entry.markUnavailable(reason: reason));

  /// Clears the entry at [index]'s failure mark — it just played
  /// (v0.4.1), so whatever stopped it last time no longer applies.
  PlaybackQueue withEntryMarkedPlayable(int index) =>
      _withEntryAt(index, (entry) => entry.markPlayable());

  PlaybackQueue _withEntryAt(
    int index,
    QueueEntry Function(QueueEntry entry) transform,
  ) {
    if (index < 0 || index >= entries.length) return this;
    final updated = transform(entries[index]);
    if (updated == entries[index]) return this;
    final newEntries = [...entries];
    newEntries[index] = updated;
    return PlaybackQueue(
      entries: newEntries,
      currentIndex: currentIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      shuffleOrder: shuffleOrder,
      origin: origin,
    );
  }

  /// The index to play once [currentIndex] finishes, honoring
  /// [repeatMode], or `null` when playback should stop.
  int? nextIndexOnCompletion() {
    if (repeatMode.repeatsCurrentEntry) return currentIndex;
    return manualNextIndex();
  }

  /// The index a manual "skip forward" moves to — always the next entry
  /// in play order (wrapping under [RepeatMode.all]), even under
  /// [RepeatMode.one]: repeating the current track only applies when it
  /// finishes on its own, never to an explicit skip past it.
  int? manualNextIndex() {
    final index = currentIndex;
    if (entries.isEmpty || index == null) return null;
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

  /// This queue's settings carried onto an edited entry list.
  ///
  /// [shuffleOrder] is passed in by each edit rather than regenerated
  /// here (v0.4.1) — the caller is what knows how the edit moved play
  /// order. A shuffled queue whose caller could not produce a valid order
  /// falls back to a fresh shuffle rather than to a broken one.
  PlaybackQueue _with({
    required List<QueueEntry> entries,
    required int? currentIndex,
    required List<int>? shuffleOrder,
  }) {
    final rebuilt = PlaybackQueue(
      entries: entries,
      currentIndex: currentIndex,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
      shuffleOrder: shuffleEnabled ? shuffleOrder : null,
      origin: origin,
    );
    if (shuffleEnabled && !rebuilt._isPermutationOfEntries(shuffleOrder)) {
      return rebuilt.withShuffle(true);
    }
    return rebuilt;
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
    origin,
  ];
}
