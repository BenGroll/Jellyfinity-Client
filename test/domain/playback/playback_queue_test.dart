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

    test('repeat one replays the same entry', () {
      final queue = _queueOf([
        'a',
        'b',
      ], startIndex: 0).withRepeatMode(RepeatMode.one);

      expect(queue.nextIndexOnCompletion(), 0);
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

    test('a structural change reshuffles the tail, still pinning current', () {
      final queue = _queueOf([
        'a',
        'b',
        'c',
      ], startIndex: 0).withShuffle(true).withEntryAdded(_entry('d'));

      expect(queue.shuffleOrder!.first, queue.currentIndex);
      expect(queue.shuffleOrder!.toSet(), {0, 1, 2, 3});
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
  });
}
