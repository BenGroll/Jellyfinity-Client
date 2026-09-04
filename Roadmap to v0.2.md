# Jellyfinity Roadmap — v0.1.x

## Scope of This Roadmap

`ROADMAP.md` defines the path through `v0.1.0` and stops there deliberately —
`OUTLOOK.md` says its post-v0.1.0 list is "not a promised release schedule."
This document picks up where `ROADMAP.md` ends.

**Assumption:** `v0.1.0` is tagged and its release blockers
(`pre-v0.1.0-review.md`) are resolved before this roadmap starts. This
document does not re-litigate that work.

### Versioning convention for this series

`v0.0.1`–`v0.0.9` were never semver "patch bumps" — each was one whole
feature/architectural increment (a full branch, its own ADR, its own
Definition of Done), same as `v0.0.8` (music library) or `v0.0.9` (audio
playback). `v0.1.0` continues that pattern: it is the proof that the whole
concept works end to end, not a "1.0-but-smaller" release.

This roadmap continues the same granularity into the `0.1.x` line:

- `v0.1.0` — proof the concept works (browse, search, play, queue,
  background playback, one coherent journey).
- `v0.1.1`, `v0.1.2`, `v0.1.3`, ... — each one whole feature, same size and
  weight as a `v0.0.x` release, not a bugfix patch.
- `v1.0.0` — first version made public. What that actually requires (which
  of `OUTLOOK.md`'s items, what polish bar, what store-readiness work) is a
  separate decision for later and is **not** defined by this document.

A true bugfix-only release on an already-tagged version (e.g. something
broken discovered in `v0.1.0` after tagging) would still use a fourth
component or an explicit "fix" branch off that tag — this document is only
about the next several whole-feature increments, not that case.

### Why this next arc, in this order

Three places in the v0.0.9/v0.1.0 code explicitly name this exact scope as
"later," so this is not a new direction — it's finishing what was
deliberately deferred:

- `StreamQuality` (`lib/domain/playback/stream_quality.dart`) has one
  member, `original`, with a doc comment saying the parameter exists so "a
  transcoded/lower-bitrate option is an addition here later, not a signature
  change through every caller."
- `PlaylistRepository` (`lib/domain/media/PlaylistRepository.dart`) is
  read-only by design, with a doc comment saying "editing playlists
  (post-v0.1.0, `OUTLOOK.md` §6) belongs here and nowhere near library
  browsing."
- ADR-0013 states outright: "Lyrics, crossfade, ReplayGain and configurable
  transcoded quality are deliberately not addressed... `StreamQuality` and
  the engine seam leave room for the last one without committing to it now."

This also follows `PHILOSOPHY.md` §18 — make an existing core feature
substantially better before widening scope to a second media type or to
downloads. Both remain tracked in `OUTLOOK.md` as later work, not narrowed
or promised by this document.

The five releases are sequenced, not parallel tracks:

1. **v0.1.1 — quality/transcoding** goes first. It's a reliability question,
   not a nice-to-have — the pre-v0.1.0 review flagged direct-play-only as a
   possible usability blocker if a meaningful share of the real ~130k-track
   library needs transcoding.
2. **v0.1.2 — playlist curation** goes second. Mostly repository/UI work
   with limited playback-engine overlap, so it can proceed independently.
3. **v0.1.3 — crossfade** goes third, once the playback engine is stable
   again after the transcoding change — stacking crossfade on top of an
   unstable transport path would make failures hard to attribute.
4. **v0.1.4 — volume normalization** goes fourth, immediately after
   crossfade: same playback-engine area, shared test/device setup.
5. **v0.1.5 — lyrics** goes last. ADR-0013 already treated lyrics as
   best-effort rather than committed scope; the same caution applies here.
   Descope cleanly if the data isn't there, without blocking anything above.

---

# v0.1.1 — Streaming Quality & Transcoding

## Goal

Make playback work well for every track in the real library, not only the
ones direct-play already handles, and give the user a real quality choice.

## Why This Is a Separate Release

`AudioSourceResolver`/`StreamQuality` already anticipate this. It was
explicitly out of scope for v0.0.9 only because building transcoding wasn't
required to prove background playback and queue ownership. Now that those
are proven in v0.1.0, this is the next unfinished seam — and the one with
the most direct effect on "can I actually use this app daily."

## Required Work

### Validate the real gap

Before building anything, confirm the problem exists: check which
codecs/containers in the real ~130k-track library direct-play cleanly on
representative Android and iOS versions, and which currently fail or
downgrade silently. This determines whether transcoding is a correctness
fix or a pure enhancement.

### Quality tiers

Extend `StreamQuality` beyond `original` with a small, meaningful set (e.g.
original/lossless passthrough, a high-bitrate transcode, a data-saver
transcode). Keep the enum's existing purpose: an addition to the resolver
contract, not a signature change through every caller.

### Jellyfin-side transcoding

Use Jellyfin's existing audio transcoding/streaming parameters
(`JellyfinAudioSourceResolver` already knows the direct-play URL shape) to
request a transcoded stream when quality requires it. Record the approach —
which endpoint/parameters, how bitrate maps to tiers, cellular vs. Wi-Fi
defaults if any — in a new ADR.

### User-facing setting

Add a quality setting (likely in the existing Settings screen alongside
navigation mode). A global default is enough for this release; per-network
(Wi-Fi/cellular) quality can be deferred if it adds meaningful scope.

### Failure behavior

A transcode failure must follow the same unavailable-track handling the
queue already has — never silently fall back to a different quality without
telling the user, and never treat it as a permanent unavailability if it was
a transient transcoding failure.

## Tests

- Resolver tests proving each quality tier requests the right stream shape.
- A regression test that an unauthenticated/expired-session transcode
  request fails the same way direct-play does today.
- Manual device validation against the real library's actual format mix.

## Definition of Done

`v0.1.1` is complete when a user can choose a streaming quality, playback
succeeds for the real library's format mix (not only formats that happened
to direct-play), and a transcoding failure is surfaced and handled the same
way an unavailable track is handled elsewhere.

