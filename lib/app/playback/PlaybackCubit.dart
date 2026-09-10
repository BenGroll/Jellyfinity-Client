import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/result/result.dart';
import '../../domain/media/artist.dart';
import '../../domain/media/ListeningContext.dart';
import '../../domain/media/ListeningHistoryRepository.dart';
import '../../domain/media/media_availability.dart';
import '../../domain/media/MediaId.dart';
import '../../domain/media/PlaybackProgressRepository.dart';
import '../../domain/media/Track.dart';
import '../../domain/playback/AudioSourceResolver.dart';
import '../../domain/playback/CrossfadeSettings.dart';
import '../../domain/playback/NormalizationSettings.dart';
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
    this._history,
    this._settings,
  ) : super(const PlaybackUiState()) {
    _statusSub = _engine.statusStream.listen(_onStatus);
    _positionSub = _engine.positionStream.listen(_onPosition);
    _durationSub = _engine.durationStream.listen(_onDuration);
    _currentIndexSub = _engine.currentIndexStream.listen(_onEngineIndexChanged);
    _failureSub = _engine.failureStream.listen(_onEngineFailure);
    _settingsSub = _settings.stream.listen((_) {
      _applyCrossfade();
      _applyNormalization();
    });
    _applyCrossfade();
    _applyNormalization();
  }

  final PlaybackEngine _engine;
  final QueueRepository _queueRepository;
  final AudioSourceResolver _sourceResolver;
  final PlaybackProgressRepository _progressRepository;
  final ListeningHistoryRepository _history;
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

  /// The normalization configuration last pushed to the engine, for the
  /// same reason [_appliedCrossfade] exists.
  NormalizationSettings? _appliedNormalization;

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
  ///
  /// Reset the moment the engine reports it is actually playing (v0.4.1),
  /// which is the only honest reading of "in a row": before that it only
  /// cleared on an engine-driven index change, so a queue recovered by a
  /// manual skip kept counting its old failures towards the cap.
  int _consecutiveFailures = 0;

  /// Entries that have already been re-resolved once after a failure
  /// (v0.4.1), so a second failure falls through to the ordinary
  /// mark-unavailable-and-advance handling rather than retrying forever.
  ///
  /// The retry exists because a source address can go stale while it sits
  /// in the queue: a download finished or was deleted since it was
  /// resolved, or the session moved to a different server. Re-resolving
  /// asks [AudioSourceResolver] the question again, which is what lets a
  /// removed download fall back to the stream (and a newly downloaded
  /// track stop streaming).
  final Set<MediaId> _retriedIds = {};

  /// Entries whose retry above is pinned to [StreamQuality.original]
  /// because they first failed at a transcoded quality (ADR-0015):
  /// `just_audio`'s error surface can't reliably tell a transient
  /// transcode failure from a dead track, so the original file gets one
  /// chance before the entry is called unavailable.
  final Set<MediaId> _retriedAtOriginal = {};

  /// The entry Jellyfin currently has an open play session for (v0.4.1) —
  /// what [PlaybackProgressRepository.reportStop] has to name, and the
  /// guard against opening a second session for a track that is already
  /// reported. Sessions used to be started only from an engine-driven
  /// index change, so every manually started or skipped-to track played
  /// without the server ever being told.
  QueueEntry? _reportedEntry;

  final Map<(MediaId, StreamQuality), PlaybackSource> _resolvedSources = {};
  Future<void> _operationTail = Future<void>.value();
  bool _isSynchronizingSources = false;

  // ---- Listening history (v0.3.1, ADR-0025) ----

  /// A play is recorded once the user has genuinely listened to a track:
  /// [_listenThreshold] of playback, or [_listenFraction] of a track whose
  /// length is known, or the track finishing on its own. The fraction
  /// covers a long track skipped after a couple of minutes; the absolute
  /// floor covers a short one. Crossfade (ADR-0016) hands control over up
  /// to 12 s early, which still clears the fraction for any track long
  /// enough to matter, so it needs no special case here.
  static const Duration _listenThreshold = Duration(seconds: 20);
  static const double _listenFraction = 0.5;

  /// The entry listening time is currently accruing against, the furthest
  /// position seen for it, and whether it has already been recorded — so a
  /// natural completion just after a threshold crossing does not
  /// double-count.
  QueueEntry? _listeningEntry;
  Duration _listeningFurthest = Duration.zero;
  bool _listeningRecorded = false;

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
    // Only this session's listening counts towards the threshold: a track
    // resumed halfway needs threshold-worth of fresh playback to record,
    // not to be credited for the part heard last time.
    _retargetListening(restored.queue.currentEntry);
  }

  // ---- Starting playback ----

  /// Replaces the queue with [tracks] and starts playing [startIndex].
  /// Keeps the current shuffle/repeat settings.
  // Do not serialize this behind queue edits: just_audio's play() Future stays
  // pending for the lifetime of playback. Queue edits are serialized with one
  // another, but must remain available while a new queue is playing.
  Future<void> playNow(List<Track> tracks, {required int startIndex}) =>
      _playNow(tracks, startIndex: startIndex);

  /// Replaces the queue with [tracks], shuffled, starting from a random
  /// entry (v0.1.6's Album/Playlist shuffle button).
  ///
  /// Starts at a random index rather than always index 0 —
  /// [PlaybackQueue] pins whichever index starts playing first in that
  /// order, so starting at a fixed index would make "shuffle" always open
  /// the same track.
  ///
  /// Shuffle is turned on as part of building the *new* queue rather than
  /// by toggling first (v0.4.1): `toggleShuffle` is a queue edit, so it
  /// reshuffled, re-persisted and re-loaded the queue being replaced
  /// half a frame before it was thrown away.
  Future<void> playShuffled(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    final startIndex = tracks.length == 1 ? 0 : Random().nextInt(tracks.length);
    await _playNow(tracks, startIndex: startIndex, shuffle: true);
  }

  /// Queues every one of [tracks] to play after the current one, in their
  /// own order (v0.4.1) — the collection-wide counterpart to [playNext],
  /// so an album header offers the same four actions a track row does.
  ///
  /// With nothing playing this is the same as [addAllToQueue]; with
  /// shuffle on the tracks take the play-order slots straight after the
  /// current entry, exactly as a single [playNext] does.
  Future<void> playNextAll(List<Track> tracks) {
    if (tracks.isEmpty) return Future<void>.value();
    return _mutate((queue) {
      var updated = queue;
      // With something playing, each insertion goes directly after the
      // current entry and pushes the previous one along, so inserting the
      // last track first is what leaves them in their own order. With an
      // empty queue there is no current entry to insert after and they
      // simply append, which the same loop already does forwards.
      final ordered = queue.currentIndex == null ? tracks : tracks.reversed;
      for (final track in ordered) {
        updated = updated.withEntryAdded(
          QueueEntry.fromTrack(track),
          playNext: true,
        );
      }
      return updated;
    });
  }

  Future<void> _playNow(
    List<Track> tracks, {
    required int startIndex,
    bool? shuffle,
  }) async {
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) {
      return;
    }
    final entries = [for (final track in tracks) QueueEntry.fromTrack(track)];
    final queue = PlaybackQueue.empty
        .withShuffle(shuffle ?? state.queue.shuffleEnabled)
        .withRepeatMode(state.queue.repeatMode)
        .withEntries(entries, startIndex: startIndex);

    _retriedIds.clear();
    _retriedAtOriginal.clear();
    _resolvedSources.clear();
    _consecutiveFailures = 0;
    _beginEntry(null);
    emit(
      PlaybackUiState(
        queue: queue,
        status: PlaybackStatus.loading,
        duration: entries[startIndex].duration,
      ),
    );
    unawaited(_queueRepository.replace(queue));
    await _loadIntoEngine(queue, play: true);
    _beginEntry(state.queue.currentEntry);
  }

  // ---- Transport ----

  Future<void> togglePlayPause() async {
    if (state.queue.isEmpty) return;
    if (state.isPlaying) {
      await _engine.pause();
      unawaited(_savePosition());
      // Jellyfin shows a paused session as paused rather than dropping
      // it, so pausing is reported, not stopped (v0.4.1).
      unawaited(_reportProgress(isPaused: true));
    } else {
      await _engine.play();
      unawaited(_reportProgress(isPaused: false));
    }
  }

  /// Carries on the restored queue from where it left off — Home's
  /// "Continue listening" (v0.3.2). The queue was primed into the engine,
  /// paused, by [restore] at launch; this just starts it. A no-op with an
  /// empty queue or one already playing, so the one entry point is safe to
  /// call from a card that may be tapped twice.
  Future<void> resume() async {
    if (state.queue.isEmpty || state.isPlaying) return;
    await _engine.play();
  }

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> next() async {
    final index = state.queue.manualNextIndex();
    if (index == null) {
      // Nothing follows and repeat will not wrap: stay on the last entry,
      // paused, rather than silently doing nothing. `PlaybackQueue
      // .isAtEndOfPlayOrder` is what the queue screen reads to say so
      // (v0.4.1).
      await _engine.pause();
      unawaited(_savePosition());
      unawaited(_reportProgress(isPaused: true));
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

  /// Appends every one of [tracks] to the end of the queue in one mutation
  /// (v0.1.6's Album/Playlist "Add to queue") — one engine sync for the
  /// whole album rather than one per track.
  Future<void> addAllToQueue(List<Track> tracks) {
    if (tracks.isEmpty) return Future<void>.value();
    return _mutate((queue) {
      var updated = queue;
      for (final track in tracks) {
        updated = updated.withEntryAdded(QueueEntry.fromTrack(track));
      }
      return updated;
    });
  }

  /// Re-queues [entry] — the currently playing track, from Now Playing's
  /// overflow menu (v0.1.6) — right after whatever plays next.
  Future<void> playNextEntry(QueueEntry entry) =>
      _mutate((queue) => queue.withEntryAdded(entry, playNext: true));

  /// Re-queues [entry] at the end of the queue, from the same menu.
  Future<void> addEntryToQueue(QueueEntry entry) =>
      _mutate((queue) => queue.withEntryAdded(entry));

  Future<void> removeAt(int entriesIndex) =>
      _mutate((queue) => queue.withEntryRemoved(entriesIndex));

  Future<void> reorder(int oldIndex, int newIndex) =>
      _mutate((queue) => queue.withReordered(oldIndex, newIndex));

  /// Moves an entry within the order it actually plays in (v0.4.1) — what
  /// a drag on the queue screen means, which is [reorder] only while
  /// shuffle is off.
  Future<void> reorderPlayOrder(int oldPosition, int newPosition) => _mutate(
    (queue) => queue.withPlayOrderReordered(oldPosition, newPosition),
  );

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

  /// Pushes the normalization preference to the engine (v0.1.4) whenever
  /// it changes.
  ///
  /// Unlike crossfade there is no repeat-mode override: gain is a
  /// per-source property carried on [PlaybackSource] itself, so it
  /// applies identically no matter how the queue orders sources.
  void _applyNormalization() {
    final effective = _settings.state.normalization;
    if (effective == _appliedNormalization) return;
    _appliedNormalization = effective;
    unawaited(_engine.setNormalization(effective));
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
    // Before the emit, so the stop report still carries the position the
    // outgoing track actually reached.
    _beginEntry(entry);
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
      _closeReportedSession();
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
      String? resolveFailure;
      if (source == null) {
        final resolved = await _sourceResolver.resolve(
          entry.id,
          quality: quality,
        );
        switch (resolved) {
          case Ok<Uri>(:final value):
            source = PlaybackSource(
              id: entry.id,
              uri: value,
              title: entry.title,
              artist: entry.artist,
              album: entry.albumName,
              duration: entry.duration,
              image: entry.image,
              normalizationGain: entry.normalizationGain,
            );
            _resolvedSources[cacheKey] = source;
          case Err<Uri>(:final failure):
            resolveFailure = failure.message;
        }
      }
      if (source != null) {
        sources.add(source);
        loadedOrder.add(entriesIndex);
      } else {
        // The address could not be worked out at all — a different
        // problem from a source the engine rejected, and the entry says
        // which (v0.4.1) instead of only greying out.
        updated = updated.withEntryMarkedUnavailable(
          entriesIndex,
          reason: resolveFailure ?? _unresolvableReason,
        );
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
    // Something is genuinely playing: whatever failed before it no longer
    // describes the queue (v0.4.1). The run of failures is over, the
    // current entry is demonstrably playable, and the one-off notice has
    // been superseded — leaving any of the three standing was how a queue
    // that had recovered kept insisting it was broken.
    var queue = state.queue;
    PlaybackFailure? failure = state.lastFailure;
    if (status == PlaybackStatus.playing) {
      _consecutiveFailures = 0;
      failure = null;
      final index = queue.currentIndex;
      if (index != null) queue = queue.withEntryMarkedPlayable(index);
      if (queue != state.queue) unawaited(_queueRepository.replace(queue));
      // Playing always means an open session. Everything that chooses an
      // entry reports it already; this covers the one path that chooses
      // nothing — pressing play on the queue `restore` primed at launch,
      // which is exactly how Home's "Continue listening" starts (v0.4.1).
      if (_reportedEntry == null) _beginEntry(queue.currentEntry);
    }
    emit(
      PlaybackUiState(
        queue: queue,
        status: status,
        position: state.position,
        duration: state.duration,
        lastFailure: failure,
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
    if (_listeningEntry != null &&
        _listeningEntry!.id == state.queue.currentEntry?.id &&
        position > _listeningFurthest) {
      _listeningFurthest = position;
    }
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
    _beginEntry(entry);
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
  }

  void _onEngineFailure(PlaybackFailure failure) {
    final entriesIndex = state.queue.entries.indexWhere(
      (entry) => entry.id == failure.id,
    );
    if (entriesIndex < 0) return;

    // The entry that just failed to play gets one re-resolve before it is
    // called unavailable (v0.4.1), because the address it failed at may
    // simply be out of date: a download completed or was deleted while it
    // sat in the queue, or — the ADR-0015 case — it was a transcode
    // `just_audio` could not tell apart from a dead track, in which case
    // the retry is pinned to the original file.
    //
    // Only for the entry actually loading/playing right now: a
    // preloaded-ahead entry failing keeps the silent-mark handling below,
    // unchanged, until playback reaches it.
    if (entriesIndex == state.queue.currentIndex &&
        _retriedIds.add(failure.id)) {
      if (_settings.state.streamQuality != StreamQuality.original) {
        _retriedAtOriginal.add(failure.id);
      }
      _forgetResolvedSource(failure.id);
      unawaited(_loadIntoEngine(state.queue, play: true));
      return;
    }

    final queue = state.queue.withEntryMarkedUnavailable(
      entriesIndex,
      reason: failure.message,
    );
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

    // This entry never played, so there is no session to close, but the
    // one it displaced may still be open on the server.
    _closeReportedSession();

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
      _reportedEntry = null;
    }

    // The track played to its natural end — a play, regardless of how far
    // the position stream got before completion was reported.
    _flushListening(completed: true);

    switch (queue.repeatMode) {
      case RepeatMode.one:
        await _engine.seek(Duration.zero);
        await _engine.play();
        // A fresh loop is a fresh listen: an hour of one track on repeat
        // is an hour the user spent with it, and the history collapses
        // the repeats into the one entry anyway. It is also a fresh play
        // session on the server (v0.4.1) — the last one was just closed.
        _beginEntry(current);
      case RepeatMode.all:
        final next = queue.nextIndexOnCompletion();
        if (next != null) {
          await _advanceTo(next);
        } else {
          _beginEntry(null);
        }
      case RepeatMode.off:
        _beginEntry(null);
    }
  }

  // ---- Listening history ----

  /// Records whatever listening time was accruing (if it qualifies), then
  /// starts accruing against [entry] — or nothing, for `null`.
  void _retargetListening(QueueEntry? entry) {
    _flushListening(completed: false);
    _listeningEntry = entry;
    _listeningFurthest = Duration.zero;
    _listeningRecorded = false;
  }

  /// Records the current listening entry as a play when the user has
  /// genuinely listened to it (ADR-0025). A no-op for an entry already
  /// recorded, one that never played, or one the engine marked
  /// unavailable.
  void _flushListening({required bool completed}) {
    final entry = _listeningEntry;
    if (entry == null || _listeningRecorded) return;
    // Read availability from the live queue, not the entry captured when
    // tracking began: the engine may have marked it unavailable since.
    final liveIndex = state.queue.entries.indexWhere(
      (candidate) => candidate.id == entry.id,
    );
    final availability = liveIndex < 0
        ? entry.availability
        : state.queue.entries[liveIndex].availability;
    if (availability == MediaAvailability.remoteUnavailable) return;

    final duration = entry.duration;
    final farEnough =
        duration != null &&
        duration > Duration.zero &&
        _listeningFurthest.inMilliseconds >=
            duration.inMilliseconds * _listenFraction;
    if (!completed && !farEnough && _listeningFurthest < _listenThreshold) {
      return;
    }

    _listeningRecorded = true;
    unawaited(
      _history.record(
        ListeningPlay(
          context: _listeningContextFor(entry),
          playedAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  /// What a play of [entry] is about: its album if it has one, else its
  /// artist, else the track on its own. This is what history collapses on
  /// — an album played straight through is one thing the user did.
  ListeningContext _listeningContextFor(QueueEntry entry) {
    if (entry.albumId case final MediaId albumId) {
      return ListeningContext(
        kind: ListeningContextKind.album,
        id: albumId,
        name: entry.albumName ?? entry.title,
        subtitle: entry.artist,
        image: entry.image,
      );
    }
    final primary = entry.artists.primary;
    if (primary?.id case final MediaId artistId) {
      return ListeningContext(
        kind: ListeningContextKind.artist,
        id: artistId,
        name: primary!.name,
      );
    }
    return ListeningContext(
      kind: ListeningContextKind.track,
      id: entry.id,
      name: entry.title,
      subtitle: entry.artist,
      image: entry.image,
    );
  }

  // ---- Jellyfin play sessions (v0.4.1) ----

  /// Switches the open Jellyfin play session to [entry] — closing the
  /// previous one, opening a new one — and retargets listening history at
  /// the same point.
  ///
  /// Every path that changes which entry is playing goes through here:
  /// starting a queue, a manual skip, a tap on a queue row, an
  /// engine-driven advance, a repeat-one loop. Reporting used to hang off
  /// the engine's index stream alone, which every one of those except the
  /// last silently bypassed, so the server saw no session at all for a
  /// track the user chose by hand.
  void _beginEntry(QueueEntry? entry) {
    final previous = _reportedEntry;
    if (previous != null && previous.id != entry?.id) {
      unawaited(
        _progressRepository.reportStop(previous.id, position: state.position),
      );
    }
    final isNewSession = entry != null && previous?.id != entry.id;
    _reportedEntry = entry;
    if (isNewSession) unawaited(_progressRepository.reportStart(entry.id));
    _retargetListening(entry);
  }

  /// Closes the open session without opening another — playback stopped
  /// rather than moved on.
  void _closeReportedSession() {
    final open = _reportedEntry;
    if (open == null) return;
    _reportedEntry = null;
    unawaited(
      _progressRepository.reportStop(open.id, position: state.position),
    );
  }

  Future<void> _reportProgress({required bool isPaused}) async {
    final entry = _reportedEntry;
    if (entry == null) return;
    await _progressRepository.reportProgress(
      entry.id,
      position: state.position,
      isPaused: isPaused,
    );
  }

  /// Drops every cached address for [id] so the next load asks
  /// [AudioSourceResolver] again — the local file may have appeared or
  /// gone since (v0.4.1).
  void _forgetResolvedSource(MediaId id) =>
      _resolvedSources.removeWhere((key, _) => key.$1 == id);

  Future<void> _savePosition() async {
    await _queueRepository.savePosition(
      currentIndex: state.queue.currentIndex,
      position: state.position,
    );
    // The same tick keeps the server's session current (v0.4.1). Jellyfin
    // drops a session it stops hearing from, which is why a track played
    // to the end used to be the only one that ever reported a position.
    unawaited(_reportProgress(isPaused: !state.isPlaying));
  }

  /// The explanation an entry gets when no address could be worked out
  /// for it at all — no file on the device and no reachable server.
  static const String _unresolvableReason =
      'No file on this device, and the server could not be reached.';

  @override
  Future<void> close() {
    // The app or this cubit is going away mid-track; a track listened to
    // for long enough by now is still a play.
    _flushListening(completed: false);
    _closeReportedSession();
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
