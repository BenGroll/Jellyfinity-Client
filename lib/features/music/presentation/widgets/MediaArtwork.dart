import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../design/design.dart';
import '../../../../domain/media/media.dart';
import '../../../../infrastructure/artwork/ArtworkCache.dart';

/// How a piece of artwork is masked.
enum ArtworkShape {
  /// Covers, playlist art, posters.
  rounded,

  /// Artists, which every music app draws as a circle.
  circle,
}

/// One piece of artwork, at the size it will actually be drawn.
///
/// Three rules live here so no screen has to remember them:
///
/// - **Ask for the size you will draw.** The resolver puts the size in the
///   URL, so a grid of covers on a phone downloads phone-sized covers.
///   `PHILOSOPHY.md` §11 is not only about rows.
/// - **Reserve the space first.** The box is laid out before anything is
///   loaded, so a list never reflows as images arrive — the skeleton and
///   the image occupy exactly the same rectangle.
/// - **Missing artwork is normal.** No image, an image on a server that is
///   not the active one, a request that fails: all three land on the same
///   quiet placeholder for the kind of media, never on an error.
class MediaArtwork extends StatelessWidget {
  const MediaArtwork({
    super.key,
    required this.image,
    required this.kind,
    required this.size,
    this.shape = ArtworkShape.rounded,
    this.resolver,
  });

  /// What to show, or `null` when the item has no artwork at all.
  final MediaImage? image;

  /// Decides the placeholder icon, and nothing else.
  final MediaKind kind;

  /// The edge length this artwork will occupy, in logical pixels.
  final double size;

  final ArtworkShape shape;

  /// Overridable for tests and previews; resolved from the graph
  /// otherwise.
  final ArtworkResolver? resolver;

  /// Replaces the network image with something a widget test can pump.
  ///
  /// The same seam as `JellyfinServerProbe.httpClientFactory`: production
  /// leaves it null. Without it every widget test that renders a row
  /// would reach for the file system through the cache manager.
  @visibleForTesting
  static Widget Function(Uri url, int pixelSize)? imageBuilderOverride;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = shape == ArtworkShape.circle
        ? BorderRadius.circular(size)
        : t.radii.smBorder;

    final url = _url(context);

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: t.colors.surfaceSunken,
          child: url == null
              ? _Placeholder(kind: kind, size: size)
              : _image(context, url),
        ),
      ),
    );
  }

  Widget _image(BuildContext context, Uri url) {
    final pixelSize = _pixelSize(context);
    final override = imageBuilderOverride;
    if (override != null) return override(url, pixelSize);

    return CachedNetworkImage(
      imageUrl: url.toString(),
      cacheManager: ArtworkCache.instance,
      fit: BoxFit.cover,
      // Decode to the drawn size rather than the source size: this is
      // the memory half of the same rule as asking the server for a
      // smaller image.
      memCacheWidth: pixelSize,
      fadeInDuration: context.motion.fast,
      placeholder: (context, _) => AppSkeleton(
        width: size,
        height: size,
        borderRadius: BorderRadius.zero,
      ),
      errorWidget: (context, _, _) => _Placeholder(kind: kind, size: size),
    );
  }

  Uri? _url(BuildContext context) {
    final source = image;
    if (source == null) return null;
    final pixelSize = _pixelSize(context);
    return (resolver ?? getIt<ArtworkResolver>()).imageUrl(
      source,
      maxWidth: pixelSize,
    );
  }

  /// The drawn size in device pixels, which is what the server and the
  /// decoder both need — asking for logical pixels would give a blurry
  /// cover on every phone made in the last decade.
  int _pixelSize(BuildContext context) =>
      (size * MediaQuery.devicePixelRatioOf(context)).round();
}

/// What stands in for artwork that is absent or unreachable.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.kind, required this.size});

  final MediaKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Icon(
        switch (kind) {
          MediaKind.artist => Icons.person_rounded,
          MediaKind.album => Icons.album_rounded,
          MediaKind.track => Icons.music_note_rounded,
          MediaKind.playlist => Icons.queue_music_rounded,
          _ => Icons.movie_rounded,
        },
        size: size * 0.42,
        color: t.colors.textDisabled,
      ),
    );
  }
}
