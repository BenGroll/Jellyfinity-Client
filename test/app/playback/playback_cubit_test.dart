import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/domain/media/media_availability.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/Track.dart';
import 'package:jellyfinity/domain/playback/CrossfadeSettings.dart';
import 'package:jellyfinity/domain/playback/NormalizationSettings.dart';
import 'package:jellyfinity/domain/playback/PlaybackFailure.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/domain/playback/QueueRepository.dart';
import 'package:jellyfinity/domain/playback/repeat_mode.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';
import 'package:jellyfinity/infrastructure/persistence/database/AppDatabase.dart';
import 'package:jellyfinity/infrastructure/persistence/key_value_store.dart';
import 'package:jellyfinity/infrastructure/persistence/playback/DriftQueueRepository.dart';

import '../../support/playback_fakes.dart';
import '../../support/settings_fakes.dart';
import '../../support/test_database.dart';

Track _track(
  String itemId, {
  String name = 'Track',
  Duration? duration,
  double? normalizationGain,
}) {
  return Track(
    id: MediaId(serverId: 's1', itemId: itemId),
    name: name,
    duration: duration ?? const Duration(minutes: 3),
    normalizationGain: normalizationGain,
  );
}

/// Lets the microtask queue a broadcast stream event was posted to run,
/// so a cubit's stream-subscription callback has had a chance to fire
/// before assertions.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

int _setSourcesCalls(FakePlaybackEngine engine) =>
    engine.calls.where((c) => c.startsWith('setSources')).length;

int _updateSourcesCalls(FakePlaybackEngine engine) =>
    engine.calls.where((c) => c.startsWith('updateSources')).length;

