import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/connectivity/OfflineMode.dart';
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
  ArtistsCubit(
    this._music,
    this.downloadsSource,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  final DownloadsLibrarySource downloadsSource;

  /// Set to search within artists instead of listing all of them.
  String? searchTerm;

  /// When set, only artists tagged with this genre (v0.4.5) — a decade
  /// has no artists equivalent (`MusicLibraryRepository.artists`'
  /// `genre`-only doc comment).
  String? genre;

  @override
  Future<Result<Page<Artist>>> fetch(PageRequest request) =>
      downloadedOnly && genre == null
      ? downloadsSource.artists(page: request, searchTerm: searchTerm)
      : _music.artists(page: request, searchTerm: searchTerm, genre: genre);

  /// Narrows to [term] and starts the list again.
  Future<void> searchFor(String? term) {
    searchTerm = term;
    return reload();
  }

  /// Narrows to every artist tagged with [name] and starts the list again
  /// — the genre shelf's "show all" (v0.4.5).
  Future<void> forGenre(String name) {
    genre = name;
    return load();
  }
}

/// Albums, either the whole library's or one artist's.
@injectable
class AlbumsCubit extends PagedCollectionCubit<Album>
    with DownloadedFilter<Album> {
  AlbumsCubit(
    this._music,
    this.downloadsSource,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  final DownloadsLibrarySource downloadsSource;

  /// When set, the albums of this artist, in release order.
  MediaId? artistId;
  String? searchTerm;

  /// When set, only albums in this genre (v0.4.4) — mutually exclusive
  /// with [artistId] and [decadeStart]; Library exploration never opens
  /// this cubit with more than one filter at a time.
  String? genre;

  /// When set, only albums from this decade (v0.4.4), e.g. `1990`.
  int? decadeStart;

  @override
  Future<Result<Page<Album>>> fetch(PageRequest request) =>
      downloadedOnly && artistId == null && genre == null && decadeStart == null
      ? downloadsSource.albums(page: request, searchTerm: searchTerm)
      : _music.albums(
          page: request,
          artistId: artistId,
          searchTerm: searchTerm,
          genre: genre,
          decadeStart: decadeStart,
        );

  Future<void> forArtist(MediaId id) {
    artistId = id;
    return load();
  }

  /// Narrows to every album in [name] and starts the list again — the
  /// genre shelf's "show all" (v0.4.4).
  Future<void> forGenre(String name) {
    genre = name;
    return load();
  }

  /// Narrows to every album released in the decade starting [startYear]
  /// (v0.4.4).
  Future<void> forDecade(int startYear) {
    decadeStart = startYear;
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
  SongsCubit(
    this._music,
    this.downloadsSource,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  final DownloadsLibrarySource downloadsSource;

  MediaId? albumId;
  MediaId? artistId;
  String? searchTerm;

  /// When set, only songs in this genre (v0.4.5) — mutually exclusive
  /// with [albumId]/[artistId]/[decadeStart], the same rule [AlbumsCubit]
  /// follows.
  String? genre;

  /// When set, only songs from this decade (v0.4.5).
  int? decadeStart;

  @override
  Future<Result<Page<Track>>> fetch(PageRequest request) =>
      downloadedOnly &&
          albumId == null &&
          artistId == null &&
          genre == null &&
          decadeStart == null
      ? downloadsSource.tracks(page: request, searchTerm: searchTerm)
      : _music.tracks(
          page: request,
          albumId: albumId,
          artistId: artistId,
          searchTerm: searchTerm,
          genre: genre,
          decadeStart: decadeStart,
        );

  Future<void> forAlbum(MediaId id) {
    albumId = id;
    return load();
  }

  Future<void> forArtist(MediaId id) {
    artistId = id;
    return load();
  }

  /// Narrows to every song in [name] and starts the list again — the
  /// genre shelf's "show all" (v0.4.5).
  Future<void> forGenre(String name) {
    genre = name;
    return load();
  }

  /// Narrows to every song released in the decade starting [startYear]
  /// (v0.4.5).
  Future<void> forDecade(int startYear) {
    decadeStart = startYear;
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
    this.downloadsSource,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

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
  PlaylistTracksCubit(
    this._playlists,
    OfflineMode offlineMode, {
    @ignoreParam super.pageSize,
  }) : super(offlineMode: offlineMode);

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

  /// Moves the loaded row at [from] to sit where the loaded row at [to]
  /// is — a drag, or a "move up"/"move down" on the playlist screen
  /// (v0.4.2). Answers with the [Failure] the server gave, or `null` when
  /// the playlist now reads the way the screen already shows it.
  ///
  /// Both indices are into [PagedCollectionState.items] — what the user
  /// is looking at. What Jellyfin needs is an absolute index into the
  /// whole playlist, unreadable entries included, and the two are only
  /// the same on a playlist that holds nothing but readable songs. That
  /// gap is why ADR-0024 deferred reorder rather than shipping a drag
  /// that silently moves the wrong entry; [PlaylistTrack.position] closes
  /// it, so the destination is read off the row being displaced and never
  /// computed from a screen position.
  ///
  /// The list is reordered locally first and put back if the server
  /// refuses. That is presentation, not a second writer: nothing local is
  /// saved, the server remains the only thing that decides what the
  /// playlist is (ADR-0024), and a successful move is followed by a
  /// reload so the numbering comes from the playlist rather than from
  /// this guess.
  Future<Failure?> moveEntry({required int from, required int to}) async {
    final id = playlistId;
    final items = state.items;
    if (id == null || from == to) return null;
    if (from < 0 || from >= items.length || to < 0 || to >= items.length) {
      return null;
    }

    final moved = items[from];
    final target = items[to];
    if (moved is! PlaylistTrack || target is! PlaylistTrack) {
      return const RecoverableFailure(
        'This copy of the playlist cannot be rearranged.',
      );
    }
    final entryId = moved.entryId;
    if (entryId == null) {
      return const RecoverableFailure('That row cannot be moved from here.');
    }

    // The row lands where the row it displaced sits. Moving down, the
    // server first lifts this row out, so everything below shifts up one
    // and the target's own index becomes the slot just after it; moving
    // up, the target has not moved and the row takes its place. Either
    // way the entries Jellyfinity cannot read keep the slots they had.
    final destination = target.position;

    final reordered = [...items];
    reordered.insert(to, reordered.removeAt(from));
    emit(state.copyWith(items: reordered));

    final result = await _playlists.moveEntry(id, entryId, destination);
    if (isClosed) return null;
    switch (result) {
      case Ok<void>():
        // Re-read rather than trusting the local shuffle: every row after
        // the move has a new position, and one of them may be an entry
        // this screen never showed.
        await refresh();
        return null;
      case Err<void>(:final failure):
        if (!isClosed) emit(state.copyWith(items: items));
        return failure;
    }
  }
}
