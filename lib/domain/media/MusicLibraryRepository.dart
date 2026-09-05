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
