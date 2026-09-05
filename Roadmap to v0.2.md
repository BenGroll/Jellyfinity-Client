# Jellyfinity v0.1.x specifications

Read only the assigned version. Each version is one complete feature increment.
Stretch items do not block release. All versions require focused changes,
behavior tests, current documentation/ADRs where relevant, a changelog entry,
and passing CI. `OUTLOOK.md` is not part of this release schedule.

## v0.1.1 — Streaming Quality & Transcoding

**Goal:** Make the real library playable when direct play is unsuitable and let
the user select stream quality.

**Required:**

- Verify the format/codec gap on representative Android and iOS devices.
- Extend `StreamQuality` with a small set of meaningful tiers while retaining
  original quality.
- Resolve non-original tiers through Jellyfin audio transcoding and document
  endpoint, codec, and bitrate choices in an ADR.
- Persist one global quality setting.
- Surface transcode failures through the existing playback failure model. A
  fallback must be visible and a transient failure must not become permanent
  unavailability.
- Test URL/parameters for every tier and expired-session behavior; manually
  validate the real library's format mix.

**Done when:** Quality is selectable, the representative format mix plays, and
transcode failures are handled consistently with other playback failures.

## v0.1.2 — Playlist Curation

**Goal:** Let users manage Jellyfin playlists, not merely browse them.

**Required:**

- Add write contracts for create, rename, delete, add tracks, remove tracks,
  and reorder. A sibling write contract is acceptable if it keeps read and
  mutation responsibilities clearer.
- Keep existing partial/unavailable item behavior and playlist numbering.
- Add create, rename, and delete UI.
- Add-to-playlist must be available anywhere a track appears and from relevant
  album/playlist detail surfaces.
- Allow reorder and removal in playlist detail, consistent with the queue UI.
- Apply edits directly to Jellyfin unless a concrete requirement justifies
  optimistic local state and reconciliation. Document a non-obvious choice.
- Test every mutation, missing/unavailable entries, create/rename/delete UI,
  reorder/removal, and numbering after an edit.

**Stretch:** Bulk add-all. It must not delay the version.

**Done when:** A user can create, rename, delete, populate, reorder, and remove
from a playlist with the app's normal loading, error, and partial-state UX.

## v0.1.3 — Crossfade

**Goal:** Add configurable crossfade without regressing gapless playback.

**Required:**

- Confirm the playback engine can crossfade with the current queue/background
  architecture and record any architectural change.
- Persist enabled state and duration in playback preferences.
- Verify transitions across direct-play and transcoded sources.
- Test preference persistence and the engine configuration seam.
- Validate crossfade on and gapless playback with crossfade off on real Android
  and iOS devices.

**Done when:** Crossfade is configurable and works on both platforms, while
gapless playback remains correct when it is disabled.

## v0.1.4 — Volume Normalization

**Goal:** Provide consistent track-to-track loudness using ReplayGain or an
equivalent loudness-based approach.

**Required:**

- Determine what loudness metadata Jellyfin and the representative library
  actually provide before choosing an implementation.
- Document the data source, limitations, and behavior for untagged tracks.
- Apply gain without making the playback engine own queue/domain concerns.
- Persist an on/off setting. Target-loudness tuning is optional.
- Unit-test gain lookup/calculation and validate perceived consistency on real
  devices with representative mismatched tracks.

**Done when:** Normalization is configurable, its data source is honest and
documented, and missing metadata has defined behavior.

## v0.1.5 — Lyrics

**Goal:** Show lyrics for tracks that provide them.

**Required:**

- Verify the lyrics exposed by Jellyfin 10.11.6+ and present in the real
  library before choosing plain or synchronized lyrics.
- Add a lyrics view reachable from Now Playing.
- Plain lyrics are the baseline. Include synchronized scrolling only if the
  available data and timing support it reliably.
- Missing lyrics is an empty state, not an error.
- Test loading, present, and absent states. If synchronization ships, test
  highlighting against playback position.

**Done when:** Available lyrics render clearly and absence is handled clearly;
half-working synchronization must not ship.

## v0.1.6 — Interface Refresh

**Goal:** Polish the screens shipped in v0.1.1–v0.1.5 — Settings, Home,
Artist, Album, Now Playing, Queue, and Playlist — before v0.2.0 starts a new
arc. Primarily visual/interaction work; the small amount of new data it
needs (favorite state, an artist's counts and banner) is scoped to stay
that way.

**Research first:**

- Jellyfin's `UserItemDataDto.IsFavorite` and the `POST`/`DELETE
  UserFavoriteItems/{itemId}` endpoints back a real favorite toggle; no
  minimum-version change needed.
- Jellyfin's `BaseItemDto` has no playlist owner/creator field, and neither
  does the dedicated `GET /Playlists/{id}` response (`Shares`, `OpenAccess`,
  `ItemIds` only). Showing who made a playlist is not implementable against
  the API Jellyfinity uses and is dropped from this version rather than
  guessed at.
- An artist's album/song counts and total playtime are not a single field:
  they need their own `ArtistIds`-scoped queries (album count, song count,
  and a bounded sum of `RunTimeTicks`), separate from browsing the artist's
  discography.

**Required:**

- Settings: the streaming-quality picker becomes a dropdown, with the
  selected tier's description shown beneath it instead of one radio row per
  tier.
- Home: the search field gets a fully rounded (pill) shape; the media-type
  pills shrink.
- Artist page: show the backdrop image and overview (both already fetched
  fields) above the discography; add album count, song count, and total
  playtime alongside them; add a favorite toggle.
- Album page: the artist credit becomes a link to that artist's page; the
  single Play action becomes a centered Play button, a Shuffle button, and
  an overflow menu (Add to playlist, Add to queue) that act on the whole
  album; add a favorite toggle.
- Now Playing: artist and album become links; the background renders a
  heavily blurred, scaled copy of the current artwork instead of a flat
  fill; the source-format line becomes a stacked container/bitrate label on
  the left with a Lossless-or-transcode-target badge on the right; the
  existing track overflow menu (Play Next / Add to Queue) is reachable from
  the app bar; add a favorite toggle.
- Queue: the clear action becomes an explicit icon with a confirmation
  prompt; the queue's remaining total runtime is shown at the top; each row
  gets a drag handle so reordering starts from the handle rather than
  anywhere on the row.
- Playlist page: the same Play/Shuffle/overflow treatment as Album
  (including Add to playlist and Add to queue for the whole playlist).
- Add-to-playlist needs a minimal write seam that v0.1.2 has not built yet:
  `PlaylistRepository.addTracks` plus the Jellyfin `POST
  /Playlists/{id}/Items` call behind it. Nothing else from v0.1.2 (create,
  rename, delete, reorder, remove) is in scope here.
- Favorite state and the artist aggregate stats are read live from the
  server and are not added to the offline cache schema; both are hidden
  when a screen is showing its saved/cached copy rather than shown stale or
  guessed.

**Done when:** All seven screens above reflect their listed changes, a
favorite can be toggled from Artist/Album/Now Playing and persists to the
server, an album or playlist can be shuffled, added to another playlist, or
queued in one action, and the queue can be reordered from its handle with
its remaining runtime visible.

## Non-goals for v0.1.1–v0.1.5

Offline downloads, movies, TV, unified multi-server libraries, social or
collaborative features, smart playlists, recommendations, customizable Home,
the full theme editor, plugins, desktop/TV clients, global search redesign, and
v1.0 readiness are outside this arc.

Questions about device format support, loudness metadata, or lyrics data are
research steps inside their named version. They do not block other versions.
