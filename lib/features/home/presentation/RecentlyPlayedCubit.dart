import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/ListeningHistoryEntry.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/media/MediaItem.dart';
import '../../../domain/media/MediaMetadataRepository.dart';
import '../../../domain/media/ListeningHistoryRepository.dart';
import '../../../domain/media/Track.dart';

enum RecentlyPlayedStatus {
  /// Nothing asked for yet.
  initial,

  /// The first read is running — nothing to show but a skeleton.
  loading,

  /// [RecentlyPlayedState.entries] is current (possibly empty).
  loaded,

  /// The first read failed and there is nothing to fall back to.
  failed,
}

/// Home's "Recently played" section (v0.3.2).
///
/// A read-only view of v0.3.1's listening history (ADR-0025): the distinct
/// albums, artists and single tracks this profile actually returned to,
/// newest first. It owns only its own loading/empty/failure — a failure
/// here leaves the rest of Home standing, the same rule `MusicSearchCubit`
/// follows for its categories (`PHILOSOPHY.md` §2).
class RecentlyPlayedState extends Equatable {
  const RecentlyPlayedState({
    this.status = RecentlyPlayedStatus.initial,
    this.entries = const [],
    this.failure,
  });

  final RecentlyPlayedStatus status;
  final List<ListeningHistoryEntry> entries;

  /// The most recent read failure. Present only alongside
  /// [RecentlyPlayedStatus.failed] — a failed refresh that still has rows
  /// keeps showing them and drops the failure.
  final Failure? failure;

  /// Loaded, and this profile has listened to nothing yet: the section is
  /// absent rather than an empty box.
  bool get isEmpty => status == RecentlyPlayedStatus.loaded && entries.isEmpty;

  @override
  List<Object?> get props => [status, entries, failure];
}

@injectable
class RecentlyPlayedCubit extends Cubit<RecentlyPlayedState> {
  RecentlyPlayedCubit(this._history, this._metadata)
    : super(const RecentlyPlayedState());

  final ListeningHistoryRepository _history;
  final MediaMetadataRepository _metadata;

  /// How many contexts Home's strip pulls. The store keeps at most 100
  /// per profile (ADR-0025); a Home section shows the freshest slice of
  /// that, not the whole cap.
  static const int limit = 20;

  /// The first load — shows a skeleton while it runs. A no-op once a load
  /// is already in flight or the data is already here (use [refresh] to
  /// re-read).
  Future<void> load() async {
    if (state.status == RecentlyPlayedStatus.loading) return;
    if (state.status == RecentlyPlayedStatus.initial ||
        state.status == RecentlyPlayedStatus.failed) {
      emit(const RecentlyPlayedState(status: RecentlyPlayedStatus.loading));
    }
    await _read();
  }

  /// Re-reads without clearing the screen — a pull-to-refresh, and what
  /// Home calls when a track starts playing while it is in the background,
  /// so the strip is current by the time the user comes back to it.
  Future<void> refresh() => _read();

  /// Retries after [RecentlyPlayedStatus.failed].
  Future<void> retry() => load();

  Future<void> _read() async {
    final result = await _history.recent(limit: limit);
    if (isClosed) return;
    switch (result) {
      case Ok<List<ListeningHistoryEntry>>(:final value):
        emit(
          RecentlyPlayedState(
            status: RecentlyPlayedStatus.loaded,
            entries: value,
          ),
        );
      case Err<List<ListeningHistoryEntry>>(:final failure):
        // A read that fails with rows already on screen keeps them; only
        // an empty section actually shows the error.
        emit(
          RecentlyPlayedState(
            status: state.entries.isEmpty
                ? RecentlyPlayedStatus.failed
                : RecentlyPlayedStatus.loaded,
            entries: state.entries,
            failure: state.entries.isEmpty ? failure : null,
          ),
        );
    }
  }

  /// Resolves the [Track] behind a `track`-kind row so Home can play it —
  /// there is no track detail screen to open, and a single played on its
  /// own is only useful as something to hear again. Offline this answers
  /// from the local copy where there is one (ADR-0023) and fails cleanly
  /// otherwise, which Home turns into a "not playable right now" row.
  Future<Result<Track>> resolveTrack(MediaId id) async {
    final result = await _metadata.item(id);
    return switch (result) {
      Ok<MediaItem>(:final value) when value is Track => Result.ok(value),
      Ok<MediaItem>() => const Result.err(
        UnavailableFailure('That is no longer a track.'),
      ),
      Err<MediaItem>(:final failure) => Result.err(failure),
    };
  }
}
