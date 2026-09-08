# ADR-0028: Favorites as a place

## Status

Accepted

## Context

`Roadmap to v0.4.md` v0.3.4 gives the star a destination. Favorites can
be set from Artist, Album and Now Playing (v0.1.6, ADR-0019) and then
never browsed. The roadmap asks for a Favorites destination reachable
from normal music navigation, Favorites sections on Home following the
ADR-0026 pattern, an `IsFavorite` filter on the shared query surface, and
an offline story that is *stated* rather than implied — either extend the
cache with a migration, or say plainly that Favorites needs the server.
It also renews ADR-0019's open question: whether favorites join the
offline cache.

## Decision: `favoritesOnly` is a flag on `queryItems`, defaulting off

`JellyfinMediaApi.queryItems` gains `bool favoritesOnly = false`, which
adds `isFavorite: true` to the query. This is the exact move ADR-0027
made for `descending`: every one of the six existing callers wants it
off, the default keeps them byte-for-byte identical, and only the three
favorites reads opt in. A filter object was not worth it for one bit.

## Decision: three distinct repository methods, not a filter on the browse reads

`MusicLibraryRepository` gains `favoriteArtists`, `favoriteAlbums` and
`favoriteTracks`, each an ordinary paged read. Folding an `isFavorite:`
argument into `artists`/`albums`/`tracks` would make every caller of
those carry a parameter for a case only Favorites uses — the same
reasoning ADR-0027 used to keep `recentlyAddedAlbums` its own method.
They sort by `SortName`: Jellyfin exposes no "date favorited", so
alphabetical is the honest, stable order, and it matches the Library.

## Decision: the migration ADR-0019 deferred is taken on — a `cached_favorites` table

ADR-0019 kept favorite state out of the cache to spare v0.1.6 a Drift
migration, and said "a future version that wants favorites available
offline will need its own ADR". This is that version and this is that
ADR.

Schema **v8** adds `cached_favorites` — `(account_key, item_id)` primary
key, plus `server_id`, `kind` and `updated_at`. It is the *set* of
favorited ids per profile; the metadata for each item still lives in
`cached_media_items` (one row per item, whoever favorited it), joined by
`(server_id, item_id)`. It is **account-scoped** like the download tables
(ADR-0023): favoriting is the Jellyfin *user's*, and two profiles on one
server keep different favorites. The step is purely additive — one new
table, nothing existing touched — so an upgrading install keeps
everything and fills its favorites the first time the Favorites screen is
opened online.

Why a table rather than ADR-0027's collection-cache trick (a per-account
`MediaCollectionKey`): the cache is server-scoped, so a per-user key
would be a string hack, and reconciling a removal (favorite on the web,
un-favorite on the web) is a clean `DELETE ... WHERE kind = ?` against a
real table rather than a windowed rewrite.

### What fills and reads it

- **A favorites list read online** (`favoriteAlbums()` etc.) replaces
  that profile's rows of that one `kind` wholesale, so a favorite removed
  on another client stops appearing offline here too. Only the first
  window is cached — offline favorites are "what was browsed", like the
  rest of the metadata cache; a profile with 300 favorite albums sees the
  first 100 offline.
- **A single detail read online** (`album(id)` / `artist(id)`) folds the
  item's live `isFavorite` into the table — added if true, removed if
  false — so browsing keeps the set from drifting between full syncs.
- **The toggle itself.** `CachedFavoritesRepository` wraps
  `JellyfinFavoritesRepository`: on a successful server write it mirrors
  the change into `cached_favorites`, so an offline Favorites view
  reflects a star tapped a moment ago online. `FavoritesRepository.
  setFavorite` gained an optional `MediaKind kind` for this — every heart
  button already knows it.

### Null vs. empty

