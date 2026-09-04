# ADR-0011: Media Domain & Repository Contracts

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.7 asks for Jellyfinity's own media vocabulary and the
mapping from Jellyfin's API into it, before the music library (v0.0.8) is
built on top. `PHILOSOPHY.md` §12 is the requirement it serves: Jellyfin
API response models must not become the application's domain vocabulary,
and the UI must never depend on raw Jellyfin JSON.

Everything below this milestone already exists — transport (ADR-0008),
sessions (ADR-0009), the local database (ADR-0010) — and none of it knows
what an album is. This is the release that introduces one.

Two constraints shape most of the decisions here:

- **Scale.** The development library is ~130k songs. Nothing may offer
  "give me all of X", and no filtering or sorting may happen in Dart.
- **Partial success.** A row the server sends that Jellyfinity cannot
  understand must not be dropped in silence, and must not fail the
  screen it appears on (`PHILOSOPHY.md` §2).

Scope is the vocabulary, the contracts, and the Jellyfin mapping, plus
Jellyfin-backed implementations so the contracts ship proven rather than
hypothetical. No UI, no search, no caching, no playback.

## Options Considered

### How much of the repositories to build

1. **Contracts, mapping and remote implementations** (chosen). The
   contracts are exercised end to end against a fake `dio` adapter, so
   v0.0.8 starts from working library reads rather than from interfaces
   nobody has called.
2. **Contracts and mapping only.** The narrowest reading of the roadmap,
   but it leaves every contract unproven until the first UI, which is
   exactly when a wrong contract is most expensive to change.
3. **Also the local-first read-through caching.** Rejected as
   v0.0.8's work: ADR-0010 deliberately deferred the local/remote base
   until there is a real second caller, and designing a cache with no
   consumer is the guesswork that ADR said to avoid. Media tables and
   media-scale query tests therefore stay in v0.0.8.

### Media identity

**`MediaId` = Jellyfinity's local server id + the Jellyfin item id**
(chosen), carried by every entity, with a `key` string form for cache
keys and route parameters.

A Jellyfin item id means nothing without the server that issued it.
Passing bare ids around is precisely what `OUTLOOK.md` §7 warns against,
and unified multi-server libraries (§14) would have to retrofit the
server dimension into every model, table and cache key. The pair costs
one small value type now and keeps both futures open.

The server half is the **local** id (`JellyfinServer.id`), not the
server's self-reported one: it is what the session layer already joins
on, and it survives a server being renamed or reinstalled.

This is not portable identity, and does not pretend to be. Share links
and cross-server resolution need identity built from stable metadata
(title, artist, MusicBrainz ids); that is a later design, and it is an
addition to this model rather than a replacement of it.

### DTO shape

**One polymorphic `BaseItemDto` plus type-switching mappers** (chosen).
Jellyfin answers every item request with the same object and
discriminates it with `Type`; per-type DTOs would duplicate the field
list several times over and still need a discriminator step. Only the
fields Jellyfinity uses are declared — the real object has well over a
hundred.

`BaseItemMapper` checks `Type` itself rather than trusting the query
that produced the item. That is what stops a film sitting in a playlist
from being rendered as a song.

### Entity depth for movies and TV

**Entities and mapping, no video repository contracts** (chosen). The
roadmap asks for enough video representation that the architecture does
not become music-specific; a `VideoLibraryRepository` with no caller for
several releases is the speculative abstraction ADR-0001 rules out.
`Movie` and `Episode` carry `PlaybackProgress` — the field music does not
need and video cannot do without — which is the part that actually keeps
the model honest.

### The base type

`MediaItem` is an ordinary abstract class, not `sealed`. Sealing would
force every entity into one library or a chain of `part` files, and
nothing yet needs an exhaustive switch. Revisit if a screen appears that
genuinely wants one.

### Where the session comes from

The media layer needs the active server's address, the Jellyfin user id,
and the local server id (the other half of every `MediaId`). It gets them
through **`JellyfinSessionContext`**, an interface declared in the
transport layer and implemented in `lib/app` by `SessionJellyfinContext`
over `AuthSessionManager` — the same seam, for the same reason, as
ADR-0008's `AuthTokenProvider`. Infrastructure still does not depend on
the composition root.

## Decision

### Domain — `lib/domain/media/`

Entities: `Artist`, `Album`, `Track`, `Playlist`, `Movie`, `Series`,
`Season`, `Episode`, all extending `MediaItem` (`id`, `name`,
`availability`, `image`, `kind`). Supporting types: `MediaId`,
`MediaKind`, `MediaImage`/`MediaImageKind`, `MediaAvailability`,
`PlaybackProgress`, `ArtistRef`, `Page`/`PageRequest`.

Fields are the ones a known view needs, not the ones Jellyfin offers.
Unreported details stay `null` rather than defaulting to zero, so a card
can omit "0 songs" instead of stating it.

`ArtistRef` is a named credit, deliberately not a half-empty `Artist`: a
credit often arrives as a name with no artist item behind it, and
modelling that as an `Artist` would make every consumer guess which
fields are real. A credit without an id is displayable but not
navigable.

