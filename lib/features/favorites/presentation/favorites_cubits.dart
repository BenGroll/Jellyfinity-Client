import 'package:injectable/injectable.dart';

import '../../../core/result/result.dart';
import '../../../domain/connectivity/OfflineMode.dart';
import '../../../domain/media/media.dart';
import '../../music/presentation/library/paged_collection_cubit.dart';

/// The three lists behind the Favorites destination (v0.3.4, ADR-0028):
/// the profile's favorite artists, albums and songs, each an ordinary
/// paged collection — same paging, same states, same offline reload — over
/// its own `MusicLibraryRepository` read.
///
/// They carry no `DownloadedFilter`: Favorites is already "a subset the
/// user curated", and offline it answers from the per-profile favorites
/// cache rather than from downloads. A song that is not on the device
/// still shows in the list (marked unplayable), the same way the Library's
/// Songs tab treats a server-only track.

@injectable
class FavoriteArtistsCubit extends PagedCollectionCubit<Artist> {
  FavoriteArtistsCubit(
    this._music,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  Future<Result<Page<Artist>>> fetch(PageRequest request) =>
      _music.favoriteArtists(page: request);
}

@injectable
class FavoriteAlbumsCubit extends PagedCollectionCubit<Album> {
  FavoriteAlbumsCubit(
    this._music,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  Future<Result<Page<Album>>> fetch(PageRequest request) =>
      _music.favoriteAlbums(page: request);
}

@injectable
class FavoriteTracksCubit extends PagedCollectionCubit<Track> {
  FavoriteTracksCubit(
    this._music,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  Future<Result<Page<Track>>> fetch(PageRequest request) =>
      _music.favoriteTracks(page: request);
}
