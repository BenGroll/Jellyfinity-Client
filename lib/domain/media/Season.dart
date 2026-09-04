import 'media_availability.dart';
import 'MediaId.dart';
import 'MediaItem.dart';
import 'media_kind.dart';

/// One season of a [Series].
///
/// [seasonNumber] is `null` for specials and for a show whose seasons the
/// server could not number.
class Season extends MediaItem {
  const Season({
    required super.id,
    required super.name,
    this.seriesId,
    this.seriesName,
    this.seasonNumber,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  final MediaId? seriesId;
  final String? seriesName;
  final int? seasonNumber;

  @override
  MediaKind get kind => MediaKind.season;

  @override
  List<Object?> get props => [
    id,
    name,
    seriesId,
    seriesName,
    seasonNumber,
    availability,
    image,
  ];
}
