import 'package:injectable/injectable.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/media/media.dart';
import 'paged_collection_cubit.dart';

/// The library's album artists.
@injectable
class ArtistsCubit extends PagedCollectionCubit<Artist> {
  ArtistsCubit(this._music, {super.pageSize});

  final MusicLibraryRepository _music;

  /// Set to search within artists instead of listing all of them.
  String? searchTerm;

  @override
  Future<Result<Page<Artist>>> fetch(PageRequest request) =>
      _music.artists(page: request, searchTerm: searchTerm);

  /// Narrows to [term] and starts the list again.
  Future<void> searchFor(String? term) {
    searchTerm = term;
    return reload();
  }
}

/// Albums, either the whole library's or one artist's.
@injectable
class AlbumsCubit extends PagedCollectionCubit<Album> {
  AlbumsCubit(this._music, {super.pageSize});

  final MusicLibraryRepository _music;

  /// When set, the albums of this artist, in release order.
  MediaId? artistId;
  String? searchTerm;

  @override
  Future<Result<Page<Album>>> fetch(PageRequest request) =>
      _music.albums(page: request, artistId: artistId, searchTerm: searchTerm);

  Future<void> forArtist(MediaId id) {
    artistId = id;
    return load();
  }

  Future<void> searchFor(String? term) {
    searchTerm = term;
    return reload();
  }
}

/// Songs: the whole library, one album's, or everything one artist plays
/// on.
@injectable
class SongsCubit extends PagedCollectionCubit<Track> {
  SongsCubit(this._music, {super.pageSize});

  final MusicLibraryRepository _music;

  MediaId? albumId;
  MediaId? artistId;
  String? searchTerm;

  @override
  Future<Result<Page<Track>>> fetch(PageRequest request) => _music.tracks(
    page: request,
    albumId: albumId,
    artistId: artistId,
    searchTerm: searchTerm,
  );

  Future<void> forAlbum(MediaId id) {
    albumId = id;
    return load();
  }

  Future<void> forArtist(MediaId id) {
    artistId = id;
    return load();
  }

  Future<void> searchFor(String? term) {
    searchTerm = term;
    return reload();
  }
}

/// The user's playlists.
@injectable
class PlaylistsCubit extends PagedCollectionCubit<Playlist> {
  PlaylistsCubit(this._playlists, {super.pageSize});

  final PlaylistRepository _playlists;

  String? searchTerm;

  @override
  Future<Result<Page<Playlist>>> fetch(PageRequest request) =>
      _playlists.playlists(page: request, searchTerm: searchTerm);

  Future<void> searchFor(String? term) {
    searchTerm = term;
    return reload();
  }
}

/// One playlist's entries, in the order the user arranged them.
@injectable
class PlaylistTracksCubit extends PagedCollectionCubit<Track> {
  PlaylistTracksCubit(this._playlists, {super.pageSize});

  final PlaylistRepository _playlists;

  MediaId? playlistId;

  @override
  Future<Result<Page<Track>>> fetch(PageRequest request) {
    final id = playlistId;
    if (id == null) return Future.value(const Result.ok(Page<Track>.empty()));
    return _playlists.tracks(id, page: request);
  }

  Future<void> forPlaylist(MediaId id) {
    playlistId = id;
    return load();
  }
}
