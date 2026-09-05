import 'artist.dart';
import 'media_availability.dart';
import 'MediaItem.dart';
import 'media_kind.dart';

/// A music album.
///
/// [trackCount] and [duration] come from the album item itself, so an
/// album card can show "12 songs · 48 min" without loading the tracks.
/// Both are `null` when the server did not report them, which is normal
/// for a partially-scanned library — the card omits them rather than
/// showing a zero.
class Album extends MediaItem {
  const Album({
    required super.id,
    required super.name,
    this.artists = const [],
    this.productionYear,
    this.duration,
    this.trackCount,
    this.isFavorite = false,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  /// The album artists, in the server's order.
  final List<ArtistRef> artists;

  final int? productionYear;

  /// Total running time, when the server reported one.
  final Duration? duration;

  final int? trackCount;

  /// Whether the signed-in user has favorited this album. See
  /// `Artist.isFavorite` for why it is not part of the offline cache.
  final bool isFavorite;

  @override
  MediaKind get kind => MediaKind.album;

  @override
  List<Object?> get props => [
    id,
    name,
    artists,
    productionYear,
    duration,
    trackCount,
    isFavorite,
    availability,
    image,
  ];
}
