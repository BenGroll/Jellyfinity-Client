import 'media_availability.dart';
import 'media_id.dart';
import 'media_item.dart';
import 'media_kind.dart';
import 'playback_progress.dart';

/// One episode of a [Series].
///
/// Carries its show and season as ids *and* names for the same reason a
/// [Track] carries its album twice: an episode row has to render "Show ·
/// S2 E4" on its own, and still navigate.
class Episode extends MediaItem {
  const Episode({
    required super.id,
    required super.name,
    this.seriesId,
    this.seriesName,
    this.seasonId,
    this.seasonNumber,
    this.episodeNumber,
    this.duration,
    this.overview,
    this.progress = PlaybackProgress.none,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  final MediaId? seriesId;
  final String? seriesName;
  final MediaId? seasonId;
  final int? seasonNumber;
  final int? episodeNumber;
  final Duration? duration;
  final String? overview;
  final PlaybackProgress progress;

  @override
  MediaKind get kind => MediaKind.episode;

  @override
  List<Object?> get props => [
    id,
    name,
    seriesId,
    seriesName,
    seasonId,
    seasonNumber,
    episodeNumber,
    duration,
    overview,
    progress,
    availability,
    image,
  ];
}
