# ADR-0035: Random discovery and a personal mix

## Status

Accepted

## Context

ADR-0034 (v0.4.4, Library exploration) shipped genre and decade entry
points scoped to albums, and a random pick scoped to albums and artists.
Three follow-ons were identified but deliberately left out to keep that
version's diff focused:

- genre browsing extended to artists, and genre/decade browsing extended
  to songs;
- a "Random song" action alongside "Random album"/"Random artist";
- genre browsing that degrades to the profile's downloads while offline
  instead of failing outright, the way random pick already does.

Ben asked for all three, plus a new request: a "Play something you think
I'll like" button on Home that fills the queue with a mix. This ADR
covers both — the three follow-ons stay inside Library exploration's own
architecture; the mix is new ground and gets its own decision below.

## Decision: the three follow-ons extend, rather than replace, ADR-0034

**Genre for artists, genre/decade for songs.** `MusicLibraryRepository
.artists`/`.tracks` gain the same `genre`/`decadeStart` parameters
`.albums` already had, read live only on the same terms. An artist has
no single release year, so `artists` never gained a `decadeStart` — there
is nothing honest to filter by.

**`LibraryFacetAlbumsPage` becomes `LibraryFacetPage`.** A genre browse
now shows three tabs (Artists, Albums, Songs); a decade browse shows two
(Albums, Songs — no Artists tab, for the reason above). It reuses
`ArtistsTab`/`AlbumsTab`/`SongsTab` from `LibraryPage` exactly as they
render there, each cubit narrowed with a new `forGenre`/`forDecade`
method alongside the existing `forArtist` — a filtered browse is still
just "which artists/albums/songs," not a different screen.

**`randomTrack()`.** A third button ("Song") beside "Album"/"Artist" on
Explore's "Surprise me" section, built the same way through
`_randomSingle` server-side and `DownloadsLibrarySource._randomPick`
offline. A track has no detail page, so a successful pick plays it
immediately (`pickRandomTrack`) instead of navigating anywhere — the same
"Play now" meaning every other track row already has.

**Genre browsing degrades offline instead of failing.** This is the one
follow-on that changes ADR-0034's own reasoning, so it is worth being
explicit about what changed and why:

ADR-0034 argued genres and decades should both fail outright while
offline, because "nothing about a genre is stored anywhere... a
deliberately- or actually-offline read fails honestly instead of showing
a stale or empty shelf." That is still true of *decades* — nothing on the
device carries a production year in a form worth aggregating offline.
It stops being true of *genres* once downloads capture one: a genre a
download actually carries is not stale or invented, it is exactly as
honest as `randomAlbum`'s downloads fallback already is. So:

- `BaseItemDto` gains a `genres` field, requested via a new
  `JellyfinMediaApi.trackDownloadFields` (`defaultFields` + `Genres`) —
  its own list, not folded into `defaultFields`, because that one is paid
  for on every row of every 130k-track browse and `Genres` is not worth
  that cost everywhere. `JellyfinMusicLibraryRepository.tracks` uses it
  only when the read is already scoped to one album or one artist
  (dozens of rows, not 130k) — the unscoped whole-library browse is
  unaffected.
- `Track` gains a matching `genres` field, mapped straight through
  `BaseItemMapper.toTrack`. It is *not* added to the offline metadata
  cache (`MediaCacheMapper` is untouched) — the precedent is
  `Artist.isFavorite`/`Track.isFavorite`: a field that is honest on a
  live read and would be stale or absent if persisted generically stays
  out of the general cache.
- `TrackDownload` gains a `genres` field instead, captured at the moment
  a track is downloaded — because `downloadAlbum`/`downloadArtist`
  already read their tracks through the newly-scoped `tracks()` call
  above, this needs no change to `DownloadsCubit`: the genre arrives for
  free wherever a bulk download already asked for it. Schema **v11**
  adds `track_downloads.genres_json` (nullable, additive).
- `DownloadsLibrarySource.genres()` unions the genres captured on
  completed downloads. `CachedMusicLibraryRepository.genres()` now
  branches on `OfflineMode.status.isOffline` to it, the same "offline is
  a different scope, not a fallback" shape `randomAlbum` already uses.

