import 'media_availability.dart';
import 'MediaItem.dart';
import 'media_kind.dart';

/// A television show. See [Movie] for why video entities exist this early.
class Series extends MediaItem {
  const Series({
    required super.id,
    required super.name,
    this.productionYear,
    this.overview,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  final int? productionYear;
  final String? overview;

  @override
  MediaKind get kind => MediaKind.series;

  @override
  List<Object?> get props => [
    id,
    name,
    productionYear,
    overview,
    availability,
    image,
  ];
}
