# Changelog

All notable changes to Jellyfinity are documented here.

## Unreleased — Windows support

- Extend album and artist artwork through their detail surfaces, add detail
  refresh actions, give artists the collection playback controls, remove
  desktop list refresh buttons, and use blurred artwork in the mini-player
  with a more transparent bottom navigation bar.

- Add a native `build_exe.bat` entry point for building and exporting the
  Windows desktop bundle from Command Prompt or PowerShell.

- Add `build_exe.sh` for labeled Windows executable exports with their complete
  runtime, plus optional clean, dependency refresh and build-mode selection.

- Remove duplicate album/artist app-bar titles and header backgrounds, keeping
  back navigation. Carry a heavily blurred current-song backdrop across the app,
  with translucent bottom navigation and a solid mini-player tint from artist
  artwork (falling back to the song cover). Artist and album detail pages always
  use their own blurred artwork, including behind the transparent back bar.

- Replace the default Windows executable icon with Jellyfinity artwork at
  seven icon sizes, using the transparent infinity mark without a colored
  background. Use a larger cover beside the player controls in wide
  windows, center Library/Favorites tabs, and color artist/album detail pages
  with heavily blurred artwork. Artist headers prefer Jellyfin Banner images
  and fall back to Backdrop artwork.

- Supply a bundled Windows audio decoder and system media controls, retaining
  the shared playback queue, streaming quality, normalization and two-deck
  crossfade. Android and iOS keep their native playback backends.
- Preserve track selection and position during Windows queue edits without
  relying on the adapter's incompatible incremental playlist indices. An edit
  may briefly rebuffer; ordinary playback uses playlist prefetch.
- Check free space on the downloads' Windows volume and recognize Windows
  disk-full errors. Retain existing secure storage, offline downloads, artwork
  caching, database and connectivity implementations.
- Make shelves draggable with a mouse, add desktop collection refresh buttons,
  Ctrl+F / Escape search shortcuts and Alt+Left navigation. Keep the full player
  and empty/error actions reachable in short windows.
- Add Windows regression/build CI, desktop behavior tests and a native smoke
  test covering local/HTTP audio, queue edits, seeking, crossfade, credentials
  and storage. Fix Windows test database cleanup and path comparison.
- Document setup, packaging and device acceptance in `docs/windows.md`, and
  the platform decisions in ADR-0029.

## v0.4.3 — Offline Favorites

The heart stays a reliable local promise when connectivity is
intermittent, instead of an attempt that could only fail.

### A favorite made offline is never lost or lied about (ADR-0033)

- **Favoriting or unfavoriting works while offline.** The change shows
  immediately — in Favorites, its Home strip, and on the item itself,
  including if the item is reopened later while still offline or after a
  restart — as a pending intent rather than a claim that the server has
  already heard about it.
- **It reaches the server as soon as it can.** Reconnecting, or signing
  back into a profile that has something pending, replays every
  outstanding change automatically. Toggling the same item several times
  offline coalesces into one eventual write — the latest tap always wins.
- **A change that still cannot reach the server stays visible and
  retryable.** The Favorites destination shows "N favorites waiting to
  sync" for as long as anything is pending, and tries again on the next
  reconnect rather than giving up silently.
- **Nothing crosses between profiles or servers.** A pending change is
  scoped to the profile that made it and replayed only while that profile
  is the one signed in.
- No user-visible change online: a favorite toggled with a live
  connection behaves exactly as before.

## v0.4.2 — Playlist mastery

Playlists stop being lists that still need Jellyfin Web for basic
curation. The two things standing in the way were both deferred on
purpose by earlier releases, and both are the same kind of problem: a
fact the server has that Jellyfinity's model was throwing away.

### Reorder, correctly (ADR-0032)

- **A playlist can be rearranged from inside Jellyfinity.** Drag a row by
  its grip — touch on Android, pointer on Windows — or use "Move up" /
  "Move down" in the row's menu, which is the same reorder without a
  drag and the path that works from a keyboard.
- **The read model carries true positions, which is why this is safe.**
  Jellyfin's move endpoint takes an absolute index into the playlist, and
  every entry counts — including the ones Jellyfinity cannot read. Rows
  now know where they sit, so a move is aimed at the row it displaces
  rather than at a position on screen. v0.1.2 left reorder out precisely
  because the difference was invisible and would have moved the wrong
  entry (ADR-0024); it is now complete.
- **A playlist is numbered the way its server numbers it.** A film or a
  deleted track sitting in a music playlist keeps its number, and the
  songs around it keep theirs, online and offline alike.
- **The same song listed twice is two rows**, and moving or removing one
  names that appearance — never "that song".
- **A move the server refuses puts the list back** and says what
  happened. A move it accepts is followed by a re-read, so the numbering
  comes from the playlist rather than from the drag.

### A playlist you can come back to

- **Listening history knows what a playlist is.** Playing a playlist is
  now one thing the listener did, not nine albums' worth — the queue
  carries what started it (the "queue origin" ADR-0026 deferred), so
  Home's "Recently played" shows playlists alongside albums and artists,
  and opens them.
- **A playlist offers to carry on the queue it started**, across a
  restart: "Continue 'Blue in Green'". It knows it is the same session
  because the queue says so, not because that song happens to appear in
  the list.
- No new table and no schema change: the origin rides the same key-value
  store the shuffled play order does.

### Honest offline

- **A saved playlist is numbered, playable, and visibly not
  editable.** No drag grips, no move or remove in the menu — editing
  reaches the server or fails (ADR-0024), and offering an action that
  cannot work is worse than not offering it.
- **The local copy keeps a window's order exactly as the server sent
  it.** Unreadable entries used to land at the end of the window they
  came from, which quietly renumbered every offline playlist containing
  one. This applies to every cached collection, not only playlists.

## v0.4.1 — Music listening perfection

An audit and hardening pass over everyday playback, adding no new place
to go. Everything below already existed; what changed is that these
things now agree with one another, and with what the listener was told.

### The queue tells the truth (ADR-0031)

- **The queue screen lists rows in the order they will actually play.**
  It listed the queue's own order, which under shuffle is not what comes
  next — the one question a queue screen exists to answer. Dragging a row
  moves it in play order; the entries list is reordered from nowhere else
  and, when it is, play order deliberately stays put.
- **A structural edit no longer reshuffles.** Adding, removing or
  reordering regenerated the entire shuffled order, so adding one track
  rearranged everything the listener had not heard yet, and "play next"
  landed the track wherever chance put it. Edits now amend the existing
  order, and the only thing that reshuffles is the shuffle button.
- **The queue says when nothing follows the last track**, instead of
  leaving a listener to find out when the music stops. Absent under
  repeat all, where something always follows.

### A restart is the same queue (schema v9)

