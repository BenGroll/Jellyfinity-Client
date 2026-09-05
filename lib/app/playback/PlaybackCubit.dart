import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/media/MediaId.dart';
import '../../domain/media/PlaybackProgressRepository.dart';
import '../../domain/media/Track.dart';
import '../../domain/playback/AudioSourceResolver.dart';
import '../../domain/playback/CrossfadeSettings.dart';
import '../../domain/playback/PlaybackEngine.dart';
import '../../domain/playback/PlaybackFailure.dart';
import '../../domain/playback/PlaybackQueue.dart';
import '../../domain/playback/PlaybackSource.dart';
import '../../domain/playback/playback_status.dart';
import '../../domain/playback/QueueEntry.dart';
import '../../domain/playback/QueueRepository.dart';
import '../../domain/playback/repeat_mode.dart';
import '../../domain/playback/stream_quality.dart';
import '../settings/SettingsCubit.dart';
import 'PlaybackUiState.dart';

/// The single source of truth for playback — Jellyfinity's own queue plus
/// what [PlaybackEngine] is doing with it.
///
/// Same architectural slot as `SessionCubit`/`AuthSessionManager`:
/// cross-cutting app state, not a feature. It is the *only* thing that
/// talks to both [PlaybackQueue] and [PlaybackEngine] — resolving
/// sources, computing the actual play order (including a shuffled one),
/// persisting the queue, and reporting playback sessions to Jellyfin.
///
/// The engine playlist is updated in place for queue edits, preserving the
/// currently playing native source and position whenever possible.
@lazySingleton
class PlaybackCubit extends Cubit<PlaybackUiState> {
  PlaybackCubit(
    this._engine,
    this._queueRepository,
    this._sourceResolver,
    this._progressRepository,
    this._settings,
  ) : super(const PlaybackUiState()) {
    _statusSub = _engine.statusStream.listen(_onStatus);
    _positionSub = _engine.positionStream.listen(_onPosition);
    _durationSub = _engine.durationStream.listen(_onDuration);
    _currentIndexSub = _engine.currentIndexStream.listen(_onEngineIndexChanged);
    _failureSub = _engine.failureStream.listen(_onEngineFailure);
    _settingsSub = _settings.stream.listen((_) => _applyCrossfade());
    _applyCrossfade();
  }

  final PlaybackEngine _engine;
  final QueueRepository _queueRepository;
  final AudioSourceResolver _sourceResolver;
  final PlaybackProgressRepository _progressRepository;
  final SettingsCubit _settings;

  late final StreamSubscription<PlaybackStatus> _statusSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<int?> _currentIndexSub;
  late final StreamSubscription<PlaybackFailure> _failureSub;
  late final StreamSubscription<SettingsState> _settingsSub;

  /// The crossfade configuration last pushed to the engine, so a
  /// settings change that does not affect it (a stream-quality change,
  /// say) does not churn the engine.
  CrossfadeSettings? _appliedCrossfade;

  /// Frequent enough that a restart loses at most a few seconds of
  /// position; cheap enough to run on every tick while a track plays.
  static const Duration _positionSaveInterval = Duration(seconds: 5);
  Timer? _positionTimer;

  /// Pressing Previous restarts the current track instead of moving back
  /// once it is already this far in — the same convention most players
  /// use.
  static const Duration _restartThreshold = Duration(seconds: 3);

  /// Indices into [PlaybackUiState.queue]'s entries, in the order last
  /// given to [PlaybackEngine.setSources] — what an engine index from
  /// [PlaybackEngine.currentIndexStream] or [PlaybackFailure.sourceIndex]
  /// is resolved against.
  List<int> _loadedOrder = const [];

  /// How many source failures have advanced the queue in a row, without
  /// anything actually starting to play in between. Guards against
  /// cycling forever through a queue that is entirely unplayable (e.g.
  /// every stream is unreachable) — capped at the queue length, since
  /// that is enough attempts to have tried every entry once.
  int _consecutiveFailures = 0;

  /// Entries that already got one retry at [StreamQuality.original] after
  /// a failure at the settings-selected quality (ADR-0015) — resolved at
  /// original from here on, so a second failure falls through to the
  /// ordinary mark-unavailable-and-advance handling below rather than
  /// retrying forever. Cleared on [playNow]; harmless to leave stale
  /// entries in it otherwise, since it only ever makes a retry get
  /// skipped once for a track that already needed one.
  final Set<MediaId> _retriedAtOriginal = {};

  final Map<(MediaId, StreamQuality), PlaybackSource> _resolvedSources = {};
  Future<void> _operationTail = Future<void>.value();
  bool _isSynchronizingSources = false;

  // ---- Cold start ----

