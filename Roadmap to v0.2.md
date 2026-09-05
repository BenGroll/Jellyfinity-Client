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

## Non-goals for v0.1.1–v0.1.5

Offline downloads, movies, TV, unified multi-server libraries, social or
collaborative features, smart playlists, recommendations, customizable Home,
the full theme editor, plugins, desktop/TV clients, global search redesign, and
v1.0 readiness are outside this arc.

Questions about device format support, loudness metadata, or lyrics data are
research steps inside their named version. They do not block other versions.
