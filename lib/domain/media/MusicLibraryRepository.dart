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
  ///
  /// [genre] narrows to artists tagged with it (v0.4.5, ADR-0034) — read
  /// live only, on the same terms [albums]' `genre` is.
  Future<Result<Page<Artist>>> artists({
    PageRequest page = const PageRequest.first(),
    String? searchTerm,
    String? genre,
  });

  /// Albums, optionally only those by [artistId], in [genre], or from the
  /// decade starting [decadeStart] (v0.4.4, ADR-0034).
  ///
  /// [genre] and [decadeStart] are read **live only**, like [genres] and
  /// [decades] below: nothing about a browsed genre or decade is cached,
  /// so working offline answers with a failure rather than a stale or
  /// partial shelf. At most one of [genre] and [decadeStart] is expected
  /// at a time — Library exploration offers them as separate entry
  /// points, never combined.
  Future<Result<Page<Album>>> albums({
    PageRequest page = const PageRequest.first(),
    MediaId? artistId,
    String? searchTerm,
    String? genre,
    int? decadeStart,
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

  /// Tracks, optionally only those on [albumId], by [artistId], in
  /// [genre], or from the decade starting [decadeStart] (v0.4.5).
  ///
  /// Album tracks come back in disc/track order; anything else is in the
  /// source's own order. [genre]/[decadeStart] are read live only, on the
  /// same terms [albums]' are — at most one of them is expected at a
  /// time, alongside at most one of [albumId]/[artistId].
  Future<Result<Page<Track>>> tracks({
    PageRequest page = const PageRequest.first(),
    MediaId? albumId,
    MediaId? artistId,
    String? searchTerm,
    String? genre,
    int? decadeStart,
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

  /// Artists the server considers related to [artistId], and albums it
  /// considers similar to [albumId] (v0.3.5) — a way to move from one
  /// thing to the next without leaving the user's own library.
  ///
  /// Both come straight from Jellyfin's own similarity endpoints; there is
  /// no external recommendation service behind them (`PHILOSOPHY.md`,
  /// `OUTLOOK.md` §13). They are bounded top-N lists rather than pageable
  /// collections — hence `List`, not `Page`, and a [limit] instead of a
  /// [PageRequest].
  ///
  /// Read **live only**, like [artistStats]: nothing is cached, so an
  /// unreachable or deliberately-offline server surfaces its failure and
  /// the section that shows this is simply absent. An empty list is a
  /// perfectly normal answer — a server with nothing useful to say — and
  /// the section is absent then too, never broken.
  Future<Result<List<Artist>>> relatedArtists(
    MediaId artistId, {
    int limit = 12,
  });

  Future<Result<List<Album>>> similarAlbums(MediaId albumId, {int limit = 12});

  /// The genre names present in the music library, alphabetical (v0.4.4,
  /// ADR-0034) — the entry points Library exploration builds its genre
  /// shelf from.
  ///
  /// A bounded facet list, not a browsable collection: like
  /// [relatedArtists], there is no paging. Read from the server while
  /// online; while deliberately or actually offline
  /// (`CachedMusicLibraryRepository`, v0.4.5, ADR-0034), it degrades to
  /// the genres captured on the profile's downloaded tracks instead of
  /// failing outright — a smaller, honestly-labeled answer rather than no
  /// answer at all. A profile with nothing downloaded, or downloads with
  /// no genre captured, gets the same failure a server-only facet always
  /// did.
  Future<Result<List<String>>> genres();

  /// The decades the library's albums span, newest first — `2020`,
  /// `2010`, … (v0.4.4, ADR-0034) — the entry points Library exploration
  /// builds its decade shelf from.
  ///
  /// Live only, for the same reason as [genres]: a production year is
  /// part of the cached `Album` entity once one has been browsed, but
  /// there is no honest way to answer "every decade this library spans"
  /// from whatever happens to be cached without silently omitting
  /// decades nobody has opened yet, which would misrepresent the
  /// library rather than merely being incomplete.
  Future<Result<List<int>>> decades();

  /// One album, chosen at random from the active library scope (v0.4.4,
  /// ADR-0034) — "surprise me".
  ///
  /// A fresh choice every call, never memoized: refreshing the action is
  /// a new pick, not a stale one replayed. Working offline, the pick
  /// comes from the signed-in profile's downloads instead of the server
  /// (`CachedMusicLibraryRepository`) — a suggestion that cannot play is
  /// worse than no suggestion, so "downloads only" is not a degraded mode
  /// here, it is the honest scope. [UnavailableFailure] means the scope
  /// (the server library, or the profile's downloads) currently has no
  /// album to offer.
  Future<Result<Album>> randomAlbum();

  /// One artist, chosen at random, on the same terms as [randomAlbum].
  Future<Result<Artist>> randomArtist();

  /// One track, chosen at random, on the same terms as [randomAlbum]
  /// (v0.4.5).
  Future<Result<Track>> randomTrack();

  /// A bounded pool of tracks chosen at random, on the same terms as
  /// [randomAlbum] (v0.4.5) — the fallback a "for you" mix tops itself up
  /// with once it has used what a listener's favorites can offer. Unlike
  /// [randomTrack] this is never shown as a suggestion on its own; it is
  /// always blended with something more targeted.
  Future<Result<List<Track>>> randomTracks({int limit = 30});
}