  /// Restores the saved queue and primes the engine at its last position,
  /// without starting playback — "restore where practical", not a
  /// surprise auto-play the moment the app launches.
  Future<void> restore() async {
    final result = await _queueRepository.load();
    if (result case Err<RestoredQueue>()) return;
    final restored = (result as Ok<RestoredQueue>).value;
    if (restored.queue.isEmpty) return;

    emit(
      PlaybackUiState(
        queue: restored.queue,
        position: restored.position,
        duration: restored.queue.currentEntry?.duration,
      ),
    );
    await _loadIntoEngine(
      restored.queue,
      play: false,
      initialPosition: restored.position,
    );
  }

  // ---- Starting playback ----

  /// Replaces the queue with [tracks] and starts playing [startIndex].
  /// Keeps the current shuffle/repeat settings.
  // Do not serialize this behind queue edits: just_audio's play() Future stays
  // pending for the lifetime of playback. Queue edits are serialized with one
  // another, but must remain available while a new queue is playing.
  Future<void> playNow(List<Track> tracks, {required int startIndex}) =>
      _playNow(tracks, startIndex: startIndex);

  Future<void> _playNow(List<Track> tracks, {required int startIndex}) async {
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) {
      return;
    }
    final entries = [for (final track in tracks) QueueEntry.fromTrack(track)];
    final queue = PlaybackQueue.empty
        .withEntries(entries, startIndex: startIndex)
        .withShuffle(state.queue.shuffleEnabled)
        .withRepeatMode(state.queue.repeatMode);

