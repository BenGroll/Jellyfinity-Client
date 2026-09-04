# ADR-0012: Music Library Experience

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.8 is the first substantial user-facing media feature:
browsing a very large Jellyfin music library. Everything under it exists
and is tested — transport (ADR-0008), sessions (ADR-0009), the local
database (ADR-0010), the media vocabulary and Jellyfin-backed
repositories (ADR-0011) — and none of it has ever been rendered. Before
this release the application had exactly one shell section and no media
UI at all.

The release also settles two debts left open on purpose:

- ADR-0010 specified the **artwork cache** (bounded disk + memory, LRU,
  invalidated by Jellyfin's image tag) and deferred the implementation to
  "when the first widget actually renders artwork". That is now.
- ADR-0010 also described a **local/remote read-through repository
  convention** and declined to write a base class "with no consumer". The
  consumer exists now, so the convention becomes code.

Three constraints shape everything below:

- **Scale.** ~130k songs. No screen, cubit or cache may hold a
  collection, and no sorting or filtering may happen in Dart
  (`PHILOSOPHY.md` §11).
- **Never leave the user guessing.** Loading, partial, empty, refreshing,
  cached, offline, unavailable and failed must all be distinguishable on
  screen (`PHILOSOPHY.md` §2).
- **Partial success beats total failure.** One unreadable row must not
  fail a page, and one failed page must not discard the pages before it.

## Options Considered

### How search is modelled

1. **A `searchTerm` on the existing collection reads** (chosen).
   `artists`, `albums`, `tracks` and `playlists` each take an optional
   term. A music search is then one scoped query per category, each paged
   exactly like any other window.
2. A separate `search()` returning a mixed result type. It would need its
   own paging, its own mapping and its own "which category is this"
   discrimination, and would still have to be split back into categories
   for display.
3. Jellyfin's `/Search/Hints`. Genuinely relevance-ranked, which
   `/Items?searchTerm=` is not — but it answers with `SearchHint` objects
   rather than items, which would mean a second DTO and a second
   translator alongside `BaseItemMapper`, breaking ADR-0011's rule that
   there is exactly one. Revisit when search quality, rather than search
   existence, is the problem.

Option 1 also gives `PHILOSOPHY.md` §8's category separation almost for
free, and makes "show all 412 songs" the ordinary library list with a
term attached rather than a second implementation of paging.

### How the local cache is shaped

**Cache what was browsed, per collection window** (chosen), in three
tables (schema v2): the items, the collections, and the ordered entries
that say which item sits at which index.

Ordering is stored rather than recomputed, because the order is the
*server's* — sort name, production year, disc and track number, a
playlist's own arrangement — and Jellyfinity must not invent its own
version of it offline. An entry the mapper could not read keeps its
position with a reason instead of an item, so numbering offline matches
what the user saw online.

Rejected: mirroring the library in the background. At 130k tracks that is
a different feature with a different cost (sync scheduling, conflict
handling, a first-run that downloads a library), and the roadmap asks
only that *previously loaded* metadata stay browsable.

Rejected: an in-memory cache. It would not survive a restart, which is
exactly when a user on a train notices.

The items table is polymorphic with a `kind` discriminator, mirroring
both Jellyfin's item shape and `MediaItem`. Only the four music kinds are
stored; a movie has fields (overview, playback progress, series links)
this schema has no columns for, and those columns arrive with the feature
that reads them.

### Read-through direction

**Server first, saved copy as the fallback** (chosen) — not ADR-0010's
literal "serve local, refresh behind it".

Serving stale content and then replacing it under the user's scroll
position is worse in a list than content arriving a moment later, and
every screen here already renders its structure before its data, so the
wait is never a blank page. Local-first also needs a streaming
repository contract; that is a real change to ADR-0011's contracts and
should be made when something demands it, not pre-emptively.

The fallback is limited to `RecoverableFailure` — the server never
answered. A 404 is the server answering: reaching for the cache there
would resurrect an album the user deleted.

Searches are neither saved nor served from the cache. ADR-0010 files
search results under "temporary cache"; offline, a search says it needs
the server rather than quietly searching whatever fraction of the
library happens to be saved.

### How freshness reaches the UI

**`PageSource` on `Page`** (chosen): `server` or `cache`. ADR-0010 said
the UI must not learn *which source answered*; `PHILOSOPHY.md` §2 says
the UI must be able to show "cached". Both hold if what crosses the
boundary is freshness rather than implementation.

Cached media additionally reads back as `MediaAvailability
.remoteUnavailable` — the metadata is real, the audio is not reachable —
which is the vocabulary ADR-0011 already defined for exactly this.

A screen showing a wholly cached page marks it with one notice above the
list rather than dimming every row: dimming everything reads as broken,
not as offline. That is what the `markUnavailable` flag on the row
widgets is for.

### The artwork cache

**`cached_network_image` over `flutter_cache_manager`** (chosen): a
count-bounded LRU on disk, placeholder and fade support, actively
maintained, and small enough to sit behind one Jellyfinity widget. This
is the "labor-intensive infrastructure" `PHILOSOPHY.md` §14 says to take
a dependency for; hand-rolling disk eviction and concurrency for a solved
problem is not.

Nothing invalidates anything by hand. `MediaImage` carries Jellyfin's
image tag, `JellyfinArtworkResolver` puts it in the URL, and the URL is
the cache key — new artwork is a new key and the old file ages out. That
was the reason the tag is in the domain model at all.

### One paging implementation, not one per screen

`PagedCollectionCubit` and `PagedCollectionView` hold every rule a large
list has to follow, and each screen supplies only what it is a list *of*.
Four tabs, three detail screens and four search-category screens would
otherwise be eleven chances to get "a failed second window must not
discard the first" wrong.

`PagedCollectionState` is one class with flags rather than a status
hierarchy, because a list can be ready *and* refreshing *and* cached
*and* missing two rows at once, and a hierarchy would force it to pick.

## Decision

### Domain — `lib/domain/media/`

- `searchTerm` on `MusicLibraryRepository.artists/albums/tracks` and
  `PlaylistRepository.playlists`. A blank term means "no search";
  `JellyfinMediaApi.normalizeSearchTerm` enforces that in one place.
- `PageSource` on `Page`, defaulting to `server`.

### Persistence — `lib/infrastructure/persistence/media/`

Schema **v2**: `cached_media_items` (keyed by server + item),
`cached_collections` (keyed by server + collection key) and
`cached_collection_entries` (server + collection key + position). Purely
additive, so an install upgrading from v1 keeps its servers, profiles and
preferences and starts with an empty cache. `MediaCollectionKey` names
the query a window belongs to; `MediaCacheMapper` is the only translator
between rows and entities; `MediaCacheStore` is the only thing that
touches the tables.

Removing a saved server drops its cached library — every `MediaId` in it
names a server that no longer exists.

### Read-through — `lib/infrastructure/media/`

`CachedMusicLibraryRepository`, `CachedPlaylistRepository` and
`CachedMediaMetadataRepository` are what resolve for their contracts; the
Jellyfin implementations are registered as themselves and wrapped.

### Artwork — `lib/infrastructure/artwork/` + `MediaArtwork`

`ArtworkCache` bounds the disk store (1200 objects, 60-day staleness) and
the decoded-image memory ceiling (48 MB, applied in `bootstrap`).
`MediaArtwork` carries the three rules no screen should have to remember:
ask the server for the size that will actually be drawn, reserve the box
before loading so a list never reflows, and treat absent, unaddressable
and failed artwork as the same quiet placeholder rather than an error.

### Presentation — `lib/features/music/`

- `PagedCollectionCubit<T>` / `PagedCollectionState<T>` /
  `PagedCollectionView<T>`.
- `ArtistsCubit`, `AlbumsCubit`, `SongsCubit`, `PlaylistsCubit`,
  `PlaylistTracksCubit` — thin, each supplying one repository call.
- `MediaDetailCubit<T>` with artist, album and playlist subclasses. A
  detail screen loads its header and its children independently, so
  neither can blank the other.
- `MusicSearchCubit`: debounced, four parallel scoped queries, a
  generation counter so a slow answer to an old query never wins, and
  per-category failures.
- Screens: `MusicPage` (four tabs), `ArtistDetailPage`,
  `AlbumDetailPage`, `PlaylistDetailPage`, `MusicSearchPage`,
  `SearchCategoryPage`.

### Navigation

Music is the shell's second destination, which is what first makes the
bottom navigation bar appear. Its detail routes are children of `/music`,
so opening an album keeps the bar and the section's own back stack. Each
takes a `MediaId.key`; a key that does not parse lands on the not-found
page rather than throwing.

Tapping a song opens the album it is on. There is no player until
v0.0.9, and a tap that appears to start playback and does not would be
the kind of guessing this project is trying to eliminate.

## Tests

- `paged_collection_cubit_test` — windows, appending, exhaustion,
  overlapping requests, a failed first window vs a failed next window,
  refresh keeping content, partial pages, empty vs failed, cached
  source, and that returning to a tab does not refetch.
- `music_page_test` — skeletons before content, the four tabs, empty and
  error states, retry, the saved-copy notice, an unavailable row kept in
  place, and paging driven by an actual scroll.
- `music_detail_test` — a header that renders while tracks load, an album
  that keeps eleven tracks and marks the twelfth, playlist numbering with
  gaps, and a header failure that does not take the list down.
- `music_search_test` — debounce, category separation, preview limits,
  one dead category, all categories dead, and a stale answer discarded.
- `music_navigation_test` — through the real router: Music tab, artist →
  album → back, the bottom bar surviving a detail push, an unparseable id,
  and search.
- `media_cache_store_test` / `cached_*_repository_test` — the store's
  contract and the read-through rules.
- `media_cache_scale_test` (`@Tags(['scale'])`) — 130k songs cached one
  window at a time, then a window read from the far end in single-digit
  milliseconds. This is the media-scale query test ADR-0010 deferred.
- `app_database_migration_test` (`@Tags(['migration'])`) — v1 stepped up
  to v2 against the committed `drift_schemas/` snapshot, with existing
  rows preserved.
- `media_artwork_test` — placeholders, unaddressable images, the
  requested pixel size, and the reserved box.

## Consequences

- The application is usable for the first time: connect, sign in, browse
  a large music library, search it, and keep browsing what was already
  loaded when the server goes away.
- ADR-0010's two deferrals are closed. Its "serve local, refresh behind
  it" wording is superseded by the direction argued above.
- New dependencies: `cached_network_image` and `flutter_cache_manager`.
- Video metadata is still not cached, and search results still are not.
  Both are deliberate, and both are additions rather than rewrites.
- v0.0.9 adds playback on top of these screens: the queue, the
  mini-player, and a song tap that plays.