`readFavorites` returns `null` — the caller re-surfaces the failure that
sent it there — only when that `(account, kind)` pair has *never* been
synced. An empty sync (you have no favorite albums) is recorded via a
marker row in `cached_collections`, exactly the table that already
answers "has this collection been read, and how long is it". So an
offline Favorites screen says "No favorite albums yet" when that is true
and "reconnect" when it genuinely does not know.

### What this does not change

The **detail-page heart stays as ADR-0019 left it**: hidden on a
cached/offline copy. The migration exists to feed the *Favorites
destination* offline, which is what the roadmap's "done when" needs;
showing (and reconciling) the heart on a cached page is a further step
for a later version, and it touches Now Playing's fetch-based flow.

## Decision: Favorites is a bottom-nav section, media-scoped like Library

Favorites is a third `ShellDestination` (heart icon), between Home and
Library. `ShellDestination`'s own doc invites new sections as "one list
entry plus one case in `AppRouter`", and a bottom-nav tab is the most
reachable place there is — the opposite of "buried in Settings", and
`AppSidebar` explicitly holds only non-media concerns. It gets the shared
header, so the media-type pill scopes it the same way it scopes Library
(Music today; Movies and Shows when they arrive).

Its body is three tabs — Artists, Albums, Songs — each an ordinary
`PagedCollectionCubit` over one favorites read, the same paging and
states the Library tabs use. The **Songs tab is playable straight
through**, with a Play/Shuffle header (`MediaPlaybackActionsRow`) and
tap-to-play-in-context — "usable like a playlist", which the Library's
Songs tab already is.

Detail navigation reuses the `library/...` route names; go_router pushes
those onto the Favorites branch's own stack (confirmed by test), so a
tapped favorite album opens in-place with the bottom bar intact and Back
returns to Favorites — no duplicate route table.

## Decision: Home gets one "Favorites" strip

Following ADR-0026/0027: `HomeFavoritesCubit`, one bounded read of
favorite albums + artists (songs are left off — a favorite song has no
card and nowhere to open), rendered as one strip whose header opens the
destination. It is independent (own loading / empty / failed / retry),
absent when empty, and a failed refresh keeps its rows.

- **Online / offline full-library scope.** The strip shows; offline it
  carries a "Saved — reconnect to sync your favorites" line when the copy
  is cached.
- **Offline, downloads-only scope.** Unlike "Recently added" (a *server*
  fact, dropped), Favorites is the user's own curated set, so the strip
  *narrows* to favorites with something downloaded — a list of what plays
  offline is exactly what that scope is for — and is absent only if
  nothing favorited is on the device.

## Decision: a zero-dependency `FavoritesRevisionCubit` signals a change

The heart lives on Artist, Album and Now Playing; the Favorites
destination and its Home strip cannot see those. Rather than a route
observer, a bump counter (`FavoritesRevisionCubit`, created in
`JellyfinityApp` beside the other cross-cutting cubits) ticks on a
successful toggle, and both views re-read on it — the same shape Home
already uses to refresh "Recently played" off `PlaybackCubit`. It lives
in `lib/app`; the bump happens in presentation (`favorite_actions.dart`),
so the dependency direction into infrastructure is untouched.

## Consequences

- `queryItems` gains one boolean; the six existing query paths are
  unchanged.
- `MusicLibraryRepository` gains three methods; `FavoritesRepository.
  setFavorite` gains an optional `kind`. `JellyfinFavoritesRepository` is
  now the remote half, wrapped by `CachedFavoritesRepository`.
- Schema **v8**: `cached_favorites`, one index, an additive migration
  step, a schema snapshot and a migration test. `MediaCacheStore` gains
  `replaceFavorites`, `readFavorites` and `setFavorite`.
- One new shell section, one `FavoritesPage` with three tabs, three
  `PagedCollectionCubit`s, one `HomeFavoritesCubit`, one
  `FavoritesRevisionCubit`.
- The offline heart on detail pages, and favorites for Movies/Shows,
  remain out of scope — each is a later version with its own decision.