---

# v0.1.2 — Playlist Curation

## Goal

Let the user actually curate playlists from Jellyfinity instead of only
browsing and playing ones that already exist on the server.

## Why This Is a Separate Release

`OUTLOOK.md` §6 lists this directly, and the domain layer already reserves
the seam for it (`PlaylistRepository`'s doc comment names this exact
scope). It is also the most obvious "core feature, not new feature" gap
left in the music vertical — every comparable music client supports this.

## Required Work

### Repository contract

Extend `PlaylistRepository` (or add a sibling contract, if read/write
deserve separate seams the way other repositories do) with the necessary
mutations: create, rename, delete, add track(s), remove track, reorder.
Keep the existing read side's partial/unavailable-item handling intact —
editing must not break the "playlist keeps its numbering even with missing
tracks" guarantee `PlaylistRepository.tracks()` already documents.

### UI

- Create/rename/delete playlist actions.
- Add-to-playlist from the existing track overflow menu (next to the
  current Play Next / Add to Queue actions) and from album/playlist detail
  screens.
- Reorder and remove within the playlist detail screen, consistent with the
  existing queue screen's `ReorderableListView` pattern.
- Bulk "add all" from an album/playlist to another playlist is a reasonable
  stretch item; do not block the release on it.

### Server sync

Decide and document whether playlist edits are applied directly against
Jellyfin (simplest, keeps Jellyfinity's playlists identical to what the
Jellyfin server/other clients see) or need local optimistic state with
reconciliation. The simpler direct-write model is the sensible default
unless a concrete requirement forces otherwise.

## Tests

- Repository contract tests for every mutation, including partial/
  unavailable interaction (e.g. removing an already-unavailable entry).
- Widget tests for create/rename/delete flows and reorder/remove within a
  playlist.
- A regression test that playlist numbering behavior for unavailable items
  survives an edit.

## Definition of Done

`v0.1.2` is complete when a user can create a playlist, rename it, delete
it, add tracks to it from anywhere a track appears, remove tracks from it,
and reorder it — with the same loading/error/partial-state discipline the
rest of the app already has.

---

# v0.1.3 — Crossfade

## Goal

Add configurable crossfade between tracks.

## Why This Is a Separate Release

This is playback-engine-level work. Sequencing it after v0.1.1 avoids
debugging two simultaneous playback-transport changes (transcoding and
crossfade) at once; sequencing it before v0.1.4 lets both engine-level
releases share test setup and device-verification passes.

## Required Work

### Engine capability

Confirm `just_audio`'s crossfade support (or the specific approach it
requires) is compatible with the existing gapless-playback requirement —
gapless and crossfade are related but distinct, and ADR-0013 already
treats gapless as verified on-device rather than by automated test. The
same verification discipline applies here.

### Domain/settings

Add a crossfade setting (on/off, duration) to playback preferences,
following the same `KeyValueStore` pattern navigation mode already uses.

### Interaction with quality/transcoding

Verify crossfade behaves correctly across a quality/transcoding boundary
(e.g. a transcoded track crossfading into a direct-play track), since
v0.1.1 may have introduced more than one stream-resolution path.

## Tests

- Automated tests for the crossfade setting's persistence and the engine
  seam's configuration surface, to the extent the engine allows without a
  real device.
- On-device verification for actual crossfade behavior and continued
  gapless behavior when crossfade is off, recorded the way the v0.1.0
  release checklist records device validation.

## Definition of Done

`v0.1.3` is complete when crossfade is configurable, gapless playback still
holds when crossfade is disabled, and both are verified on real Android and
iOS devices.

---

# v0.1.4 — Volume Normalization

## Goal

