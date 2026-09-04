import 'package:equatable/equatable.dart';

import 'media_availability.dart';
import 'MediaId.dart';
import 'MediaImage.dart';
import 'media_kind.dart';

/// What every piece of media in Jellyfinity has: an identity, a name,
/// something to show for it, and a state of availability.
///
/// The base type exists for the few places that genuinely handle "some
/// media item, we do not know which yet" — resolving a link or a search
/// result, and the DTO mapper's return type. Feature code normally works
/// with the concrete types.
///
/// Deliberately **not** `sealed`: sealing would force every entity into
/// one library (or a chain of `part` files), and nothing yet needs an
/// exhaustive switch. Subtypes therefore live in their own files, and a
/// `switch` over a [MediaItem] needs a default branch.
abstract class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.name,
    required this.availability,
    this.image,
  });

  final MediaId id;

  /// The display title. Never empty — an item the server named nothing is
  /// treated as unmappable rather than shown blank.
  final String name;

  final MediaAvailability availability;

  /// The item's primary artwork, or the artwork it inherits (a track
  /// points at its album's cover). `null` when there is no image at all.
  final MediaImage? image;

  MediaKind get kind;
}
