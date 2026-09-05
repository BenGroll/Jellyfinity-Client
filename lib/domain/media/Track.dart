import 'artist.dart';
import 'media_availability.dart';
import 'MediaId.dart';
import 'MediaItem.dart';
import 'media_kind.dart';

/// One song.
///
/// A track keeps its album as an id *and* a name: a track list needs the
/// name to render and the id to navigate, and a queue restored offline
/// has to show "which album is this from" without loading the album.
class Track extends MediaItem {
  const Track({
    required super.id,
    required super.name,
    this.artists = const [],
    this.albumId,
    this.albumName,
    this.trackNumber,
    this.discNumber,
    this.duration,
    this.normalizationGain,
    this.isFavorite = false,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  final List<ArtistRef> artists;

  final MediaId? albumId;
  final String? albumName;

  /// Position within its disc, when known.
  final int? trackNumber;

  /// Which disc of a multi-disc release, when known.
  final int? discNumber;

  final Duration? duration;

  /// Jellyfin's loudness gain for this track (its `NormalizationGain`,
  /// v0.1.4), in dB. `null` when the server has neither analyzed the
  /// file's loudness nor found an embedded ReplayGain tag.
  final double? normalizationGain;

  /// Whether the signed-in user has favorited this track. See
  /// `Artist.isFavorite` for why it is not part of the offline cache.
  final bool isFavorite;

  @override
  MediaKind get kind => MediaKind.track;

  @override
  List<Object?> get props => [
    id,
    name,
    artists,
    albumId,
    albumName,
    trackNumber,
    discNumber,
    duration,
    normalizationGain,
    isFavorite,
    availability,
    image,
  ];
}
