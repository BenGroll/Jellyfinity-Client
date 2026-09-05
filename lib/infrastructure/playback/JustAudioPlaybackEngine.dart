import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart' as just_audio;

import '../../domain/media/ArtworkResolver.dart';
import '../../domain/playback/CrossfadeSettings.dart';
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
/// ## Two decks (ADR-0016)
///
/// `just_audio` has no crossfade, and one native player cannot overlap
/// two items of its own playlist, so crossfade is implemented here with
/// **two `AudioPlayer` instances**. Both hold the same source list; only
/// one is *active* at a time and everything below — the transport
/// methods, the exposed streams, the `audio_service` media session —
/// reads through [_player], the active deck. The second deck is created
/// lazily the first time a crossfade actually needs it, so a user who
/// never turns crossfade on never pays for a second native player.
///
/// With crossfade off there is exactly one deck running one `just_audio`
/// playlist, which is the untouched v0.0.9 arrangement — gapless
/// playback is preserved by construction rather than by re-verification.
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
    _listenTo(_primaryPlayer);
  }

  final ArtworkResolver _artworkResolver;

  /// The deck that plays whenever crossfade is off, and the one the
  /// first crossfade fades *out* of.
  final just_audio.AudioPlayer _primaryPlayer = just_audio.AudioPlayer();

  /// Built on the first crossfade that needs somewhere to fade *in*.
  just_audio.AudioPlayer? _secondaryPlayer;

  /// Which deck is active. Flipped at the *start* of a crossfade, not
  /// its end: the moment the incoming track begins, it is the track the
  /// user is listening to, the one Now Playing should show, and the one
  /// a Next press should skip past. The outgoing deck is only an audible
  /// tail from that point on.
  bool _secondaryIsActive = false;

  /// The active deck. Every transport call and every exposed stream goes
  /// through this, so the rest of the class reads the same as it did
  /// when there was only one player.
  just_audio.AudioPlayer get _player =>
      _secondaryIsActive ? _secondaryPlayer! : _primaryPlayer;

  /// The source list currently mirrored into `just_audio`; indices from
  /// `just_audio` and `audio_service` are resolved against this list.
  List<PlaybackSource> _sources = const [];

  CrossfadeSettings _crossfade = CrossfadeSettings.disabled;

  /// Loading the incoming source only once the fade starts would spend
  /// the first seconds of the overlap buffering a network stream. The
  /// standby deck is loaded this far ahead of the fade point instead,
  /// and left paused until the overlap actually begins.
  static const Duration _preloadLead = Duration(seconds: 5);

  /// Ramp resolution. Fine enough to be inaudible as steps, coarse
  /// enough not to flood the platform channel.
  static const Duration _rampStep = Duration(milliseconds: 50);

  Timer? _rampTimer;
  bool _crossfading = false;

  /// The index the standby deck has been (or is being) loaded with.
  int? _preparedIndex;
  Future<void>? _preparation;

  /// An index the standby deck failed to load. Not reported as a
  /// failure: the active deck holds the same list and will reach — and
  /// report — the same source at its own natural transition. Remembered
  /// only so preparation is not retried on every position tick.
  int? _unpreparableIndex;

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

  @override
  Future<void> setSources(
    List<PlaybackSource> sources, {
    required int initialIndex,
    Duration? initialPosition,
  }) async {
    await _abandonCrossfade();
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
    // A tail fading out of the old list, and a standby deck loaded from
    // it, are both stale the moment the list changes.
    await _abandonCrossfade();

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
  Future<void> setCrossfade(CrossfadeSettings settings) async {
    if (settings == _crossfade) return;
    _crossfade = settings;
    // Nothing is reloaded on a change: both modes play the same
    // `just_audio` playlist on the active deck, so the setting simply
    // decides how the *next* transition is made. Turning it off midway
    // through an overlap does end that overlap, though — the user asked
    // for no crossfade.
    if (!settings.enabled) await _abandonCrossfade();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    // Pausing during an overlap leaves a tail playing on the other deck
    // otherwise.
    await _abandonCrossfade();
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _abandonCrossfade();
    await _player.seek(position);
  }

  @override
  Future<void> skipToIndex(int index, {Duration? position}) async {
    if (index < 0 || index >= _sources.length) return;
    await _abandonCrossfade();
    mediaItem.add(_toMediaItem(_sources[index]));
    await _player.seek(position ?? Duration.zero, index: index);
  }

  @override
  Future<void> stop() async {
    await _abandonCrossfade();
    await _player.stop();
    _sources = const [];
    queue.add(const []);
    mediaItem.add(null);
  }

  // ---- Crossfade (ADR-0016) ----

  /// The deck that is *not* currently active, building the second one on
  /// first use.
  just_audio.AudioPlayer _standbyPlayer() {
    if (_secondaryIsActive) return _primaryPlayer;
    final existing = _secondaryPlayer;
    if (existing != null) return existing;
    final created = just_audio.AudioPlayer();
    _secondaryPlayer = created;
    _listenTo(created);
    return created;
  }

  /// Ends any overlap in progress and releases whatever the standby deck
  /// is holding, leaving both decks at full volume.
  ///
  /// Called before every explicit transport command and every source
  /// change: after this, the active deck is the only thing making sound,
  /// which is the state the rest of the class assumes.
  Future<void> _abandonCrossfade() async {
    _rampTimer?.cancel();
    _rampTimer = null;
    _crossfading = false;
    _preparedIndex = null;
    _preparation = null;
    _unpreparableIndex = null;

    // Before a fade this is the deck holding a preloaded next source;
    // during one it is the outgoing tail. Both want stopping.
    final standby = _secondaryIsActive ? _primaryPlayer : _secondaryPlayer;
    if (standby != null) {
      await standby.stop();
      await standby.setVolume(1);
    }
    if (_player.volume != 1) await _player.setVolume(1);
  }

  /// Decides, on each position tick of the active deck, whether it is
  /// time to preload the next source and then to start overlapping it.
  void _maybeCrossfade(Duration position) {
    if (_crossfading || !_crossfade.enabled || !_player.playing) return;

    final index = _player.currentIndex;
    if (index == null) return;
    final next = index + 1;
    // Nothing to fade into. The wrap-around of repeat-all lives in
    // `PlaybackQueue`, not here, so the last source of the loaded list
    // always ends on its own.
    if (next >= _sources.length || _unpreparableIndex == next) return;

    final duration = _player.duration;
    final fade = _crossfade.effectiveDurationFor(duration);
    if (fade == null) return;

    final remaining = duration! - position;
    if (remaining <= Duration.zero || remaining > fade + _preloadLead) return;
    if (remaining > fade) {
      unawaited(_prepare(next));
      return;
    }
    unawaited(_startCrossfade(next, fade));
  }

  /// Loads the standby deck with the same list, cued to [index], silent
  /// and paused.
  ///
  /// The whole list is loaded rather than the single source so that the
  /// deck is a fully-fledged playlist player the moment it becomes
  /// active — including for the transition after this one, and for a
  /// gapless run if crossfade is turned off midway.
  ///
  /// Cueing to position zero (never a seek) is deliberate: it is what
  /// makes the overlap work identically for a transcoded stream, which
  /// Jellyfin does not serve seekably, and a direct-play file.
  Future<void> _prepare(int index) {
    if (_preparedIndex == index) return _preparation ?? Future<void>.value();
    _preparedIndex = index;
    final sources = _sources;
    return _preparation = () async {
      final standby = _standbyPlayer();
      try {
        await standby.setVolume(0);
        await standby.setAudioSources(
          [for (final source in sources) _toAudioSource(source)],
          initialIndex: index,
          initialPosition: Duration.zero,
        );
      } on Object {
        _preparedIndex = null;
        _unpreparableIndex = index;
      }
    }();
  }

  Future<void> _startCrossfade(int index, Duration fade) async {
    if (_crossfading) return;
    _crossfading = true;

    final outgoing = _player;
    await _prepare(index);
    if (_preparedIndex != index) {
      // Preparation failed; let the outgoing source finish normally.
      _crossfading = false;
      return;
    }

    final incoming = _standbyPlayer();
    await incoming.setVolume(0);

    // The outgoing deck holds the whole list too, so it would advance
    // into the next source by itself if the fade outlasts the track by
    // even a few milliseconds. Truncating its playlist makes the end of
    // this source the end of that deck.
    final outgoingIndex = outgoing.currentIndex;
    if (outgoingIndex != null && outgoingIndex + 1 < _sources.length) {
      await outgoing.removeAudioSourceRange(
        outgoingIndex + 1,
        _sources.length,
      );
    }

    // Control transfers here, at the start of the overlap.
    _secondaryIsActive = !_secondaryIsActive;
    _preparedIndex = null;
    _preparation = null;

    await incoming.play();
    _onCurrentIndexChanged(index);
    _durationController.add(incoming.duration);
    _broadcastPlaybackState(incoming.playerState);

    _ramp(outgoing: outgoing, incoming: incoming, fade: fade);
  }

  /// Ramps [outgoing] down and [incoming] up over [fade].
  ///
  /// Equal-power (cosine/sine) rather than linear: two different
  /// recordings are uncorrelated, so their loudness sums as power, and a
  /// linear amplitude ramp audibly dips about 3 dB in the middle of the
  /// overlap.
  void _ramp({
    required just_audio.AudioPlayer outgoing,
    required just_audio.AudioPlayer incoming,
    required Duration fade,
  }) {
    final steps = math.max(
      1,
      (fade.inMilliseconds / _rampStep.inMilliseconds).ceil(),
    );
    var step = 0;

    _rampTimer?.cancel();
    _rampTimer = Timer.periodic(_rampStep, (timer) {
      step++;
      final progress = math.min(1.0, step / steps);
      unawaited(outgoing.setVolume(math.cos(progress * math.pi / 2)));
      unawaited(incoming.setVolume(math.sin(progress * math.pi / 2)));
      if (progress < 1) return;

      timer.cancel();
      _rampTimer = null;
      _crossfading = false;
      unawaited(() async {
        await outgoing.stop();
        await outgoing.setVolume(1);
        await incoming.setVolume(1);
      }());
    });
  }

  // System-control entry points (lock screen, notification, headset).
  // Delegating to just_audio's own sequence navigation, rather than
  // reimplementing it, is what lets a system button press and an in-app
  // `skipToIndex` call converge on the same `currentIndexStream` event.
  @override
  Future<void> skipToNext() async {
    await _abandonCrossfade();
    if (_player.hasNext) await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _abandonCrossfade();
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) => skipToIndex(index);

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

  /// Subscribes to one deck's `just_audio` streams, forwarding them only
  /// while that deck is the active one.
  ///
  /// This is why position, duration, status and index are republished
  /// through controllers rather than exposed straight off the player:
  /// with two decks the *source* of each of those changes at a
  /// crossfade, while `PlaybackCubit` subscribes exactly once, at
  /// construction.
  void _listenTo(just_audio.AudioPlayer player) {
    player.playerStateStream.listen((state) {
      if (!identical(player, _player)) return;
      _broadcastPlaybackState(state);
    });
    player.currentIndexStream.listen((index) {
      if (!identical(player, _player)) return;
      _onCurrentIndexChanged(index);
    });
    player.errorStream.listen((error) {
      if (!identical(player, _player)) return;
      _onPlayerError(error);
    });
    player.positionStream.listen((position) {
      if (!identical(player, _player)) return;
      _positionController.add(position);
      _maybeCrossfade(position);
    });
    player.durationStream.listen((duration) {
      if (!identical(player, _player)) return;
      _durationController.add(duration);
    });
  }

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
