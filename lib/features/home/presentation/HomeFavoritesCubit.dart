import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/Album.dart';
import '../../../domain/media/artist.dart';
import '../../../domain/media/MusicLibraryRepository.dart';
import '../../../domain/media/page.dart';

enum HomeFavoritesStatus { initial, loading, loaded, failed }

/// Home's "Favorites" section (v0.3.4, ADR-0028).
///
/// A bounded peek at the profile's favorite albums and artists — the
/// section header opens the full Favorites destination — behind the same
/// shape `RecentlyAddedCubit` established (ADR-0027): it owns only its own
/// loading / empty / failed state, a failure here leaves the rest of Home
/// standing, and a failed refresh that still has rows keeps them.
///
/// Songs are left off the strip: a favorite song has no card and nowhere
/// to navigate (there is no track screen), and the destination's Songs
/// tab is where they live.
class HomeFavoritesState extends Equatable {
  const HomeFavoritesState({
    this.status = HomeFavoritesStatus.initial,
    this.albums = const [],
    this.artists = const [],
    this.isCached = false,
    this.failure,
  });

  final HomeFavoritesStatus status;
  final List<Album> albums;
  final List<Artist> artists;

  /// What is on screen came from the saved copy, not a fresh read.
  final bool isCached;

  final Failure? failure;

  bool get isEmpty =>
      status == HomeFavoritesStatus.loaded && albums.isEmpty && artists.isEmpty;

  @override
  List<Object?> get props => [status, albums, artists, isCached, failure];
}

@injectable
class HomeFavoritesCubit extends Cubit<HomeFavoritesState> {
  HomeFavoritesCubit(this._music) : super(const HomeFavoritesState());

  final MusicLibraryRepository _music;

  /// How many of each the strip pulls. A small top-N — Home never pages
  /// this — kept cheap for the app's busiest screen.
  static const int limit = 12;

  Future<void> load() async {
    if (state.status == HomeFavoritesStatus.loading) return;
    if (state.status == HomeFavoritesStatus.initial ||
        state.status == HomeFavoritesStatus.failed) {
      emit(const HomeFavoritesState(status: HomeFavoritesStatus.loading));
    }
    await _read();
  }

  Future<void> refresh() => _read();

  Future<void> retry() => load();

  Future<void> _read() async {
    const page = PageRequest.first(limit: limit);
    final results = await Future.wait([
      _music.favoriteAlbums(page: page),
      _music.favoriteArtists(page: page),
    ]);
    if (isClosed) return;

    final albumsResult = results[0] as Result<Page<Album>>;
    final artistsResult = results[1] as Result<Page<Artist>>;

    // One list answering is enough for a section; both failing is the
    // only real failure.
    if (albumsResult is Err<Page<Album>> &&
        artistsResult is Err<Page<Artist>>) {
      emit(
        HomeFavoritesState(
          status: (state.albums.isEmpty && state.artists.isEmpty)
              ? HomeFavoritesStatus.failed
              : HomeFavoritesStatus.loaded,
          albums: state.albums,
          artists: state.artists,
          isCached: state.isCached,
          failure: (state.albums.isEmpty && state.artists.isEmpty)
              ? albumsResult.failure
              : null,
        ),
      );
      return;
    }

    final albums = switch (albumsResult) {
      Ok<Page<Album>>(:final value) => value,
      Err<Page<Album>>() => null,
    };
    final artists = switch (artistsResult) {
      Ok<Page<Artist>>(:final value) => value,
      Err<Page<Artist>>() => null,
    };

    emit(
      HomeFavoritesState(
        status: HomeFavoritesStatus.loaded,
        albums: albums?.items ?? state.albums,
        artists: artists?.items ?? state.artists,
        isCached: (albums?.isCached ?? false) || (artists?.isCached ?? false),
      ),
    );
  }
}
