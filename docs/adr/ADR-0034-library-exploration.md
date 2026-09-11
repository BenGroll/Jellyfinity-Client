# ADR-0034: Library exploration

## Status

Accepted

## Context

`Roadmap to v0.5md`'s "Library exploration" (v0.4.4) asks for intentional
ways into the library a listener already owns, without an opaque
recommendation service:

- genre and decade entry points, built from the user's Jellyfin library,
  with separate result categories rather than a mixed search dump, and
  without materializing a whole large library to construct them;
- a deliberate random-choice action for an album or artist, scoped
  honestly and explained, reproducible enough that a refresh is a new
  choice rather than a broken loading state;
- cached/local metadata where it is honest offline; a server-only facet
  says when it is unavailable or stale; downloads-only mode cannot
  suggest an item that cannot play.

ADR-0029 (v0.3.5, related artists and albums) explicitly left this open:
"the genre / decade entry points listed as a stretch goal are not taken
on — they are a browsing surface of their own, not a section." This ADR
is that browsing surface.

## Decision: genres, decades, and genre/decade browsing are live only

`MusicLibraryRepository` gains `genres()` and `decades()` — bounded facet
lists (`List<String>`, `List<int>`, not `Page`), the same shape ADR-0029
gave `relatedArtists`/`similarAlbums` — plus optional `genre` and
`decadeStart` filters on the existing `albums()`.

Both facets, and an album browse filtered by either, are read live only
and never cached:

- No domain entity anywhere carries a genre, so there is nothing honest
  to answer "every genre this library has" from once the server cannot
  be reached — unlike `recentlyAddedAlbums` (ADR-0027), where the cached
  window is a server fact worth showing stale-but-labeled, a genre list
  built from whatever happened to be browsed would misrepresent the
  library instead of merely being outdated.
- `Album.productionYear` *is* cached once an album has been browsed, but
  "every decade this library spans" from that partial set would silently
  omit decades nobody has opened — the same misrepresentation, not an
  honest partial answer.
- This mirrors `CachedMusicLibraryRepository`'s treatment of a search
  term (ADR-0010): offline, the entry point reports its own failure
  immediately rather than timing out or guessing, and — because the facet
  chips that lead to a genre or decade browse are themselves absent
  offline (nothing to tap) — no separate offline path for the *filtered*
  album list is needed either.

Unlike `RelatedMediaCubit`'s bonus strips, a failure here is **shown**,
not swallowed: `LibraryFacetsCubit` keeps genres and decades as two
independent sub-states (their own `isLoading`/`failure`), so a server
missing just `/Years` still shows the genre shelf, and the Explore tab
says "needs a connection" rather than quietly having two empty shelves.
Genre/decade browsing is a primary way into the library, not a footer
suggestion — it has to be honest about being unavailable, not just absent.

`JellyfinMusicLibraryRepository.genres()` reads `/MusicGenres`;
`decades()` reads `/Years` (scoped to `MusicAlbum`) and buckets the
returned production years into decades client-side — a cheap operation
over a small facet list, not the "materialize the library" `PHILOSOPHY.md`
§11 rules out. `queryItems` gains `genres`/`years` parameters (Jellyfin's
own `Genres` and `Years` filters) rather than a second query method,
since a genre/decade browse is still an ordinary windowed `/Items` read
in every other respect.

## Decision: random pick is the one part that works offline, from downloads

`randomAlbum()`/`randomArtist()` ask the server for one row sorted
`SortBy=Random` — a fresh pick every call, never memoized, so a refresh is
a new choice. The roadmap is explicit that "downloads-only mode cannot
suggest items that cannot play", which random pick is the one place in
this version that actually has to honor: unlike genre/decade browsing,
there genuinely is a good in-scope answer while offline.
`CachedMusicLibraryRepository` branches on `OfflineMode.status.isOffline`
the same way every other offline check here does, but instead of a
cache-fallback or an immediate failure, it asks `DownloadsLibrarySource`
for a random pick among the profile's own downloads — a different active
*scope*, not a degraded fallback, because there is no "saved copy of the
whole library" to fall back to and a suggestion that cannot play would be
worse than none.

`DownloadsLibrarySource.randomAlbum`/`randomArtist` pick a uniformly
random row without materializing the downloads catalog: one request to
learn the total, then one more windowed at the chosen index — the same
discipline the server-backed repository uses for a library many orders of
magnitude larger, applied here even though a profile's downloads are
bounded by what the user chose to keep.

The Explore tab's "Surprise me" section states which scope a pick came
from ("your whole library" / "what you have downloaded"), reading
`OfflineCubit` directly, so the scope is never a mystery.

## Decision: presentation reuses the existing collection machinery

- `AlbumsCubit` (already "the whole library's or one artist's") gains
  `forGenre`/`forDecade` alongside `forArtist`, rather than new cubit
  classes — a genre or decade browse is just another way of asking "which
  albums," the same paging, loading, empty, and offline-failed states
  every other album grid already has tested. `downloadedOnly` (the
  "Downloaded" filter) is disabled when a genre or decade is set, since
  neither has a downloads-backed answer.
- `LibraryFacetAlbumsPage` is one page for both a genre and a decade
  browse (mutually exclusive by construction, asserted), reusing
  `PagedCollectionView<Album>` exactly as `SearchCategoryPage`'s
  `_AlbumResults` does — new routes (`library/genre/:name`,
  `library/decade/:decade`), no new list-rendering code.
- Random pick is a free function over `getIt<MusicLibraryRepository>()`
  (`explore_actions.dart`), the shape `playlist_actions.dart` documents
  for a one-shot action with nowhere to keep state between calls: the
  button that triggers it already owns its own "picking" spinner, and a
  success pushes the album/artist route directly; a failure surfaces as a
  snackbar, the same pattern `createPlaylist` uses for a write that can
  fail.
- Library exploration is a fifth tab ("Explore") on the existing
  `LibraryPage`, not a new shell destination or a Home section — it is a
  way of browsing the library, the same category `LibraryPage`'s other
  four tabs are already in, and ADR-0029 already declined a Home section
  for anything without an honest, non-guessed seed.

## Consequences

- `MusicLibraryRepository` gains four methods and two new optional
  parameters on `albums()`. `JellyfinMediaApi.queryItems` gains `genres`/
  `years` parameters; no existing call site is affected (`Ok` and `Err`
  handling elsewhere is unchanged).
- `CachedMusicLibraryRepository` and `DownloadsLibrarySource` each gain a
  handful of methods; no schema change, no new cache table, no new
  collection-cache key for the live-only reads.
- One new cubit (`LibraryFacetsCubit`), one extended cubit (`AlbumsCubit`),
  one new page (`LibraryFacetAlbumsPage`), one new tab (`ExploreTab`), two
  new routes, one small free-function file (`explore_actions.dart`).
- Personal music discovery (v0.5.0, née v0.4.4 in `Roadmap to v0.5md`)
  remains open: it is discovery seeded by the user's own listening
  activity (history, favorites, related items), a different question from
  browsing the library by a fact it already carries.
