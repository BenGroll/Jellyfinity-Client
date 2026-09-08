# ADR-0029: Related artists and albums

## Status

Accepted

## Context

`Roadmap to v0.4.md` v0.3.5 asks that one thing lead to the next: related
artists on Artist detail, similar albums on Album detail, drawn entirely
from the user's own server. The roadmap is explicit about the shape:

- Use **Jellyfin's own similarity endpoints** — no external
  recommendation service, no tracking backend, nothing that sends
  listening data anywhere (`PHILOSOPHY.md`, `OUTLOOK.md` §13).
- A server that answers nothing useful is a **normal outcome, not a
  failure**. The section is absent, not broken, and never a spinner
  forever.
- Surface the same relationships on Home **only where it earns its place**
  — useful, not filler.

This is the fifth section of the Home arc, but the first that lives
primarily on a detail screen rather than on Home.

## Decision: a live-only read, modelled on `artistStats`

`MusicLibraryRepository` gains `relatedArtists(id, {limit})` and
`similarAlbums(id, {limit})`, each returning `Future<Result<List<T>>>`.

- **`List`, not `Page`.** These are bounded "you might also like" strips,
  not browsable collections. There is no paging and no "load more", so a
  `limit` replaces the `PageRequest` and the result is a plain list. This
  is the same call ADR-0027 weighed for `recentlyAddedAlbums` and
  resolved the other way — but that one is cached through the collection
  path and needs a `Page` to carry `PageSource`; this one is not.
- **Live only, nothing cached.** Similarity is the server's computed
  answer about the whole library; it is cheap to ask for again, it is
  only ever shown on a screen the user reached online-or-cached anyway,
  and a stale "similar" list is not worth a schema table or a
  collection-cache key. This mirrors `artistStats` exactly: its own
  query, read live, and a failure just hides the section rather than
  failing the page it sits under.
- **`CachedMusicLibraryRepository` short-circuits when offline.** Unlike
  `artistStats` (which delegates straight through), the offline check is
  worth the two lines here: there is genuinely nothing to attempt, so the
  read returns a `RecoverableFailure` immediately rather than waiting for
  a network timeout. Either way the caller's section is absent.

## Decision: `JellyfinMediaApi.similarItems`, its own request

`GET /Items/{itemId}/Similar` is its own method, not a mode of
`queryItems`. The `/Similar` route takes none of the collection
vocabulary `queryItems` speaks — no `SortBy`, `IncludeItemTypes` or
`Recursive` — and the server picks both the ordering and the returned
type (an album's similars are albums, an artist's are artists). Folding
it into `queryItems` would mean a second code path inside that method
guarded by "is this the similar endpoint". The new method takes a
`limit`, asks for the default image types, and returns the same
`ItemsResponseDto` every other read maps.

A server that predates the endpoint answers 404, which
`TransportErrorMapper` turns into `UnavailableFailure` — the caller
treats that like any other failure: no suggestions, section absent. This
is the "older-but-supported server degrades quietly" case the roadmap
names, and it needs no version check.

`JellyfinMusicLibraryRepository` maps the rows with `toArtist` / `toAlbum`
and **drops** anything of the wrong type or that will not map, rather than
surfacing it as an `unavailable` card. A suggestion strip has no use for
a blank tile — this is the one place the "record it, do not drop it"
rule (`PHILOSOPHY.md` §2) does not apply, because the row was never
something the user asked to see.

## Decision: rendered as a footer strip, absent until it has something

Both detail pages already build their body from `PagedCollectionView`
(the discography grid / the track list). That widget gained a
`footerSlivers` parameter — the mirror of its existing `headerSlivers` —
and each page passes one `SliverToBoxAdapter` holding a
`BlocBuilder<RelatedMediaCubit>`.

The strip renders **nothing at all** while loading and whenever the read
came back empty or failed. No skeleton, no error row, no retry button: it
is a bonus that appears when it is ready and is simply not there
otherwise. `RelatedArtistsCubit` / `SimilarAlbumsCubit` extend a shared
`RelatedMediaCubit<T>` (the same generic-base-plus-typed-subclass shape
as `MediaDetailCubit`), carry `OfflineReload` so coming back online fills
a strip that was empty offline, and expose only `items` / `isLoading` /
`hasLoaded` — there is no `failure` field, because a failure is never
shown.

`RelatedMediaStrip` is one widget for both: it takes plain `MediaItem`s,
draws an artist as a circle and an album as a rounded cover, and reads the
credit line off an `Album`. A tapped card pushes the matching
`library/...` detail route onto whatever branch the page is on (Library,
Home or Favorites), exactly as ADR-0028 established for the Favorites
destination.

## Decision: no Home section

The roadmap allows a Home strip "where it earns its place… only if it
reads as useful rather than as filler". It is left off:

- Home already opens on four sections (Continue listening, Recently
  played, Recently added, Favorites). A fifth that is "more like
  something" competes with all of them for the first screen.
- Every other Home section is anchored in something the user *did* — a
  queue, a play, a star — or a plain library fact ("what is new").
  "Similar to X" needs the app to **pick X**: the last-played artist, a
  favorite, a random album. Choosing that seed is a recommendation
  heuristic, and §13 draws the line at exactly that kind of guessing.
- The roadmap's "Done when" — "finishing an album offers somewhere
  obvious to go next" — is the *album page*, and it is met there.

If a later version finds a seed that is honest rather than guessed, a
Home strip is one `RelatedMediaStrip` and one cubit away.

## Consequences

- `MusicLibraryRepository` gains two methods; `JellyfinMediaApi` gains
  `similarItems` and `similarItemsPath`. No change to `queryItems`, so
  every existing query path is untouched.
- `CachedMusicLibraryRepository` gains two pass-through methods with an
  offline guard. **No schema change, no cache key, no new table.**
- One shared feature cubit family (`RelatedMediaCubit` +
  `RelatedArtistsCubit` + `SimilarAlbumsCubit`), one widget
  (`RelatedMediaStrip`), one new parameter on `PagedCollectionView`.
- The genre / decade entry points listed as a stretch goal are not
  taken on — they are a browsing surface of their own, not a section.
