import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/media/media.dart';

enum PlaylistEditStatus { initial, loading, ready, failed }

/// The full, editable form of one playlist: every track, in order, with
/// its entry id — as opposed to `PlaylistTracksCubit`'s windowed, browse-
/// only reading of the same playlist.
///
/// Loaded in full (paged internally) only when editing starts, because
/// reordering and removing need the whole ordered list on hand; ordinary
/// browsing keeps using the windowed cubit so opening a playlist never
/// pays this cost.
class PlaylistEditState extends Equatable {
  const PlaylistEditState({
    this.status = PlaylistEditStatus.initial,
    this.editing = false,
    this.tracks = const [],
    this.failure,
  });

  final PlaylistEditStatus status;

  /// Whether the edit UI (reorder handles, remove buttons) is showing.
  final bool editing;

  /// Every track in the playlist, in order. Only meaningful once
  /// [status] is [PlaylistEditStatus.ready].
  final List<Track> tracks;

  final Failure? failure;

  bool get isReady => status == PlaylistEditStatus.ready;

  PlaylistEditState copyWith({
    PlaylistEditStatus? status,
    bool? editing,
    List<Track>? tracks,
    Failure? failure,
  }) {
    return PlaylistEditState(
      status: status ?? this.status,
      editing: editing ?? this.editing,
      tracks: tracks ?? this.tracks,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, editing, tracks, failure];
}

/// Drives edit mode on `PlaylistDetailPage`: loading the full playlist,
/// and reordering/removing against `PlaylistEditor`.
///
/// Every mutation updates the in-memory list immediately so a drag or a
/// remove feels instant, then confirms against the server; a failed
/// confirmation re-reads the whole playlist rather than trying to
/// reverse the local edit; the server is always right (ADR-0016).
@injectable
class PlaylistEditCubit extends Cubit<PlaylistEditState> {
  PlaylistEditCubit(this._playlists, this._editor)
    : super(const PlaylistEditState());

  final PlaylistRepository _playlists;
  final PlaylistEditor _editor;

  static const int _pageSize = 200;

  MediaId? _playlistId;

  /// Turns edit mode on for [playlistId], loading its full track list if
  /// this is the first time.
  Future<void> startEditing(MediaId playlistId) async {
    _playlistId = playlistId;
    emit(state.copyWith(editing: true));
    await _load();
  }

  void stopEditing() {
    if (isClosed) return;
    emit(state.copyWith(editing: false));
  }

  Future<void> retry() => _load();

  /// [oldIndex]/[newIndex] come from `ReorderableListView`'s
  /// `onReorderItem`, whose `newIndex` is already adjusted for the
  /// removed item — usable directly with `removeAt`/`insert`, unlike the
  /// deprecated `onReorder` callback.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final playlistId = _playlistId;
    if (playlistId == null || !state.isReady || oldIndex == newIndex) return;

    final tracks = [...state.tracks];
    final moved = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, moved);
    emit(state.copyWith(tracks: tracks));

    final entryId = moved.playlistEntryId;
    if (entryId == null) return;
    final result = await _editor.moveEntry(
      playlistId,
      entryId: entryId,
      newIndex: newIndex,
    );
    if (isClosed) return;
    if (result case Err<void>()) await _load();
  }

  Future<void> remove(Track track) async {
    final playlistId = _playlistId;
    final entryId = track.playlistEntryId;
    if (playlistId == null || entryId == null || !state.isReady) return;

    emit(
      state.copyWith(
        tracks: state.tracks
            .where((t) => t.playlistEntryId != entryId)
            .toList(growable: false),
      ),
    );

    final result = await _editor.removeEntries(playlistId, [entryId]);
    if (isClosed) return;
    if (result case Err<void>()) await _load();
  }

  Future<void> _load() async {
    final playlistId = _playlistId;
    if (playlistId == null) return;
    emit(state.copyWith(status: PlaylistEditStatus.loading));

    final tracks = <Track>[];
    PageRequest? request = const PageRequest.first(limit: _pageSize);
    while (request != null) {
      final result = await _playlists.tracks(playlistId, page: request);
      if (isClosed) return;
      if (result case Err<Page<Track>>(:final failure)) {
        emit(
          state.copyWith(status: PlaylistEditStatus.failed, failure: failure),
        );
        return;
      }
      final page = (result as Ok<Page<Track>>).value;
      tracks.addAll(page.items);
      request = page.nextRequest(limit: _pageSize);
    }

    emit(state.copyWith(status: PlaylistEditStatus.ready, tracks: tracks));
  }
}