- **The shuffled play order survives a restart.** It was never saved, so
  every launch generated a fresh random order: the up-next list a
  listener left was never the one they came back to. A saved order that
  no longer matches the saved rows is discarded rather than trusted.
- **Volume normalization works on a restored queue.** The loudness gain
  had no column, so normalization (v0.1.4) silently stopped applying to
  every queue that survived a restart — on every install, since v0.1.4.
- **A track that failed still says so, and why**, after a restart.

### Failures explain themselves and can be retried

- **A failed queue row shows the reason and "Tap to try again".** It
  greyed out with no explanation and no way to retry: "unavailable" is a
  state, not an explanation. A row stays tappable while online, because
  trying again is the action; offline with no local file is the one case
  where there is genuinely nothing to try, and it says that.
- **A failure gets one automatic re-resolve before the entry is called
  unavailable**, and the cached address is dropped first — which is what
  recovers a track whose download was deleted while it sat in the queue
  (it falls back to the stream), and a newly downloaded one (it stops
  streaming). This widens ADR-0015's retry, which applied only to a
  transcoded stream; the original-quality pin is unchanged.
- **A queue that has recovered stops claiming it is broken.** The failure
  mark, the explanation, the one-off notice and the run-of-failures count
  are all cleared the moment the engine reports it is playing. The count
  previously survived any manual recovery and kept counting towards the
  give-up cap.

### Every playback entry point means the same thing

- **Album, artist, playlist and Favorites headers gain "Play next"**,
  queueing the whole collection in its own order directly after the
  current track. Play, Shuffle and Add to queue were already there; this
  was the one action a collection could not do that a track row could.
- **Shuffling a collection no longer disturbs the queue it replaces.**
  Turning shuffle on was a queue edit, so it reshuffled, re-saved and
  re-loaded the outgoing queue half a frame before discarding it.

### Features say when they cannot apply

- Now Playing states, in place and only when it holds, that a downloaded
  file is played as the file it is so the streaming-quality setting does
  not apply; that normalization is on but the server has no loudness data
  for this track; and that crossfade is paused because repeat-one leaves
  no next track to fade into. A feature that quietly does nothing reads
  as a feature that does not work.

### Jellyfin hears about playback

- **A manually started track opens a play session.** Sessions were
  reported only from an engine-driven track change, which every
  `playNow`, every skip and every tap on a queue row bypassed — so the
  server saw nothing for a track the listener chose by hand.
- **Position is reported while a track plays**, on the same five-second
  tick that already saved it locally. Pausing reports the session as
  paused rather than ending it; emptying the queue closes it.

### Platform

- Queue reordering is covered by a pointer drag for Windows alongside the
  existing touch handle, and no interaction added here is exclusive to
  either platform. Background and media-session behavior is unchanged.

## v0.3.6 — Offline music completion, finished

The offline **feature** deliverables `Roadmap to v0.3.md`'s v0.3.0
listed and left outstanding — v0.3.0 shipped only its hardening half.
With these, offline is the "trust it for travel" experience the roadmap
asked for.

### Offline music completion (ADR-0030)

- **Every music surface now shows download and offline state.** Now
  Playing gains the same one-tap "keep this on my device" control every
  track row has. Inline search results gain a download button (the full
  search page already had one). The queue and the mini-player show a
  "downloaded" mark, and — offline, with no downloaded copy — a track
  reads **"Not available offline"** and is dimmed rather than silently
  un-playable.
- **"Only on this device"** now appears on a downloaded track the server
  has since dropped (`MediaAvailability.localOnly`). v0.2.3 tracked that
  state; nothing drew it until now.
- **Batch actions on the Downloads screen.** An app-bar menu with
  **"Retry failed downloads"** (one tap to recover every part-finished
  collection after a spell offline) and **"Remove all downloads"** —
  behind a confirmation that names the songs and bytes freed and repeats
  that nothing changes on your server.
- **Removing a saved profile or server now reclaims its downloads.**
  Its records are forgotten and its files deleted — except a file a
  second profile on the same server still keeps, which stays. Before
  this, a removed identity left downloaded audio on disk that nothing
  could ever play or clean up.
- No schema change: the download tables already carried the columns the
  new purge queries read.

## v0.3.5 — Related artists and albums

Finishing an album, or landing on an artist, now offers somewhere
obvious to go next — drawn entirely from your own server.

### Related artists and albums (ADR-0029)

- **A "Related artists" strip under an artist's discography** and a
  **"Similar albums" strip under an album's track list**, from Jellyfin's
  own similarity endpoint (`/Items/{id}/Similar`). No external
  recommendation service, no tracking backend — the suggestions never
  leave your library.
- **Absent, never broken.** A server with nothing to suggest, one that
  predates the endpoint, or one that cannot be reached simply shows no
  strip — no spinner, no error row. Coming back online fills a strip that
  was empty offline.
- **Live only.** Nothing is cached and there is no schema change: the
  strips are a bonus over the detail page, which already renders and owns
  its own offline state.
- No Home section: Home already opens on four strong sections, and a
  "more like this" strip would need the app to *guess* which artist or
  album to seed it with — the kind of guessing the project's philosophy
  rules out. The album page is where "somewhere to go next" belongs.
- Genre and decade entry points (a stretch goal) are not included — they
  are a browsing surface of their own, not a section.

## v0.3.4 — Favorites as a place

The star gets a destination. A track, album or artist could be favorited
from three screens and then never found again; now Favorites is a place
you can open, on Home and in the bottom navigation.

### Favorites as a place (ADR-0028)

- **A Favorites section in the bottom navigation**, between Home and
  Library, with a heart icon. Scoped by the same media-type pill as
  Library — Music today — with Artists, Albums and Songs tabs. Each tab
  is an ordinary paged list; the **Songs tab plays straight through**,
  with Play and Shuffle, like a playlist.
- **A Favorites strip on Home**, following the section pattern
  "Recently played" and "Recently added" established (ADR-0026): favorite
  albums and artists, its header opening the full destination, absent
  when there is nothing starred, and independent — a failure there leaves
  the rest of Home standing.
- **`IsFavorite` on the shared query surface.** `queryItems` gained a
  `favoritesOnly` flag that defaults off, so the library, discography,
  album-tracks, playlist, search and "recently added" reads are all
  unchanged and only the three favorites reads opt in.
- **Favorites are honest offline.** The migration ADR-0019 deliberately
  deferred is now taken on: schema **v8** adds an account-scoped
  `cached_favorites` table, so a cold offline open shows the last known
  favorites marked as a saved copy rather than an empty list. A favorite
  removed on another client disappears on the next sync; a star tapped
  online shows offline straight away. A profile whose favorites were
  never read online is told to reconnect, not shown "you have none".
  Under the downloads-only scope, the Home strip narrows to favorites
  with something on the device.
