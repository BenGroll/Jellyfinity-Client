# ADR-0027: Recently added

## Status

Accepted

## Context

`Roadmap to v0.4.md` v0.3.3 adds a **Recently added** section to Home —
the albums the server has gained, newest first — so "a user who added
music to their server last night sees it on Home this morning". The
roadmap names the mechanics: one extra library query, a **descending**
sort the shared query surface does not yet do, the same cache fallback
every other browse read has, and an offline story that does not imply a
freshness check the app could not make.

This is the third section of the Home arc and it follows the pattern
ADR-0026 set: an independent widget or cubit over one source, offline
rules at the widget layer, one line in Home's child list.

## Decision: `descending` is a flag on `queryItems`, defaulting to ascending

`JellyfinMediaApi.queryItems` hard-coded `sortOrder: Ascending` inside
the block that emits `sortBy`. Every existing caller — the library, a
discography, an album's tracks, a playlist, search — wants ascending, so
the change is a `bool descending = false` parameter and
`sortOrder: descending ? 'Descending' : 'Ascending'`. Nothing else
moves; the default keeps all five existing queries byte-for-byte the
same, which is what the roadmap's "must not regress the existing library,
artist and playlist queries" asks for. Only `recentlyAddedAlbums` passes
`true`.

A `SortOrder` enum was considered and rejected as more surface than one
call site earns — if a second descending query ever appears, promoting
the flag then is a smaller change than carrying an enum nobody else uses
until then.

## Decision: a distinct repository method, not a parameter on `albums`

`MusicLibraryRepository.recentlyAddedAlbums({page})` is its own method
rather than a `sort:` argument on `albums`. "What is new" is a different
question from "the albums, alphabetically": it sorts on `DateCreated`
(the date the server acquired the item, with `SortName` only as a
tiebreaker so a batch imported in one scan does not reshuffle between
reads), it is a bounded top-N rather than a window into a collection, and
it has its own cache key. Folding it into `albums` would mean every
caller of `albums` carries a sort parameter for a case only Home uses,
the same reasoning ADR-0024 used to keep an entry id off `Track`.

## Decision: the window is reported complete, so the cache replaces cleanly

Home asks for one window of 20 and never pages "Recently added". The
Jellyfin read still comes back with `totalRecordCount` set to *every*
album in the library, so `JellyfinMusicLibraryRepository` overrides the
page's `totalCount` to the number of rows actually in the window. Two
consequences follow:

- `hasMore` is always false — the section cannot try to page a list that
  has no more.
- `MediaCacheStore.savePage` treats the window as the whole collection,
  so a refresh that returns a shorter list (albums removed, or simply a
  smaller "recent" set) fully replaces the saved copy instead of leaving
  rows stranded past the new end.

## Decision: cached like any browse read; honesty is the widget's job

`CachedMusicLibraryRepository.recentlyAddedAlbums` goes through the same
`_collection` path as `albums`: a served answer is saved under
`MediaCollectionKey.recentlyAddedAlbums`, and a `RecoverableFailure` (an
unreachable server, or a deliberately-offline read short-circuited to the
same place) is answered from the saved copy marked `PageSource.cache`.
This satisfies the roadmap's "a cold offline open still shows the last
known recently added rather than an error".

`RecentlyAddedCubit` does **not** watch `OfflineCubit`. It is a plain
history-style read that surfaces `Page.isCached` and nothing more.
Whether a *server* fact is honest to present offline is decided where the
offline scope already lives — the widget layer, exactly as ADR-0026 put
the "playable offline" rules there rather than in `RecentlyPlayedCubit`.

At the widget layer:

- **Online.** The strip is a normal section.
- **Offline, full-library scope.** The strip shows the saved copy with a
  line under the heading — "Saved list — reconnect to see new music" —
  so the list never reads as a freshness check the app could not make.
  The cards stay tappable: an album page owns its own offline state
  (cached header, downloaded tracks), unlike a "recently played" track
  row, which has nowhere to go and no audio.
- **Offline, downloads-only scope.** The section is dropped entirely.
  The scope is a request to see only what plays without the server, and
  "what the server just added" is the opposite of that — the same reason
  ADR-0026 removes an unplayable "recently played" row under this scope
  rather than dimming it.

## Decision: albums only; artists are deferred

The roadmap allows artists "where it reads well". They are left out:

- Jellyfin's `DateCreated` on an artist is when the artist *entity* was
  created, which is not reliably "when this artist's music landed" — a
  new album by an artist already in the library does not move the artist
  row.
- Surfacing both would mean merging two independently date-sorted lists
  into one strip, which is more machinery than a section is meant to
  carry (ADR-0026's preamble rule).

An album-only "Recently added" is the reading every other music client
ships, and it answers the roadmap's "Done when" directly.

## Consequences

- `queryItems` gains one boolean; the five existing query paths are
  unchanged.
- `MusicLibraryRepository` gains `recentlyAddedAlbums`; its cached and
  Jellyfin implementations each gain one method. No schema change — the
  cache table already stores arbitrary collection keys.
- One new feature cubit (`RecentlyAddedCubit`), the same shape as
  `RecentlyPlayedCubit`. Home now composes three sections; the child
  list and the offline switch in `_HomeBody` are where a fourth
  (Favorites, v0.3.4) slots in.
- "Recently added" is a live server read cached opportunistically. It is
  never a background sync, and offline it says so.
