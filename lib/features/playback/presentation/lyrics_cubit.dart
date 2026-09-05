import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/playback/Lyrics.dart';
import '../../../domain/playback/LyricsResolver.dart';

/// One track's lyrics for the Lyrics view (v0.1.5).
///
/// Page-scoped like `TrackSourceInfoCubit`, not app-wide state: only the
/// Lyrics view needs this, for whichever track is current.
///
/// `lyrics == null` after loading means "this track has no lyrics" — an
/// empty state, not [failure].
class LyricsState extends Equatable {
  const LyricsState({this.lyrics, this.failure, this.isLoading = false});

  final Lyrics? lyrics;
  final Failure? failure;
  final bool isLoading;

  @override
  List<Object?> get props => [lyrics, failure, isLoading];
}

@injectable
class LyricsCubit extends Cubit<LyricsState> {
  LyricsCubit(this._resolver) : super(const LyricsState());

  final LyricsResolver _resolver;

  /// The id currently loaded/loading, so a stale response for a track the
  /// user has since skipped past never overwrites newer state.
  MediaId? _id;

  /// Loads [id]'s lyrics, or does nothing if it is already loaded or
  /// loading — safe to call every time the current entry changes without
  /// re-fetching on every rebuild in between.
  Future<void> open(MediaId id) async {
    if (id == _id) return;
    _id = id;
    await _load(id);
  }

  /// Re-fetches the currently open track's lyrics, for [ErrorStateView]'s
  /// retry action.
  Future<void> retry() async {
    final id = _id;
    if (id != null) await _load(id);
  }

  Future<void> _load(MediaId id) async {
    emit(const LyricsState(isLoading: true));

    final result = await _resolver.resolve(id);
    if (isClosed || id != _id) return;

    switch (result) {
      case Ok<Lyrics?>(:final value):
        emit(LyricsState(lyrics: value));
      case Err<Lyrics?>(:final failure):
        emit(LyricsState(failure: failure));
    }
  }
}