- Toggling a favorite anywhere in the app refreshes the destination and
  the Home strip — no stale list after starring something.
- The detail-page heart on a cached/offline copy stays hidden, as
  ADR-0019 left it; reconciling it offline is a later step.

## v0.3.3 — Recently added

Home gains a third section: the albums the server has just gained,
newest first, so music added to the server last night is on Home this
morning.

### Recently added (ADR-0027)

- **One extra library query.** The newest albums by the date the server
  acquired them (`DateCreated`, descending). No new content type, no new
  playback capability — the same section shape "Continue listening" and
  "Recently played" already use (ADR-0026).
- **Descending sort on the shared query surface.** `queryItems` only ever
  sorted ascending; it now takes a `descending` flag that defaults to
  ascending, so the library, discography, album-tracks, playlist and
  search queries are all unchanged and only "Recently added" opts in.
- **Cached like every other browse read.** A served answer is saved; an
  unreachable server is answered from the saved copy, marked as such. A
  cold offline open still shows the last known "recently added" rather
  than an error.
- **Honest offline.** "Recently added" is a *server* fact. With the
  full-library scope offline, the saved list shows under a
  "Saved list — reconnect to see new music" line so it never implies a
  freshness check the app could not make; with the "downloads only"
  scope, the section is dropped entirely, the same way an unplayable
  "recently played" row is (ADR-0026).
- **Albums only.** Artists are deferred: Jellyfin's `DateCreated` on an
  artist does not track when their music actually landed, and merging two
  date-sorted lists is more than a section should carry.
- A bounded top-20 window that reports itself complete, so the saved copy
  replaces cleanly on a refresh instead of stranding rows past a list
  that shrank. No schema change.

## v0.3.2 — Continue listening and recently played

Home stops being a placeholder. It now opens on what the user was doing —
what is waiting to be resumed, and what they have played lately — with the
server up or down.

### Home sections (ADR-0026)

- **Continue listening.** The playback queue is already restored, paused,
  at launch (v0.0.9). Home surfaces it: the track, how far in, and one tap
  to carry on. Nothing to resume — no queue, or already playing — and the
  section is absent, not an empty box.
- **Recently played.** The albums, artists and single tracks this profile
  actually returned to, newest first, from v0.3.1's listening history
  (ADR-0025). An album or artist opens its page; a single plays again
  (there is no track screen to open).
- **Each section stands on its own.** They share no state, so one that
  fails shows its own compact retry and leaves the rest of Home usable —
  the rule `MusicSearchCubit` already follows for search categories. A
  failed *refresh* that still has rows keeps showing them.
- **Honest offline.** With the full-library scope, a row whose audio is
  not on the device is shown dimmed and labelled rather than hidden. With
  the "downloads only" scope (ADR-0023), it is left out entirely, and
  Continue listening is absent when the queued track is not downloaded —
  no resume button that reaches only silence.
- The strip refreshes itself when a track starts playing, so it is
  current by the time the user comes back to the Home tab.
- Home's "Browse music" button now appears only when there is nothing to
  resume or replay; otherwise the Library is its bottom-navigation tab.
- `PlaybackCubit` gains `resume()`. No new domain contract, no schema
  change.
- **Not** in this version: attributing plays to the playlist they came
  from (needs a queue origin, which ADR-0025 and ADR-0026 both defer), and
  a reorderable Home (`OUTLOOK.md` §9).

## v0.3.1 — Listening history

The first step of the Home arc: Jellyfinity now durably records what the
signed-in profile listened to, online and off, so later versions can show
it. Nothing displays it yet.

### Listening history (ADR-0025)

- **Recorded locally, not read from the server.** Jellyfin keeps a
  last-played date and play count, but reading a "recently played" list
  out of it is a query against the whole library on the app's busiest
  screen, and it cannot be read or written offline at all. History is a
  small local table written by the player.
- **A play is recorded once it genuinely happened** — 20 seconds of
  playback, or half of a track whose length is known, or the track
  finishing on its own. A song skipped after two seconds is not
  listening. The rule composes with crossfade (ADR-0016), which ends a
  track early by design, without a special case.
- **Repetition collapses.** History keeps one entry per *context* — an
  album, an artist, or a single track played on its own — so an album
  played straight through is one thing the user did, not twelve, and
  returning to it a week later moves that one entry back to the top.
- **Bounded.** At most 100 context entries per profile; the
  oldest-played is evicted when a new one would exceed that. A year of
  listening does not make the list longer, only more churned.
- **Per-profile, like downloads (ADR-0023).** Every row is scoped to the
  signed-in profile; one profile's listening never appears under
  another's, and signing out reads empty rather than exposing it.
- **Offline is not a special case.** Recording is a purely local write,
  so a downloaded album played on a plane is recorded exactly like a
  streamed one.
- The playback queue snapshot (`QueueEntry` / `queue_entries`) gained the
  album id and artist ids it was missing, so a queued track — and a
  history entry derived from one — can open its album or artist, not just
  print the name. Schema v7; a pre-v7 queue row keeps its data with those
  ids null.
- Playlists are not yet a history context: the queue does not record what
  a track was played *from*. That arrives with v0.3.2's "Continue
  listening".

## v0.3.0 — Offline music hardening and playlist curation

Bug fixes, lifecycle hardening and release hygiene on top of v0.2.3, plus
the playlist curation v0.1.2 specified and never finished. This is **not**
the whole of `Roadmap to v0.3.md`'s v0.3.0 scope — the offline feature
deliverables it lists are still outstanding, and are named at the end of
this entry.

### Playlist curation (ADR-0024)

Until now a playlist could be browsed, played and downloaded, but every
act of making one happened on the Jellyfin web UI — the Add-to-playlist
sheet's own empty state said so. `PlaylistRepository` had exactly one
write, `addTracks`, added in v0.1.6 with a comment noting the rest was
still v0.1.2's unfinished work.

- Create a playlist, from a "New playlist" row at the top of the
  Library's Playlists tab or from the Add-to-playlist sheet. Creating
  from the sheet resolves it the same way picking an existing playlist
  does, so the tracks land in the new playlist without the caller knowing
  it was new.
- Rename and delete a playlist, from a new overflow on its detail page.
  Deleting asks first and says the songs stay in the library, then leaves
  the page — a screen for a playlist that no longer exists is the one
  state it cannot render honestly.
- Remove a song from a playlist, from that row's existing overflow menu.
- Removal is keyed on Jellyfin's `PlaylistItemId` rather than on track
  ids, because a playlist can list the same song more than once and each
  appearance is its own row. That handle reaches the UI as
  `PlaylistTrack`, a subtype of `Track` rather than a nullable field on
  it. A row read from the offline cache or a download snapshot is a plain
  `Track` and carries no entry id, so "is this a `PlaylistTrack`" is also
  the honest answer to "can this row be edited right now".
