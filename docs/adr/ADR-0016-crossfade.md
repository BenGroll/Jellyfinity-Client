# ADR-0016: Crossfade

## Status

Accepted

## Context

`Roadmap to v0.2.md`'s v0.1.3 asks for "configurable crossfade without
regressing gapless playback", and its first required step is to *confirm*
the playback engine can crossfade with the current queue/background
architecture before committing to an implementation.

The answer to that research step is the reason this ADR exists:
**`just_audio` 0.10.6 has no crossfade at all.** There is no crossfade,
fade-in or fade-out API anywhere in the package — the only relevant
control is `AudioPlayer.setVolume`. And one native player cannot overlap
two items of its own playlist: `ExoPlayer`/`AVQueuePlayer` play a
sequence, one item at a time, which is exactly what makes ADR-0013's
`setAudioSources` preloading gapless in the first place.

So crossfade is not a setting to turn on. It is a second player plus a
volume ramp, and the question is where that lives without unpicking
ADR-0013's engine seam or the gapless behavior that seam was built to
deliver.

## Options Considered

### Where crossfade lives

1. **Inside the engine implementation, behind one new contract method,
   `PlaybackEngine.setCrossfade(CrossfadeSettings)`** (chosen).
   Crossfade describes the *handover* between two sources the engine has
   already been given — not which source comes next, which remains
   `PlaybackQueue`'s answer. That keeps the contract as narrow as
   ADR-0013 made it: a second engine still only has to "play this list,"
   and one that cannot overlap sources may treat an enabled setting as a
   no-op rather than failing.
2. `PlaybackCubit` driving the fade itself, by asking the engine to
   start the next source early and ramping volumes through new engine
   methods. Rejected: it puts frame-rate audio work in a Cubit, needs a
   *wider* engine contract (per-source volume, simultaneous sources)
   than the one method above, and makes every future engine reimplement
   the ramp.

### How the overlap is produced

**Two decks, both holding the whole source list, one active at a time**
(chosen).

- With crossfade **off** there is one deck running one `just_audio`
  playlist — the untouched v0.0.9 arrangement. Gapless playback is
  preserved by construction, not by re-verification.
- With crossfade **on**, the standby deck is loaded with the *same* list
  cued to the next index, pre-buffered ~5 s ahead of the fade point,
  then played at volume 0 and ramped up while the active deck ramps
  down.

Loading the whole list on both decks (rather than a single source on the
standby) is what makes a deck a fully-fledged playlist player the moment
it becomes active — including for the transition after this one, and for
a gapless run if the user turns crossfade off midway. It also means
`setCrossfade` never reloads or interrupts anything: both modes play the
same playlist on the active deck, so the setting only decides how the
*next* transition is made.

Two variants were rejected:

- **Fading the outgoing track on the second deck** (seeking it to
  `duration − fade`) rather than the incoming one. Rejected on the
  roadmap's own "verify transitions across direct-play and transcoded
  sources" requirement: it needs a seek into a stream, and Jellyfin's
  transcode endpoint is not reliably seekable, so crossfade would work
  on direct play and stall on transcodes. Cueing the *incoming* source
  to position zero never seeks, which is why the overlap behaves
  identically for both source types.
- **Handing control back to the original deck at the end of the fade.**
  Rejected: it needs a mid-fade seek and produces an audible hard swap
  at exactly the moment the ear is listening for a seam. Instead
  **control transfers at the *start* of the overlap** — the incoming
  deck becomes the active one immediately, and the outgoing deck is only
  an audible tail from that point on. Everything downstream (position,
  duration, index, `mediaItem`, a Next press) refers to the track the
  user is now listening to.

Because the source of position/duration/status/index now *changes* at a
crossfade while `PlaybackCubit` subscribes exactly once at construction,
those four streams are republished through the engine's own broadcast
controllers instead of being exposed straight off the player.

The second `AudioPlayer` is built lazily, on the first crossfade that
needs somewhere to fade in: a user who never turns crossfade on never
pays for a second native player.

### The ramp

**Equal-power (cosine/sine), 50 ms steps.** Two different recordings are
uncorrelated, so their loudness sums as power, not amplitude; a linear
amplitude ramp audibly dips about 3 dB in the middle of the overlap.

The outgoing deck holds the whole list too, so it would advance into the
next source by itself if the fade outlasts the track by even a few
milliseconds. Its playlist is therefore truncated at its current item
when the fade starts, making the end of that source the end of that
deck.

### Repeat-one

The engine deliberately knows nothing about repeat, so it would happily
start overlapping the *next* source in the loaded list — which a
repeat-one queue never reaches. `PlaybackCubit` resolves this by pushing
`CrossfadeSettings.disabled` to the engine while repeat-one is active
and the stored preference again when it ends. The domain rule stays
where the queue lives, and the engine contract stays narrow.

### The preference