    _retriedAtOriginal.clear();
    emit(
      PlaybackUiState(
        queue: queue,
        status: PlaybackStatus.loading,
        duration: entries[startIndex].duration,
      ),
    );
    unawaited(_queueRepository.replace(queue));
    await _loadIntoEngine(queue, play: true);
  }

  // ---- Transport ----

  Future<void> togglePlayPause() async {
    if (state.queue.isEmpty) return;
    if (state.isPlaying) {
      await _engine.pause();
      unawaited(_savePosition());
    } else {
      await _engine.play();
    }
  }

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> next() async {
    final index = state.queue.manualNextIndex();
    if (index == null) {
      await _engine.pause();
      return;
    }
    await _advanceTo(index);
  }

  Future<void> previous() async {
    if (state.position > _restartThreshold) {
      await _engine.seek(Duration.zero);
      return;
    }
    final index = state.queue.previousIndex();
    if (index == null) {
      await _engine.seek(Duration.zero);
      return;
    }
    await _advanceTo(index);
  }

  /// Jumps directly to [entriesIndex] — a tap on a row in the queue
  /// screen.
  Future<void> playAt(int entriesIndex) => _advanceTo(entriesIndex);

  // ---- Queue editing ----

  Future<void> addToQueue(Track track) =>
      _mutate((queue) => queue.withEntryAdded(QueueEntry.fromTrack(track)));

  Future<void> playNext(Track track) => _mutate(
    (queue) =>
        queue.withEntryAdded(QueueEntry.fromTrack(track), playNext: true),
  );

  Future<void> removeAt(int entriesIndex) =>
      _mutate((queue) => queue.withEntryRemoved(entriesIndex));

  Future<void> reorder(int oldIndex, int newIndex) =>
      _mutate((queue) => queue.withReordered(oldIndex, newIndex));

  Future<void> clear() => _mutate((queue) => queue.withCleared());

  Future<void> toggleShuffle() =>
      _mutate((queue) => queue.withShuffle(!queue.shuffleEnabled));

  Future<void> setRepeatMode(RepeatMode mode) async {
    await _mutate((queue) => queue.withRepeatMode(mode));
    // Repeat-one changes what a crossfade would even be fading into.
    _applyCrossfade();
  }

  // ---- Playback preferences ----

  /// Pushes the effective crossfade configuration to the engine
  /// (ADR-0016), whenever the preference or the repeat mode changes.
  ///
  /// Repeat-one is the one case the preference is overridden. The engine
  /// deliberately knows nothing about repeat — it would happily start
  /// overlapping the *next* source in the loaded list, while repeat-one
  /// means this queue never reaches it. Resolving that here keeps the
  /// domain rule where the queue lives and leaves the engine contract
  /// as narrow as ADR-0013 made it.
  void _applyCrossfade() {
    final effective = state.queue.repeatMode == RepeatMode.one
        ? CrossfadeSettings.disabled
        : _settings.state.crossfade;
    if (effective == _appliedCrossfade) return;
    _appliedCrossfade = effective;
    unawaited(_engine.setCrossfade(effective));
  }

  Future<void> _mutate(PlaybackQueue Function(PlaybackQueue queue) transform) =>
      _enqueue(() => _mutateNow(transform));

  Future<void> _mutateNow(
    PlaybackQueue Function(PlaybackQueue queue) transform,
  ) async {
    final wasPlaying = state.isPlaying;
    final position = state.position;
    final queue = transform(state.queue);

    emit(
      PlaybackUiState(
        queue: queue,
        status: state.status,
        position: position,
        duration: state.duration,
        lastFailure: state.lastFailure,
      ),
    );
    unawaited(_queueRepository.replace(queue));
    await _loadIntoEngine(queue, play: wasPlaying, initialPosition: position);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationTail.then((_) => operation());
    _operationTail = next.then<void>((_) {}, onError: (error, stack) {});
    return next;
  }

  // ---- Engine loading ----

  Future<void> _advanceTo(int entriesIndex) async {
    final queue = state.queue;
    if (entriesIndex < 0 || entriesIndex >= queue.entries.length) return;

    final moved = queue.withCurrentIndex(entriesIndex);
    final entry = moved.entries[entriesIndex];
    emit(
      PlaybackUiState(
        queue: moved,
        status: PlaybackStatus.loading,
        duration: entry.duration,
        lastFailure: state.lastFailure,
      ),
    );
    unawaited(
      _queueRepository.savePosition(
        currentIndex: entriesIndex,
        position: Duration.zero,
      ),
    );

    final engineIndex = _loadedOrder.indexOf(entriesIndex);
    if (engineIndex >= 0) {
      await _engine.skipToIndex(engineIndex);
    } else {
      await _loadIntoEngine(moved, play: true);
    }
  }

  /// Resolves stream addresses for the entries that should be loaded and
  /// hands them to the engine.
  ///
  /// The complete play order stays loaded for every repeat mode. Repeat-one
  /// is handled when completion is reported, avoiding a playlist replacement
  /// when the user toggles the repeat button.
  Future<void> _loadIntoEngine(
    PlaybackQueue queue, {
    required bool play,
    Duration? initialPosition,
  }) async {
    final currentIndex = queue.currentIndex;
    if (queue.isEmpty || currentIndex == null) {
      _loadedOrder = const [];
      await _engine.stop();
      return;
    }

    // Keep the full playlist loaded; repeat-one is handled at completion.
    final order = queue.playOrder;

    final sources = <PlaybackSource>[];
    final loadedOrder = <int>[];
    var updated = queue;
    var anyUnavailable = false;

    for (final entriesIndex in order) {
      final entry = updated.entries[entriesIndex];
      final quality = _retriedAtOriginal.contains(entry.id)
          ? StreamQuality.original
          : _settings.state.streamQuality;
      final cacheKey = (entry.id, quality);
      var source = _resolvedSources[cacheKey];
      if (source == null) {
        final resolved = await _sourceResolver.resolve(
          entry.id,
          quality: quality,
        );
        if (resolved case Ok<Uri>(:final value)) {
          source = PlaybackSource(
            id: entry.id,
            uri: value,
            title: entry.title,
            artist: entry.artist,
            album: entry.albumName,
            duration: entry.duration,
            image: entry.image,
          );
          _resolvedSources[cacheKey] = source;
        }
      }
      if (source != null) {
        sources.add(source);
        loadedOrder.add(entriesIndex);
      } else {
        updated = updated.withEntryMarkedUnavailable(entriesIndex);
        anyUnavailable = true;
      }
    }

    if (anyUnavailable && !loadedOrder.contains(updated.currentIndex)) {
      updated = updated.withCurrentIndex(
        loadedOrder.isEmpty ? null : loadedOrder.first,
      );
    }
    if (anyUnavailable) {
      emit(
        PlaybackUiState(
          queue: updated,
          status: state.status,
          position: state.position,
          duration: state.duration,
          lastFailure: state.lastFailure,
        ),
      );
      unawaited(_queueRepository.replace(updated));
    }

    final hadLoadedSources = _loadedOrder.isNotEmpty;
    _loadedOrder = loadedOrder;

    if (sources.isEmpty) {
      await _engine.stop();
      return;
    }

    final updatedCurrentIndex = updated.currentIndex;
    final startEngineIndex = updatedCurrentIndex == null
        ? -1
        : loadedOrder.indexOf(updatedCurrentIndex);
    final initialIndex = startEngineIndex < 0 ? 0 : startEngineIndex;
    if (!hadLoadedSources) {
      await _engine.setSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
      if (play) await _engine.play();
    } else {
      _isSynchronizingSources = true;
      try {
        await _engine.updateSources(
          sources,
          initialIndex: initialIndex,
          initialPosition: initialPosition,
          resumePlaying: play,
        );
        await Future<void>.delayed(Duration.zero);
      } finally {
        _isSynchronizingSources = false;
      }
    }
  }

  // ---- Engine stream handling ----

  void _onStatus(PlaybackStatus status) {
    emit(
      PlaybackUiState(
        queue: state.queue,
        status: status,
        position: state.position,
        duration: state.duration,
        lastFailure: state.lastFailure,
      ),
    );
    if (status == PlaybackStatus.playing) {
      _positionTimer ??= Timer.periodic(
        _positionSaveInterval,
        (_) => unawaited(_savePosition()),
      );
    } else {
      _positionTimer?.cancel();
      _positionTimer = null;
    }
    if (status == PlaybackStatus.completed) {
      unawaited(_onCompleted());
    }
  }

  void _onPosition(Duration position) {
    emit(
      PlaybackUiState(
        queue: state.queue,
        status: state.status,
        position: position,
        duration: state.duration,
        lastFailure: state.lastFailure,
      ),
    );
  }

  void _onDuration(Duration? duration) {
    emit(
      PlaybackUiState(
        queue: state.queue,
        status: state.status,
        position: state.position,
        duration: duration,
        lastFailure: state.lastFailure,
      ),
    );
  }

  void _onEngineIndexChanged(int? engineIndex) {
    if (_isSynchronizingSources) return;
    if (engineIndex == null ||
        engineIndex < 0 ||
        engineIndex >= _loadedOrder.length) {
      return;
    }
    final entriesIndex = _loadedOrder[engineIndex];
    if (entriesIndex == state.queue.currentIndex) return;

    _consecutiveFailures = 0;
    final queue = state.queue.withCurrentIndex(entriesIndex);
    final entry = queue.entries[entriesIndex];
    emit(
      PlaybackUiState(
        queue: queue,
        status: state.status,
        duration: entry.duration,
      ),
    );
    unawaited(
      _queueRepository.savePosition(
        currentIndex: entriesIndex,
        position: Duration.zero,
      ),
    );
    unawaited(_progressRepository.reportStart(entry.id));
  }

  void _onEngineFailure(PlaybackFailure failure) {
    final entriesIndex = state.queue.entries.indexWhere(
      (entry) => entry.id == failure.id,
    );
    if (entriesIndex < 0) return;

    // The entry that just failed to play was streamed at a transcoded
    // quality — retry once at the original file before treating it as
    // genuinely unavailable (ADR-0015), since just_audio's error surface
    // can't reliably tell a transient transcode/network failure from a
    // dead track. Only for the entry actually loading/playing right now:
    // a preloaded-ahead entry failing keeps today's silent-mark handling
    // below, unchanged.
    if (entriesIndex == state.queue.currentIndex &&
        _settings.state.streamQuality != StreamQuality.original &&
        _retriedAtOriginal.add(failure.id)) {
      unawaited(_loadIntoEngine(state.queue, play: true));
      return;
    }

    final queue = state.queue.withEntryMarkedUnavailable(entriesIndex);
    emit(
      PlaybackUiState(
        queue: queue,
        status: state.status,
        position: state.position,
        duration: state.duration,
        lastFailure: failure,
      ),
    );
    unawaited(_queueRepository.replace(queue));

    // A track other than the one currently loading/playing failed (e.g.
    // one the engine was preloading ahead of time) — nothing more to do
    // until playback actually reaches it.
    if (entriesIndex != queue.currentIndex) return;

    _consecutiveFailures++;
    if (_consecutiveFailures > queue.entries.length) {
      unawaited(_engine.stop());
      return;
    }
    final next = queue.manualNextIndex();
    if (next == null) {
      unawaited(_engine.stop());
      return;
    }
    unawaited(_advanceTo(next));
  }

  Future<void> _onCompleted() async {
    final queue = state.queue;
    final current = queue.currentEntry;
    if (current != null) {
      unawaited(
        _progressRepository.reportStop(
          current.id,
          position: state.duration ?? state.position,
        ),
      );
    }

    switch (queue.repeatMode) {
      case RepeatMode.one:
        await _engine.seek(Duration.zero);
        await _engine.play();
      case RepeatMode.all:
        final next = queue.nextIndexOnCompletion();
        if (next != null) await _advanceTo(next);
      case RepeatMode.off:
      // The queue reached its natural end; there is nothing more to do.
    }
  }

  Future<void> _savePosition() => _queueRepository.savePosition(
    currentIndex: state.queue.currentIndex,
    position: state.position,
  );

  @override
  Future<void> close() {
    _positionTimer?.cancel();
    unawaited(_settingsSub.cancel());
    unawaited(_statusSub.cancel());
    unawaited(_positionSub.cancel());
    unawaited(_durationSub.cancel());
    unawaited(_currentIndexSub.cancel());
    unawaited(_failureSub.cancel());
    return super.close();
  }
}
