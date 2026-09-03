import 'package:injectable/injectable.dart';

import '../../../domain/media/artwork_resolver.dart';
import '../../../domain/media/media_image.dart';
import '../identity/jellyfin_session_context.dart';

/// [ArtworkResolver] that builds Jellyfin image URLs for the active
/// server.
///
/// Jellyfin serves images unauthenticated, so the address is all a widget
/// needs — no token handling, no request wrapper, and images can be
/// fetched by any image loader.
///
/// The size is passed to the server rather than applied after download:
/// a grid of covers on a phone should not be pulling full-resolution
/// artwork. The tag is what makes a changed image a different URL, which
/// is the invalidation strategy ADR-0010 specified for the artwork cache.
@LazySingleton(as: ArtworkResolver)
class JellyfinArtworkResolver implements ArtworkResolver {
  JellyfinArtworkResolver(this._context);

  final JellyfinSessionContext _context;

  /// Jellyfin's JPEG quality scale. High enough to look clean on a
  /// phone, low enough that a scrolling grid is not paying for
  /// imperceptible detail.
  static const int imageQuality = 90;

  @override
  Uri? imageUrl(MediaImage image, {int? maxWidth, int? maxHeight}) {
    final baseUrl = _context.baseUrl;
    // Signed out, or the image belongs to a different saved server than
    // the one in use: there is no address for it right now. A caller
    // shows its placeholder instead of loading artwork from the wrong
    // library.
    if (baseUrl == null || image.itemId.serverId != _context.serverId) {
      return null;
    }

    final uri = Uri.tryParse(
      '$baseUrl/Items/${image.itemId.itemId}/Images/${_imageType(image.kind)}',
    );
    if (uri == null) return null;

    return uri.replace(
      queryParameters: <String, String>{
        'tag': image.tag,
        if (maxWidth != null) 'maxWidth': '$maxWidth',
        if (maxHeight != null) 'maxHeight': '$maxHeight',
        'quality': '$imageQuality',
      },
    );
  }

  static String _imageType(MediaImageKind kind) => switch (kind) {
    MediaImageKind.primary => 'Primary',
    MediaImageKind.backdrop => 'Backdrop',
    MediaImageKind.logo => 'Logo',
  };
}
