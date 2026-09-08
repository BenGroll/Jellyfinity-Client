import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/Album.dart';
import '../../../domain/media/MusicLibraryRepository.dart';
import '../../../domain/media/page.dart';

enum RecentlyAddedStatus {
  /// Nothing asked for yet.
  initial,

  /// The first read is running — nothing to show but a skeleton.
  loading,

  /// [RecentlyAddedState.albums] is current (possibly empty).
  loaded,

  /// The first read failed and there is nothing saved to fall back to.
  failed,
}

/// Home's "Recently added" section (v0.3.3, ADR-0027).
///
/// One extra library query — the newest albums by the date the server
/// acquired them — behind the same section shape `RecentlyPlayedCubit`
/// established (ADR-0026): it owns only its own loading / empty / failed
/// state, and a failure here leaves the rest of Home standing.
///
/// It does **not** watch `OfflineCubit` or apply an offline policy. The
/// repository already answers from the saved copy when the server cannot
/// be reached ([RecentlyAddedState.isCached] then reports it); whether a
/// *server* fact is honest to present while offline is decided at the
/// widget layer, where the offline scope already lives.
class RecentlyAddedState extends Equatable {
  const RecentlyAddedState({
    this.status = RecentlyAddedStatus.initial,
    this.albums = const [],
    this.isCached = false,
    this.failure,
  });

  final RecentlyAddedStatus status;
  final List<Album> albums;

  /// What is on screen came from the saved copy, not a fresh server read.
  /// The section marks it rather than passing it off as current.
  final bool isCached;

  /// The most recent read failure. Present only alongside
  /// [RecentlyAddedStatus.failed] — a failed refresh that still has rows
  /// keeps showing them and drops the failure.
  final Failure? failure;

  /// Loaded, and the library has no albums (or none the server would
  /// call recent): the section is absent rather than an empty box.
  bool get isEmpty => status == RecentlyAddedStatus.loaded && albums.isEmpty;

  @override
  List<Object?> get props => [status, albums, isCached, failure];
}

@injectable
class RecentlyAddedCubit extends Cubit<RecentlyAddedState> {
  RecentlyAddedCubit(this._music) : super(const RecentlyAddedState());

  final MusicLibraryRepository _music;

  /// How many albums the strip pulls. A bounded top-N — Home never pages
  /// this — kept small so the app's busiest screen stays cheap.
  static const int limit = 20;

  /// The first load — shows a skeleton while it runs. A no-op once a load
  /// is already in flight or the data is already here (use [refresh] to
  /// re-read).
  Future<void> load() async {
    if (state.status == RecentlyAddedStatus.loading) return;
    if (state.status == RecentlyAddedStatus.initial ||
        state.status == RecentlyAddedStatus.failed) {
      emit(const RecentlyAddedState(status: RecentlyAddedStatus.loading));
    }
    await _read();
  }

  /// Re-reads without clearing the screen — a pull-to-refresh, or a
  /// return to the tab after time away.
  Future<void> refresh() => _read();

  /// Retries after [RecentlyAddedStatus.failed].
  Future<void> retry() => load();

  Future<void> _read() async {
    final result = await _music.recentlyAddedAlbums(
      page: const PageRequest.first(limit: limit),
    );
    if (isClosed) return;
    switch (result) {
      case Ok<Page<Album>>(:final value):
        emit(
          RecentlyAddedState(
            status: RecentlyAddedStatus.loaded,
            albums: value.items,
            isCached: value.isCached,
          ),
        );
      case Err<Page<Album>>(:final failure):
        // A read that fails with rows already on screen keeps them; only
        // an empty section actually shows the error.
        emit(
          RecentlyAddedState(
            status: state.albums.isEmpty
                ? RecentlyAddedStatus.failed
                : RecentlyAddedStatus.loaded,
            albums: state.albums,
            isCached: state.isCached,
            failure: state.albums.isEmpty ? failure : null,
          ),
        );
    }
  }
}
