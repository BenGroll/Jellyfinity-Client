# ADR-0031: Music listening perfection

## Status

Accepted

## Context

`Roadmap to v0.5md`'s "Music Listening Perfection" (v0.4.1) is the first
release in this arc that adds no new place to go. Everything it names —
entry points, the queue, source transitions, the playback features
layered on top, and reporting — already exists. What it asks is that they
agree with one another, and with what the listener was told.

The audit found five things that did not.

1. **The queue screen did not show the queue.** `QueuePage` listed
   `queue.entries` — the user's own order — while playback followed
   `shuffleOrder`. With shuffle on, the list labelled "up next" was not
   what came next. `PlaybackQueue.upNext` already computed the right
   answer and nothing rendered it.
2. **Every structural edit reshuffled.** `_rebuilt` regenerated the whole
   permutation on add, remove and reorder. Adding one track re-ordered
   everything the listener had not heard yet, and "play next" landed the
   track wherever the fresh permutation happened to put it — so the one
   action whose entire meaning is a position did not have one.
3. **A restart was a different queue.** `shuffleOrder` was never
   persisted; `DriftQueueRepository.load` called `withShuffle(true)`,
   which generates a new random order. `normalizationGain` had no column
   at all, so volume normalization (v0.1.4) silently stopped applying to
   every restored queue.
4. **Failures did not explain themselves.** `PlaybackUiState.lastFailure`
   was set and consumed by nothing outside a test. A failed entry greyed
   out with no reason and no way to try again. `_consecutiveFailures` was
   cleared only by an engine-driven index change, so a queue recovered by
   a manual skip carried its old failures towards the give-up cap.
5. **Jellyfin was not told about manually started tracks.**
   `reportStart` fired only from `_onEngineIndexChanged`, which returns
   early whenever `PlaybackCubit` has already moved the index — which is
   every `playNow`, every skip, and every tap on a queue row.
   `reportStop` fired only on natural completion, and `reportProgress`
   was implemented and never called at all.

## Decision: play order is a first-class thing the UI reads

`PlaybackQueue` gains `upNextIndices`, `currentPlayPosition` and
`isAtEndOfPlayOrder`, and `QueueEditor` renders `playOrder` rather than
`entries`. Each row now carries two positions: its play position (where
it sits on screen, and what a drag moves) and its entries index (what
`PlaybackCubit` names it by). Rows are keyed by both, because the same
track can legitimately sit in a queue twice and two identical `ValueKey`s
make a reorder move the wrong row.

Reordering therefore needed to mean two different things, and both are
kept rather than conflated:

- `withReordered` moves an entry in the user's own list and **remaps
  `shuffleOrder` so play order is unchanged**. Rearranging your list is
  not a statement about what plays next.
- `withPlayOrderReordered` moves an entry within play order, touching
  only `shuffleOrder` when shuffle is on and delegating to
  `withReordered` when it is off — because then the two orders are the
  same thing. The queue screen calls this one.

## Decision: only the shuffle button reshuffles

Every structural edit now *amends* `shuffleOrder` instead of regenerating
it:

- adding shifts the indices at or past the insertion point and inserts
  the new one at the right **play** position — directly after the current
  entry for "play next", at the end otherwise;
- removing drops the index and shifts the rest down;
- reordering remaps through an old-index-to-new-index function.

`_with` validates the result and falls back to a fresh shuffle if a
caller could not produce a valid permutation, so a bug here degrades to
the old behavior rather than to a play order that skips or repeats an
entry.

This is what makes "play next" mean what it says under shuffle, and it is
the difference between a queue that a listener can shape and one that
rearranges itself whenever it is touched.

## Decision: schema v9 carries the two things a restart was losing

`queue_entries` gains `normalization_gain` and `failure_message`, both
nullable and additive. The shuffled play order rides `KeyValueStore` as
comma-separated indices, alongside the current index, shuffle flag and
repeat mode: it is one value about the queue as a whole, not a property
of any entry, and writing it costs nothing next to rewriting every row.

A restored order is accepted only when it is a genuine permutation of the
saved rows — `PlaybackQueue.withRestoredShuffleOrder` refuses anything
else and leaves the fresh shuffle `withShuffle` already generated. A
truncated, corrupt or stale value therefore costs the listener their
up-next order, which is the old behavior, rather than a play order that
skips entries.

One migration hazard is worth recording, because it is not obvious and it
broke every pre-v7 upgrade path when v9 was added: drift's `alterTable`
recreates a table from its **current** definition and copies everything
not listed in `newColumns`. The v7 step therefore has to declare v9's
columns too, or a v1-to-v9 upgrade asks a v6 database for a column that
did not exist for another two versions. The v7 step now names all four,
producing the fully widened row in one pass, and the v9 step is guarded
to `from >= 7` so an install coming through v7 does not redo it. This is
the `alterTable` counterpart of the frozen `CREATE TABLE` strings
ADR-0010's forward-only policy already required.

## Decision: a failed entry says why, and a retry is a tap

`QueueEntry` gains `failureMessage`, set from the `PlaybackFailure` that
marked it and persisted with it. "Unavailable" is a state, not an
explanation: a dead stream, an undecodable file and a download deleted
since it was queued are three different problems with three different
things a listener can do. The queue row shows the reason and "Tap to try
again", and stays tappable while online — trying again *is* the action.
Offline with no local file is the one case where the row is genuinely
inert, and it says that instead.

