import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/media/media.dart';

/// The current track's full record, on demand, for the two things a
/// [QueueEntry]'s denormalized snapshot cannot carry (v0.1.6): whether it
/// is favorited, and the artist/album ids to link to. Same page-scoped,
/// fetched-fresh shape as `TrackSourceInfoCubit`/`ArtistStatsCubit` — read
/// live only, never persisted, so an offline Now Playing keeps showing
/// the queue snapshot's title/artist text without a broken link or a
/// guessed favorite state.
class NowPlayingDetailsState extends Equatable {
  const NowPlayingDetailsState({
    this.track,
    this.failure,
    this.isLoading = false,
  });

  final Track? track;
  final Failure? failure;
  final bool isLoading;

  @override
  List<Object?> get props => [track, failure, isLoading];
}

@injectable
class NowPlayingDetailsCubit extends Cubit<NowPlayingDetailsState> {
  NowPlayingDetailsCubit(this._metadata)
    : super(const NowPlayingDetailsState());

  final MediaMetadataRepository _metadata;

  MediaId? _id;

  Future<void> open(MediaId id) async {
    if (id == _id) return;
    _id = id;
    emit(const NowPlayingDetailsState(isLoading: true));

    final result = await _metadata.item(id);
    if (isClosed || id != _id) return;

    switch (result) {
      case Ok<MediaItem>(:final value) when value is Track:
        emit(NowPlayingDetailsState(track: value));
      case Ok<MediaItem>():
        // Answered with something that is not a track — treat the same
        // as "could not describe this track" rather than showing it.
        emit(
          const NowPlayingDetailsState(
            failure: UnavailableFailure('That is not a song.'),
          ),
        );
      case Err<MediaItem>(:final failure):
        emit(NowPlayingDetailsState(failure: failure));
    }
  }
}
