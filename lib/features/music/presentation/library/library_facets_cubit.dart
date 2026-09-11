import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/connectivity/OfflineMode.dart';
import '../../../../domain/media/MusicLibraryRepository.dart';
import '../offline_reload.dart';

/// The Explore tab's genre and decade shelves (v0.4.4, ADR-0034).
///
/// Two independent facets in one cubit because they are read together, on
/// the same screen, on the same live-only terms — but each keeps its own
/// loading/failure state rather than being folded into one, so a server
/// that only supports one of `/MusicGenres` and `/Years` still shows the
/// shelf it can answer. A failure here is shown, unlike
/// `RelatedMediaCubit`'s: genre and decade browsing is a primary entry
/// point into the library, not a bonus strip, so "unavailable offline"
/// has to be said rather than silently hidden.
class LibraryFacetsState extends Equatable {
  const LibraryFacetsState({
    this.genres = const [],
    this.genresLoading = false,
    this.genresFailure,
    this.decades = const [],
    this.decadesLoading = false,
    this.decadesFailure,
  });

  final List<String> genres;
  final bool genresLoading;
  final Failure? genresFailure;

  final List<int> decades;
  final bool decadesLoading;
  final Failure? decadesFailure;

  bool get hasLoadedGenres => genresLoading == false && genresFailure == null;
  bool get hasLoadedDecades =>
      decadesLoading == false && decadesFailure == null;

  LibraryFacetsState copyWith({
    List<String>? genres,
    bool? genresLoading,
    Failure? genresFailure,
    bool clearGenresFailure = false,
    List<int>? decades,
    bool? decadesLoading,
    Failure? decadesFailure,
    bool clearDecadesFailure = false,
  }) {
    return LibraryFacetsState(
      genres: genres ?? this.genres,
      genresLoading: genresLoading ?? this.genresLoading,
      genresFailure: clearGenresFailure
          ? null
          : (genresFailure ?? this.genresFailure),
      decades: decades ?? this.decades,
      decadesLoading: decadesLoading ?? this.decadesLoading,
      decadesFailure: clearDecadesFailure
          ? null
          : (decadesFailure ?? this.decadesFailure),
    );
  }

  @override
  List<Object?> get props => [
    genres,
    genresLoading,
    genresFailure,
    decades,
    decadesLoading,
    decadesFailure,
  ];
}

@injectable
class LibraryFacetsCubit extends Cubit<LibraryFacetsState>
    with OfflineReload<LibraryFacetsState> {
  LibraryFacetsCubit(this._music, OfflineMode offlineMode)
    : super(const LibraryFacetsState()) {
    bindOfflineReload(offlineMode);
  }

  final MusicLibraryRepository _music;

  bool _opened = false;

  /// Coming back online is the chance to fill a shelf that read
  /// "unavailable offline".
  @override
  void onOfflineChanged() {
    if (_opened) _reload();
  }

  /// Loads both shelves. Safe to call on every build, like
  /// `PagedCollectionCubit.load`: returning to the tab must not re-ask a
  /// server that already answered.
  Future<void> load() async {
    if (_opened) return;
    _opened = true;
    await _reload();
  }

  Future<void> _reload() => Future.wait([_loadGenres(), _loadDecades()]);

  Future<void> _loadGenres() async {
    emit(state.copyWith(genresLoading: true, clearGenresFailure: true));
    final result = await _music.genres();
    if (isClosed) return;
    switch (result) {
      case Ok<List<String>>(:final value):
        emit(state.copyWith(genres: value, genresLoading: false));
      case Err<List<String>>(:final failure):
        emit(
          state.copyWith(
            genres: const [],
            genresLoading: false,
            genresFailure: failure,
          ),
        );
    }
  }

  Future<void> _loadDecades() async {
    emit(state.copyWith(decadesLoading: true, clearDecadesFailure: true));
    final result = await _music.decades();
    if (isClosed) return;
    switch (result) {
      case Ok<List<int>>(:final value):
        emit(state.copyWith(decades: value, decadesLoading: false));
      case Err<List<int>>(:final failure):
        emit(
          state.copyWith(
            decades: const [],
            decadesLoading: false,
            decadesFailure: failure,
          ),
        );
    }
  }
}
