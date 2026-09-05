import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfinity/app/playback/PlaybackCubit.dart';
import 'package:jellyfinity/app/settings/SettingsCubit.dart';
import 'package:jellyfinity/core/result/failure.dart';
import 'package:jellyfinity/core/result/result.dart';
import 'package:jellyfinity/domain/media/MediaId.dart';
import 'package:jellyfinity/domain/media/PlaybackProgress.dart';
import 'package:jellyfinity/domain/media/PlaybackProgressRepository.dart';
import 'package:jellyfinity/domain/playback/AudioSourceResolver.dart';
import 'package:jellyfinity/domain/playback/PlaybackEngine.dart';
import 'package:jellyfinity/domain/playback/PlaybackFailure.dart';
import 'package:jellyfinity/domain/playback/PlaybackQueue.dart';
import 'package:jellyfinity/domain/playback/PlaybackSource.dart';
import 'package:jellyfinity/domain/playback/playback_status.dart';
import 'package:jellyfinity/domain/playback/QueueRepository.dart';
import 'package:jellyfinity/domain/playback/stream_quality.dart';
import 'package:jellyfinity/domain/playback/TrackSourceInfo.dart';
import 'package:jellyfinity/domain/playback/TrackSourceInfoResolver.dart';
import 'package:jellyfinity/features/playback/presentation/track_source_info_cubit.dart';

import 'settings_fakes.dart';

/// A [PlaybackCubit] wired entirely to fakes, for tests that only need
/// one to exist (e.g. because the widget tree requires it) without
/// driving or asserting on playback itself.
PlaybackCubit fakePlaybackCubit({SettingsCubit? settings}) => PlaybackCubit(
  FakePlaybackEngine(),
  FakeQueueRepository(),
  FakeAudioSourceResolver(),
  RecordingPlaybackProgressRepository(),
  settings ?? fakeSettingsCubit(),
);

/// A [PlaybackEngine] a test can both drive (call the transport methods
/// on) and steer (push stream events as if the real engine produced
/// them), so `PlaybackCubit` can be tested without `just_audio` or
/// `audio_service`, neither of which run outside a real device.
class FakePlaybackEngine implements PlaybackEngine {
  final StreamController<PlaybackStatus> _statusController =
      StreamController.broadcast();
  final StreamController<Duration> _positionController =
      StreamController.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController.broadcast();
  final StreamController<int?> _currentIndexController =
      StreamController.broadcast();
  final StreamController<PlaybackFailure> _failureController =
      StreamController.broadcast();

  /// The list most recently given to [setSources].
  List<PlaybackSource> sources = const [];
  int? currentIndex;
  bool playing = false;
  Completer<void>? playCompletion;
  final List<int?> indicesToEmitDuringUpdate = [];

  /// Every call made, in the order they arrived — for asserting exactly
  /// what the cubit told the engine to do.
  final List<String> calls = [];

  @override
  Future<void> setSources(
    List<PlaybackSource> sources, {
    required int initialIndex,
    Duration? initialPosition,
  }) async {
    this.sources = sources;
    currentIndex = sources.isEmpty ? null : initialIndex;
    calls.add('setSources(${sources.length}, initialIndex: $initialIndex)');
    _currentIndexController.add(currentIndex);
  }

  @override
  Future<void> updateSources(
    List<PlaybackSource> sources, {
    required int initialIndex,
    Duration? initialPosition,
    required bool resumePlaying,
  }) async {
    this.sources = sources;
    currentIndex = sources.isEmpty ? null : initialIndex;
    calls.add('updateSources(${sources.length}, initialIndex: $initialIndex)');
    _currentIndexController.add(currentIndex);
    for (final index in indicesToEmitDuringUpdate) {
      _currentIndexController.add(index);
    }
    if (resumePlaying && !playing) await play();
  }

  @override
  Future<void> play() async {
    playing = true;
    calls.add('play');
    _statusController.add(PlaybackStatus.playing);
    await playCompletion?.future;
  }

  @override
  Future<void> pause() async {
    playing = false;
    calls.add('pause');
    _statusController.add(PlaybackStatus.paused);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek($position)');
    _positionController.add(position);
  }

  @override
  Future<void> skipToIndex(int index, {Duration? position}) async {
    calls.add('skipToIndex($index)');
    currentIndex = index;
    _currentIndexController.add(index);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = false;
    sources = const [];
    currentIndex = null;
    _statusController.add(PlaybackStatus.idle);
  }

  @override
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Stream<PlaybackFailure> get failureStream => _failureController.stream;

  // ---- Steering: simulate events the real engine would produce ----

