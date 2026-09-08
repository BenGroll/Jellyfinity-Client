import '../../core/result/result.dart';
import 'Album.dart';
import 'artist.dart';
import 'ArtistStats.dart';
import 'MediaId.dart';
import 'page.dart';
import 'Track.dart';

/// Reading the music library: artists, albums and tracks.
///
/// One of several narrow media contracts rather than a single media
/// repository (ADR-0001). Everything it returns is a Jellyfinity domain
/// entity — no caller of this interface can tell that a Jellyfin server
/// exists on the other side of it, which is the whole point of v0.0.7.
///
/// ## Reading the results
///
/// - `Err` means the request as a whole could not be answered (no
///   session, server unreachable, unauthorized). Callers show an error
///   state with a retry.
/// - `Ok` with a [Page] means it was answered. The page may still carry
///   `unavailable` entries for rows that could not be understood; those
///   are shown as unavailable items, not as a failed screen.
///
/// ## Paging
///
/// Every collection method is paged and none of them has an
/// "everything" variant. Implementations must push filtering and sorting
/// to the source (`PHILOSOPHY.md` §11) rather than fetching a library
/// and narrowing it in Dart.
///
/// ## Searching
///
/// Search is a [searchTerm] on the same collection reads rather than a
/// separate result type, which is what keeps `PHILOSOPHY.md` §8's
/// category separation cheap: a music search is one scoped query per
/// category, each paged like any other window, instead of one noisy list
/// that has to be sorted back out afterwards. A blank or whitespace-only
/// term means "no search", not "match nothing".
abstract class MusicLibraryRepository {
  /// The library's album artists — the artists a music app lists, rather
  /// than every performer credited anywhere.
  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
  });

  /// Albums, optionally only those by [artistId].
  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    MediaId? artistId,
    String? searchTerm,
  });

  /// The albums most recently added to the library, newest first by the
  /// date the server acquired them (v0.3.3).
  ///
  /// A distinct question from [albums], which is always alphabetical: this
  /// one is "what is new", and it is a bounded top-N list rather than a
  /// window into a collection — the returned [Page] reports itself
  /// complete and is never paged. Cached like [albums], so a cold offline
  /// open answers from the saved copy marked [PageSource.cache]; but it is
  /// a *server* fact, and a deliberately-offline caller must not present
  /// the saved copy as if freshness had been checked.
  Future<Result<Page<Album>>> recentlyAddedAlbums({
    PageRequest page = const PageRequest.first(),
  });

  /// The signed-in profile's favorite artists, albums and tracks (v0.3.4,
  /// ADR-0028), alphabetical — the same order [artists]/[albums]/[tracks]
  /// use, since Jellyfin exposes no "date favorited" to sort on.
  ///
  /// Each is a distinct question rather than an `isFavorite:` flag on the
  /// method above it, the same reasoning [recentlyAddedAlbums] is its own
  /// method (ADR-0027): these back the Favorites destination and its Home
  /// section, they have their own per-profile cache, and folding a flag
  /// into [artists]/[albums]/[tracks] would make every caller carry a
  /// parameter for a case only Favorites uses.
  ///
  /// Favorite state is the *user's*, not the server's, so the cache is
  /// account-scoped: a cold offline open answers from the saved copy
  /// marked [PageSource.cache]; a profile whose favorites have never been
  /// read online gets the failure back, not an empty list that would read
  /// as "you have no favorites".
  Future<Result<Page<Artist>>> favoriteArtists({
    PageRequest page = const PageRequest.first(),
  });

  Future<Result<Page<Album>>> favoriteAlbums({
    PageRequest page = const PageRequest.first(),
  });

  Future<Result<Page<Track>>> favoriteTracks({
    PageRequest page = const PageRequest.first(),
  });

  /// Tracks, optionally only those on [albumId] or by [artistId].
  ///
  /// Album tracks come back in disc/track order; anything else is in the
  /// source's own order.
  Future<Result<Page<Track>>> tracks({
    PageRequest page = const PageRequest.first(),
    MediaId? albumId,
    MediaId? artistId,
    String? searchTerm,
  });

  /// One artist.
  Future<Result<Artist>> artist(MediaId id);

  /// One album, without its tracks — ask [tracks] for those, so an album
  /// header can render while a long track list is still loading.
  Future<Result<Album>> album(MediaId id);

  /// How much of the library is credited to [artistId] (v0.1.6): its
  /// album and song counts, and — when there are few enough tracks to sum
  /// — their total running time. Read live; not part of the offline cache
  /// (see `ArtistStats.totalDuration`).
  Future<Result<ArtistStats>> artistStats(MediaId artistId);
}
