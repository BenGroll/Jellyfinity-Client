import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The bounded disk and memory cache for artwork that ADR-0010 specified
/// and deferred to v0.0.8, "when the first widget actually renders
/// artwork". This is that release.
///
/// ## Why it is bounded, and by what
///
/// Covers are the one part of a 130k-track library that is genuinely
/// large on disk, and they are also the part that is cheapest to fetch
/// again. So this is a *temporary* cache in ADR-0010's sense: dropping
/// any of it costs one request, never a piece of the user's library. The
/// bound is a count of files under least-recently-used eviction, which is
/// what `flutter_cache_manager` provides, sized so a heavily browsed
/// library settles well under a hundred megabytes rather than growing
/// without limit.
///
/// ## Why nothing here invalidates
///
/// It does not have to. A `MediaImage` carries Jellyfin's content tag for
/// the image, `JellyfinArtworkResolver` puts that tag in the URL, and the
/// URL is the cache key — so new artwork is a new key and the old file
/// simply ages out. That was the point of keeping the tag in the domain
/// model.
class ArtworkCache extends CacheManager {
  ArtworkCache._()
    : super(
        Config(
          cacheKey,
          stalePeriod: stalePeriod,
          maxNrOfCacheObjects: maxObjects,
        ),
      );

  /// Its own store, kept apart from any other cache the app may keep, so
  /// clearing artwork never clears anything else.
  static const String cacheKey = 'jellyfinity_artwork';

  /// Roughly a thousand covers. At the sizes Jellyfinity requests, that
  /// is tens of megabytes — enough that a library the user browses often
  /// stops re-fetching, small enough to be an unremarkable amount of
  /// storage on a phone.
  static const int maxObjects = 1200;

  /// A cover the user has not seen in two months is not worth the space.
  static const Duration stalePeriod = Duration(days: 60);

  /// How much decoded image data may sit in memory at once.
  ///
  /// Flutter's default (100 MB) is generous for a scrolling grid of
  /// covers on a mid-range phone; a smaller ceiling means the list evicts
  /// and re-decodes rather than pushing the process towards its limit.
  static const int memoryCacheBytes = 48 << 20;

  static final ArtworkCache instance = ArtworkCache._();

  /// Applies the memory bound. Called once from `bootstrap`.
  static void configureImageCache([ImageCache? cache]) {
    (cache ?? PaintingBinding.instance.imageCache).maximumSizeBytes =
        memoryCacheBytes;
  }
}
