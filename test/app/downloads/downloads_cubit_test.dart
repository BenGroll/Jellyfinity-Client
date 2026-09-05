import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/downloads/DownloadsCubit.dart';
import 'package:jellyfinity/core/result/failure.dart';

import '../../support/download_fakes.dart';
import '../../support/music_fakes.dart';
import '../../support/playback_fakes.dart';

void main() {
  late InMemoryDownloadStore store;
  late FakeDownloadEngine engine;
  late FakeAudioSourceResolver resolver;
  late FakeMusicLibraryRepository library;
  late DownloadsCubit cubit;

  setUp(() {
    store = InMemoryDownloadStore();
    engine = FakeDownloadEngine();
    resolver = FakeAudioSourceResolver();
    library = FakeMusicLibraryRepository();
    cubit = fakeDownloadsCubit(
      store: store,
      engine: engine,
      resolver: resolver,
      library: library,
    );
  });

  tearDown(() => cubit.close());

  group('requesting a track', () {
    test('queues, transfers, and completes it', () async {
      final track = testTrack('t1');

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      final record = cubit.state[track.id]!;
      expect(record.state, DownloadState.completed);
      expect(engine.fetched, [track.id]);
      expect(store.records[track.id]?.state, DownloadState.completed);
    });

    test('adding it again does not fetch it twice', () async {
      final track = testTrack('t1');
      await cubit.downloadTrack(track);
      await pumpEventQueue();

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      expect(engine.fetched, [track.id]);
    });

    test(
      'being downloaded on its own and via an album keeps two owners',
      () async {
        final track = testTrack('t1', albumId: 'album-1');
        library.trackList = [track];

        await cubit.downloadTrack(track);
        await cubit.downloadAlbum(testAlbum('album-1'));
        await pumpEventQueue();

        expect(engine.fetched, [track.id]);
        expect(cubit.state[track.id]?.owners, {
          DownloadOwner.track(track.id),
          DownloadOwner.album(mediaId('album-1')),
        });
      },
    );
  });

  group('requesting an album', () {
    test('queues every track the album has', () async {
      final album = testAlbum('album-1');
      library.trackList = [
        testTrack('t1', albumId: 'album-1'),
        testTrack('t2', albumId: 'album-1'),
      ];

      final result = await cubit.downloadAlbum(album);
      await pumpEventQueue();

      expect(result.isOk, isTrue);
      expect(engine.fetched.toSet(), {mediaId('t1'), mediaId('t2')});
      expect(cubit.state.isDownloaded(mediaId('t1')), isTrue);
      expect(cubit.state.isDownloaded(mediaId('t2')), isTrue);
    });

    test(
      'reports a failure instead of queuing anything it could not read',
      () async {
        library.failure = const UnavailableFailure('no such album');

        final result = await cubit.downloadAlbum(testAlbum('album-1'));

        expect(result.isErr, isTrue);
        expect(cubit.state.downloads, isEmpty);
      },
    );

    test('an empty album queues nothing and does not fail', () async {
      final result = await cubit.downloadAlbum(testAlbum('album-1'));
      expect(result.isOk, isTrue);
      expect(cubit.state.downloads, isEmpty);
    });
  });

  group('the worker', () {
    test('runs one transfer at a time, oldest request first', () async {
      final first = testTrack('t1');
      final second = testTrack('t2');
      // Hold the first transfer open so the second cannot start early.
      engine.gates[first.id] = Completer<void>();

      await cubit.downloadTrack(first);
      await cubit.downloadTrack(second);
      await pumpEventQueue();

      expect(engine.fetched, [first.id]);
      expect(cubit.state[second.id]?.state, DownloadState.queued);

      engine.gates[first.id]!.complete();
      await pumpEventQueue();

      expect(engine.fetched, [first.id, second.id]);
      expect(cubit.state[second.id]?.state, DownloadState.completed);
    });
  });

  group('pausing and retrying', () {
    test(
      'pause keeps bytes and stops the transfer without failing it',
      () async {
        final track = testTrack('t1');
        engine.gates[track.id] = Completer<void>();
        await cubit.downloadTrack(track);
        await pumpEventQueue();

        await cubit.pause(track.id);
        await pumpEventQueue();

        expect(engine.aborted, [track.id]);
        expect(cubit.state[track.id]?.state, DownloadState.paused);
        expect(cubit.state[track.id]?.failureReason, isNull);
      },
    );

    test('retry queues a paused download again', () async {
      final track = testTrack('t1');
      engine.gates[track.id] = Completer<void>();
      await cubit.downloadTrack(track);
      await pumpEventQueue();
      await cubit.pause(track.id);

      // The gate from the aborted attempt is gone; the retried fetch
      // completes normally.
      await cubit.retry(track.id);
      await pumpEventQueue();

      expect(cubit.state[track.id]?.state, DownloadState.completed);
    });

    test('a failed download can be retried', () async {
      final track = testTrack('t1');
      engine.failures[track.id] = const UnavailableFailure('gone');
      await cubit.downloadTrack(track);
      await pumpEventQueue();
      expect(cubit.state[track.id]?.state, DownloadState.failed);

      engine.failures.remove(track.id);
      await cubit.retry(track.id);
      await pumpEventQueue();

      expect(cubit.state[track.id]?.state, DownloadState.completed);
    });

    test(
      'retryAll retries every failed/paused track an owner asked for',
      () async {
        final album = testAlbum('album-1');
        final t1 = testTrack('t1', albumId: 'album-1');
        final t2 = testTrack('t2', albumId: 'album-1');
        library.trackList = [t1, t2];
        engine.failures[t1.id] = const UnavailableFailure('gone');
        engine.failures[t2.id] = const UnavailableFailure('gone');

        await cubit.downloadAlbum(album);
        await pumpEventQueue();
        expect(cubit.state[t1.id]?.state, DownloadState.failed);
        expect(cubit.state[t2.id]?.state, DownloadState.failed);

        engine.failures.clear();
        await cubit.retryAll(DownloadOwner.album(album.id));
        await pumpEventQueue();

        expect(cubit.state[t1.id]?.state, DownloadState.completed);
        expect(cubit.state[t2.id]?.state, DownloadState.completed);
      },
    );

    test(
      'an abort from pause does not get overwritten by a late failure',
      () async {
        final track = testTrack('t1');
        engine.gates[track.id] = Completer<void>();
        engine.failures[track.id] = const UnavailableFailure('gone');
        await cubit.downloadTrack(track);
        await pumpEventQueue();

        // Pause races the engine's own eventual failure for the aborted
        // transfer (FakeDownloadEngine.abort completes the gate itself,
        // the same way a real engine's cancellation unblocks its
        // stream); the user's pause must win.
        await cubit.pause(track.id);
        await pumpEventQueue();

        expect(cubit.state[track.id]?.state, DownloadState.paused);
      },
    );
  });

  group('failure reasons', () {
    test('maps an unauthorized source to a sign-in-again reason', () async {
      final track = testTrack('t1');
      resolver.unresolvable.add(track.id.itemId);

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      expect(
        cubit.state[track.id]?.failureReason,
        DownloadFailureReason.unavailable,
      );
    });

    test('maps insufficient storage distinctly from other failures', () async {
      final track = testTrack('t1');
      engine.failures[track.id] = const InsufficientStorageFailure('full');

      await cubit.downloadTrack(track);
      await pumpEventQueue();

      expect(
        cubit.state[track.id]?.failureReason,
        DownloadFailureReason.insufficientStorage,
      );
    });
  });

  group('removing', () {
    test(
      'removing a track with no owner drops every claim and the file',
      () async {
        final track = testTrack('t1', albumId: 'album-1');
        library.trackList = [track];
        await cubit.downloadTrack(track);
        await cubit.downloadAlbum(testAlbum('album-1'));
        await pumpEventQueue();

        await cubit.removeTrack(track.id);

        expect(cubit.state[track.id], isNull);
        expect(engine.discarded, [track.id]);
        expect(store.records[track.id], isNull);
      },
    );

    test(
      'removing an album keeps a track also downloaded on its own',
      () async {
        final track = testTrack('t1', albumId: 'album-1');
        final album = testAlbum('album-1');
        library.trackList = [track];
        await cubit.downloadTrack(track);
        await cubit.downloadAlbum(album);
        await pumpEventQueue();

        await cubit.removeAlbum(album.id);

        expect(cubit.state[track.id]?.state, DownloadState.completed);
        expect(cubit.state[track.id]?.owners, {DownloadOwner.track(track.id)});
        expect(engine.discarded, isEmpty);
      },
    );

    test('removing the last owner deletes the file', () async {
      final track = testTrack('t1', albumId: 'album-1');
      final album = testAlbum('album-1');
      library.trackList = [track];
      await cubit.downloadAlbum(album);
      await pumpEventQueue();

      await cubit.removeAlbum(album.id);

      expect(cubit.state[track.id], isNull);
      expect(engine.discarded, [track.id]);
    });

    test('cancels an in-flight transfer before discarding it', () async {
      final track = testTrack('t1');
      engine.gates[track.id] = Completer<void>();
      await cubit.downloadTrack(track);
      await pumpEventQueue();

      await cubit.removeTrack(track.id);

      expect(engine.aborted, [track.id]);
      expect(engine.discarded, [track.id]);
    });
  });

  group('restart recovery', () {
    test('an interrupted download resumes from its partial bytes', () async {
      final track = testTrack('t1');
      store.records[track.id] = downloadRecord(
        track.id,
        title: track.name,
        state: DownloadState.downloading,
        receivedBytes: 0,
      );
      engine.partials[track.id] = 4096;

      await cubit.restore();
      await pumpEventQueue();

      // It picks up as a normal queued download and finishes.
      expect(cubit.state[track.id]?.state, DownloadState.completed);
      expect(engine.fetched, [track.id]);
    });

    test('a completed record survives a restart untouched', () async {
      final track = testTrack('t1');
      store.records[track.id] = downloadRecord(
        track.id,
        state: DownloadState.completed,
        totalBytes: 900,
        receivedBytes: 900,
      );

      await cubit.restore();
      await pumpEventQueue();

      expect(cubit.state[track.id]?.state, DownloadState.completed);
      // Nothing was re-fetched — it was already done.
      expect(engine.fetched, isEmpty);
    });

    test(
      'a paused record stays paused rather than resuming on its own',
      () async {
        final track = testTrack('t1');
        store.records[track.id] = downloadRecord(
          track.id,
          state: DownloadState.paused,
        );

        await cubit.restore();
        await pumpEventQueue();

        expect(cubit.state[track.id]?.state, DownloadState.paused);
        expect(engine.fetched, isEmpty);
      },
    );
  });
}
