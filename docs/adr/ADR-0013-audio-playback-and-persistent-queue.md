# ADR-0013: Audio Playback & Persistent Queue

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.9 turns the browse-only music library (v0.0.8) into a
real player. Everything under it exists and is tested — the media domain
(ADR-0011), the cached music library (ADR-0012) — and none of it has ever
made a sound. `Track.dart`, `PlaybackProgress.dart` and
`PlaybackProgressRepository.dart` all carry doc comments written in
v0.0.7 that already point at this release ("reporting a position mid-
playback needs a play session and belongs with the player"). `ADR-0012`
is explicit that tapping a song currently opens its album and nothing
plays.

Two constraints shape everything below:

- `CONTEXT.md`: "The queue is Jellyfinity application state, not merely
  state inside a playback package." Ownership of the queue, shuffle and
  repeat has to sit in Jellyfinity's own code, not a package's internals.
- Gapless playback is called out in both `ROADMAP.md` and `PHILOSOPHY.md`
  as a hard requirement, with an explicit instruction not to rely solely
  on a package's claim.

Ben's decision: **`just_audio` + `audio_service`**, the standard Flutter
combination for background execution and system media controls, and the
same combination Finamp — an existing Flutter Jellyfin music client —
uses. With one condition: the engine must be swappable later (to
`media_kit`, or a future custom engine) without the queue, domain or UI
code changing. No engine-picker UI ships in this release — Jellyfinity
has no Settings feature yet, and building one is out of scope here; the
requirement is a clean seam, not a switch.

## Options Considered

### Where the swappable boundary sits

1. **A `PlaybackEngine` contract that only knows "play this ordered list
   of resolved sources"; the engine has no idea what a queue, shuffle or
   repeat is** (chosen). Jellyfinity's own `PlaybackQueue` computes the
   actual play order — including the shuffled one — and hands the
   engine a plain list plus a start index. Advancing, repeating, and
   reordering are queue operations that recompute the list and hand it
   to the engine again. This is the minimum surface a second engine
   needs to satisfy, and it keeps queue logic testable in pure Dart
   without a fake player pretending to be `just_audio`.
2. A `PlaybackEngine` that itself takes a queue with shuffle/repeat
   flags and manages advancement internally (closer to how
   `just_audio`'s own playlist APIs and `audio_service`'s `QueueHandler`
   mixin already work). Rejected: it pushes "what is Jellyfinity's play
   order" — a domain question — into the engine, and a second engine
   would have to reimplement Jellyfinity's specific repeat/shuffle
   semantics rather than just play a list.

`just_audio`'s gapless-capable playlist loading (`setAudioSources`) is
still used *inside* the chosen engine implementation — the contract
being engine-agnostic doesn't mean giving up real gapless preloading,
it means the *next resolved source* is computed by the queue and handed
to the engine ahead of the boundary, same as today.

### What the engine implementation actually is

**The `audio_service` handler *is* the engine implementation**
(`JustAudioPlaybackEngine extends BaseAudioHandler … implements
PlaybackEngine`), not a separate wrapper around it. `BaseAudioHandler` is
what `AudioService.init()` needs and the natural owner of the
`just_audio` `AudioPlayer` instance — background execution and system
media controls are not a layer on top of playback, they are playback, on
these platforms. A `media_kit`-backed engine later would be a second
`BaseAudioHandler` implementation over a `media_kit` player; this is
`media_kit`'s own documented integration shape too, so the swap stays a
real one-class change, not aspirational.

Registration cannot be a plain `@LazySingleton`, and — unlike
`JellyfinClientIdentity`'s `@preResolve`d device-id lookup — it also
cannot be a `@preResolve` DI module step: building a `BaseAudioHandler`
requires the async `AudioService.init()` call, and that call is guarded
to run at most once per process, which conflicts with
`configureDependencies()` running fresh in every test (`service_locator_
test.dart` rebuilds the whole graph per test; the second `AudioService
.init()` call hits its own assertion). So, the same way `AppConfig` is,
it is built in `bootstrap()` and registered with `getIt` directly,
outside the generated graph and everything that exercises it under
`flutter test`.

### Where the queue is persisted

**A new `QueueEntries` table (schema v3), self-contained rather than
joined against `CachedMediaItems`** (chosen). `CachedCollectionEntries`
(ADR-0012) is the obvious template — ordered rows, position as part of
the key — but it only holds items that arrived through a cached
collection window, and ADR-0012 deliberately does not cache search
results. A track queued from music search would have nothing to join
against. `QueueEntries` instead carries its own denormalized display
fields, which is exactly what `Track.dart`'s v0.0.7 doc comment already
asked for: "a queue restored offline has to show which album is this
from without loading the album."

Scalar queue state — current index, shuffle, repeat mode, last saved
position — rides on the existing `KeyValueStore` rather than a new
one-row table. It is the same category of small structured app state
the store was already built for (device id, active-account pointer).

### How streaming is authenticated

Jellyfin's stream endpoint needs a token, but a URL handed to a native
player (`ExoPlayer`/`AVPlayer`) does not go through `JellyfinHttpClient`'s
header interceptors. **The token travels as an `api_key` query
parameter** on the stream URL, mirroring how other Jellyfin clients solve
the same problem, rather than attempting per-platform custom-header
support in the player. `JellyfinAudioSourceResolver` is the one place
that builds this URL, the same shape as `JellyfinArtworkResolver` for
images.

### Stream quality

Direct play only (`/Audio/{id}/stream?static=true`, the original file,
no transcoding) behind a `StreamQuality` parameter that has exactly one
member today. `ROADMAP.md` explicitly asks for an architecture that
"should not assume only one stream quality forever" while deferring
"full transcoding/quality sophistication" — this is that seam without
building the feature it will eventually select between.

### Failure handling

An engine source failure (a track the device can't decode, a dead
stream) is reported on `PlaybackEngine.failureStream` by index and
handled by `PlaybackCubit`: the entry is marked unavailable in place —
same vocabulary as an unavailable row in a browsed list — and playback
advances to the next entry. The queue is never cleared and the user is
never navigated away because one track failed; the album-with-one-dead-
track rule from `PHILOSOPHY.md` §1 applies to the queue as much as to any
other list.

## Decision

### Domain — `lib/domain/playback/`

- `PlaybackEngine` (contract above), `PlaybackSource`, `PlaybackStatus`,
  `PlaybackFailure`.
- `QueueEntry` (denormalized queued item), `PlaybackQueue` (ordered
  entries + current index + shuffle + repeat, and the pure play-order
  logic), `RepeatMode`.
- `QueueRepository` (persistence contract), `AudioSourceResolver`
  (mirrors `ArtworkResolver`), `StreamQuality`.

### Infrastructure

- `lib/infrastructure/playback/JustAudioPlaybackEngine.dart` — the
  `BaseAudioHandler`/`PlaybackEngine` implementation described above.
- `lib/infrastructure/jellyfin/media/JellyfinAudioSourceResolver.dart` —
  builds the authenticated direct-stream URL.
- `lib/infrastructure/persistence/playback/DriftQueueRepository.dart` —
  over the new `QueueEntries` table (schema v3) and `KeyValueStore`.
- `JellyfinPlaybackProgressRepository` gains the three
  `/Sessions/Playing…` calls (start/progress/stop), closing the seam its
  own v0.0.7 doc comment left open.

### App — `lib/app/playback/PlaybackCubit.dart`

Same architectural slot as `SessionCubit`/`AuthSessionManager` —
cross-cutting app state, not a feature. The only thing that talks to
both `PlaybackQueue` and `PlaybackEngine`; resolves sources, computes
play order, persists structural changes immediately and position on a
debounced timer, restores the saved queue at cold start primed but
paused (no surprise auto-play), and reports progress.

### Presentation — `lib/features/playback/presentation/`

`MiniPlayer` (in `AppShell`, above the bottom navigation bar, shown only
with a non-empty queue), `NowPlayingPage`, `QueuePage`
(`ReorderableListView`, no new dependency). Both are root routes
(`/now-playing`, `/now-playing/queue`), reachable from any shell tab.
Track taps across the music screens, previously dead per ADR-0012, now
start playback with the already-loaded list as the queue; album/playlist
headers gain a `Play` button; `TrackRow` gains an optional Play
Next/Add to Queue action.

### Platform

Android: `MainActivity` becomes a `FlutterFragmentActivity`
(`audio_service` requirement); manifest gains
`FOREGROUND_SERVICE`/`FOREGROUND_SERVICE_MEDIA_PLAYBACK`/
`POST_NOTIFICATIONS`/`WAKE_LOCK`. iOS: `Info.plist` gains
`UIBackgroundModes = [audio]`.

## Tests

- `playback_queue_test` — shuffle order, repeat off/one/all at the
  boundary, add/remove/reorder/clear, restore — pure logic, no fakes
  needed.
- `playback_cubit_test` — a hand-written `FakePlaybackEngine` (this
  project's established preference over mocks for a seam this shaped):
  transport controls, a source failure marking an entry unavailable and
  advancing without clearing the queue, persistence firing at the right
  points, cold-start restore that primes without auto-playing.
- `drift_queue_repository_test`, `app_database_migration_test` extended
  to v2 → v3, `jellyfin_audio_source_resolver_test`,
  `jellyfin_playback_progress_repository_test`.
- Widget/navigation tests for the mini-player, Now Playing, the queue
  screen, and a track tap actually starting playback through the real
  router.
- Gapless: verified by construction (a real preloading playlist API, not
  sequential single-track swaps) plus Ben's on-device check across an
  album boundary with headphones — not something a unit test can hear,
  the same treatment v0.0.8's sideload testing gave background/network
  behavior.

## Consequences

- Jellyfinity can play music: background playback, lock-screen/
  notification controls, a persistent queue that survives a restart.
- The engine can be swapped later by writing one new
  `BaseAudioHandler`-shaped class and changing one DI registration — no
  Settings UI exists yet to expose that choice, and none is added here.
- New dependencies: `just_audio`, `audio_service` (pulls in
  `audio_session`).
- Movies, TV and video playback remain entirely out of scope — this ADR
  is audio-only, matching `ROADMAP.md`'s v0.1.0 non-goals.
- Lyrics, crossfade, ReplayGain and configurable transcoded quality are
  deliberately not addressed; `StreamQuality` and the engine seam leave
  room for the last one without committing to it now.
