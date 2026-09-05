# ADR-0017: Volume normalization

## Status

Accepted

## Context

`Roadmap to v0.2.md`'s v0.1.4 asks for "consistent track-to-track loudness
using ReplayGain or an equivalent loudness-based approach," and its first
required step is to determine what loudness metadata Jellyfin and the
real library actually provide before choosing an implementation.

Jellyfin's server (confirmed against `jellyfin/jellyfin`'s `DtoService`)
already computes this for every item: `BaseItemDto.NormalizationGain` is
a nullable dB value, set unconditionally on every item response —
`-18 − LUFS` when the server has run loudness analysis on the file, else
whatever it parsed from an embedded `REPLAYGAIN_TRACK_GAIN` tag, else
left `null` for a track the server has neither analyzed nor found a tag
on. This is not gated behind a `fields` request the way `MediaSources`
is (ADR-0015's `trackSourceFields`), so it arrives on every track
response Jellyfinity already makes, at no extra request cost. It
predates Jellyfinity's 10.11.6 floor, so nothing here needs a minimum
version bump.

That settles the data source: Jellyfinity reads `NormalizationGain`
as-is rather than re-deriving loudness itself, and does not additionally
read `AlbumNormalizationGain` (a newer, separate field for album-mode
normalization) — the roadmap only asks for a single on/off setting, and
per-track gain is the direct equivalent of ReplayGain track gain, the
behavior most other Jellyfin clients that support this already default
to.

ADR-0016 anticipated the one real design constraint this feature runs
into: crossfade already owns `AudioPlayer.setVolume` on both decks for
the ramp, so normalization has to apply gain *through* that seam, not
around it, or the two features would fight over the same call.

## Options Considered

### Where the gain value lives

**On `PlaybackSource`, as a plain `double? normalizationGain` in dB**
(chosen). The engine already reads `PlaybackSource.duration` for
`CrossfadeSettings.effectiveDurationFor` — a source-level number the
engine interprets without knowing what a track or an album is. Gain
is the same shape of fact, so it travels the same way: `Track` carries
it from `BaseItemMapper`, `QueueEntry.fromTrack` denormalizes it for a
restored queue exactly like duration and artwork, and `PlaybackCubit`
copies it onto each `PlaybackSource` it builds.

Rejected: a separate `TrackSourceInfoResolver`-style on-demand lookup.
That resolver exists because `MediaSources` is heavy and only ever
needed for the one currently-playing track (Now Playing). Gain is a
single cheap number already present on every item response — resolving
it per-track, on demand, would add a network round trip for data
Jellyfinity is handed for free.

### The engine contract

**A second narrow method, `PlaybackEngine.setNormalization(NormalizationSettings)`**
(chosen), the same shape as ADR-0016's `setCrossfade`: a preference
about what to *do* with data the engine already has, not where that
data comes from. An implementation that cannot apply gain may treat any
setting as a no-op, same as an engine that cannot crossfade.

One difference from crossfade: crossfade only ever affects the *next*
transition, so `setCrossfade` can leave whatever is currently playing
alone. A volume level has no "next transition" to wait for — a user
toggling normalization expects the currently playing track to change
volume immediately. `setNormalization` therefore reapplies the current
source's gain-adjusted volume right away (unless a crossfade ramp is in
progress, which owns volume until it finishes).

### Applying gain without fighting the crossfade ramp

`JustAudioPlaybackEngine` now computes a per-source linear volume
multiplier (`NormalizationSettings.volumeFactorFor`) and folds it into
every place it already sets `AudioPlayer.volume`, rather than adding a
separate gain stage:

- **Steady state** (`_abandonCrossfade`, `setSources`, `updateSources`):
  the active deck's volume is set from its *current* source's gain
  instead of a hardcoded `1`.
- **A natural gapless transition** (crossfade off, or between prepares):
  `just_audio`'s own playlist advances with no crossfade code running at
  all, so `_onCurrentIndexChanged` — already the hook every index change
  goes through — re-levels the deck for whichever source just became
  current. This is the case easiest to miss: without it, a queue's
  second track would keep playing at the first track's gain until some
  unrelated transport call happened to reset volume.
- **Mid-crossfade** (`_ramp`): each deck ramps toward its *own* source's
  gain-adjusted peak (`outgoingGain`/`incomingGain`) rather than toward
  `1`, computed once when the fade starts (ADR-0016's ramp already reads
  `PlaybackSource.duration` once per fade the same way). The cosine/sine
  envelope is unchanged; only the peak each curve ramps to and from
  moves.

This means normalization needs no new timer, no separate audio stage,
and no new state beyond one settings object and one per-source number —
it rides the exact volume-setting code ADR-0016 already built.

