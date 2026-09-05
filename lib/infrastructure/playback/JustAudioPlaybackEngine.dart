import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart' as just_audio;

import '../../domain/media/ArtworkResolver.dart';
import '../../domain/playback/PlaybackEngine.dart';
import '../../domain/playback/PlaybackFailure.dart';
import '../../domain/playback/PlaybackSource.dart';
import '../../domain/playback/playback_status.dart';

/// [PlaybackEngine] over `just_audio` + `audio_service` (ADR-0013).
///
/// This class *is* the `audio_service` handler, not a wrapper around one:
/// `BaseAudioHandler` is what `AudioService.init()` needs and the natural
/// owner of the `just_audio` player, so background execution and system
/// media controls are implemented here rather than layered on top.
///
/// It knows nothing about Jellyfinity's queue, shuffle or repeat — it
/// plays exactly the list [setSources] was last given, start to finish,
/// which is what keeps this class the *only* thing that would need
/// replacing to swap engines later (see `PlaybackEngine`'s own doc
/// comment). A lock-screen/headset "next" press is handled the same way:
/// it advances within the current source list via `just_audio`'s own
/// [just_audio.AudioPlayer.seekToNext], and `PlaybackCubit` — which
/// already listens to [currentIndexStream] to stay in sync with every
/// index change, whichever end it comes from — reacts exactly as it
/// would to a `skipToIndex` call it made itself.
///
/// Registered outside the generated DI graph, the same way `AppConfig`
/// is: building a `BaseAudioHandler` requires the async
/// `AudioService.init()` call, which is also guarded to run at most once
/// per process — incompatible with an `@preResolve` DI module step,
/// since `configureDependencies()` runs fresh in every test. `bootstrap()`
/// constructs this and registers the result with `getIt` directly.
class JustAudioPlaybackEngine extends audio_service.BaseAudioHandler
    with audio_service.SeekHandler
    implements PlaybackEngine {
  JustAudioPlaybackEngine(this._artworkResolver) {
    _player.playerStateStream.listen(_broadcastPlaybackState);
    _player.currentIndexStream.listen(_onCurrentIndexChanged);
    _player.errorStream.listen(_onPlayerError);
  }

  final ArtworkResolver _artworkResolver;
  final just_audio.AudioPlayer _player = just_audio.AudioPlayer();

  /// The source list currently mirrored into `just_audio`; indices from
  /// `just_audio` and `audio_service` are resolved against this list.
  List<PlaybackSource> _sources = const [];

  final StreamController<PlaybackStatus> _statusController =
      StreamController.broadcast();
  final StreamController<int?> _currentIndexController =
      StreamController.broadcast();
  final StreamController<PlaybackFailure> _failureController =
      StreamController.broadcast();

  @override
  Future<void> setSources(
    List<PlaybackSource> sources, {
    required int initialIndex,
    Duration? initialPosition,
  }) async {
    _sources = sources;
    queue.add([for (final source in sources) _toMediaItem(source)]);

    if (sources.isEmpty) {
      await _player.stop();
      mediaItem.add(null);
      return;
    }

    mediaItem.add(_toMediaItem(sources[initialIndex]));
    try {
      await _player.setAudioSources(
        [for (final source in sources) _toAudioSource(source)],
        initialIndex: initialIndex,
        initialPosition: initialPosition ?? Duration.zero,
        // Loading starts on an explicit play() — setSources primes the
        // engine (and, on a cold-start restore, must not throw just
        // because the device is offline).
        preload: false,
      );
    } on Object catch (error) {
      _reportFailure(initialIndex, error);
    }
  }

  @override
  Future<void> updateSources(
    List<PlaybackSource> sources, {
    required int initialIndex,
    Duration? initialPosition,
    required bool resumePlaying,
  }) async {
    if (sources.isEmpty) {
      await stop();
      return;
    }

    final wasPlaying = _player.playing;
    final oldKeys = _occurrenceKeys(_sources);
    final desiredKeys = _occurrenceKeys(sources);
    final activeKey =
        _player.currentIndex == null || _player.currentIndex! >= oldKeys.length
        ? null
        : oldKeys[_player.currentIndex!];
    final workingKeys = [...oldKeys];
    final workingSources = [..._sources];

    for (var index = workingKeys.length - 1; index >= 0; index--) {
      if (!desiredKeys.contains(workingKeys[index])) {
        await _player.removeAudioSourceAt(index);
        workingKeys.removeAt(index);
        workingSources.removeAt(index);
      }
    }

    for (var index = 0; index < desiredKeys.length; index++) {
      final key = desiredKeys[index];
      if (index < workingKeys.length && workingKeys[index] == key) continue;
      final existing = workingKeys.indexOf(key, index);
      if (existing >= 0) {
        await _player.moveAudioSource(existing, index);
        final movedKey = workingKeys.removeAt(existing);
        final movedSource = workingSources.removeAt(existing);
        workingKeys.insert(index, movedKey);
        workingSources.insert(index, movedSource);
      } else {
        await _player.insertAudioSource(index, _toAudioSource(sources[index]));
        workingKeys.insert(index, key);
        workingSources.insert(index, sources[index]);
      }
    }

    _sources = List.unmodifiable(sources);
    queue.add([for (final source in sources) _toMediaItem(source)]);

    final activeIndex = activeKey == null ? -1 : desiredKeys.indexOf(activeKey);
    final targetIndex = activeIndex >= 0
        ? activeIndex
        : initialIndex.clamp(0, sources.length - 1);
    if (activeIndex < 0) {
      mediaItem.add(_toMediaItem(sources[targetIndex]));
      await _player.seek(initialPosition ?? Duration.zero, index: targetIndex);
    } else if (targetIndex < sources.length) {
      mediaItem.add(_toMediaItem(sources[targetIndex]));
    }
    if (resumePlaying && !wasPlaying && !_player.playing) await _player.play();
  }

  List<String> _occurrenceKeys(List<PlaybackSource> sources) {
    final counts = <String, int>{};
    return [
      for (final source in sources)
        () {
          final base = '${source.id.key}|${source.uri}';
          final occurrence = counts.update(
            base,
            (value) => value + 1,
            ifAbsent: () => 0,
          );
          return '$base#$occurrence';
        }(),
    ];
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToIndex(int index, {Duration? position}) async {
    if (index < 0 || index >= _sources.length) return;
    mediaItem.add(_toMediaItem(_sources[index]));
    await _player.seek(position ?? Duration.zero, index: index);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _sources = const [];
    queue.add(const []);
    mediaItem.add(null);
  }

  // System-control entry points (lock screen, notification, headset).
  // Delegating to just_audio's own sequence navigation, rather than
  // reimplementing it, is what lets a system button press and an in-app
  // `skipToIndex` call converge on the same `currentIndexStream` event.
  @override
  Future<void> skipToNext() =>
      _player.hasNext ? _player.seekToNext() : Future<void>.value();

  @override
  Future<void> skipToPrevious() =>
      _player.hasPrevious ? _player.seekToPrevious() : Future<void>.value();

  @override
  Future<void> skipToQueueItem(int index) => skipToIndex(index);

  @override
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Stream<PlaybackFailure> get failureStream => _failureController.stream;

  void _onCurrentIndexChanged(int? index) {
    _currentIndexController.add(index);
    if (index != null && index >= 0 && index < _sources.length) {
      mediaItem.add(_toMediaItem(_sources[index]));
    }
  }

  void _onPlayerError(just_audio.PlayerException error) {
    final index = error.index ?? _player.currentIndex;
    if (index == null) return;
    _reportFailure(index, error);
  }

  void _reportFailure(int index, Object error) {
    if (index < 0 || index >= _sources.length) return;
    final message = error is just_audio.PlayerException
        ? (error.message ?? 'This track could not be played.')
        : 'This track could not be played.';
    _failureController.add(
      PlaybackFailure(
        sourceIndex: index,
        id: _sources[index].id,
        message: message,
      ),
    );
    _statusController.add(PlaybackStatus.idle);
  }

  void _broadcastPlaybackState(just_audio.PlayerState state) {
    final status = _toStatus(state);
    _statusController.add(status);

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          audio_service.MediaControl.skipToPrevious,
          status == PlaybackStatus.playing
              ? audio_service.MediaControl.pause
              : audio_service.MediaControl.play,
          audio_service.MediaControl.skipToNext,
        ],
        systemActions: const {audio_service.MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _toProcessingState(state.processingState),
        playing: state.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  PlaybackStatus _toStatus(just_audio.PlayerState state) {
    return switch (state.processingState) {
      just_audio.ProcessingState.idle => PlaybackStatus.idle,
      just_audio.ProcessingState.loading => PlaybackStatus.loading,
      just_audio.ProcessingState.buffering => PlaybackStatus.buffering,
      just_audio.ProcessingState.completed => PlaybackStatus.completed,
      just_audio.ProcessingState.ready =>
        state.playing ? PlaybackStatus.playing : PlaybackStatus.paused,
    };
  }

  audio_service.AudioProcessingState _toProcessingState(
    just_audio.ProcessingState state,
  ) {
    return switch (state) {
      just_audio.ProcessingState.idle =>
        audio_service.AudioProcessingState.idle,
      just_audio.ProcessingState.loading =>
        audio_service.AudioProcessingState.loading,
      just_audio.ProcessingState.buffering =>
        audio_service.AudioProcessingState.buffering,
      just_audio.ProcessingState.ready =>
        audio_service.AudioProcessingState.ready,
      just_audio.ProcessingState.completed =>
        audio_service.AudioProcessingState.completed,
    };
  }

  /// A direct-play Jellyfin stream is always progressive HTTP, never a
  /// DASH/HLS manifest, so this is constructed directly rather than via
  /// `AudioSource.uri`'s extension-guessing — which also does not accept
  /// a [PlaybackSource.duration] hint to pass through.
  just_audio.ProgressiveAudioSource _toAudioSource(PlaybackSource source) =>
      just_audio.ProgressiveAudioSource(source.uri, duration: source.duration);

  audio_service.MediaItem _toMediaItem(PlaybackSource source) {
    final image = source.image;
    return audio_service.MediaItem(
      id: source.id.key,
      title: source.title,
      artist: source.artist,
      album: source.album,
      duration: source.duration,
      artUri: image == null
          ? null
          : _artworkResolver.imageUrl(image, maxWidth: 512, maxHeight: 512),
    );
  }
}