void main() {
  late AppDatabase db;
  late QueueRepository queueRepository;
  late FakePlaybackEngine engine;
  late FakeAudioSourceResolver resolver;
  late RecordingPlaybackProgressRepository progress;
  late SettingsCubit settings;
  late PlaybackCubit cubit;

  setUp(() {
    db = newTestDatabase();
    queueRepository = DriftQueueRepository(db, DriftKeyValueStore(db));
    engine = FakePlaybackEngine();
    resolver = FakeAudioSourceResolver();
    progress = RecordingPlaybackProgressRepository();
    settings = fakeSettingsCubit();
    cubit = PlaybackCubit(
      engine,
      queueRepository,
      resolver,
      progress,
      settings,
    );
  });

  tearDown(() async {
    await cubit.close();
    await settings.close();
    await engine.disposeForTest();
    await db.close();
  });

  group('starting playback', () {
    test('queue controls remain available while playNow is playing', () async {
      final completion = Completer<void>();
      engine.playCompletion = completion;

      final starting = cubit.playNow([_track('a')], startIndex: 0);
      await _pump();
      await cubit.setRepeatMode(RepeatMode.all);

      expect(cubit.state.queue.repeatMode, RepeatMode.all);
      completion.complete();
      await starting;
    });

    test('playNow loads the engine and starts playing', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

      expect(engine.sources, hasLength(2));
      expect(engine.currentIndex, 0);
      expect(engine.playing, isTrue);
      expect(cubit.state.queue.entries, hasLength(2));
      expect(cubit.state.queue.currentIndex, 0);
    });

    test('playNow persists the new queue', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 1);

      final restored = (await queueRepository.load()).valueOrNull!;
      expect(restored.queue.entries, hasLength(2));
      expect(restored.queue.currentIndex, 1);
    });

    test(
      'an unresolvable start track falls back to the next resolvable one',
      () async {
        resolver.unresolvable.add('a');

        await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

        expect(
          cubit.state.queue.entries.first.availability,
          MediaAvailability.remoteUnavailable,
        );
        expect(cubit.state.queue.currentIndex, 1);
        expect(engine.sources, hasLength(1));
        expect(engine.playing, isTrue);
      },
    );

    test(
      "a track's normalization gain is carried onto its PlaybackSource",
      () async {
        await cubit.playNow([
          _track('a', normalizationGain: -4.5),
          _track('b'),
        ], startIndex: 0);

        expect(engine.sources[0].normalizationGain, -4.5);
        expect(engine.sources[1].normalizationGain, isNull);
      },
    );
  });

  group('transport', () {
    test('togglePlayPause pauses and resumes', () async {
      await cubit.playNow([_track('a')], startIndex: 0);
      expect(engine.playing, isTrue);

      await cubit.togglePlayPause();
      expect(engine.playing, isFalse);

      await cubit.togglePlayPause();
      expect(engine.playing, isTrue);
    });

    test('seek delegates straight to the engine', () async {
      await cubit.playNow([_track('a')], startIndex: 0);

      await cubit.seek(const Duration(seconds: 30));

      expect(engine.calls, contains('seek(0:00:30.000000)'));
    });

    test('next moves to the next entry within the loaded window', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

      await cubit.next();

      expect(cubit.state.queue.currentIndex, 1);
      expect(engine.calls, contains('skipToIndex(1)'));
    });

    test('previous restarts the track past the threshold', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 1);
      engine.emitPosition(const Duration(seconds: 10));
      await _pump();

      await cubit.previous();

      expect(
        cubit.state.queue.currentIndex,
        1,
        reason: 'stayed on the same track',
      );
      expect(engine.calls.last, 'seek(0:00:00.000000)');
    });

    test('previous moves back within the first few seconds', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 1);
      engine.emitPosition(const Duration(seconds: 1));
      await _pump();

      await cubit.previous();

      expect(cubit.state.queue.currentIndex, 0);
    });
  });

  group('failure handling', () {
    test(
      'a failed current track is marked unavailable and playback moves on',
      () async {
        await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

        engine.emitFailure(
          PlaybackFailure(
            sourceIndex: 0,
            id: MediaId(serverId: 's1', itemId: 'a'),
            message: 'could not decode',
          ),
        );
        await _pump();

        expect(
          cubit.state.queue.entries,
          hasLength(2),
          reason: 'the queue is not cleared',
        );
        expect(
          cubit.state.queue.entries.first.availability,
          MediaAvailability.remoteUnavailable,
        );
        expect(cubit.state.queue.currentIndex, 1);
        expect(cubit.state.lastFailure?.message, 'could not decode');
        expect(engine.calls, contains('skipToIndex(1)'));
      },
    );

    test('a failure on a track that is not current only marks it', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

      engine.emitFailure(
        PlaybackFailure(
          sourceIndex: 1,
          id: MediaId(serverId: 's1', itemId: 'b'),
          message: 'could not decode',
        ),
      );
      await _pump();

      expect(
        cubit.state.queue.currentIndex,
        0,
        reason: 'still on the first track',
      );
      expect(
        cubit.state.queue.entries[1].availability,
        MediaAvailability.remoteUnavailable,
      );
    });
  });

  group('repeat', () {
    test(
      'transient indices during playlist synchronization do not change the current track',
      () async {
        await cubit.playNow([_track('a'), _track('b')], startIndex: 0);
        engine.indicesToEmitDuringUpdate.add(1);

        await cubit.setRepeatMode(RepeatMode.all);

        expect(cubit.state.queue.currentIndex, 0);
      },
    );

    test('repeat all advances without replacing the engine playlist', () async {
      await cubit.setRepeatMode(RepeatMode.all);
      await cubit.playNow([_track('a'), _track('b')], startIndex: 1);
      final callsBefore = _updateSourcesCalls(engine);

      engine.emitStatus(PlaybackStatus.completed);
      await _pump();

      expect(_updateSourcesCalls(engine), callsBefore);
    });

    test('repeat one replays the same track without rebuilding', () async {
      await cubit.setRepeatMode(RepeatMode.one);
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);
      expect(
        engine.sources,
        hasLength(2),
        reason: 'the full playlist remains loaded',
      );
      final callsBefore = _setSourcesCalls(engine);

      engine.emitStatus(PlaybackStatus.completed);
      await _pump();

      expect(_setSourcesCalls(engine), callsBefore, reason: 'no reload needed');
      expect(engine.calls.last, 'play');
      expect(cubit.state.queue.currentIndex, 0);
    });
  });

  group('cold-start restore', () {
    test('primes the engine at the saved position without playing', () async {
      final started = PlaybackCubit(
        engine,
        queueRepository,
        resolver,
        progress,
        settings,
      );
      await started.playNow([_track('a'), _track('b')], startIndex: 1);
      await queueRepository.savePosition(
        currentIndex: 1,
        position: const Duration(seconds: 45),
      );
      await started.close();

      final freshEngine = FakePlaybackEngine();
      addTearDown(freshEngine.disposeForTest);
      final restoredCubit = PlaybackCubit(
        freshEngine,
        queueRepository,
        resolver,
        progress,
        settings,
      );
      addTearDown(restoredCubit.close);

      await restoredCubit.restore();

      expect(restoredCubit.state.queue.currentIndex, 1);
      expect(restoredCubit.state.position, const Duration(seconds: 45));
      expect(freshEngine.playing, isFalse);
      expect(freshEngine.calls, isNot(contains('play')));
    });

    test('does nothing when nothing was saved', () async {
      await cubit.restore();

      expect(cubit.state.queue.isEmpty, isTrue);
      // Construction configures crossfade (ADR-0016) and normalization
      // (v0.1.4) on the engine; restore itself must not load, play or
      // otherwise touch it.
      expect(
        engine.calls.where(
          (c) =>
              !c.startsWith('setCrossfade') &&
              !c.startsWith('setNormalization'),
        ),
        isEmpty,
      );
    });
  });

  group('queue editing', () {
    test(
      'addToQueue appends and persists without disturbing playback',
      () async {
        await cubit.playNow([_track('a')], startIndex: 0);

        await cubit.addToQueue(_track('b'));

        expect(cubit.state.queue.entries, hasLength(2));
        expect(cubit.state.queue.currentIndex, 0);
        final restored = (await queueRepository.load()).valueOrNull!;
        expect(restored.queue.entries, hasLength(2));
      },
    );

    test('removeAt drops an entry', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

      await cubit.removeAt(1);

      expect(cubit.state.queue.entries, hasLength(1));
    });
  });

  group('streaming quality (ADR-0015)', () {
    test('resolves sources at the settings-selected quality', () async {
      await settings.setStreamQuality(StreamQuality.dataSaver);

      await cubit.playNow([_track('a')], startIndex: 0);

      expect(resolver.requestedQuality['a'], StreamQuality.dataSaver);
    });

    test('a current-track failure at a transcoded quality retries once at '
        'original instead of marking unavailable', () async {
      await settings.setStreamQuality(StreamQuality.high);
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);
      final updateSourcesBefore = _updateSourcesCalls(engine);

      engine.emitFailure(
        PlaybackFailure(
          sourceIndex: 0,
          id: MediaId(serverId: 's1', itemId: 'a'),
          message: 'transcode failed',
        ),
      );
      await _pump();

      expect(
        cubit.state.queue.entries.first.availability,
        isNot(MediaAvailability.remoteUnavailable),
        reason: 'not marked unavailable on the first failure',
      );
      expect(cubit.state.queue.currentIndex, 0, reason: 'still track a');
      expect(resolver.requestedQuality['a'], StreamQuality.original);
      expect(_updateSourcesCalls(engine), updateSourcesBefore + 1);
    });

    test('a second failure after the retry marks the entry unavailable as '
        'usual', () async {
      await settings.setStreamQuality(StreamQuality.high);
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

      engine.emitFailure(
        PlaybackFailure(
          sourceIndex: 0,
          id: MediaId(serverId: 's1', itemId: 'a'),
          message: 'transcode failed',
        ),
      );
      await _pump();
      engine.emitFailure(
        PlaybackFailure(
          sourceIndex: 0,
          id: MediaId(serverId: 's1', itemId: 'a'),
          message: 'still failing at original',
        ),
      );
      await _pump();

      expect(
        cubit.state.queue.entries.first.availability,
        MediaAvailability.remoteUnavailable,
      );
      expect(cubit.state.queue.currentIndex, 1);
    });

    test('a failure while already at original quality marks unavailable '
        'immediately, unchanged from today', () async {
      await cubit.playNow([_track('a'), _track('b')], startIndex: 0);

      engine.emitFailure(
        PlaybackFailure(
          sourceIndex: 0,
          id: MediaId(serverId: 's1', itemId: 'a'),
          message: 'could not decode',
        ),
      );
      await _pump();

      expect(
        cubit.state.queue.entries.first.availability,
        MediaAvailability.remoteUnavailable,
      );
      expect(cubit.state.queue.currentIndex, 1);
    });
  });

  group('crossfade configuration seam (ADR-0016)', () {
    List<String> crossfadeCalls() =>
        engine.calls.where((c) => c.startsWith('setCrossfade')).toList();

    test('the engine is configured from the saved preference at '
        'construction, before anything is queued', () async {
      final saved = fakeSettingsCubit(
        crossfade: const CrossfadeSettings(
          enabled: true,
          duration: Duration(seconds: 7),
        ),
      );
      addTearDown(saved.close);
      final savedEngine = FakePlaybackEngine();
      addTearDown(savedEngine.disposeForTest);
      final savedCubit = PlaybackCubit(
        savedEngine,
        queueRepository,
        resolver,
        progress,
        saved,
      );
      addTearDown(savedCubit.close);
      await _pump();

      expect(savedEngine.crossfade.enabled, isTrue);
      expect(savedEngine.crossfade.duration, const Duration(seconds: 7));
    });

    test('a preference change reaches the engine', () async {
      await settings.setCrossfadeEnabled(true);
      await _pump();

      expect(engine.crossfade.enabled, isTrue);
      expect(engine.crossfade.duration, CrossfadeSettings.defaultDuration);

      await settings.setCrossfadeDuration(const Duration(seconds: 9));
      await _pump();

      expect(engine.crossfade.duration, const Duration(seconds: 9));

      await settings.setCrossfadeEnabled(false);
      await _pump();

      expect(engine.crossfade.enabled, isFalse);
    });

    test(
      'an unrelated settings change does not reconfigure the engine',
      () async {
        final before = crossfadeCalls().length;

        await settings.setStreamQuality(StreamQuality.high);
        await _pump();

        expect(crossfadeCalls(), hasLength(before));
      },
    );

    test('repeat-one suppresses crossfade, and leaving it restores the '
        'preference', () async {
      await settings.setCrossfadeEnabled(true);
      await _pump();
      expect(engine.crossfade.enabled, isTrue);

      // The engine would otherwise start overlapping the next source in
      // the loaded list — which repeat-one never reaches.
      await cubit.setRepeatMode(RepeatMode.one);
      await _pump();
      expect(engine.crossfade.enabled, isFalse);

      await cubit.setRepeatMode(RepeatMode.all);
      await _pump();
      expect(engine.crossfade.enabled, isTrue);
      expect(engine.crossfade.duration, CrossfadeSettings.defaultDuration);
    });

    test('a preference change made during repeat-one is applied when '
        'repeat-one ends, not while it is on', () async {
      await cubit.setRepeatMode(RepeatMode.one);
      await _pump();

      await settings.setCrossfadeEnabled(true);
      await _pump();
      expect(engine.crossfade.enabled, isFalse);

      await cubit.setRepeatMode(RepeatMode.off);
      await _pump();
      expect(engine.crossfade.enabled, isTrue);
    });
  });

  group('normalization configuration seam (v0.1.4)', () {
    List<String> normalizationCalls() =>
        engine.calls.where((c) => c.startsWith('setNormalization')).toList();

    test('the engine is configured from the saved preference at '
        'construction, before anything is queued', () async {
      final saved = fakeSettingsCubit(
        normalization: const NormalizationSettings(enabled: true),
      );
      addTearDown(saved.close);
      final savedEngine = FakePlaybackEngine();
      addTearDown(savedEngine.disposeForTest);
      final savedCubit = PlaybackCubit(
        savedEngine,
        queueRepository,
        resolver,
        progress,
        saved,
      );
      addTearDown(savedCubit.close);
      await _pump();

      expect(savedEngine.normalization.enabled, isTrue);
    });

    test('a preference change reaches the engine', () async {
      await settings.setNormalizationEnabled(true);
      await _pump();

      expect(engine.normalization.enabled, isTrue);

      await settings.setNormalizationEnabled(false);
      await _pump();

      expect(engine.normalization.enabled, isFalse);
    });

    test(
      'an unrelated settings change does not reconfigure the engine',
      () async {
        final before = normalizationCalls().length;

        await settings.setStreamQuality(StreamQuality.high);
        await _pump();

        expect(normalizationCalls(), hasLength(before));
      },
    );

    test(
      'repeat mode does not affect normalization, unlike crossfade',
      () async {
        await settings.setNormalizationEnabled(true);
        await _pump();

        await cubit.setRepeatMode(RepeatMode.one);
        await _pump();

        expect(engine.normalization.enabled, isTrue);
      },
    );
  });
}
