import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/connectivity/OfflineMode.dart';
import '../../../../domain/media/media.dart';
import '../offline_reload.dart';

/// The header of a detail screen: one item, or why there isn't one.
///
/// Separate from the tracks or albums below it on purpose. A screen that
/// waits for everything before drawing anything is the "generic spinner
/// on an empty page" `PHILOSOPHY.md` §2 rules out — the album title and
/// cover should be on screen while a long track list is still arriving,
/// and a failure in one half must not blank the other.
class MediaDetailState<T extends MediaItem> extends Equatable {
  const MediaDetailState({this.item, this.failure, this.isLoading = false});

  final T? item;
  final Failure? failure;
  final bool isLoading;

  bool get hasItem => item != null;

  /// Loaded, but the server could not be reached — what is shown is the
  /// saved copy.
  bool get isCached =>
      item?.availability == MediaAvailability.remoteUnavailable;

  @override
  List<Object?> get props => [item, failure, isLoading];
}

/// Loads one media item for a detail screen.
abstract class MediaDetailCubit<T extends MediaItem>
    extends Cubit<MediaDetailState<T>>
    with OfflineReload<MediaDetailState<T>> {
  MediaDetailCubit({OfflineMode? offlineMode}) : super(MediaDetailState<T>()) {
    bindOfflineReload(offlineMode);
  }

  Future<Result<T>> read(MediaId id);

  MediaId? _id;

  /// Bumped on every [open]; a slow read whose generation is stale — the
  /// offline switch flipped and re-opened underneath it — drops its
  /// result instead of overwriting the newer one (v0.2.3).
  int _generation = 0;

  /// Going on- or offline re-reads the item, once one has been opened —
  /// the server's live copy or the saved one.
  @override
  void onOfflineChanged() {
    if (_id != null) retry();
  }

  /// Loads [id], or reloads if it is the same one.
  Future<void> open(MediaId id) async {
    _id = id;
    final generation = ++_generation;
    if (isClosed) return;
    emit(MediaDetailState<T>(isLoading: true));

    final result = await read(id);
    if (isClosed || generation != _generation) return;

    switch (result) {
      case Ok<T>(:final value):
        emit(MediaDetailState<T>(item: value));
      case Err<T>(:final failure):
        emit(MediaDetailState<T>(failure: failure));
    }
  }

  Future<void> retry() async {
    final id = _id;
    if (id != null) await open(id);
  }
}

/// The artist a detail screen is about.
@injectable
class ArtistDetailCubit extends MediaDetailCubit<Artist> {
  ArtistDetailCubit(this._music, OfflineMode offlineMode)
    : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  Future<Result<Artist>> read(MediaId id) => _music.artist(id);
}

/// The album a detail screen is about — without its tracks, which page
/// in separately so the header can render first.
@injectable
class AlbumDetailCubit extends MediaDetailCubit<Album> {
  AlbumDetailCubit(this._music, OfflineMode offlineMode)
    : super(offlineMode: offlineMode);

  final MusicLibraryRepository _music;

  @override
  Future<Result<Album>> read(MediaId id) => _music.album(id);
}

/// The playlist a detail screen is about.
///
/// Read through [MediaMetadataRepository] rather than a playlist-specific
/// call: the contract already answers "what is this id", and a playlist
/// header needs nothing more than that.
@injectable
class PlaylistDetailCubit extends MediaDetailCubit<Playlist> {
  PlaylistDetailCubit(this._metadata, OfflineMode offlineMode)
    : super(offlineMode: offlineMode);

  final MediaMetadataRepository _metadata;

  @override
  Future<Result<Playlist>> read(MediaId id) async {
    final result = await _metadata.item(id);
    return switch (result) {
      Ok<MediaItem>(:final value) when value is Playlist => Result.ok(value),
      Ok<MediaItem>() => const Result.err(
        UnavailableFailure('That is not a playlist.'),
      ),
      Err<MediaItem>(:final failure) => Result.err(failure),
    };
  }
}