- Every editing affordance is hidden when Jellyfinity is offline rather
  than offered and doomed. Playlist writes reach the server or fail;
  nothing is applied optimistically, for the reasons ADR-0024 records.
- **Reorder is deliberately not included.** Jellyfin's move endpoint
  takes an absolute index into the playlist, and the page model splits
  unmappable entries out of the ordered list, so the only index the UI
  can compute is wrong on any playlist holding something that is not a
  readable song. A drag that lands the song in the right place most of
  the time and the wrong place the rest, silently, is worse than not
  offering it; doing it properly needs a read model that exposes true
  positions. v0.1.2 stays open in `ROADMAP.md` because of it.
- Made the download engine's abort test deterministic. It waited a fixed
  20 ms for the first chunk to reach the disk, which the suite outran
  once it grew past 750 tests; it now waits on the engine's own byte
  count. A wall-clock race does not belong in a suite that gates CI.

### Offline hardening

- **A retried download no longer splices two encodings together.** A
  partial file was keyed by track alone, with no record of the address its
  bytes came from. Pausing or failing a download at one download quality
  and retrying it at another appended the tail of the new encoding to the
  head of the old one, and the result completed, reported itself
  downloaded, and played as noise. `DownloadStorage` now records the
  source beside the partial and discards a partial fetched under a
  different one; a re-issued session token is explicitly *not* a different
  source, so an ordinary re-sign-in still resumes rather than starting
  over. A partial left by an older install carries no marker and is
  discarded once, costing one track a fresh start.
- **A connection returning mid-check no longer strands the download
  queue.** The worker's Wi-Fi-only gate and the connectivity listener both
  read the network and then wrote, unserialized. On a rapid transition the
  listener's release could land first and the worker's stale hold on top
  of it, leaving every request parked on "waiting for Wi-Fi" with good
  Wi-Fi and nothing left to wake it. Both now go through one lock and one
  answer per pass.
- **Now Playing no longer claims a transcode for a downloaded track.** The
  quality badge read the *streaming* preference, which
  `LocalFirstAudioSourceResolver` deliberately ignores when it plays a
  local file — so a downloaded lossless track announced itself as "AAC ·
  256 kbps" because of a preference that never touched it. The badge now
  answers to the download-quality preference when the track is on the
  device.
- The Downloads screen's Collections list keeps a stable order. It was
  built by walking maps whose iteration order shifts as records change
  state, so it reshuffled itself while a download ran; it is now grouped
  by kind and sorted by name, like the two sections either side of it.
- `DownloadsCubit` no longer accumulates abandoned-download ids for the
  life of the process. Only the transfer actually in flight is marked, and
  the mark is cleared however that transfer ends.
- Removed the `markUnavailable` flag from `ArtistRow`, `AlbumRow`,
  `TrackRow` and `PlaylistRow`. It was documented, threaded through, and
  set at every call site, but the shared row had been changed to a
  hardcoded "never dim" and ignored it entirely. `AlbumTile`, which does
  honour the flag, keeps it; `TrackRow.playable` remains the live
  mechanism for a row that genuinely cannot be tapped. No rendering
  changes.
- Added a CI workflow (format, analyze, test), which `CONTEXT.md` has
  required since v0.0.1 and which the repository did not have. Making the
  formatting gate pass reformatted 21 files that were already unformatted
  on `main`; those changes are whitespace only.
- Corrected `pubspec.yaml`'s version, left at the `flutter create` default
  of `1.0.0` through every release so far. `1.0.0` is reserved for the
  first public release.
- Gave this changelog per-version sections. Everything up to v0.1.0 was
  recorded without headings and is kept as one section rather than split
  on guesswork.

Still outstanding from v0.3.0's offline specification, all of it new
behaviour rather than repair: the entry-point audit (Now Playing, the queue and the
mini-player carry no download or offline state, and inline search has no
download action); batch retry and batch removal on the Downloads screen;
rendering `MediaAvailability.localOnly` as "Only on this device", which
v0.2.3 promised and no widget yet does; and reclaiming downloaded files
when an account or server is removed, which today leaves them on disk and
unreachable. **All four shipped in v0.3.6 (ADR-0030); v0.3.0's offline
specification is now complete.** Device validation across the whole
offline story remains part of a later release's hardening pass.

## v0.0.1 – v0.1.0 — Proof of concept

Recorded without per-version headings at the time. `ROADMAP.md` and
`Proof Of Concept Roadmap.md` carry the version-by-version scope; the
entries below are in the order the work landed.

- Initialized the Flutter Android and iOS application.
- Added the reproducible development container.
- Added Windows-hosted Android emulator support through ADB.
- Added the initial Jellyfinity development shell.
- Added the application architecture core: feature-first Clean
  Architecture direction (ADR-0001), `flutter_bloc` state management
  (ADR-0002), `get_it`/`injectable` dependency composition (ADR-0003), a
  shared `Result`/`Failure`/`Partial` model (ADR-0004), and privacy-safe
  logging/configuration conventions (ADR-0005), each with focused tests.
- Added navigation with `go_router` (ADR-0006): a composition-root
  `AppRouter`, an auth gate driven by a stubbed `SessionCubit`
  (`unauthenticated` → welcome, `authenticated` → shell), a
  `StatefulShellRoute` app shell (Home section only for now), and a
  not-found route.
- Added the `lib/design/` design system (ADR-0007): semantic tokens for
  colour, spacing, radii, typography, elevation, and motion, delivered as
  a `ThemeExtension` and read through `context.tokens`; dark-first light
  and dark themes; and shared UX primitives — `AppScaffold`, shimmering
  `AppSkeleton`/`AppSkeletonList`, `EmptyStateView`, `ErrorStateView`
  (with failure-aware retry), `UnavailableContent`, and `AppButton`.
- Replaced the placeholder development shell with the real welcome and
  Home screens built on the design system.
- Added the Jellyfin transport layer (ADR-0008) under
  `lib/infrastructure/jellyfin/`: a `dio`-based `JellyfinHttpClient` whose
  request surface returns `Result` and never leaks a `DioException`;
  centralized `JellyfinClientIdentity` building the Jellyfin
  `Authorization` header, with an `AuthTokenProvider` seam for v0.0.5;
  `dio` interceptors for the identity/auth header, debug request
  correlation, and bounded GET-only retry; `JellyfinServerUrl`
  normalization; `ServerVersion` plus a one-line `MinimumServerVersionPolicy`
  (floor: Jellyfin 10.11.6); a `json_serializable` `PublicSystemInfoDto`;
  `TransportErrorMapper` normalizing transport failures to the ADR-0004
  model; and `JellyfinServerProbe.validate()` to check a server is
  reachable, really Jellyfin, and supported.
