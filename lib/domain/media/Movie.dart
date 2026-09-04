import 'media_availability.dart';
import 'MediaItem.dart';
import 'media_kind.dart';
import 'PlaybackProgress.dart';

/// A film.
///
/// Movies are not a v0.1.0 feature. They exist here because a media
/// vocabulary shaped only by music would quietly become music-only, and
/// the roadmap asks for enough video representation to prevent that.
/// [progress] is the field music does not need and video cannot do
/// without — Continue Watching and resume are built on it.
class Movie extends MediaItem {
  const Movie({
    required super.id,
    required super.name,
    this.productionYear,
    this.duration,
    this.overview,
    this.progress = PlaybackProgress.none,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  final int? productionYear;
  final Duration? duration;
  final String? overview;
  final PlaybackProgress progress;

  @override
  MediaKind get kind => MediaKind.movie;

  @override
  List<Object?> get props => [
    id,
    name,
    productionYear,
    duration,
    overview,
    progress,
    availability,
    image,
  ];
}