  void emitStatus(PlaybackStatus status) => _statusController.add(status);

  void emitPosition(Duration position) => _positionController.add(position);

  void emitDuration(Duration? duration) => _durationController.add(duration);

  /// Simulates the engine advancing on its own — a natural gapless
  /// transition, or a system next/previous press.
  void emitCurrentIndex(int? index) {
    currentIndex = index;
    _currentIndexController.add(index);
  }

  void emitFailure(PlaybackFailure failure) => _failureController.add(failure);

  Future<void> disposeForTest() async {
    await _statusController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentIndexController.close();
    await _failureController.close();
  }
}

/// An [AudioSourceResolver] whose failures a test controls.
class FakeAudioSourceResolver implements AudioSourceResolver {
  /// Item ids that resolve as [UnavailableFailure] instead of a URL.
  final Set<String> unresolvable = {};

  /// The quality most recently requested for each item id — lets a test
  /// assert `PlaybackCubit` asked for the settings-selected quality (or
  /// the retry-at-original override) without inspecting the built URL.
  final Map<String, StreamQuality> requestedQuality = {};

  @override
  Future<Result<Uri>> resolve(
    MediaId id, {
    StreamQuality quality = StreamQuality.original,
  }) async {
    requestedQuality[id.itemId] = quality;
    if (unresolvable.contains(id.itemId)) {
      return const Result.err(UnavailableFailure('Could not resolve.'));
    }
    return Result.ok(
      Uri.parse('https://media.example.com/Audio/${id.itemId}/stream'),
    );
  }
}

/// An in-memory [QueueRepository] — no database — for widget/navigation
/// tests that need `PlaybackCubit` wired up but do not care about
/// persistence specifics (those are covered by
/// `drift_queue_repository_test`).
class FakeQueueRepository implements QueueRepository {
  PlaybackQueue queue = PlaybackQueue.empty;
  Duration position = Duration.zero;

  @override
  Future<Result<RestoredQueue>> load() async =>
      Result.ok((queue: queue, position: position));

  @override
  Future<Result<void>> replace(PlaybackQueue queue) async {
    this.queue = queue;
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> savePosition({
    required int? currentIndex,
    required Duration position,
  }) async {
    this.position = position;
    return const Result.ok(null);
  }
}

/// A [PlaybackProgressRepository] that records every session-reporting
/// call instead of making one.
class RecordingPlaybackProgressRepository
    implements PlaybackProgressRepository {
  final List<MediaId> started = [];
  final List<({MediaId id, Duration position, bool isPaused})> progressed = [];
  final List<({MediaId id, Duration position})> stopped = [];

  @override
  Future<Result<PlaybackProgress>> forItem(MediaId id) async =>
      const Result.ok(PlaybackProgress.none);

  @override
  Future<Result<void>> markPlayed(MediaId id) async => const Result.ok(null);

  @override
  Future<Result<void>> markUnplayed(MediaId id) async => const Result.ok(null);

  @override
  Future<Result<void>> reportStart(MediaId id) async {
    started.add(id);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> reportProgress(
    MediaId id, {
    required Duration position,
    required bool isPaused,
  }) async {
    progressed.add((id: id, position: position, isPaused: isPaused));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> reportStop(
    MediaId id, {
    required Duration position,
  }) async {
    stopped.add((id: id, position: position));
    return const Result.ok(null);
  }
}

/// A [TrackSourceInfoResolver] whose answer a test controls — defaults to
/// "unavailable" so Now Playing's source-quality hint (ADR-0015) simply
/// stays hidden for tests that don't care about it.
class FakeTrackSourceInfoResolver implements TrackSourceInfoResolver {
  Result<TrackSourceInfo> Function(MediaId id) answer = (_) =>
      const Result.err(UnavailableFailure('No source info.'));

  @override
  Future<Result<TrackSourceInfo>> resolve(MediaId id) async => answer(id);
}

/// Registers a fake [TrackSourceInfoCubit] factory into the real `getIt`,
/// the way `registerMusicCubits` does for the music detail cubits —
/// `NowPlayingPage` reads this via `getIt` directly (it is a root route
/// the router constructs with no constructor args), so any test that can
/// reach Now Playing needs this registered first. [pumpApp] calls it by
/// default; pass [resolver] to control what the hint shows.
void registerTrackSourceInfoCubit({TrackSourceInfoResolver? resolver}) {
  final getIt = GetIt.instance;
  final effectiveResolver = resolver ?? FakeTrackSourceInfoResolver();
  getIt.registerFactory<TrackSourceInfoCubit>(
    () => TrackSourceInfoCubit(effectiveResolver),
  );
  addTearDown(getIt.reset);
}
