# ADR-0015: Streaming Quality & Transcoding

## Status

Accepted

## Context

`Roadmap to v0.2.md` (the file predates the `v0.1.x` naming that its own
header now uses) opens the post-v0.1.0 arc with streaming quality:
direct-play-only was flagged in the pre-v0.1.0 review as a possible
usability blocker if a meaningful share of the real ~130k-track library
needs transcoding on a given device. ADR-0013 built the seam for this on
purpose and stopped there: `StreamQuality` had one member (`original`)
and a doc comment saying a transcoded tier would be "an addition here
later, not a signature change through every caller." This is that
addition.

Ben confirmed the scope up front rather than leaving it to be guessed:

- Build the tiers now; validate them against the real library's actual
  format mix on real devices afterward, the same order ADR-0013 verified
  gapless — a device check, not a unit test.
- Four tiers: **Lossless** (`original`, unchanged) plus three transcoded
  ones at **320 / 192 / 128 kbps**.
- Now Playing should show two extra facts: the source file's own
  format/bitrate, and whether the current stream is actually being
  transcoded, with its target format/bitrate.
- A transcode failure on the currently playing track should retry once
  at `original` before being treated as genuinely unavailable.

## Options Considered

### How Jellyfinity asks Jellyfin to transcode

1. **Extend the existing `/Audio/{id}/stream` URL with `audioCodec` and
   `audioBitRate` query parameters, no `PlaybackInfo` negotiation**
   (chosen). `JellyfinAudioSourceResolver` already builds this URL
   synchronously with no server round trip; adding two parameters when
   `quality.isTranscoded` keeps that shape intact and matches the
   roadmap's explicit instruction to use "Jellyfin's existing audio
   transcoding/streaming parameters," not build new integration surface.
   Jellyfin itself decides whether the request needs a real transcode or
   only a remux — Jellyfinity never has to know which.
