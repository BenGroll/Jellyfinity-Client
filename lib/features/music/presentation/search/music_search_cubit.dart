import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/media/media.dart';

/// Which kind of music a set of results is.
///
/// The order is the order the results are shown in, which is the priority
/// `ROADMAP.md` gives for music search: artists, albums, songs, then
/// playlists.
enum SearchCategory {
  artists('Artists'),
  albums('Albums'),
  songs('Songs'),
  playlists('Playlists');

  const SearchCategory(this.label);

  final String label;

  /// Parses the `:category` path segment of the "show all" route.
  static SearchCategory? tryParse(String value) {
    for (final category in values) {
      if (category.name == value) return category;
    }
    return null;
  }
}

/// One category's slice of a search.
class SearchSection<T extends MediaItem> extends Equatable {
  const SearchSection({this.items = const [], this.total = 0, this.failure});

  /// The handful shown on the search screen — never the whole match set.
  final List<T> items;

  /// How many matches there are in total, so the screen can offer the
  /// rest without having loaded it.
  final int total;

  /// This category failed while the others may have succeeded. One dead
  /// category does not fail the search (`PHILOSOPHY.md` §2).
  final Failure? failure;

  bool get isEmpty => items.isEmpty && failure == null;
  bool get hasMore => total > items.length;

  @override
  List<Object?> get props => [items, total, failure];
}

enum MusicSearchStatus {
  /// Nothing typed yet.
  idle,

  /// A search is running. Previous results stay on screen until the new
  /// ones replace them.
  searching,

  /// Results are current for [MusicSearchState.query].
  results,
}

class MusicSearchState extends Equatable {
  const MusicSearchState({
    this.query = '',
    this.status = MusicSearchStatus.idle,
    this.artists = const SearchSection<Artist>(),
    this.albums = const SearchSection<Album>(),
    this.songs = const SearchSection<Track>(),
    this.playlists = const SearchSection<Playlist>(),
  });

  final String query;
  final MusicSearchStatus status;
  final SearchSection<Artist> artists;
  final SearchSection<Album> albums;
  final SearchSection<Track> songs;
  final SearchSection<Playlist> playlists;

  /// The search ran and matched nothing anywhere.
  bool get foundNothing =>
      status == MusicSearchStatus.results &&
      artists.isEmpty &&
      albums.isEmpty &&
      songs.isEmpty &&
      playlists.isEmpty &&
      !hasFailure;

  /// At least one category could not be searched.
  bool get hasFailure =>
      artists.failure != null ||
      albums.failure != null ||
      songs.failure != null ||
      playlists.failure != null;

  /// Every category failed — which is what an unreachable server looks
  /// like, and is worth saying once instead of four times.
  Failure? get wholeSearchFailure {
    final failures = [
      artists.failure,
      albums.failure,
      songs.failure,
      playlists.failure,
    ];
    if (failures.any((failure) => failure == null)) return null;
    return failures.first;
  }

  @override
  List<Object?> get props => [query, status, artists, albums, songs, playlists];
}

/// Music-scoped search.
///
/// `PHILOSOPHY.md` §8: a search started from Music searches music, and
/// keeps its categories apart rather than pouring artists, albums, songs
/// and playlists into one list that happens to be sorted by name. Each
/// category is its own server-side query with its own small window, which
/// is also why one failing category cannot take the others down.
///
/// Typing is debounced, and a result that arrives after the query has
/// moved on is discarded — otherwise a slow answer to "mil" overwrites a
/// fast answer to "miles".
@injectable
class MusicSearchCubit extends Cubit<MusicSearchState> {
  MusicSearchCubit(this._music, this._playlists)
    : super(const MusicSearchState());

  final MusicLibraryRepository _music;
  final PlaylistRepository _playlists;

  /// Long enough to skip the letters of a word being typed, short enough
  /// that results feel like they are keeping up.
  static const Duration debounce = Duration(milliseconds: 300);

  /// How many of each category the search screen shows before "show all".
  static const int previewLimit = 5;

  Timer? _timer;
  int _generation = 0;

  /// Called on every keystroke.
  void queryChanged(String value) {
    _timer?.cancel();
    final term = value.trim();

    if (term.isEmpty) {
      _generation++;
      emit(const MusicSearchState());
      return;
    }

    emit(
      MusicSearchState(
        query: value,
        status: MusicSearchStatus.searching,
        artists: state.artists,
        albums: state.albums,
        songs: state.songs,
        playlists: state.playlists,
      ),
    );
    _timer = Timer(debounce, () => _run(term));
  }

  /// Runs the current query immediately, skipping the debounce.
  Future<void> submit() async {
    _timer?.cancel();
    final term = state.query.trim();
    if (term.isNotEmpty) await _run(term);
  }

  Future<void> _run(String term) async {
    final generation = ++_generation;
    const window = PageRequest(startIndex: 0, limit: previewLimit);

    final results = await Future.wait([
      _music.artists(page: window, searchTerm: term),
      _music.albums(page: window, searchTerm: term),
      _music.tracks(page: window, searchTerm: term),
      _playlists.playlists(page: window, searchTerm: term),
    ]);

    // The user kept typing while these were in flight.
    if (isClosed || generation != _generation) return;

    emit(
      MusicSearchState(
        query: state.query,
        status: MusicSearchStatus.results,
        artists: _section<Artist>(results[0] as Result<Page<Artist>>),
        albums: _section<Album>(results[1] as Result<Page<Album>>),
        songs: _section<Track>(results[2] as Result<Page<Track>>),
        playlists: _section<Playlist>(results[3] as Result<Page<Playlist>>),
      ),
    );
  }

  SearchSection<T> _section<T extends MediaItem>(Result<Page<T>> result) {
    return switch (result) {
      Ok<Page<T>>(:final value) => SearchSection<T>(
        items: value.items,
        total: value.totalCount,
      ),
      Err<Page<T>>(:final failure) => SearchSection<T>(failure: failure),
    };
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