This is deliberately **honest partial coverage, not a promise**: most
download paths (a single ad-hoc track, a playlist) still do not request
`Genres`, so a profile's offline genre shelf reflects only what a bulk
album/artist download happened to capture. That is consistent with how
this codebase already treats partial data everywhere else — a row it
cannot make sense of is marked unavailable, not hidden and not faked.

`DownloadsLibrarySource` also gains `randomTracks({limit})` — a shuffled,
bounded sample of the profile's downloaded tracks, read once into memory
rather than one windowed query per sampled track (downloads are bounded
by what the user chose to keep, unlike the server library). This is the
mix's fallback pool below, and also `MusicLibraryRepository`'s live-side
counterpart for the same purpose online.

## Decision: the "for you" mix stays inside this arc's privacy rule, and says so

Ben's ask — "fill your queue with random stuff you will like" — sits
right at the boundary `PHILOSOPHY.md`/`OUTLOOK.md` §13 draws: useful
discovery is welcome, an opaque recommendation engine or tracking backend
is not. The mix is built from exactly what the signed-in profile has
already told Jellyfinity, and nothing else:

1. Favorited tracks, directly (`favoriteTracks`).
2. A sample from each of up to five favorited albums
   (`favoriteAlbums` + `tracks(albumId:)`).
3. A sample from each of up to five favorited artists
   (`favoriteArtists` + `tracks(artistId:)`).
4. If that still does not fill the mix — including a profile with no
   favorites at all — `randomTracks` tops it up.

No listening history, no cross-profile or cross-server merging, no
external call. Every read this composes already has its own offline
story (favorites are cached per profile, ADR-0028; `randomTracks`
degrades to downloads while offline, this ADR above), so the mix
degrades along with them with no special-casing of its own.

**It never claims more personalization than it used.** The snackbar
after playback starts is one of three exact sentences depending on what
actually happened: built entirely from favorites, favorites topped up
with a random sample, or — a profile with no favorites yet — an outright
random mix, said as such rather than dressed up. This is the same
standard ADR-0034 held random pick to ("the caption always says which,
so a pick is never a mystery about what it drew from"), applied to a
mix instead of a single item.

**A free function, not a cubit.** `playForYouMix` follows
`explore_actions.dart`'s documented shape: a one-shot action over
`getIt<MusicLibraryRepository>()` with nowhere to keep state between
calls. The button that triggers it (`_ForYouMixCard`, new on
`HomePage`) owns its own "building" spinner; the mix logic holds none.

**On Home, not Explore.** The roadmap's `OUTLOOK.md` §13 items this
answers — "because you listened to...", personalized Home sections — are
named for v0.5.0 (Personal music discovery), not this version. Placing
the entry point on Home rather than folding it into Explore acknowledges
that: it is a *listening* shortcut keyed to what the profile already
loves, the same category Home's other sections are already in, not a
*browsing* tool like the rest of Explore. It leads every populated Home
(`_HomeBody`) and gets its own copy inside `_EmptyHome` — a fresh
install with nothing to resume or replay is exactly who most needs a
"press play" nudge, and an honest random mix is a fine answer for one.

v0.5.0 remains open: it is discovery seeded by listening *history* and
related-item endpoints, a materially different question from "what has
this profile already starred."

## Consequences

- `MusicLibraryRepository` gains `genre` on `artists`, `genre`/
  `decadeStart` on `tracks`, `randomTrack`, and `randomTracks`.
- Schema **v11**: `track_downloads.genres_json`, nullable and additive.
- `AppButton`'s label is now wrapped in `Flexible` with ellipsis
  overflow — found by the "Song"/"Album"/"Artist" row not fitting three
  across on a phone width even without icons. A backward-compatible
  hardening of the shared component: any button that already fit is
  unchanged, one that does not now ellipsizes instead of overflowing.
- `LibraryFacetAlbumsPage` is renamed `LibraryFacetPage` and gains tabs;
  its routes are unchanged.
- One new free-function file (`for_you_mix_actions.dart`), one new Home
  widget (`_ForYouMixCard`).