2. **A full `PlaybackInfo`/`DeviceProfile` negotiation** (the mechanism
   Jellyfin's own web client and most full-featured clients use):
   `POST /Items/{id}/PlaybackInfo` with a device profile describing
   supported containers/codecs/bitrates, returning a definitive
   direct-play/direct-stream/transcode decision and URL. Rejected for
   this release: it is materially more integration surface (a device
   profile payload, a new response shape, a new failure mode) than one
   release's worth of scope, and the roadmap explicitly scoped this
   release to the simpler parameter-based approach. Revisit if the
   client-side transcode heuristic below (or per-network quality,
   deferred in `Roadmap to v0.2.md`) turns out to need it.

### Tier bitrates and codec

Three transcoded tiers — 320 / 192 / 128 kbps — plus untouched
`original`, all transcoding to **AAC**: broad, unambiguous Android/iOS
decoder support without a per-platform codec choice. `StreamQuality`
carries the bitrates and the codec as constants (`highBitrateBps` /
`mediumBitrateBps` / `dataSaverBitrateBps`, `transcodeCodec`) rather than
hardcoding them at the one call site, since the Now Playing transcode
indicator (below) needs the same numbers.

### Failure handling: retry once at original, not transience detection

`PlaybackEngine.failureStream` (`just_audio`'s `PlayerException`) does
not reliably distinguish a transient transcode/network hiccup from a
genuinely undecodable file across Android and iOS. Two approaches:

1. **Retry once at `StreamQuality.original` before marking unavailable**
   (chosen). `PlaybackCubit` tracks entries that already got this retry
   (`_retriedAtOriginal`); a failure on the *current* entry at a
   transcoded quality re-resolves and reloads at `original` instead of
   marking it unavailable immediately. A second failure (now at
   `original`) falls through to the existing mark-unavailable-and-advance
   handling unchanged. When the selected quality is already `original`
   (today's default), this path never triggers — zero behavior change
   from v0.1.0. A preloaded-but-not-yet-current entry failing keeps
   today's silent-mark handling untouched; only the entry actually
   loading/playing gets the retry, to avoid an audible reload for a
   failure the user hasn't reached yet.
2. **Classify failures as transient/permanent** from `PlayerException`'s
   error code. Rejected: the codes are platform-specific
   (`ExoPlayer`/`AVPlayer`) and not a reliable transience signal, which
   risks silently under- or over-retrying in a way that is hard to
   reason about or test.

### Showing source format/bitrate and a transcode indicator

Now Playing needed a track's file details (container/codec/bitrate),
which nothing before this release read. Added `TrackSourceInfo` +
`TrackSourceInfoResolver` (mirrors `AudioSourceResolver`/
`ArtworkResolver`'s narrow-contract shape) over Jellyfin's
`MediaSources`/`MediaStreams`, fetched only for the one currently-playing
track (a new `JellyfinMediaApi.trackSourceFields = ['MediaSources']`,
kept out of `detailFields` deliberately — that list is paid for on every
row of every paged detail view, including the album grid, while source
detail is a single-track, on-demand read). `TrackSourceInfoCubit` is a
small page-scoped cubit in the same spirit as `MediaDetailCubit`, just
not tied to `MediaItem`.

Whether the current stream is *actually* being transcoded is not
something Jellyfinity can know for certain without the `PlaybackInfo`
negotiation rejected above. The indicator is therefore a **client-side
heuristic**: transcoding is assumed unless the source is already in the
requested codec (AAC) and at or under the tier's target bitrate, in
which case Jellyfin would stream/remux rather than transcode. This can
be wrong at the margins (a source that happens to match exactly). It is
documented here as a known limitation rather than presented as fact —
consistent with `PHILOSOPHY.md`'s "never leave the user guessing," this
is a best-effort hint, not a guarantee, and is worded in the UI
accordingly ("Transcoding to ...", not "This file is being transcoded").

## Decision

### Domain — `lib/domain/playback/`

- `StreamQuality` grows to `original, high, medium, dataSaver`, each with
  a `targetBitrateBps` (`null` for `original`), plus `transcodeCodec`,
  `isTranscoded`, `tryParse`/`fallback` (mirrors `ShellNavigationMode`).
- `TrackSourceInfo` (new): container/codec/bitrate/sample rate/bit
  depth/channels — a track's file, not its stream.
- `TrackSourceInfoResolver` (new): one-method contract, same shape as
  `AudioSourceResolver`.

### Infrastructure — `lib/infrastructure/jellyfin/media/`

- `JellyfinAudioSourceResolver` branches on `quality`: `original` keeps
  today's `stream?static=true`; every other tier requests
  `stream.aac?audioCodec=aac&audioBitRate=<bps>`.
- `jellyfin_media_api.dart` gains `trackSourceFields` and an optional
  `fields` parameter on `item()` (defaulted to `detailFields`, so every
  existing caller is unaffected).
- `BaseItemDto` gains `mediaSources` (`MediaSourceInfoDto` →
  `MediaStreamDto`); `BaseItemMapper.toTrackSourceInfo` reads the first
  source's first audio stream, falling back to the source-level bitrate.
- `JellyfinTrackSourceInfoResolver` (new): same scope/fetch/map shape
  `JellyfinMusicLibraryRepository._single` already uses.

### App — `lib/app/`

- `SettingsCubit`/`SettingsState` gain `streamQuality`, persisted via
  `KeyValueStore` (`settings.streamQuality`) the same way
  `navigationMode` is.
- `PlaybackCubit` takes `SettingsCubit` as a dependency, resolves each
  queue entry at the settings-selected quality (or `original`, for an
  entry already retried per the failure policy above), and implements
  the retry-once-at-original policy in `_onEngineFailure`.

### Presentation

- `SettingsPage` gains a "Streaming quality" section (four radio-style
  rows, same shape as the navigation-mode section).
- `NowPlayingPage` shows a small caption under the artist line: the
  source format/bitrate, and, when the heuristic above says so, a
  transcode indicator with its target format/bitrate.

## Tests

- `stream_quality_test`: tier bitrates, `tryParse`/`fallback`.
- `jellyfin_audio_source_resolver_test`: URL/query shape per tier;
  auth failures are quality-independent.
- `base_item_mapper_test`: `toTrackSourceInfo` — present, audio-stream
  fallback, non-audio streams skipped, no media sources, wrong type.
- `jellyfin_track_source_info_resolver_test`: scope/fetch/map, not
  found, wrong server, signed out.
- `settings_cubit_test`: `streamQuality` load/persist/no-op.
- `playback_cubit_test`: the resolver receives the settings-selected
  quality; a current-entry failure at a transcoded quality retries once
  at `original`; a second failure marks unavailable; a failure already
  at `original` is unchanged from v0.1.0.
- `settings_page_test`, `playback_ui_test`: widget coverage for the new
  Settings section and the Now Playing hint/indicator.
- Manual device validation against the real library's actual format mix
  is explicitly Ben's step, per the roadmap's Definition of Done — not
  something this pass can do.

## Consequences

- A user who never opens Settings sees byte-identical behavior to
  v0.1.0: `original` is the default, and its resolver path/URL shape is
  unchanged.
- Transcoding correctness (does the real library actually need it, do
  the tiers sound acceptable) is unverified until Ben's on-device pass —
  tracked as this release's open item, not silently assumed done.
- The Now Playing transcode indicator is a heuristic, not a guarantee;
  if that proves confusing in practice, the fix is either wording it more
  conservatively or eventually adopting the `PlaybackInfo` negotiation
  rejected above — not something this ADR forecloses.
- No per-network (Wi-Fi/cellular) quality default — deferred, as the
  roadmap allows, to keep this release to a single global default.