- Added `UnauthorizedFailure` and `UnsupportedServerFailure` to the core
  `Failure` hierarchy (note added to ADR-0004).
- Added `dio`, `json_annotation`, and `json_serializable` (dev)
  dependencies.
- Added authentication, servers, and sessions (ADR-0009). `lib/domain/`
  gains its first content — the session concepts kept distinct
  (`JellyfinServer`, `JellyfinAccount`, `AuthSession`) and their
  contracts (`ServerRegistry`, `AccountStore`, `CredentialStore`,
  `JellyfinAuthenticator`). A real user journey now works end to end:
  enter a server address → validate it → sign in with a Jellyfin
  username/password (`AuthenticateByName`) → the session is restored on
  the next launch (no network call, so a currently-offline server does
  not block startup) → switch profile, sign out, or remove a saved
  profile/server from the new Accounts screen. Polished connecting and
  error states throughout; no raw exception text in the UI.
- Access tokens are stored in platform secure storage
  (`flutter_secure_storage`: iOS Keychain, Android Keystore-backed
  `EncryptedSharedPreferences`). The non-secret saved-servers/profiles
  registry uses a small JSON-file store behind the domain contracts as
  an explicit interim until the v0.0.6 database.
- `SessionAuthTokenProvider` replaces `NoAuthTokenProvider` as the
  transport layer's token source; `JellyfinHttpClient` gained a
  `postJson` surface.
- The router's onboarding flow (`/connect`, `/connect/sign-in`) and the
  `/accounts` screen; the welcome screen now starts the connect flow
  instead of a development shortcut.
- Added `flutter_secure_storage`, `path_provider`, and `uuid`
  dependencies.
- Added the local-data foundation (ADR-0010): a SQLite database via
  `drift` under `lib/infrastructure/persistence/database/`, with a
  forward-only migration policy (`schemaVersion` 1, committed schema
  snapshot in `drift_schemas/`, `PRAGMA foreign_keys` on). Schema v1:
  `saved_servers`, `saved_accounts`, and a typed `key_value_entries`.
- Replaced v0.0.5's interim JSON store: `DriftServerRegistry` and
  `DriftAccountStore` now back the unchanged `ServerRegistry` /
  `AccountStore` contracts, and a one-time `LegacyJsonImporter` moves any
  existing `servers.json` / `accounts.json` into the database at startup
  (renaming the files to `*.migrated`). `JsonStore`, `FileJsonStore`,
  `FileServerRegistry`, `FileAccountStore` and `PersistenceModule` are
  removed.
- The device id Jellyfinity reports to a server is now generated once and
  persisted (`DeviceIdentityStore`), closing the deferral in ADR-0008 and
  ADR-0009 — a server sees one stable device instead of one per launch.
- Added a typed `KeyValueStore` for small non-sensitive state (preferences,
  the device id, the active-account pointer). Secrets stay in secure
  storage.
- Documented cache semantics and the local/remote repository-source
  convention in ADR-0010; the artwork disk cache is specified but its
  implementation waits for v0.0.8, when artwork is first rendered.
- Added a representative-scale database test (`@Tags(['scale'])`): 130k
  rows, batched insert, indexed lookup, offset pagination.
- Added `drift` and `drift_flutter` dependencies (`drift_dev` for
  codegen); `drift` / `drift_dev` pinned to 2.34.0.
- Added Jellyfinity's media vocabulary (ADR-0011) in
  `lib/domain/media/`: `Artist`, `Album`, `Track`, `Playlist`, `Movie`,
  `Series`, `Season` and `Episode` over a shared `MediaItem`, plus
  `MediaImage`, `MediaAvailability`, `PlaybackProgress`, `ArtistRef` and
  the `Page`/`PageRequest` pair every collection is read through. Media
  is identified by `MediaId` — Jellyfinity's local server id together
  with the Jellyfin item id — so no bare, server-specific id is ever
  passed around.
- Added narrow media repository contracts —
  `MusicLibraryRepository`, `PlaylistRepository`,
  `MediaMetadataRepository`, `PlaybackProgressRepository` and
  `ArtworkResolver` — with Jellyfin-backed implementations under
  `lib/infrastructure/jellyfin/media/`. Every read is a windowed,
  server-sorted query; nothing offers "give me everything", and nothing
  filters a library in Dart.
- Added `BaseItemDto` and `BaseItemMapper`: one polymorphic DTO matching
  Jellyfin's item response, and the codebase's only translator from it
  to domain entities. It maps ticks to `Duration`, `UserData` to
  playback progress, and image tags to artwork (a song points at its
  album's cover, an episode at its show's poster, so an image is cached
  once rather than once per row). An item of the wrong type, or without
  an id or a name, becomes an `unavailable` entry on its page instead of
  a dropped row or a failed screen.
- Added `JellyfinMediaApi`: the single place that knows Jellyfin's query
  vocabulary, owner of the session-scoped HTTP client (rebuilt when the
  active profile moves to another server), and the guard that refuses to
  ask one server for another server's item.
- Added the `JellyfinSessionContext` seam (implemented by
  `SessionJellyfinContext` over `AuthSessionManager`), so the media
  layer can read the active server and user without infrastructure
  depending on the composition root — the same arrangement as
  `AuthTokenProvider`.
- Artwork resolves to a sized URL rather than being fetched; the bounded
  artwork cache lands in v0.0.8, behind the same contract.
- `JellyfinHttpClient` gained `send()` for endpoints whose answer is
  their status code — marking an item played or unplayed.
- Renamed every single-class file to `PascalCase` matching its class
  (e.g. `media_id.dart` → `MediaId.dart`); files with no class or more
  than one, and every `_test.dart` file, keep
  `lower_case_with_underscores`. Convention recorded in
  `CONTRIBUTING.md`; `flutter_lints`' `file_names` rule is disabled for
  it in `analysis_options.yaml`.
- Fixed the Android release build having no network access: the
  `INTERNET` permission, which Flutter only writes into the debug and
  profile manifests, is now declared in the main manifest. A release APK
  could not reach any server; a debug build on the same URL could.
- Added an Android network security config that permits cleartext
  traffic, so a release build can connect to the plain `http://` LAN
  servers the connect screen already accepts. HTTPS is still preferred
  wherever the server offers it.
- Added audio playback (ADR-0013): `just_audio` for decode/gapless
  playback, `audio_service` for background execution and lock-screen/
  notification media controls. `JustAudioPlaybackEngine` is both the
  `PlaybackEngine` implementation and the `audio_service` handler
  itself, kept deliberately ignorant of queues, shuffle or repeat so a
  future engine (e.g. `media_kit`) is a one-class swap.