Add configurable loudness normalization (ReplayGain or an equivalent
loudness-based approach) so track-to-track volume is consistent.

## Why This Is a Separate Release

Same playback-engine area as crossfade; sequencing it immediately after
lets the two share device-verification passes.

## Required Work

### Data availability

Determine what loudness metadata Jellyfin actually exposes for the real
library (ReplayGain tags depend on the source files having been tagged).
This is a real open question — decide early whether to rely on
Jellyfin-provided metadata, compute it client-side, or defer normalization
for untagged tracks. Record the decision and its limitations in an ADR;
do not silently under-normalize without telling the user why.

### Engine integration

Apply gain via the playback engine consistent with the existing
engine-ignorant-of-domain-concepts design (`JustAudioPlaybackEngine` is
deliberately kept ignorant of queue/shuffle/repeat; normalization should
respect that boundary rather than leaking into the engine's queue
awareness).

### Settings

A normalization on/off setting is sufficient for this release; per-target-
loudness tuning is a reasonable stretch item, not a requirement.

## Tests

- Unit tests for gain calculation/lookup logic.
- On-device verification that perceived volume is materially more
  consistent across a representative set of tracks with mismatched source
  loudness.

## Definition of Done

`v0.1.4` is complete when normalization is configurable, uses a documented
and honest data source, and its behavior for tracks lacking loudness
metadata is defined rather than silently inconsistent.

---

# v0.1.5 — Lyrics

## Goal

Show lyrics for tracks that have them.

## Why This Is a Separate Release

ADR-0013 already scoped lyrics as best-effort rather than committed work.
The same applies here: attempt it once the higher-value, better-understood
releases above are done, and descope cleanly if the data isn't there.

## Required Work

### Data source

Confirm what lyrics data Jellyfin 10.11.6+ actually exposes (embedded
lyrics, a dedicated lyrics endpoint, or neither depending on library
tagging) and what the real library actually has. This determines whether
synced lyrics are realistic or only plain lyrics are.

### UI

A lyrics view reachable from Now Playing. Plain, non-synced lyrics are the
required baseline. Synced/scrolling lyrics are included only if the data
and engine timing make it straightforward — matching ADR-0013's original
language exactly.

### Missing lyrics

A track without lyrics must present a clear empty state, never an error
state — consistent with `PHILOSOPHY.md`'s "never leave the user guessing."

## Tests

- Widget tests for present/absent/loading lyrics states.
- If synced lyrics are attempted, a test proving line-highlighting tracks
  playback position correctly.

## Definition of Done

`v0.1.5` is complete when lyrics display for tracks that have them, absence
is a clear empty state rather than an error, and synced lyrics either work
correctly or are not shipped at all — no half-working timing.

---

## Explicitly Not Required in This Arc

Deferred further, consistent with `OUTLOOK.md` and `PHILOSOPHY.md`'s scope
discipline:

- full offline downloads (including offline playlist sync);
- movies;
- television;
- unified multi-server libraries;
- social sharing / shareable links;
- collaborative playlists;
- smart/dynamic playlists;
- recommendations, discovery, and recently-played/history surfaces (natural
  fit for a future Home-customization release, not this arc);
- modular/customizable Home;
- full theme system / theme editor;
- plugin framework;
- desktop clients;
- Android TV;
- comprehensive accessibility work;
- context-aware/global search evolution beyond what v0.1.0 already has;
- anything that would define `v1.0.0` readiness — that's a separate future
  decision, not scoped here.

These remain tracked in `OUTLOOK.md` as candidates for whatever comes after
`v0.1.5`.

---

## Open Questions to Resolve Before/During Implementation

These are genuinely undetermined and should be settled as each release
starts, not guessed at now:

1. Does the real library's format mix actually require transcoding, or
   does it direct-play cleanly on representative devices? This decides how
   much of v0.1.1 is a correctness fix versus a pure enhancement.
2. Are playlist edits applied directly against Jellyfin, or does Jellyfinity
   need local optimistic state with reconciliation?
3. What loudness metadata (if any) does the real library actually carry,
   and is client-side loudness analysis worth the engineering cost if it
   doesn't?
4. Does Jellyfin 10.11.6+ expose usable lyrics data for a meaningful share
   of the real library, and if so, is it synced or plain-text only?
5. What should `v1.0.0` actually require? Not needed to start v0.1.1, but
   worth deciding before this arc runs out, so v0.1.x work can be sequenced
   toward it rather than discovering the target late.

## Release Discipline

Unchanged from `ROADMAP.md`: focused branches, meaningful commits, PRs, CI
before merge, `CHANGELOG.md` updates, and semantic tagging apply to every
release in this document the same way they applied to every v0.0.x and
v0.1.0 release. Each of `v0.1.1`–`v0.1.5` gets its own branch (e.g.
`v0.1.1-streaming-quality`), its own PR, and its own tag — the same
discipline `v0.0.8` and `v0.0.9` already used.
