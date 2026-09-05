import 'package:injectable/injectable.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/media/media.dart';
import '../../../../infrastructure/downloads/DownloadsLibrarySource.dart';
import 'paged_collection_cubit.dart';

/// The "Downloaded" filter (v0.2.3) the library tabs and search share.
///
/// When on, a collection cubit reads the signed-in profile's downloads
/// through [DownloadsLibrarySource] instead of the server-backed
/// repository, so a listener can find what they have kept — the same
/// screens, filtered to what plays without a connection.
mixin DownloadedFilter<T extends MediaItem> on PagedCollectionCubit<T> {
  DownloadsLibrarySource get downloadsSource;

  bool _downloadedOnly = false;
  bool get downloadedOnly => _downloadedOnly;

  /// Turns the filter on or off and reloads the list from the start.
  Future<void> showDownloadedOnly(bool value) {
    if (value == _downloadedOnly) return Future<void>.value();
    _downloadedOnly = value;
    return reload();
  }
}

/// The library's album artists.
@injectable
class ArtistsCubit extends PagedCollectionCubit<Artist>
    with DownloadedFilter<Artist> {
  ArtistsCubit(this._music, this.downloadsSource, {@ignoreParam super.pageSize});

  final MusicLibraryRepository _music;

  @override
  final DownloadsLibrarySource downloadsSource;

  /// Set to search within artists instead of listing all of them.
  String? searchTerm;

  @override
  Future<Result<Page<Artist>>> fetch(PageRequest request) => downloadedOnly
      ? downloadsSource.artists(page: request, searchTerm: searchTerm)
      : _music.artists(page: request, searchTerm: searchTerm);

  /// Narrows to [term] and starts the list again.
  Future<void> searchFor(String? term) {
    searchTerm = term;
    return reload();
  }
}

/// Albums, either the whole library's or one artist's.
@injectable
class AlbumsCubit extends PagedCollectionCubit<Album>
    with DownloadedFilter<Album> {
  AlbumsCubit(this._music, this.downloadsSource, {@ignoreParam super.pageSize});

  final MusicLibraryRepository _music;

  @override
  final DownloadsLibrarySource downloadsSource;

  /// When set, the albums of this artist, in release order.
  MediaId? artistId;
  String? searchTerm;

  @override
  Future<Result<Page<Album>>> fetch(PageRequest request) =>
      downloadedOnly && artistId == null
      ? downloadsSource.albums(page: request, searchTerm: searchTerm)
      : _music.albums(page: request, artistId: artistId, searchTerm: searchTerm);

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
class SongsCubit extends PagedCollectionCubit<Track>
    with DownloadedFilter<Track> {
  SongsCubit(this._music, this.downloadsSource, {@ignoreParam super.pageSize});

  final MusicLibraryRepository _music;

  @override
  final DownloadsLibrarySource downloadsSource;

  MediaId? albumId;
  MediaId? artistId;
  String? searchTerm;

  @override
  Future<Result<Page<Track>>> fetch(PageRequest request) =>
      downloadedOnly && albumId == null && artistId == null
      ? downloadsSource.tracks(page: request, searchTerm: searchTerm)
      : _music.tracks(
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
class PlaylistsCubit extends PagedCollectionCubit<Playlist>
    with DownloadedFilter<Playlist> {
  PlaylistsCubit(
    this._playlists,
    this.downloadsSource, {
    @ignoreParam super.pageSize,
  });

  final PlaylistRepository _playlists;

  @override
  final DownloadsLibrarySource downloadsSource;

  String? searchTerm;

  @override
  Future<Result<Page<Playlist>>> fetch(PageRequest request) => downloadedOnly
      ? downloadsSource.playlists(page: request, searchTerm: searchTerm)
      : _playlists.playlists(page: request, searchTerm: searchTerm);

  Future<void> searchFor(String? term) {
    searchTerm = term;
    return reload();
  }
}

/// One playlist's entries, in the order the user arranged them.
@injectable
class PlaylistTracksCubit extends PagedCollectionCubit<Track> {
  PlaylistTracksCubit(this._playlists, {@ignoreParam super.pageSize});

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