Recovery is symmetrical. `markPlayable` clears the mark and the message,
and `_onStatus` applies it the moment the engine reports it is playing,
along with clearing `lastFailure` and resetting `_consecutiveFailures`.
A queue that has recovered must stop insisting it is broken.

## Decision: one retry per entry, by re-resolving

ADR-0015 gave a failed entry one retry at `StreamQuality.original`, but
only when it had failed at a transcoded quality — the reasoning being
that `just_audio` cannot tell a transient transcode failure from a dead
track. That reasoning generalizes: an address can go stale for reasons
that have nothing to do with transcoding. A download can complete or be
deleted while its track sits in the queue, and `_resolvedSources` caches
the answer `LocalFirstAudioSourceResolver` gave at load time.

So the retry now applies to every current-entry failure, and it drops the
cached addresses for that id first, which is what makes re-resolving
meaningful: a removed download falls back to the stream, and a newly
downloaded track stops streaming. The original-quality pin remains
exactly as ADR-0015 set it, for the case it was written for. A second
failure falls through to mark-unavailable-and-advance, unchanged.

This is a deliberate behavior change to ADR-0015's boundary, and its
tests were updated to state the new rule rather than the old one.

## Decision: playing means an open Jellyfin session

Every path that changes which entry is playing goes through one
`_beginEntry`, which closes the previous session and opens the new one:
`playNow`, a manual skip, a tap on a queue row, an engine-driven advance,
a repeat-one loop. `_onStatus` covers the one path that chooses nothing —
pressing play on the queue `restore` primed at launch, which is exactly
how Home's "Continue listening" (ADR-0026) starts.

The position-save tick, which already ran every five seconds while a
track played, now also calls `reportProgress`; pausing reports the
session as paused rather than ending it, since Jellyfin shows a paused
session rather than dropping it. Emptying the queue and closing the cubit
close the session.

## Decision: an unavailable feature says so, in place

`_PlaybackNotes` sits under Now Playing's existing source/quality row and
states the conditions that were previously silent:

- a downloaded file is played as the file it already is, so the streaming
  quality preference does not apply to it;
- normalization is on but this server produced no loudness data for this
  track;
- crossfade is paused because repeat-one means there is no next track to
  fade into.

Each note appears only when its condition holds, and the whole row
disappears when there is nothing to say. A feature that quietly does
nothing reads to a listener as a feature that does not work.

## Decision: collection headers offer the same four actions a row does

`MediaPlaybackActionsRow` gains "Play next" beside "Add to queue", backed
by `PlaybackCubit.playNextAll`. Play and Shuffle were already buttons;
Play next was the one action an album, artist, playlist or Favorites
header could not do. It inserts the tracks in their own order directly
after the current entry — reversed insertion when something is playing,
forward when the queue is empty and each insertion simply appends.

`playShuffled` no longer calls `toggleShuffle` first. That was a queue
edit: it reshuffled, re-persisted and re-loaded the queue being replaced,
half a frame before it was thrown away. Shuffle is now part of building
the new queue.

## Tests

- `playback_queue_test` — a fixed shuffle order (via
  `withRestoredShuffleOrder`) makes every edit's effect on play order
  assertable rather than a matter of chance: add-to-end, play-next,
  remove, list reorder, play-order reorder, and the permutation
  validation. Plus `upNextIndices`, `currentPlayPosition` and
  `isAtEndOfPlayOrder` under each repeat mode.
- `playback_cubit_test` — `playNextAll` ordering with and without a
  current entry, play-next under shuffle leaving the rest of the order
  alone, `playShuffled` not re-loading the outgoing queue, the re-resolve
  retry and its recovery, an entry that plays after failing dropping its
  mark, and session reporting for manual start, skip, queue tap, resume
  after restore, pause, and clear.
- `drift_queue_repository_test` — the play order, loudness gain and
  failure message each surviving a restart, and a saved order that no
  longer fits its rows being discarded.
- `app_database_migration_test` — every path now validates at schema v9.
- `playback_ui_test` — the queue listing in play order, the end-of-queue
  note appearing and disappearing with repeat, a failed row explaining
  itself, the three honesty notes, and a **mouse** drag reordering the
  queue for Windows.
- `music_navigation_test` — the album header's Play next.

Android and Windows: the queue's reorder affordance is the drag handle,
driven by touch on Android and by pointer on Windows (covered by the
mouse-drag test above); no interaction added here is exclusive to either.
Background and media-session behavior is unchanged — this release adds no
engine call — so `integration_test/windows_platform_test.dart` continues
to cover it. On-device acceptance of the new reporting against a live
Jellyfin server is a manual check, the same treatment ADR-0013 gave
gapless playback.

## Consequences

- The queue screen answers "what plays next" correctly for the first
  time under shuffle, and survives a restart saying the same thing.
- Volume normalization works on a restored queue. It did not before, on
  any install, since v0.1.4.
- Jellyfin sees sessions for manually started tracks, and live positions
  while they play.
- ADR-0015's retry rule is widened; its narrower form is superseded here.
- Schema v9. Forward-only, additive, no data loss.
- The queue's own order and its play order are now genuinely two things
  the UI can move independently. The v0.4.2 playlist reorder ADR-0024
  deferred is a different problem — absolute server indices — and is
  untouched by this.