**Availability.** All five roadmap states are modelled. Today the mapper
produces `remoteOnly`, and `remoteUnavailable` for an item the library
lists but has no file for (Jellyfin's `LocationType: Virtual` — a missing
episode). The download states arrive with downloads (post-v0.1.0);
`partiallyAvailable` becomes producible in v0.0.8, when a collection is
loaded together with its children. The vocabulary exists now so the first
UI branches on it rather than being retrofitted.

**Paging.** `PageRequest` (start index + limit, default 100) and
`Page<T>`. No contract offers an unwindowed read. A `Page` holds its
items as ADR-0004's `Partial<T>`, so unreadable rows are recorded rather
than dropped, and `consumed` counts them — otherwise a broken row would
be requested forever and paging would stall.

**Contracts** (narrow, per ADR-0001, not one media repository):
`MusicLibraryRepository`, `PlaylistRepository`,
`MediaMetadataRepository`, `PlaybackProgressRepository`,
`ArtworkResolver`. `Err` means the request could not be answered at all;
`Ok` with unavailable entries means it was answered imperfectly, which
is a rendered screen and not an error state.

### Infrastructure — `lib/infrastructure/jellyfin/media/`

- **`BaseItemDto`** / `NameIdPairDto` / `UserItemDataDto` /
  `ItemsResponseDto` — `json_serializable`, every field nullable, same
  rules as the existing DTOs.
- **`BaseItemMapper`** — bound to one server id, the only translator in
  the codebase. Ticks to `Duration`, `LocationType` to availability,
  `UserData` to `PlaybackProgress`, image tags to `MediaImage` following
  Jellyfin's inheritance (a song's artwork points at its *album*, an
  episode's at its *show*, so one image is cached once instead of once
  per row). Never throws: an item without an id or a name, or of the
  wrong type, maps to `null` and the caller records it as unavailable.
- **`JellyfinMediaApi`** — the one place that knows Jellyfin's query
  vocabulary, and the owner of the session-scoped `JellyfinHttpClient`
  (one per server, rebuilt when the active profile moves to another
  server). Also hands out the server-bound mapper and validates that a
  `MediaId` belongs to the server in use — an id from another saved
  server comes back as `UnavailableFailure`, never as a query to the
  wrong library.
- **Repositories** — `JellyfinMusicLibraryRepository`,
  `JellyfinPlaylistRepository`, `JellyfinMediaMetadataRepository`,
  `JellyfinPlaybackProgressRepository`, `JellyfinArtworkResolver`, all
  registered against their contracts. Signed out, every one of them
  fails as `UnauthorizedFailure` without touching the network.

Single items are fetched through the collection endpoint filtered to one
id, rather than the single-item route: it is the same query surface (so
the same fields and user data come back) and a removed item answers with
an empty list instead of a 404.

`JellyfinHttpClient` gains `send()`, for endpoints whose answer is their
status code (marking an item played or unplayed via
`/UserPlayedItems/{itemId}`, which replaced the per-user route in
Jellyfin 10.10). Reporting a *position* mid-playback needs a play
session and belongs with the player in v0.0.9.

**Artwork** resolves to a URL rather than being fetched: Jellyfin serves
images unauthenticated, so any image loader can take it. Callers pass the
size they will draw, because a grid of covers on a phone must not pull
full-resolution artwork. The image tag makes a changed image a different
URL, which is the invalidation ADR-0010 specified; the bounded
disk/memory cache itself still lands in v0.0.8, behind the same contract.

## Tests

All hermetic — the `FakeDioAdapter` from v0.0.4 answers every request, so
no Jellyfin server is required:

- `test/domain/media/` — identity (including the pair-not-the-id
  property), availability semantics, progress arithmetic, and paging
  (windows, end detection, and that unusable rows still advance the
  window).
- `base_item_mapper_test` — the heart of the release: type
  discrimination across all eight kinds, refusal to map an item of the
  wrong type, ticks/credits/artwork-inheritance mapping, missing fields
  staying null, virtual episodes marked unavailable, and pages that keep
  their usable rows.
- `jellyfin_media_api_test` — query building (window, sort, fields,
  user), signed-out short-circuiting, the played-flag verbs, id scoping,
  and that the client follows a profile switch to another server.
- One test file per repository, covering the endpoint and parameters
  each one produces, entity mapping, partial pages, removed items,
  cross-server ids, and signed-out behaviour.
- `session_jellyfin_context_test` — the seam reports the *local* server
  id, and stops reporting anything after sign-out.
- `service_locator_test` — every media contract resolves from the graph.

## Consequences

- `lib/domain/` now holds Jellyfinity's media vocabulary, and a feature
  can be written against it without importing anything from
  `lib/infrastructure/`. That is v0.0.7's definition of done.
- v0.0.8 builds the music UI on these contracts, adds search to
  `MusicLibraryRepository`, and puts the local cache behind the same
  interfaces — the UI will not know which source answered.
- The mapper is the single point of change when Jellyfin's item shape
  moves; nothing else in the codebase reads a Jellyfin field name.
- `partiallyAvailable` and the two download states are modelled but not
  yet produced. This is deliberate, and the same discipline ADR-0010
  applied to the artwork cache.
- Entities will gain fields as views need them. The rule is that a field
  arrives with the behaviour that uses it, not because Jellyfin offers
  it.
