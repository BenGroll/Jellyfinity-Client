# ADR-0019: Favorites

## Status

Accepted

## Context

`Roadmap to v0.2.md`'s v0.1.6 asks for a favorite toggle on the Artist,
Album, and Now Playing screens, alongside several other, purely visual
changes. Making it real (not decorative) needs a place to read whether an
item is already a favorite, and a way to change that on the server.

Jellyfin already sends `UserData.IsFavorite` on every item response —
nothing extra to ask for, unlike `MediaSources` (ADR-0015) or `Overview`.
Setting it is `POST`/`DELETE UserFavoriteItems/{itemId}` (the current
route; the legacy `Users/{userId}/FavoriteItems/{itemId}` form still works
but is obsolete on the servers Jellyfinity targets). No minimum-version
change is needed either way.

The harder question was the offline cache. `CachedMusicLibraryRepository`
persists every `Artist`/`Album`/`Track` it reads into a typed Drift table
(`CachedMediaItems`), which would ordinarily mean a schema migration to add
a favorite column — plus the same question for `Artist.overview`/`banner`
and the new `ArtistStats` counts v0.1.6 also adds. v0.1.6 is meant to stay
a UI-focused release; taking on a Drift migration for it is a materially
different, larger piece of work than the rest of the version.

## Decision

Favorite state (and the new artist overview/banner/stats) is **read live
only, never persisted to the offline cache**:

- `Artist`, `Album`, and `Track` each gain an `isFavorite` field, defaulted
  to `false`. `BaseItemMapper` sets it from `dto.userData?.isFavorite`.
- `MediaCacheMapper.toRow`/`toItem` are **not** changed. A row written to
  the cache simply has nothing to say about the new fields; reading it
  back gets the constructor's `false`/`null` defaults. This is why the
  fields could be added with no migration at all — Drift never has to
  reproduce them.
- A new narrow `FavoritesRepository` contract (`setFavorite(MediaId id,
  {required bool favorite})`), on the same "several narrow media
  contracts" precedent as `MusicLibraryRepository`'s own doc comment
  (ADR-0001). `JellyfinFavoritesRepository` is its only implementation —
  there is no cached/local half, because a write is only ever attempted
  while a screen is showing a live-fetched item.
- Every screen with a heart button hides it while showing a cached/offline
  copy, or before an on-demand fetch (Now Playing's `NowPlayingDetailsCubit`)
  has completed — never showing an unfilled heart that might actually be a
  favorite, or a filled one that might not be.
- `ArtistStats` (album/song counts, total playtime) follows the identical
  rule: a new `MusicLibraryRepository.artistStats` method,
  `CachedMusicLibraryRepository` delegating straight through with no
  caching, and the artist page hiding the whole stats row on failure
  rather than showing stale numbers.

### Now Playing's favorite state and artist/album links

`QueueEntry` (the queue's persisted, denormalized snapshot of a track) was
deliberately kept out of this: adding `isFavorite` and navigable artist/
album ids to it would mean the same kind of schema change to
`QueueEntries` this ADR is avoiding elsewhere, for a screen that already
has an established "fetch fresh, on demand" pattern
(`TrackSourceInfoCubit`, ADR-0015). `NowPlayingDetailsCubit` re-reads the
current track's full record via `MediaMetadataRepository.item` when Now
Playing opens, and both the heart button and the artist/album links use
that instead. Offline, the cubit's fetch fails, the heart stays hidden,
and the artist/album lines fall back to the queue snapshot's plain text —
exactly what Now Playing already showed before this version.

### Playlist ownership is not implemented

The roadmap also asked to show who made a playlist. Checked against
Jellyfin's `BaseItemDto` and the dedicated `GET /Playlists/{id}` response
(`Shares`, `OpenAccess`, `ItemIds` only): neither exposes an owner/creator
name. This is dropped from the version rather than guessed at from a
`Shares` entry or invented — `CONTEXT.md`'s "never leave users guessing"
cuts against showing a name that might be wrong as often as it is right.

### Cross-navigator links from Now Playing

Implementing the artist/album links surfaced an unrelated, pre-existing
gap: Now Playing is a root-level `GoRoute` (so it can cover the bottom
nav), while `libraryArtist`/`libraryAlbum` are nested inside the shell's
Library branch. Pushing a shell-nested named route directly from a root
route reproduces a `go_router`/`Navigator`
`!keyReservation.contains(key)` assertion once the branch's own page stack
already exists — confirmed with a minimal reproduction that bypassed
Jellyfinity's own widgets entirely. Now Playing's links close the player
(`context.pop()`) before pushing into the library, the same "tap an artist
from the full-screen player" behavior most music apps already have, which
sidesteps the cross-navigator push rather than fixing `AppRouter`'s
shell/root nesting — a larger change than this version's scope.

## Tests

- `base_item_mapper_test` — `isFavorite` mapped from `UserData`, and
  defaulting to `false` when absent; `Artist`'s new `overview`/`banner`
  fields, including the empty-backdrop-tag edge case.
- `jellyfin_media_api_test` — `setFavorite`/`addPlaylistItems` POST/DELETE
  and their query parameters.
- `jellyfin_favorites_repository_test` — the cross-server id guard.
- `jellyfin_music_library_repository_test` — `artistStats`' counts and
  summed runtime, the `durationSumLimit` cutoff, and failure propagation.
- `playback_ui_test` — the Now Playing heart toggling through a fake
  `FavoritesRepository`, the artist link opening `ArtistDetailPage`, and
  the pre-fetch fallback to plain text.

## Consequences

- A favorite toggled while offline is not possible and is not offered —
  consistent with every other mutation in this codebase (`CachedPlaylist
  Repository.addTracks`, similarly, is not cached).
- Reopening a cached/offline Artist, Album, or Track always shows it as
  not-favorited and hides the heart, even if it actually is one on the
  server — a deliberate "say nothing rather than guess" choice, not a bug
  to fix by adding the migration this ADR chose to avoid.
- `ArtistStats.totalDuration` is `null` for an artist with more than
  `ArtistStats.durationSumLimit` (2000) tracks, so the page shows counts
  without a total rather than summing an unbounded number of tracks for
  one label.
- A future version that wants favorites/stats available offline, or wants
  to show a playlist's owner once Jellyfin exposes one, will need its own
  ADR — this one's cache and API decisions do not extend to that.
