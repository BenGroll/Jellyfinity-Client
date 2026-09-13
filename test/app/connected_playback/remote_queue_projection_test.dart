import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/connected_playback/RemoteQueueProjection.dart';
import 'package:jellyfinity/app/playback/PlaybackUiState.dart';
import 'package:jellyfinity/domain/connected_playback/ConnectedPlaybackLimits.dart';
import 'package:jellyfinity/domain/connected_playback/RemotePlaybackSnapshot.dart';
import 'package:jellyfinity/domain/connected_playback/StateRevision.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/domain/playback/PlaybackQueue.dart';
import 'package:jellyfinity/domain/playback/QueueEntry.dart';
import 'package:jellyfinity/domain/playback/QueueOrigin.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';

import '../../support/connected_playback/connected_playback_fixtures.dart';

QueueEntry _entry(int i) => QueueEntry(
  id: MediaId(serverId: 's1', itemId: 't$i'),
  title: 'Track $i',
);

PlaybackQueue _queueOf(int count, {int startIndex = 0}) =>
    PlaybackQueue.empty.withEntries([
      for (var i = 0; i < count; i++) _entry(i),
    ], startIndex: startIndex);

RemotePlaybackSnapshot _base() => RemotePlaybackSnapshot.idle(
  scope: testScope,
  sessionId: 'session-local',
  revision: const StateRevision(3),
);

void main() {
  group('apply', () {
    test('carries queue, position and current index straight through', () {
      final queue = _queueOf(3, startIndex: 1);
      final projected = RemoteQueueProjection.apply(
        _base(),
        PlaybackUiState(
          queue: queue,
          status: PlaybackStatus.playing,
          position: const Duration(seconds: 30),
        ),
      );

      expect(projected.queue, hasLength(3));
      expect(projected.queue[1].title, 'Track 1');
      expect(projected.currentIndex, 1);
      expect(projected.status, PlaybackStatus.playing);
      expect(projected.position, const Duration(seconds: 30));
      // Preserved from the snapshot it started from, not reset.
      expect(projected.scope, testScope);
      expect(projected.sessionId, 'session-local');
      expect(projected.revision, const StateRevision(3));
    });

    test('an empty queue has no current index', () {
      final projected = RemoteQueueProjection.apply(
        _base(),
        const PlaybackUiState(),
      );

      expect(projected.queue, isEmpty);
      expect(projected.currentIndex, isNull);
    });

    test('shuffle, repeat and a playlist origin all come from the queue', () {
      const origin = QueueOrigin.playlist(
        playlistId: MediaId(serverId: 's1', itemId: 'playlist-1'),
        name: 'Late Night',
      );
      final queue = _queueOf(
        3,
      ).withShuffle(true).withRepeatMode(RepeatMode.all).withOrigin(origin);

      final projected = RemoteQueueProjection.apply(
        _base(),
        PlaybackUiState(queue: queue),
      );

      expect(projected.shuffleEnabled, isTrue);
      expect(projected.repeatMode, RepeatMode.all);
      expect(projected.originName, 'Late Night');
    });

    test(
      'a queue past the bound is windowed from the current position, not truncated from the start',
      () {
        final size = ConnectedPlaybackLimits.maxQueueEntries + 50;
        final queue = _queueOf(size, startIndex: 30);

        final projected = RemoteQueueProjection.apply(
          _base(),
          PlaybackUiState(queue: queue),
        );

        expect(
          projected.queue,
          hasLength(ConnectedPlaybackLimits.maxQueueEntries),
        );
        // The current entry survives at the front of the window rather
        // than being one of the entries dropped to make room.
        expect(projected.currentIndex, 0);
        expect(projected.queue.first.title, 'Track 30');
        expect(
          projected.queue.last.title,
          'Track ${30 + ConnectedPlaybackLimits.maxQueueEntries - 1}',
        );
      },
    );

    test('a queue exactly at the bound is not windowed', () {
      final queue = _queueOf(
        ConnectedPlaybackLimits.maxQueueEntries,
        startIndex: 5,
      );

      final projected = RemoteQueueProjection.apply(
        _base(),
        PlaybackUiState(queue: queue),
      );

      expect(
        projected.queue,
        hasLength(ConnectedPlaybackLimits.maxQueueEntries),
      );
      expect(projected.currentIndex, 5);
      expect(projected.queue.first.title, 'Track 0');
    });
  });

  group('resolveEntriesIndex', () {
    test('an unbounded queue resolves a window index straight to itself', () {
      final queue = _queueOf(4, startIndex: 0);
      expect(RemoteQueueProjection.resolveEntriesIndex(queue, 2), 2);
    });

    test('a bounded queue resolves relative to the current position', () {
      final size = ConnectedPlaybackLimits.maxQueueEntries + 50;
      final queue = _queueOf(size, startIndex: 30);

      // Window index 0 is "Track 30" (the current entry); index 5 is
      // five tracks further into play order.
      expect(RemoteQueueProjection.resolveEntriesIndex(queue, 0), 30);
      expect(RemoteQueueProjection.resolveEntriesIndex(queue, 5), 35);
    });

    test('an index outside the published window is unresolvable', () {
      final size = ConnectedPlaybackLimits.maxQueueEntries + 50;
      final queue = _queueOf(size, startIndex: 30);

      expect(
        RemoteQueueProjection.resolveEntriesIndex(
          queue,
          ConnectedPlaybackLimits.maxQueueEntries,
        ),
        isNull,
      );
      expect(RemoteQueueProjection.resolveEntriesIndex(queue, -1), isNull);
    });

    test('shuffled play order is respected, not entries order', () {
      final queue = _queueOf(4, startIndex: 0).withShuffle(true);
      final shuffledEntriesIndex = queue.playOrder[1];

      expect(
        RemoteQueueProjection.resolveEntriesIndex(queue, 1),
        shuffledEntriesIndex,
      );
    });
  });
}