### Never boosting above the source's own volume

`NormalizationSettings.volumeFactorFor` clamps the computed multiplier
to `1` and never exceeds it. `NormalizationGain` is *positive* for a
track quieter than the server's reference loudness — applying it
literally would mean turning that track up. Nothing downstream of
`just_audio`'s `setVolume` is a limiter, so boosting risks clipping on
a track whose peaks are already near full scale. Attenuating loud
tracks down towards the reference, and leaving quiet tracks alone, is
the same "never boost" default most ReplayGain-supporting players ship
with, and it means a wrong or extreme gain value degrades to "this one
track is a little quieter than usual" rather than "this track clips."

A `null` gain — the server found neither an analysis nor a tag — means
unity volume, identically to a disabled setting. Untagged tracks are
not guessed at; they simply play unchanged, which is the "defined
behavior for missing metadata" the roadmap asks for.

### The preference

`NormalizationSettings` (one `enabled` bool) is a domain value object,
read and written by `SettingsCubit` over `KeyValueStore` exactly as
`CrossfadeSettings` is, and resolved once in `bootstrap()` before the
restored queue is primed. It is a settings object rather than a raw
`bool` registered with `getIt` so its DI registration stays as
unambiguous as every other bootstrap-resolved preference's.

Target-loudness tuning (choosing a reference LUFS other than the
server's) is the roadmap's named stretch item and is not implemented:
`NormalizationSettings` has room to grow a target field the way
`CrossfadeSettings` grew a duration, without another engine-contract
change.

## Decision

- `lib/domain/playback/NormalizationSettings.dart` — the preference and
  `volumeFactorFor`.
- `PlaybackEngine.setNormalization` — one new contract method, mirroring
  `setCrossfade`'s "no-op, never fail" contract for a second
  implementation. Until first called, behaves as
  `NormalizationSettings.disabled`.
- `PlaybackSource.normalizationGain`, `QueueEntry.normalizationGain`,
  `Track.normalizationGain` — the dB value carried from Jellyfin's
  `NormalizationGain` down to the engine, denormalized the same way
  duration and artwork already are.
- `BaseItemDto.normalizationGain` / `BaseItemMapper.toTrack` — reads the
  field Jellyfin already sends; no new `fields` entry needed.
- `JustAudioPlaybackEngine` — computes and applies the gain-adjusted
  volume everywhere it already sets `AudioPlayer.volume`: steady state,
  every `currentIndexStream` event, and both ends of the crossfade ramp.
- `SettingsCubit` gains `normalization` state, `loadInitialNormalization`
  and `setNormalizationEnabled`; `bootstrap()` registers the initial
  value like `CrossfadeSettings`.
- `PlaybackCubit` subscribes to `SettingsCubit` and pushes the setting to
  the engine, with no repeat-mode override — gain is a per-source
  property, so it applies the same regardless of play order.
- `SettingsPage` gains a Volume normalization section: a single switch,
  with copy stating plainly that untagged tracks play unchanged.

## Tests

- `normalization_settings_test` — disabled default, unity while
  disabled, unity for a `null` gain, attenuation for a positive dB
  value, and the never-boost clamp for a negative one.
- `settings_cubit_test` — default, a saved preference, persistence, and
  a no-op set.
- `playback_cubit_test` — a track's gain reaching its `PlaybackSource`,
  and the engine-configuration seam: configured at construction,
  reconfigured on a preference change, unaffected by an unrelated
  settings change, and (unlike crossfade) unaffected by repeat mode.
- `base_item_mapper_test` — `NormalizationGain` mapped onto `Track`, and
  left `null` when the server sends none.
- `settings_page_test` — the switch toggling the setting.
- The perceived result — whether two mismatched tracks actually sound
  level, and whether the never-boost clamp is inaudible rather than
  simply quieter than expected — is verified on real devices with a
  representative mismatched pair, the same treatment ADR-0013 gave
  gapless and ADR-0016 gave the crossfade ramp: neither `just_audio` nor
  `audio_service` runs outside a real device.

## Consequences

- Normalization is configurable and, unlike crossfade, takes effect on
  whatever is currently playing the moment it is toggled.
- A track with no `NormalizationGain` (unanalyzed and untagged) always
  plays at its original volume; this is not a failure state, just an
  honest absence of data.
- Loud tracks may play quieter than their source file; no track ever
  plays louder than its source file. A library where every track needs
  boosting to reach the reference will not sound leveled — only evened
  out where the server already has data to even it out with.
- Crossfade and normalization now share one set of `setVolume` calls
  rather than two independent ones; a future feature that also wants to
  shape playback volume (a user-facing gain slider, say) should extend
  this same seam rather than adding a third, competing one.