- Added Jellyfinity's own playback queue in `lib/domain/playback/`:
  `PlaybackQueue`/`QueueEntry` (pure, engine-free shuffle/repeat/reorder
  logic), the `PlaybackEngine` contract, `AudioSourceResolver`
  (mirrors `ArtworkResolver`, resolves a track's authenticated stream
  URL), and `QueueRepository`. Persisted in schema **v3**'s
  `QueueEntries` table — a self-contained denormalized snapshot per
  entry, since a queued track is not guaranteed to have gone through
  the v0.0.8 cache.
- `JellyfinAudioSourceResolver` builds the direct-play stream address
  (`static=true`, no transcoding); the session token travels as an
  `api_key` query parameter, since a stream URL is fetched by the
  native platform player directly rather than through
  `JellyfinHttpClient`'s interceptors.
- `PlaybackProgressRepository` gained `reportStart`/`reportProgress`/
  `reportStop` over Jellyfin's `/Sessions/Playing` endpoints, closing
  the seam its own v0.0.7 doc comment left open — Jellyfin's resume
  position and played state now agree with what Jellyfinity actually
  played.
- Added `PlaybackCubit` (`lib/app/playback/`), the same architectural
  slot as `SessionCubit`/`AuthSessionManager`: the only thing that
  talks to both the queue and the engine, resolving sources, computing
  play order (including shuffled), persisting the queue, and marking a
  failed track unavailable in place and moving on rather than clearing
  the queue.
- Added the mini-player (in the shell, above the bottom nav, shown only
  with a non-empty queue), the full Now Playing screen (artwork, seek,
  transport, shuffle/repeat), and the queue screen
  (`ReorderableListView`, remove, jump to any entry). Both Now
  Playing and the queue are root routes so they cover the bottom nav
  from any tab.
- Every track tap across the music screens — album/playlist detail, the
  Songs tab, and search — previously dead per ADR-0012 ("no player
  until v0.0.9"), now starts playback with whatever list was already
  loaded as the queue. Album/playlist headers gained a Play button;
  `TrackRow` gained an optional overflow menu for Play Next and Add to
  Queue.
- Android: `MainActivity` now extends `AudioServiceActivity`; the
  manifest gained the foreground-service permissions and the service/
  media-button-receiver entries `audio_service` needs. iOS: `Info.plist`
  gained `UIBackgroundModes = [audio]`. Gapless playback and background/
  lock-screen behavior are verified on-device rather than by an
  automated test — nothing in this stack runs outside a real device.
- Added swappable navigation modes (ADR-0014): a persistent header
  (search field always visible, never a subscreen; a row of media-type
  "pills" beneath it) versus a unified mode with no pill row, chosen in
  a new Settings screen and persisted via `KeyValueStore`. Only Music is
  a real pill today — no fake placeholders for the unimplemented Movies/
  TV/Audiobooks/Ebooks types, and no "Combine" UI, since there is
  nothing to combine yet.
- Added the app sidebar (`AppSidebar`, a standard `Drawer` on `AppShell`
  — default edge-swipe plus a menu button, no custom gesture code):
  Accounts (the existing screen, unchanged) and the new Settings screen.
- Search moved inline: `MusicSearchPage` (a pushed page) is retired in
  favor of `InlineMusicSearch`, swapped in for the header in place so
  the bottom nav and mini-player stay visible underneath it. Reuses
  `MusicSearchCubit` and the categorized-results widgets unchanged.
- The Music tab is renamed Library, scoped to whichever media-type pill
  is active (today, always Music); every `/music` route and name is
  renamed to `/library` to match (`MusicPage.dart` → `LibraryPage.dart`).
- `test/support/pump_app.dart` now sets a realistic phone viewport
  (390×844) for every full-app test — the default 800×600 test surface
  left too little room once the persistent header, mini-player and
  bottom nav were all present, which could silently mis-hit-test a tap
  on content lower in the screen.
- Replaced the placeholder Flutter launcher icon with the real
  Jellyfinity app icon. Android ships density-specific legacy and round
  bitmaps plus an adaptive icon (navy `#000080` background, monochrome
  foreground) for API 26+, and the manifest now declares a `roundIcon`
  and the display label `Jellyfinity`. iOS gets the full `AppIcon`
  asset catalogue, with every image flattened to opaque RGB so the
  1024px marketing icon carries no alpha channel. The web `manifest.json`
  and `index.html` lose their "A new Flutter project" boilerplate.

## v0.1.1 — Streaming quality and transcoding

- Added streaming quality and transcoding (ADR-0015, v0.1.1):
  `StreamQuality` grows from direct-play-only to Lossless plus three AAC
  transcoded tiers (320/192/128 kbps), selectable from a new "Streaming
  quality" section in Settings and persisted like navigation mode. A
  transcode failure on the currently playing track retries once at the
  original file before being marked unavailable, rather than treating a
  transient failure as permanent. Now Playing shows the source file's own
  format/bitrate and, when a transcode is likely, what it is being
  transcoded to.

## v0.1.3 — Crossfade

- Added crossfade (ADR-0016, v0.1.3), configurable from a new Crossfade
  section in Settings: a switch plus a 1-12 second length slider,
  persisted like the other preferences. `just_audio` has no crossfade of
  its own and one native player cannot overlap two items of its own
  playlist, so `JustAudioPlaybackEngine` now runs **two decks** — both
  holding the whole source list, one active at a time — and equal-power
  ramps between them, cueing the incoming source to position zero so the
  overlap behaves the same for a transcoded stream as for a direct-play
  file. With crossfade off it is one deck on the unchanged single-player
  path, so gapless playback is preserved by construction. Repeat-one
  suppresses crossfade, since a queue repeating one track never reaches
  the next source the engine would otherwise fade into.

## v0.1.4 — Volume normalization

- Added volume normalization (ADR-0017, v0.1.4), configurable from a new
  Volume normalization switch in Settings. Reads Jellyfin's own
  `NormalizationGain` — server-side loudness analysis when available,
  else an embedded ReplayGain tag — already sent on every track
  response, so no extra request or minimum-version bump was needed.
  `JustAudioPlaybackEngine` folds the gain-adjusted volume into every
  place it already sets `AudioPlayer.volume`: steady state, every
  natural gapless transition, and both ends of the crossfade ramp, so
  the two features share one volume seam instead of fighting over two.
  Gain is only ever applied as attenuation, never a boost, to avoid
  clipping a track with no limiter downstream; a track with no reported
  gain plays unchanged rather than being guessed at.

## v0.1.5 — Lyrics

- Added lyrics (ADR-0018, v0.1.5), reached from a new lyrics button in Now
  Playing's app bar. Jellyfin's `/Audio/{itemId}/Lyrics` endpoint answers
  with a line list that carries per-line timing only when the source
  lyrics file has it, so Jellyfinity decides plain vs. synchronized per
  track rather than as a single app-wide choice: synchronized scrolling
  and highlighting only when every line is timed and the timestamps never
  run backwards, plain lyrics otherwise. A 404 (no lyrics file, or the
  track itself is gone) is treated as the empty state the roadmap asks
  for, not an error; the Lyrics view otherwise shows a loading skeleton or
  a retryable failure like every other on-demand detail screen.

## v0.1.6 — Interface refresh

- Added an interface refresh (ADR-0019, v0.1.6) across Settings, Home,
  Artist, Album, Now Playing, Queue, and Playlist:
  - Settings' streaming-quality picker is a dropdown, with the selected
    tier's description shown beneath it, instead of one radio row per tier.
  - Home's search field is a fully rounded pill; the media-type pills are
    smaller.
  - The Artist page shows the artist's backdrop image and overview above
    its discography, alongside its album/song counts and total playtime
    (`ArtistStats`, computed live), plus a favorite toggle.
  - The Album page replaces its single Play button with a centered Play, a
    Shuffle button, and an overflow menu (Add to playlist, Add to queue)
    that act on the whole album; its artist credit is now a link; it gets
    a favorite toggle. The Playlist page gets the identical treatment.
    Add to playlist uses a new minimal `PlaylistRepository.addTracks`
    write seam — the rest of v0.1.2's playlist-curation writes (create,
    rename, delete, reorder, remove) remain unimplemented.
  - Now Playing's artist and album lines are links (resolved on demand,
    same as ADR-0015's track-source lookup); its background is a heavily
    blurred, scaled copy of the current artwork; the source-format line is
    now a stacked container/bitrate label with a Lossless-or-transcode
    badge; its app bar gains the same track overflow menu (Play Next / Add
    to Queue) library rows already have, and a favorite toggle. Opening an
    artist/album link closes the player first — a `go_router` limitation
    pushing a shell-nested route directly from Now Playing's root route,
    documented in ADR-0019.
  - The Queue's clear action is a plain "X" with a confirmation prompt
    instead of one-tap clearing; it shows the queue's remaining runtime at
    the top; each row gets a drag handle so reordering starts there
    instead of anywhere on the row.
  - Favorite state and the artist stats are read live from the server only
    — never added to the offline cache — and hide themselves on a cached/
    offline screen rather than showing a stale or guessed answer; showing
    who created a playlist was investigated and dropped, since neither
    Jellyfin's item response nor its dedicated Playlists endpoint exposes
    an owner.
