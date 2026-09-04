import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/MediaId.dart';
import '../../../domain/playback/TrackSourceInfo.dart';
import '../../../domain/playback/TrackSourceInfoResolver.dart';

/// One track's file details for the Now Playing screen (ADR-0015).
///
/// Deliberately not app-wide state the way `PlaybackCubit` is: only Now
/// Playing needs this, only for whichever track is current, so it is a
/// small page-scoped cubit in the same spirit as `MediaDetailCubit` —
/// just not tied to `MediaItem`, since [TrackSourceInfo] isn't one.
class TrackSourceInfoState extends Equatable {
  const TrackSourceInfoState({this.info, this.failure, this.isLoading = false});

  final TrackSourceInfo? info;
  final Failure? failure;
  final bool isLoading;

  @override
  List<Object?> get props => [info, failure, isLoading];
}

@injectable
class TrackSourceInfoCubit extends Cubit<TrackSourceInfoState> {
  TrackSourceInfoCubit(this._resolver) : super(const TrackSourceInfoState());

  final TrackSourceInfoResolver _resolver;

  /// The id currently loaded/loading, so a stale response for a track the
  /// user has since skipped past never overwrites newer state.
  MediaId? _id;

  /// Loads [id]'s source info, or does nothing if it is already loaded or
  /// loading — safe to call every time Now Playing's current entry
  /// changes without re-fetching on every rebuild in between.
  Future<void> open(MediaId id) async {
    if (id == _id) return;
    _id = id;
    emit(const TrackSourceInfoState(isLoading: true));

    final result = await _resolver.resolve(id);
    if (isClosed || id != _id) return;

    switch (result) {
      case Ok<TrackSourceInfo>(:final value):
        emit(TrackSourceInfoState(info: value));
      case Err<TrackSourceInfo>(:final failure):
        emit(TrackSourceInfoState(failure: failure));
    }
  }
}
