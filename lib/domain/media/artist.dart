import 'package:equatable/equatable.dart';

import 'media_availability.dart';
import 'MediaId.dart';
import 'MediaItem.dart';
import 'media_kind.dart';

/// A music artist as a browsable library entry.
class Artist extends MediaItem {
  const Artist({
    required super.id,
    required super.name,
    super.availability = MediaAvailability.remoteOnly,
    super.image,
  });

  @override
  MediaKind get kind => MediaKind.artist;

  @override
  List<Object?> get props => [id, name, availability, image];
}

/// A named artist credit on an album or track.
///
/// Not an [Artist]: a credit is what an album says about who made it, and
/// the server often gives only a name. Modelling it as a half-empty
/// [Artist] would mean every consumer having to know which of its fields
/// are real; this type promises exactly what a credit contains.
///
/// [id] is `null` when the server credited a name with no corresponding
/// artist item — common for guest and featured artists. Such a credit is
/// displayable but not navigable, which is a real thing the UI must
/// handle.
class ArtistRef extends Equatable {
  const ArtistRef({required this.name, this.id});

  final String name;
  final MediaId? id;

  /// Whether tapping this credit can open an artist page.
  bool get isNavigable => id != null;

  @override
  List<Object?> get props => [name, id];
}

/// The "who is this by" line a card or row shows under a title.
extension ArtistCredits on List<ArtistRef> {
  ArtistRef? get primary => isEmpty ? null : first;

  /// The joined credits — "Miles Davis, John Coltrane". Empty when there
  /// are none, so a caller can fall back to something else.
  String get display => map((artist) => artist.name).join(', ');
}