- Follow-up fixes to the v0.1.6 interface refresh, from a first testing pass:
  - Home's media-type pills size their label and selected checkmark from
    content rather than a fixed pixel height, so neither gets clipped.
  - The streaming-quality dropdown shows a rough data-usage-per-hour
    estimate for each tier alongside its name.
  - The Album and Now Playing pages: clickable artist/album names drop
    their underline (the accent color already reads as a link); the
    track title, artist, and album text are larger; Now Playing's heart
    moves next to the title and its Lyrics/Queue actions fold into the
    overflow menu, leaving one icon in the app bar; the Album page's
    heart moves down next to Shuffle/Play/overflow instead of the app
    bar, with Play staying centered; Now Playing's background blur is
    stronger.
  - Fixed a bug where toggling shuffle (or any other queue edit) could
    make the currently playing track briefly jump to full volume before
    settling back — `JustAudioPlaybackEngine` was re-levelling volume off
    of `just_audio`'s transient, mid-reorder index reports, which could
    momentarily disagree with the not-yet-updated source list.
  - Fixed crossfade producing an audible stutter instead of a fade: when
    preparing the standby deck's network stream took longer than the
    outgoing source had left to play, the outgoing deck had already
    gaplessly advanced on its own, and starting the overlap anyway played
    the same source twice at once (ADR-0016). The preload lead is also
    widened from 5 s to 10 s so this is hit less often.

## v0.2.0 — Downloaded tracks and albums

- Added downloaded tracks and albums (ADR-0020, v0.2.0), the first
  release in the offline-music arc:
  - New `lib/domain/downloads/` vocabulary: `TrackDownload` (a
    denormalized snapshot, the download counterpart to `QueueEntry`),
    `DownloadOwner`/`DownloadOwnerKind` (why a file is kept — a set,
    since the same track can be wanted on its own and via its album),
    `DownloadState`/`DownloadFailureReason`, `DownloadCatalog` (what a
    collection's downloads add up to, with failures named rather than
    averaged away), and the `DownloadStore`/`DownloadEngine` seams.
  - Schema v4 adds `track_downloads` and `download_owners` — ordered,
    migratable, additive per ADR-0010's policy.
  - `HttpDownloadEngine`: a foreground `dio`-based engine with HTTP
    Range resume, cancellation, atomic completion (rename on finish),
    and partial-file cleanup, behind a replaceable `DownloadEngine`
    seam — the roadmap's documented-foreground-only interim, since an
    Android+iOS resume/cancellation proof of a background-transfer
    dependency was not possible in this environment (ADR-0020).
    `DownloadStorage` keeps audio under application support, not a
    disposable cache — downloaded media is first-class local media.
  - `DownloadsCubit` runs downloads one at a time, oldest request
    first; resumes any download a fresh process finds still marked
    "downloading" from its partial bytes on disk; and supports pause,
    retry, retry-all, and remove (dropping one owner, or every claim).
  - Playback prefers a completed download over a stream via
    `LocalFirstAudioSourceResolver`, a decorator over the existing
    `AudioSourceResolver` — the queue, crossfade, and normalization
    pipeline are unchanged; only the resolved address differs.
  - Track rows and album headers gain a download control that both
    shows the state and is the action for it (download / stop / resume
    / remove-with-confirmation / retry), plus an album-wide aggregate
    summary.
  - `InsufficientStorageFailure` joins the core `Failure` hierarchy
    (ADR-0004) as its own distinct, user-actionable outcome.

## v0.2.1 — Downloadable playlists

- Added downloadable playlists (ADR-0021, v0.2.1), the next release in
  the offline-music arc:
  - `DownloadOwnerKind.playlist` joins `track` and `album` with no
    change to the owner model — "remove this playlist" drops the
    playlist claim from each member, and a file a standalone download or
    another downloaded playlist still wants is kept.
  - Schema v5 adds `playlist_download_members`: the ordered membership
    snapshot, one row per downloadable member, additive per ADR-0010.
    It records the order the user arranged — separate from the per-track
    owner rows, the same split `cached_collection_entries` uses — so a
    later server-side edit reconciles against it rather than rewriting
    it.
  - `DownloadsCubit` gains `downloadPlaylist` (pages the playlist and
    requests each page as it arrives, reusing a track already
    downloaded), `removePlaylist`, and `reconcilePlaylist` — the diff
    against the server that queues members added to the playlist, drops
    the claim on ones removed, rewrites the snapshot to the server's
    order, and reports the counts. Reconcile refuses to run against a
    cache-served read, and `retryAll` already covered the roadmap's
    "download all available" stretch item.
  - The playlist header gains a download control mirroring the album's,
    plus the aggregate summary. It differs where a playlist must:
    "downloaded" means a snapshot exists, and its menu offers "Check for
    changes." Opening a downloaded playlist online reconciles it once
    and reports what changed in a dismissible message — the roadmap's
    other reconcile trigger; there is no background auto-sync.
  - `CachedPlaylistRepository` falls back to the download snapshot when
    the server is unreachable and the metadata cache has been evicted,
    so a downloaded playlist still plays in order offline. A downloaded
    member plays through the unchanged v0.2.0 local-first path.

