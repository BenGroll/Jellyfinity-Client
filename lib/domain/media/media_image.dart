import 'package:equatable/equatable.dart';

import 'media_id.dart';

/// The role an image plays for an item.
///
/// Only the roles Jellyfinity actually renders. Jellyfin serves many more
/// (thumb, banner, art, disc, ...); they can be added when a view needs
/// one.
enum MediaImageKind {
  /// Cover art / poster — the image shown in lists and grids.
  primary,

  /// Wide background image, used behind detail headers.
  backdrop,

  /// Transparent title treatment, overlaid on a backdrop.
  logo,
}

/// A pointer to one image belonging to one item.
///
/// It is not the image data and not a URL: turning it into something
/// loadable is [ArtworkResolver]'s job, because the address depends on the
/// server and on the size the caller wants.
///
/// [itemId] is the item that **owns** the image, which is not always the
/// item that displays it: a track usually has no artwork of its own and
/// shows its album's cover, so its [MediaImage] points at the album. That
/// keeps one image cached once instead of once per track.
///
/// [tag] is Jellyfin's content hash for the image. It is part of the
/// address and makes cache invalidation free — new artwork means a new
/// tag, which means a different cache key (ADR-0010's artwork cache).
class MediaImage extends Equatable {
  const MediaImage({
    required this.itemId,
    required this.kind,
    required this.tag,
    this.aspectRatio,
  });

  /// The item the image belongs to.
  final MediaId itemId;

  final MediaImageKind kind;

  /// The server's tag for this image; changes whenever the image does.
  final String tag;

  /// Width divided by height, when the server reported it. Lets a grid
  /// reserve the right space before the image arrives, instead of
  /// reflowing when it does.
  final double? aspectRatio;

  @override
  List<Object?> get props => [itemId, kind, tag, aspectRatio];
}
