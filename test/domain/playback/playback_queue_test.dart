import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/playback/PlaybackQueue.dart';
import 'package:jellyfinity/domain/playback/QueueEntry.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';

QueueEntry _entry(String itemId) => QueueEntry(
  id: MediaId(serverId: 's1', itemId: itemId),
  title: itemId,
);

PlaybackQueue _queueOf(List<String> ids, {int startIndex = 0}) => PlaybackQueue
    .empty
    .withEntries([for (final id in ids) _entry(id)], startIndex: startIndex);

void main() {
  group('PlaybackQueue — building and reading', () {
    test('an empty queue has no current entry', () {
      expect(PlaybackQueue.empty.isEmpty, isTrue);
      expect(PlaybackQueue.empty.currentEntry, isNull);
      expect(PlaybackQueue.empty.currentIndex, isNull);
    });

    test('withEntries starts at the given index', () {
      final queue = _queueOf(['a', 'b', 'c'], startIndex: 1);

      expect(queue.currentIndex, 1);
      expect(queue.currentEntry!.id.itemId, 'b');
      expect(queue.upNext.map((e) => e.id.itemId), ['c']);
    });

    test('withEntries of an empty list has no current entry', () {
      final queue = PlaybackQueue.empty.withEntries(const [], startIndex: 0);

      expect(queue.isEmpty, isTrue);
      expect(queue.currentIndex, isNull);
    });
  });

  group('PlaybackQueue — add/remove/reorder', () {
    test('Add to Queue appends after the end', () {
      final queue = _queueOf(['a', 'b']).withEntryAdded(_entry('c'));

      expect(queue.entries.map((e) => e.id.itemId), ['a', 'b', 'c']);
      expect(queue.currentIndex, 0);
    });

    test('Play Next inserts right after the current entry', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 1).withEntryAdded(_entry('x'), playNext: true);

      expect(queue.entries.map((e) => e.id.itemId), ['a', 'b', 'x', 'c']);
      expect(queue.currentIndex, 1, reason: 'the current entry did not move');
    });

    test('adding to an empty queue makes the new entry current', () {
      final queue = PlaybackQueue.empty.withEntryAdded(_entry('a'));

      expect(queue.currentIndex, 0);
    });

    test('removing an earlier entry shifts the current index back', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 2).withEntryRemoved(0);

      expect(queue.entries.map((e) => e.id.itemId), ['b', 'c']);
      expect(queue.currentEntry!.id.itemId, 'c');
    });

    test('removing the last remaining entry empties the queue', () {
      final queue = _queueOf(['a']).withEntryRemoved(0);

      expect(queue.isEmpty, isTrue);
      expect(queue.currentIndex, isNull);
    });

    test('removing the playing entry falls back to its neighbor', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 1).withEntryRemoved(1);

      expect(queue.entries.map((e) => e.id.itemId), ['a', 'c']);
      expect(
        queue.currentEntry!.id.itemId,
        'c',
        reason: 'the track that shifted into the removed slot plays next',
      );
    });

    test('reordering keeps the current entry pointed at the same track', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 0).withReordered(0, 2);

      expect(queue.entries.map((e) => e.id.itemId), ['b', 'c', 'a']);
      expect(queue.currentEntry!.id.itemId, 'a');
      expect(queue.currentIndex, 2);
    });

    test('withCleared drops every entry but keeps shuffle/repeat', () {
      final queue = _queueOf([
        'a',
        'b',
      ]).withRepeatMode(RepeatMode.all).withCleared();

      expect(queue.isEmpty, isTrue);
      expect(queue.repeatMode, RepeatMode.all);
    });
  });

  group('PlaybackQueue — completion and repeat', () {
    test('repeat off stops after the last entry', () {
      final queue = _queueOf(['a', 'b'], startIndex: 1);

      expect(queue.nextIndexOnCompletion(), isNull);
    });

    test('repeat all wraps back to the first entry', () {
      final queue = _queueOf([
        'a',
        'b',
      ], startIndex: 1).withRepeatMode(RepeatMode.all);

      expect(queue.nextIndexOnCompletion(), 0);
    });

    test('repeat one replays the same entry on natural completion', () {
      final queue = _queueOf([
        'a',
        'b',
      ], startIndex: 0).withRepeatMode(RepeatMode.one);

      expect(queue.nextIndexOnCompletion(), 0);
    });

    test('repeat one does not block a manual skip past the track', () {
      final queue = _queueOf([
        'a',
        'b',
      ], startIndex: 0).withRepeatMode(RepeatMode.one);

      expect(queue.manualNextIndex(), 1);
    });

    test('an empty queue has nothing to complete into', () {
      expect(PlaybackQueue.empty.nextIndexOnCompletion(), isNull);
    });

    test('previousIndex walks back through play order', () {
      final queue = _queueOf(['a', 'b', 'c'], startIndex: 2);

      expect(queue.previousIndex(), 1);
      expect(queue.withCurrentIndex(0).previousIndex(), isNull);
    });
  });

  group('PlaybackQueue — shuffle', () {
    test('shuffle keeps the current entry first in play order', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
        'd',
        'e',
      ], startIndex: 2).withShuffle(true);

      expect(queue.shuffleOrder!.first, 2);
      expect(queue.shuffleOrder!.toSet(), {0, 1, 2, 3, 4});
      expect(
        queue.currentEntry!.id.itemId,
        'c',
        reason: 'shuffling never restarts the current track',
      );
    });

    test('turning shuffle off restores the entries order untouched', () {
      final shuffled = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 1).withShuffle(true);
      final unshuffled = shuffled.withShuffle(false);

      expect(unshuffled.shuffleOrder, isNull);
      expect(unshuffled.entries.map((e) => e.id.itemId), ['a', 'b', 'c']);
      expect(unshuffled.currentEntry!.id.itemId, 'b');
    });

    test('a structural change keeps every index in the play order', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 0).withShuffle(true).withEntryAdded(_entry('d'));

      expect(queue.shuffleOrder!.first, queue.currentIndex);
      expect(queue.shuffleOrder!.toSet(), {0, 1, 2, 3});
    });
  });

  group('PlaybackQueue — shuffle survives editing (v0.4.1)', () {
    /// A shuffled queue whose play order is fixed, so a test can assert
    /// what an edit does to it rather than what chance did.
    PlaybackQueue shuffled(List<String> ids, List<int> order, {int? current}) =>
        _queueOf(ids, startIndex: current ?? order.first)
            .withShuffle(true)
            .withRestoredShuffleOrder(order);

    List<String> playedOrder(PlaybackQueue queue) => [
      for (final i in queue.playOrder) queue.entries[i].id.itemId,
    ];

    test('adding to the end does not disturb what is already coming up', () {
      final queue = shuffled(['a', 'b', 'c'], [2, 0, 1]);

      final updated = queue.withEntryAdded(_entry('d'));

      expect(playedOrder(updated), ['c', 'a', 'b', 'd']);
      expect(updated.currentEntry!.id.itemId, 'c');
    });

    test('Play Next means next in play order, not next in the list', () {
      final queue = shuffled(['a', 'b', 'c'], [2, 0, 1]);

      final updated = queue.withEntryAdded(_entry('x'), playNext: true);

      expect(
        playedOrder(updated),
        ['c', 'x', 'a', 'b'],
        reason: 'x plays immediately after the current entry',
      );
      expect(updated.currentEntry!.id.itemId, 'c');
    });

    test('removing an entry leaves the rest in the same play order', () {
      final queue = shuffled(['a', 'b', 'c', 'd'], [2, 0, 3, 1]);

      final updated = queue.withEntryRemoved(0);

      expect(playedOrder(updated), ['c', 'd', 'b']);
      expect(updated.currentEntry!.id.itemId, 'c');
    });

    test('reordering the list does not change what plays next', () {
      final queue = shuffled(['a', 'b', 'c'], [2, 0, 1]);

      final updated = queue.withReordered(0, 2);

      expect(updated.entries.map((e) => e.id.itemId), ['b', 'c', 'a']);
      expect(
        playedOrder(updated),
        ['c', 'a', 'b'],
        reason: 'the user rearranged their own list, not the play order',
      );
      expect(updated.currentEntry!.id.itemId, 'c');
    });

    test('reordering the play order moves it there instead', () {
      final queue = shuffled(['a', 'b', 'c'], [2, 0, 1]);

      final updated = queue.withPlayOrderReordered(2, 1);

      expect(playedOrder(updated), ['c', 'b', 'a']);
      expect(
        updated.entries.map((e) => e.id.itemId),
        ['a', 'b', 'c'],
        reason: "the user's own list is untouched",
      );
    });

    test('with shuffle off a play-order move is an ordinary reorder', () {
      final queue = _queueOf(['a', 'b', 'c']).withPlayOrderReordered(0, 2);

      expect(queue.entries.map((e) => e.id.itemId), ['b', 'c', 'a']);
      expect(queue.currentEntry!.id.itemId, 'a');
    });

    test('a saved order that no longer fits the queue is not used', () {
      final queue = _queueOf(['a', 'b', 'c']).withShuffle(true);

      // Too short, out of range, and a duplicate: each has to be refused
      // in favour of a fresh shuffle rather than produce a play order
      // that skips or repeats an entry.
      for (final bad in [
        <int>[0, 1],
        <int>[0, 1, 7],
        <int>[0, 1, 1],
      ]) {
        final restored = queue.withRestoredShuffleOrder(bad);
        expect(restored.shuffleOrder, hasLength(3));
        expect(restored.shuffleOrder!.toSet(), {0, 1, 2});
      }
    });

    test('a saved order is ignored entirely while shuffle is off', () {
      final queue = _queueOf(['a', 'b', 'c']).withRestoredShuffleOrder([2, 1, 0]);

      expect(queue.shuffleOrder, isNull);
      expect(queue.playOrder, [0, 1, 2]);
    });
  });

  group('PlaybackQueue — play-order reading (v0.4.1)', () {
    test('upNextIndices names the entries after the current one', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 0).withShuffle(true).withRestoredShuffleOrder([0, 2, 1]);

      expect(queue.currentPlayPosition, 0);
      expect(queue.upNextIndices, [2, 1]);
      expect(queue.upNext.map((e) => e.id.itemId), ['c', 'b']);
    });

    test('the last entry is the end of the queue with repeat off', () {
      final queue = _queueOf(['a', 'b'], startIndex: 1);

      expect(queue.isAtEndOfPlayOrder, isTrue);
    });

    test('repeat all means there is always something after', () {
      final queue = _queueOf([
        'a',
        'b',
      ], startIndex: 1).withRepeatMode(RepeatMode.all);

      expect(queue.isAtEndOfPlayOrder, isFalse);
    });

    test('an empty queue is not "at the end"', () {
      expect(PlaybackQueue.empty.isAtEndOfPlayOrder, isFalse);
    });
  });

  group('PlaybackQueue — failure handling', () {
    test('a failed entry is marked unavailable and stays in the queue', () {
      final queue = _queueOf(['a', 'b']).withEntryMarkedUnavailable(0);

      expect(queue.entries, hasLength(2));
      expect(
        queue.entries.first.availability,
        MediaAvailability.remoteUnavailable,
      );
      expect(queue.entries.last.availability, MediaAvailability.remoteOnly);
    });

    test('a failed entry carries the reason it failed (v0.4.1)', () {
      final queue = _queueOf([
        'a',
      ], startIndex: 0).withEntryMarkedUnavailable(0, reason: 'Stream ended.');

      expect(queue.entries.first.failureMessage, 'Stream ended.');
    });

    test('marking an entry playable clears the failure (v0.4.1)', () {
      final queue = _queueOf(['a'], startIndex: 0)
          .withEntryMarkedUnavailable(0, reason: 'Stream ended.')
          .withEntryMarkedPlayable(0);

      expect(queue.entries.first.failureMessage, isNull);
      expect(
        queue.entries.first.availability,
        isNot(MediaAvailability.remoteUnavailable),
      );
    });
  });
}