`CrossfadeSettings` (enabled + duration) is a domain value object, read
and written by `SettingsCubit` over `KeyValueStore` exactly as ADR-0014's
navigation mode and ADR-0015's stream quality are, and resolved once in
`bootstrap()` so the engine is configured before the restored queue is
primed — a saved preference is in force from the first transition, not
the second.

Enabled state and duration are stored as **two scalars**, not one
encoded string, so turning crossfade off and on again keeps the length
the user had chosen. Duration is clamped to 1–12 s: below a second the
ramp is indistinguishable from a hard cut, past twelve it overlaps more
of a short track than it transitions between two. A stored value outside
that range degrades to the nearest usable one rather than disabling the
feature.

A crossfade longer than half a track would still be fading the outgoing
source in when the next one starts, so short tracks get a proportionally
shorter overlap (`effectiveDurationFor`) rather than no crossfade at all.
A source whose duration is unknown gets none — the engine cannot know
where the end is, so there is nothing to fade towards.

## Decision

- `lib/domain/playback/CrossfadeSettings.dart` — the preference, its
  bounds, and `effectiveDurationFor`.
- `PlaybackEngine.setCrossfade` — one new contract method. Until it is
  first called, an implementation must behave as
  `CrossfadeSettings.disabled`; `PlaybackCubit` configures the engine
  explicitly at construction rather than assuming a default.
- `JustAudioPlaybackEngine` — the two-deck implementation above.
- `SettingsCubit` gains `crossfade` state, `loadInitialCrossfade`,
  `setCrossfadeEnabled` and `setCrossfadeDuration`; `bootstrap()`
  registers the initial value like `StreamQuality`.
- `PlaybackCubit` subscribes to `SettingsCubit` and pushes the effective
  configuration (preference, overridden by repeat-one) to the engine.
- `SettingsPage` gains a Crossfade section: a switch, and — only while
  it is on — a 1–12 s length slider that persists on drag end, one write
  per adjustment rather than one per pixel.

## Tests

- `crossfade_settings_test` — bounds, clamping, and the short-track and
  unknown-duration cases of `effectiveDurationFor`.
- `settings_cubit_test` — defaults, a saved preference, an out-of-range
  stored duration, a duration surviving off/on, and no-op sets.
- `playback_cubit_test` — the engine-configuration seam: configured at
  construction from the saved preference, a preference change reaching
  the engine, an unrelated settings change *not* reconfiguring it, and
  repeat-one suppressing then restoring crossfade.
- `settings_page_test` — the switch revealing and hiding the length
  control, and the slider persisting one value per drag.
- The audible result itself is verified on device, the same treatment
  ADR-0013 gave gapless: no unit test can hear a 3 dB dip, and neither
  `just_audio` nor `audio_service` runs outside a real device.

## Consequences

- Crossfade is configurable and applies from the next transition, with
  no reload when it is switched.
- Gapless playback with crossfade off is the pre-existing single-player
  code path, unchanged.
- A second `AudioPlayer` exists while crossfade is in use. Both decks
  handle audio-session interruptions independently, so a phone call
  pauses both — the correct outcome, but worth knowing.
- Crossfade preloads the next source ~10 s early (widened from an
  original 5 s — see below), a small amount of network use ahead of a
  transition that might still be skipped.
- Two transitions are deliberately *not* crossfaded: the repeat-all wrap
  from the last entry back to the first, and repeat-one's replay. Both
  are handled by `PlaybackCubit` at completion, past the point where the
  engine could have started an overlap.
- Volume normalization (v0.1.4) will need to apply gain per source while
  these ramps are running; the ramp owns `setVolume` on both decks
  today, so that feature has to route through it rather than around it.

### v0.1.6 fix: a stutter instead of a fade

First real-world testing after this shipped found crossfade producing an
audible stutter at transitions rather than a fade — reported as neither
a clean cut nor a smooth overlap. The cause: `_prepare` opens a *fresh
network stream* for the standby deck (worse yet for a source Jellyfin
has to transcode, which first spins up server-side encoding), which can
take longer than the outgoing source has left to play. When it does, the
outgoing deck — still holding its own full, untruncated list — has
already gaplessly advanced into the next source **on its own** by the
time `_prepare` finally resolves. `_startCrossfade` used to plough ahead
regardless: truncating the (already-advanced) outgoing deck and starting
the standby deck on the *same* source from position zero, so the same
audio briefly played twice at once before the ramp math dragged one copy
down — the stutter.

The fix has two parts:
- `_startCrossfade` now records the outgoing deck's index *before*
  awaiting `_prepare`, and re-checks it immediately after. If the
  outgoing deck moved on its own in the meantime, the natural gapless
  transition already happened correctly — the fix is to recognize that
  and stand down, not to fight it.
- `_preloadLead` widened from 5 s to 10 s, so preparation starts earlier
  and hits this race less often to begin with (it does not eliminate the
  race — a sufficiently slow connection can still lose it, in which case
  gapless playback rather than a stutter is what the guard above now
  guarantees).
