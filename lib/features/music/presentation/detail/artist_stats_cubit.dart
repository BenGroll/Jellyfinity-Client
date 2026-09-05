import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../domain/media/ArtistStats.dart';
import '../../../../domain/media/MediaId.dart';
import '../../../../domain/media/MusicLibraryRepository.dart';

/// An artist's album/song counts and total playtime for the artist page
/// header (v0.1.6).
///
/// Separate from [ArtistDetailCubit] the same way `TrackSourceInfoCubit`
/// is separate from playback state: nothing that lists or browses artists
/// needs these numbers, they cost their own queries
/// (`JellyfinMusicLibraryRepository.artistStats`), and they are read live
/// only — a failure here (typically "offline") just hides the stats row
/// rather than failing the whole page, since the artist header itself
/// already rendered from [ArtistDetailCubit].
class ArtistStatsState extends Equatable {
  const ArtistStatsState({this.stats, this.failure, this.isLoading = false});

  final ArtistStats? stats;
  final Failure? failure;
  final bool isLoading;

  @override
  List<Object?> get props => [stats, failure, isLoading];
}

@injectable
class ArtistStatsCubit extends Cubit<ArtistStatsState> {
  ArtistStatsCubit(this._music) : super(const ArtistStatsState());

  final MusicLibraryRepository _music;

  MediaId? _id;

  Future<void> open(MediaId id) async {
    if (id == _id) return;
    _id = id;
    emit(const ArtistStatsState(isLoading: true));

    final result = await _music.artistStats(id);
    if (isClosed || id != _id) return;

    switch (result) {
      case Ok<ArtistStats>(:final value):
        emit(ArtistStatsState(stats: value));
      case Err<ArtistStats>(:final failure):
        emit(ArtistStatsState(failure: failure));
    }
  }
}