## v0.2.2 — Artist downloads, download quality, and management

- Added artist downloads, download quality, and a Downloads screen
  (ADR-0022, v0.2.2), the third release in the offline-music arc:
  - `DownloadOwnerKind.artist` joins `track`, `album` and `playlist`
    with no change to the owner model. `downloadArtist` pages the
    artist's tracks one window at a time and requests each window as it
    arrives — a prolific artist is never loaded into memory — reusing any
    track a download already holds. `removeArtist` drops only the artist
    claim; a file another target keeps stays. No membership snapshot: an
    artist's order comes from release date and disc/track number, the
    same as an album's.
  - A download-quality preference, persisted independently of the
    streaming quality (`SettingsCubit`, default original/lossless). It
    applies to new and retried downloads and never re-fetches or rewrites
    a file already on the device. `SettingsCubit` became a
    `lazySingleton` so `PlaybackCubit` and `DownloadsCubit` read the same
    instance the settings screen writes to.
  - A Wi-Fi-only download preference (opt-in, default off). When it is on
    and the connection is metered or absent, a queued download moves to a
    new `DownloadState.waitingForNetwork` — a clearly paused request, not
    a failure — and resumes on its own when Wi-Fi returns or the
    preference is turned off. `connectivity_plus` sits behind a narrow
    `NetworkCondition` seam. Enforcement is foreground only, disclosed in
    the settings screen and ADR-0022, the same limit as the foreground
    download engine.
  - A Downloads screen reached from the sidebar: aggregate storage in
    use, an in-progress/needs-attention list with per-item retry, resume,
    cancel and remove, the downloaded albums/artists/playlists as
    tappable rows, and standalone songs. It holds no state of its own —
    every figure is derived from `DownloadsCubit`'s catalog, which gains
    `overallStatus`, `storageInUse`, `collectionOwners` and
    `standaloneTrackDownloads`.
  - `DownloadsCubit` now resolves the *remote* audio source under its
    named registration rather than the bare contract, so a retried
    download is re-fetched from the server at the current quality instead
    of resolving to the partial local file.
  - Added the `ACCESS_NETWORK_STATE` Android permission.

## v0.2.3 — Offline library and recovery

- Added the offline library and recovery release (ADR-0023, v0.2.3), the
  fourth in the offline-music arc — downloaded music you can find and
  trust when the server is away or has changed:
  - Downloads are now per-profile. Schema v6 adds an `account_key` to the
    primary key of `track_downloads`, `download_owners` and
    `playlist_download_members`; `DriftDownloadStore` scopes every read
    and write to the signed-in Jellyfin user, so two profiles on one
    server keep separate collections and neither sees, plays or removes
    the other's. `DownloadsCubit` rebuilds its catalog on a profile
    switch or sign-out. Downloads made before v0.2.3 are claimed by the
    first profile to sign in after the upgrade — the old single-bucket
    behaviour, carried forward, not lost.
  - The new `downloaded_collections` table stores a downloaded album's,
    artist's or playlist's name and artwork, recorded at download time
    and refreshed on an online open. A downloaded playlist shows its real
    name instead of a generic label, and a collection renders offline
    before its tracks have been browsed.
  - The library and search fall back to the profile's downloads through
    `DownloadsLibrarySource`, read as ordinary library windows. Artists
    and albums are browsable offline from a single downloaded track of
    theirs, not only from a whole-artist or whole-album download. A music
    search that fails whole offline falls back to those downloads when
    they match, so an offline search still finds playable music rather
    than only an error.
  - Opening one of those artists, albums or playlists offline now works
    too, not just finding it: the detail page renders from the downloads
    when nothing was ever saved for it. The part that is not on the
    device is one honest "N songs not available offline" / "N albums not
    available offline" line — the count, not a row per title the user
    never downloaded. Playlists fill from their membership snapshot the
    same way.
  - A "Work offline" switch in the sidebar deliberately puts the whole
    app offline — the library and search answer from the device, no
    server round-trips. With no connection it shows on and disabled. A
    new Settings choice, "Offline library", decides what offline shows:
    the whole cached library with download markers ("Show everything"),
    or only what is on the device ("Downloads only"). It applies only
    while offline. Switching on or off reloads every list already on
    screen, and the reloaded window reflects the mode it landed in even
    when the switch and the scope both fired on the same frame. See
    ADR-0023; this revisits `CONTEXT.md`'s "not a separate app mode"
    line, which is updated to match.
  - Downloaded albums and artists carry a small marker on their library
    tile or row and on their detail header.
  - A downloaded song plays from a single tap — on the Downloads screen's
    own song list, and in the library, album, playlist and search views
    even where the row is marked unavailable because the server dropped
    it or cannot be reached. A song that genuinely cannot play offline is
    greyed out in place instead.
  - The per-list "showing your saved copy" notice is replaced by one
    offline line under the shared search field, shown on every Home and
    Library tab. It is the only offline banner: its wording switches on
    the "Offline library" scope ("showing your saved library" /
    "showing downloaded music only") instead of the library page stacking
    a second line of its own. The search screen's "can't reach the
    server" state is likewise one line under its field rather than a
    full-page error and a red line under every category.
  - Opening a downloaded album or artist online reconciles its tracks
    against the server: one the server no longer lists is marked
    `server_gone` and shown as "Only on this device" — kept and still
    playable — not as a remote failure or by vanishing; one that
    reappears loses the mark. A playlist reconcile marks a
    removed-but-kept member the same way. Nothing local is ever deleted
    as a side effect of a sign-in, refresh or server removal.
  - `restore` verifies each completed download still has its file and
    re-queues any whose file has vanished, so a database/file mismatch
    can no longer leave a phantom "downloaded" track that plays silence.
  - A low-storage warning before a large download: `DownloadStorageProbe`
    (over `disk_space_plus`, behind a replaceable seam) backs
    `DownloadsCubit.storageWarning`, and the album, artist and playlist
    download controls ask the user to confirm past it. Advisory only —
    no automatic cleanup, and a platform that will not report free space
    never blocks a download.
  - `disk_space_plus` is a new dependency.
