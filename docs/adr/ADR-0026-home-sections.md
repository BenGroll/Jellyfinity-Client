# ADR-0026: Home sections

## Status

Accepted

## Context

`Roadmap to v0.4.md` v0.3.2 replaces the Home placeholder — an icon, a
sentence, and a button that pointed at the Library tab — with a real
Home built from **Continue listening** and **Recently played**, and asks
that it "establish the section pattern the rest of the arc uses": each
section loads, empties, fails and refreshes on its own, and one dead
section never takes the screen down (`PHILOSOPHY.md` §2, the rule
`MusicSearchCubit` already follows for its categories).

Two constraints from the arc's preamble shape this:

- **No new subsystem.** Every section is built from data Jellyfinity
  already collects — the persisted queue (v0.0.9), listening history
  (v0.3.1, ADR-0025), the download catalog (ADR-0020) — or one extra
  library query. A section that needs a new table or a new capability is
  the wrong section.
- **Honest offline.** ADR-0023 made offline a deliberate mode with a
  "downloads only" scope. Every section has to say something truthful in
  that mode.

## Decision: sections are independent widgets over existing state, not one Home cubit

There is no `HomeCubit`. Home composes independent pieces:

- **Continue listening** is a `BlocBuilder<PlaybackCubit>`. The queue is
  already restored, paused, into the engine at launch (v0.0.9); the
  section reads `PlaybackUiState` directly — current entry, position,
  duration — and adds nothing. `PlaybackCubit.resume()` is the one new
  method: start the primed engine, a no-op on an empty or
  already-playing queue.
- **Recently played** is `RecentlyPlayedCubit`, a thin read-only view of
  `ListeningHistoryRepository.recent()`. It owns only its own
  loading / empty / failed state. A failed *first* read shows a
  compact retry inside the section; a failed *refresh* that still has
  rows keeps showing them.

Independence falls out of this for free: the sections share no state, so
one failing cannot blank the other, and neither has to know the other
exists. A later section (Recently added, Favorites) is a new cubit or a
new `BlocBuilder` and one entry in Home's child list — the same shape.

`RecentlyPlayedCubit` deliberately does **not** filter for offline
playability or apply the downloads-only scope. That is a presentation
concern that depends on `OfflineCubit`, `SettingsCubit` and
`DownloadsCubit` — all already watched at the widget layer, exactly as
`LibraryPage` marks availability there. Keeping it out of the cubit
leaves the cubit a pure history read, and keeps the offline rules in one
place per screen.

## Decision: offline shows the part that plays, and says so

Per `OfflineLibraryScope`:

- **Full library scope (the default).** Every recently-played row and the
  Continue listening card stay visible; a context whose audio is not on
  the device is dimmed, made non-interactive, and labelled ("Not
  playable offline" / "Not available offline"). This is the
  `CONTEXT.md` rule — never show an empty list and let the user conclude
  they have nothing.
- **Downloads-only scope.** A row that cannot play is removed, not
  dimmed — the scope's whole point is to show only what works. Continue
  listening is absent when the queue's current track is not downloaded,
  rather than a resume button that reaches only silence.

"Playable offline" is: for an album or artist context, at least one
track of it is downloaded (`CollectionDownloadStatus.completed > 0`); for
a track context, that track is downloaded.

## Decision: a `track` context row plays; it does not navigate

Listening history records three context kinds (ADR-0025): `album`,
`artist`, `track`. Album and artist rows navigate into the Library
branch (`go` to `/library/album/:id` etc. — the detail screens already
exist and already handle their own offline state). There is no track
detail screen, and a single played on its own is only useful as
something to hear again, so a `track` row resolves the `Track` through
`MediaMetadataRepository` and plays it. Offline that resolves from the
local copy where there is one and otherwise fails into a "can't play
that right now" notice.

## Decision: the strip refreshes when a new track starts

Home lives in a keep-alive shell branch, so it is not rebuilt when the
user returns to the tab. Rather than a route observer or a lifecycle
hook, Home listens to `PlaybackCubit` and calls
`RecentlyPlayedCubit.refresh()` whenever the current entry's id changes.
Playing anything warms the strip in the background, so it is current by
the time the user comes back. `refresh()` is one indexed local read.

## What this defers

ADR-0025 forecast that v0.3.2 would add a "queue origin" so a playlist
played straight through becomes a `playlist` history context. It does
not: a queue origin is a schema migration plus a change to every
`playNow` call site — a new subsystem, which the arc's preamble rules
out of a section. A playlist still collapses to its album(s) in history,
which ADR-0025 already calls "a reasonable answer, not a wrong one".
Whichever later version genuinely needs playlist attribution takes the
origin on.

Also still deferred: a modular or user-reorderable Home (`OUTLOOK.md`
§9). Strong defaults first.

## Consequences

- `PlaybackCubit` gains `resume()` and nothing else; Continue listening
  is pure presentation over existing state.
- One new feature cubit (`RecentlyPlayedCubit`), no new domain contract,
  no schema change.
- Home is now the app's first meaningful screen. The "Browse music"
  button survives only in the empty-Home state; otherwise the Library is
  reached by its bottom-nav tab.
- The section pattern — independent widget or cubit, offline rules at the
  widget layer, one line in Home's child list — is what v0.3.3–v0.3.5
  extend.
