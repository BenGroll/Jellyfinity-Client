# ADR-0018: Lyrics

## Status

Accepted

## Context

`Roadmap to v0.2.md`'s v0.1.5 asks for a lyrics view reachable from Now
Playing, with its first required step being to verify what lyrics Jellyfin
10.11.6+ exposes and what a real library actually contains before choosing
between plain and synchronized presentation.

Jellyfin's server exposes a dedicated endpoint, `GET
/Audio/{itemId}/Lyrics`, returning a `LyricDto` whose `Lyrics` array holds
one entry per line: `Text`, plus an optional `Start` (100-nanosecond ticks,
the same unit every other timestamp in this codebase already uses). `Start`
is present when the source lyrics file carries timing (an `.lrc` file) and
absent for a plain-text lyrics file — the two cases the roadmap
distinguishes are really one endpoint whose response shape varies per
track. The server answers 404 both when a track has no lyrics file and
when the item itself does not exist; either way there is nothing to show.
This is stable, documented server behavior, not something a client
negotiates.

What this ADR could **not** verify is which of the two shapes a real,
populated Jellyfin library actually returns for its tracks — doing so
needs a live server with a real music collection, which was not reachable
from the environment this version was implemented in. The decision below
is deliberately built to not need that answer in advance.

## Options Considered

### Choosing plain vs. synchronized ahead of time

**Decide once, hardcode the presentation** (rejected). The roadmap's
instruction to "verify... before choosing" reads as picking a single
answer for the whole app. That is fragile in practice: a library is not
uniformly tagged — some tracks may carry `.lrc` lyrics, most will not (or
will have none at all) — so a single hardcoded choice would either show
broken timing on untimed tracks or never light up synchronized scrolling
on tracks that do have it.

**Decide per response, from the data itself** (chosen). Since `Start` is
already optional per line in Jellyfin's own schema, whether a given
track's lyrics are trustworthy for synchronized scrolling is answered by
the response itself: synchronized only when *every* line carries a
`Start` and the values are non-decreasing (`BaseItemMapper.toLyrics`
computes `Lyrics.isSynchronized`); otherwise the view falls back to plain
lyrics for that track. This satisfies "half-working synchronization must
not ship" (a track with partial or backwards timing degrades cleanly to
plain rather than jittering or standing still) without requiring advance
knowledge of what any specific library contains, and it also means the
same code path is already correct once real usage against a live server
confirms which shape is common.

### Modeling "no lyrics" as data, not failure

Jellyfin's 404 is normalized by `TransportErrorMapper` to
`UnavailableFailure` everywhere else in the transport layer. For lyrics
specifically, `JellyfinMediaApi.lyrics()` folds that one failure back into
`Ok(null)` before it reaches the resolver, so `LyricsResolver.resolve`
returns `Result<Lyrics?>` — `Ok(null)` for "no lyrics," `Err` reserved for
a request that could not be answered at all (signed out, wrong server,
offline, a real server error). This keeps the roadmap's "missing lyrics is
an empty state, not an error" a property of the domain contract itself
rather than something every caller has to remember to special-case.

Rejected: treating every 404 as `Err(UnavailableFailure)` and having the
cubit/view treat that specific failure type as empty. That would work, but
it would make "no lyrics" indistinguishable from "the track was removed
from the library" at the type level, and would need the same
special-casing duplicated in the cubit or view instead of once, close to
where the transport detail is known.

### Where lyrics fetching lives

Same on-demand, one-track-at-a-time shape as `TrackSourceInfoResolver`
(ADR-0015): a `LyricsResolver` domain contract, a `JellyfinLyricsResolver`
infrastructure implementation calling `JellyfinMediaApi.lyrics`, and a
page-scoped `LyricsCubit` opened by the Lyrics view for whichever track is
current — not folded into `MusicLibraryRepository` or made part of
`Track`, since nothing browses by lyrics and no list view needs them.

## Decision

- `lib/domain/playback/Lyrics.dart` — `LyricLine` (`text`, optional
  `start`) and `Lyrics` (`lines`, `isSynchronized`).
- `lib/domain/playback/LyricsResolver.dart` — `resolve(MediaId) ->
  Result<Lyrics?>`, `Ok(null)` meaning no lyrics.
- `JellyfinMediaApi.lyrics()` — calls `/Audio/{itemId}/Lyrics`, folding a
  404 (`UnavailableFailure`) into `Ok(null)` and propagating every other
  failure.
- `BaseItemMapper.toLyrics` — maps `LyricsDto` to `Lyrics`, drops blank
  lines, and computes `isSynchronized` (every line timed, timestamps
  non-decreasing).
- `JellyfinLyricsResolver` — the `LyricsResolver` implementation, same
  scope/fetch/map shape as `JellyfinTrackSourceInfoResolver`.
- `LyricsCubit` — page-scoped state (`lyrics`, `failure`, `isLoading`),
  mirroring `TrackSourceInfoCubit`, plus a `retry()` for the error state's
  "Try again" action.
- `LyricsPage` — a child route of Now Playing (`/now-playing/lyrics`),
  reached via a new lyrics button in `NowPlayingPage`'s app bar. Renders a
  loading skeleton, `ErrorStateView.forFailure` with retry, an
  `EmptyStateView` for no lyrics, plain centered lines, or — when
  `isSynchronized` — the current line highlighted and scrolled into view
  against `PlaybackUiState.position`.

## Tests

- `base_item_mapper_test` (`toLyrics` group) — plain lines, synchronized
  detection, the zero-timestamp-is-not-missing edge case, falling back to
  plain for partial or backwards timing, blank-line dropping, and the
  no-usable-lines/null cases.
- `jellyfin_lyrics_resolver_test` — the same behaviors through the
  transport layer, plus the 404-to-`Ok(null)` fold, a real failure
  propagating instead, cross-server rejection, and the signed-out case.
- `playback_ui_test` (`lyrics (v0.1.5)` group) — plain lyrics rendering,
  the empty state, a retryable error recovering, and synchronized
  highlighting changing as playback position advances.

## Consequences

- Plain and synchronized presentation coexist per track rather than being
  an app-wide setting; a library with mixed lyrics sources gets the right
  behavior for each track without configuration.
- Whether synchronized scrolling is ever seen in practice depends on
  whether the operator's library actually has `.lrc`-style lyrics files;
  this was not verified against a live server as part of this version, so
  the plain path is the one guaranteed to be exercised on every server
  today, and the synchronized path should be checked against a real
  library before release.
- No new minimum server version: the lyrics endpoint has been part of
  Jellyfin's API for longer than Jellyfinity's 10.11.6 floor.
- The Lyrics view adds one more on-demand, per-track network request,
  made only when a user opens it — never as part of browsing or of Now
  Playing's default render.
