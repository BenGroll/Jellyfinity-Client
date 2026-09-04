import 'MediaImage.dart';

/// Turns a [MediaImage] into an address something can load.
///
/// Kept out of the entities on purpose: the same image resolves to
/// different addresses on different servers and at different sizes, so
/// baking a URL into an entity would make cached metadata wrong the
/// moment a server's address changes.
///
/// Asking for a size is not optional politeness — a 130k-track library
/// scrolled as a grid must not pull full-resolution covers, so callers
/// pass the size they will actually draw.
///
/// v0.0.8 adds the bounded disk/memory artwork cache specified in
/// ADR-0010 behind this same contract; the tag inside a [MediaImage] is
/// what makes that cache invalidate itself.
abstract class ArtworkResolver {
  /// Where to load [image] from, sized for the space it will occupy.
  ///
  /// Returns `null` when the image cannot be addressed right now —
  /// notably when it belongs to a server other than the active one,
  /// which is what stops a cached entity from silently loading artwork
  /// from the wrong place.
  Uri? imageUrl(MediaImage image, {int? maxWidth, int? maxHeight});
}
