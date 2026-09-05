import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/connectivity/OfflineMode.dart';
import '../../../../domain/media/media.dart';
import '../../../../infrastructure/downloads/DownloadsLibrarySource.dart';
import '../offline_reload.dart';

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
class MusicSearchCubit extends Cubit<MusicSearchState>
    with OfflineReload<MusicSearchState> {
  MusicSearchCubit(
    this._music,
    this._playlists,
    this._downloads, [
    OfflineMode? offlineMode,
  ]) : super(const MusicSearchState()) {
    bindOfflineReload(offlineMode);
  }

  final MusicLibraryRepository _music;
  final PlaylistRepository _playlists;

  /// Crossing on-/offline re-runs whatever is typed, so results switch
  /// between the server and the downloads without the user resubmitting.
  @override
  void onOfflineChanged() {
    final term = state.query.trim();
    if (term.isNotEmpty) _run(term);
  }

  /// The signed-in profile's downloads (v0.2.3): what the "Downloaded"
  /// filter searches directly, and what a search falls back to when the
  /// server cannot be reached — so an offline search still finds the
  /// music that can actually play.
  final DownloadsLibrarySource _downloads;

  bool _downloadedOnly = false;
  bool get downloadedOnly => _downloadedOnly;

  /// Turns the "Downloaded" filter on or off and re-runs the current
  /// query.
  Future<void> showDownloadedOnly(bool value) async {
    if (value == _downloadedOnly) return;
    _downloadedOnly = value;
    final term = state.query.trim();
    if (term.isNotEmpty) await _run(term);
  }

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

    var results = _downloadedOnly
        ? await _searchDownloads(window, term)
        : await _searchServer(window, term);

    // Offline, a music search would otherwise fail whole: fall back to
    // the downloads so the listener still finds what they can play
    // (v0.2.3). Only when every category failed — a partial failure is a
    // real, if incomplete, answer — and only when the downloads actually
    // match something, so an offline search with no local hits still
    // says "search needs the server" rather than a misleading "no
    // matches".
    if (!_downloadedOnly && results.every((r) => r is Err)) {
      final local = await _searchDownloads(window, term);
      final hasLocalHits = local.any(
        (result) =>
            result is Ok<Page<MediaItem>> && result.value.items.isNotEmpty,
      );
      if (hasLocalHits) results = local;
    }

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

  Future<List<Result<Page<MediaItem>>>> _searchServer(
    PageRequest window,
    String term,
  ) => Future.wait<Result<Page<MediaItem>>>([
    _music.artists(page: window, searchTerm: term),
    _music.albums(page: window, searchTerm: term),
    _music.tracks(page: window, searchTerm: term),
    _playlists.playlists(page: window, searchTerm: term),
  ]);

  Future<List<Result<Page<MediaItem>>>> _searchDownloads(
    PageRequest window,
    String term,
  ) => Future.wait<Result<Page<MediaItem>>>([
    _downloads.artists(page: window, searchTerm: term),
    _downloads.albums(page: window, searchTerm: term),
    _downloads.tracks(page: window, searchTerm: term),
    _downloads.playlists(page: window, searchTerm: term),
  ]);

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
