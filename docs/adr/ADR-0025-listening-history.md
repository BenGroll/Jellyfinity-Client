# ADR-0025: Listening history

## Status

Accepted

## Context

`Roadmap to v0.4.md` v0.3.1 opens the Home arc by recording what this
profile actually listened to, so v0.3.2's "Recently played" and later
sections have something to show. Nothing displays history in this
release; the deliverable is that Jellyfinity durably and correctly
*knows*.

Three questions had to be settled, and the roadmap names all three:
where history comes from, what counts as "listened to", and how the same
album played twelve times in a row stays one line.

## Decision: history is recorded locally, not derived from the server

Jellyfin already keeps `UserData.LastPlayedDate` and a play count per
item, and Jellyfinity already reports playback sessions to it (v0.0.9).
Server-derived history would need no new table. It was still rejected:

- **Offline.** A downloaded album played on a plane is listening. Server
  history cannot be read with the server unreachable, and cannot be
  *written* either — so the one place Jellyfinity would forget what
  offline is would be the feature whose whole job is remembering.
- **Large-library cost.** Turning `LastPlayedDate` into a "recently
  played" list means querying the library sorted by it and filtering to
  recently-touched items — a query against the 130k-song scale
  `CONTEXT.md` treats as normal, run on the app's most-opened screen.
  Locally recorded history is a bounded local table read in one indexed
  scan.
- **It is Jellyfinity's own.** Local history is exact (it records what
  the player actually played, not what a heuristic on the server
  inferred) and it is never a network round trip.

So history is a local table, written by `PlaybackCubit` — the one place
that already sees both the queue and the engine, and already reports
sessions to the server.

## Decision: an entry is a *context*, and repetition collapses at the write

`listening_history_entries` (schema v7) holds **one row per context** —
an album, an artist, or (for a song played on its own) the track — keyed
by `(account_key, server_id, context_kind, context_item_id)`. A
qualifying play bumps the matching row's `play_count` and
`last_played_at_ms`, or inserts a new row. Playing an album straight
through therefore produces one row with `play_count` 12, not twelve
rows; returning to an album a week later moves its existing row back to
the front rather than adding a second.

This is collapse "at the source" (the roadmap offered source or read).
It is cleaner than collapsing at the read because the stored shape is
already the shape "recently played" wants — a list of distinct things
the user returned to, newest by `last_played_at_ms` — so the read is a
plain ordered scan with no post-processing, and the bound is a row count
rather than a guess about how many raw plays collapse into a useful
list.

The context of a play is derived from the queue entry: its album if it
has one, else its primary artist, else the track itself. Playlists are
**not** a context here — the queue does not record what a track was
played *from*, only what it is. Attributing plays to a playlist needs a
queue origin, which v0.3.2 introduces with "Continue listening"; until
then a playlist played straight through collapses by its album(s), which
is a reasonable answer, not a wrong one.

### The queue snapshot gained two ids

`QueueEntry` and `queue_entries` carried `album_name` but no `album_id`
and no artist ids, so a queued track could be named but not opened. v0.3.1
adds `album_item_id` and `artists_json` (both nullable, the frozen-
`CREATE TABLE` + `TableMigration` pattern ADR-0023 established). History
attribution needs them, and so does the queue screen; a pre-v7 row keeps
its data with both null.

## Decision: the play threshold is 20 s or half the track or completion

A play is recorded once `PlaybackCubit` has seen **20 seconds** of
playback position for the entry, **or** a position past **50%** of a
track whose length is known, **or** the engine reporting the track
finished on its own. Whichever comes first; an entry the engine marked
unavailable is never recorded.

- The 50% fraction is the main rule and matches how scrobbling has always
  worked. The 20 s floor catches a long track skipped after a verse.
- **Crossfade** (ADR-0016) hands control to the next source up to 12 s
  before the outgoing track's end. That still leaves the outgoing
  position well past 50% for any track longer than about 25 seconds, and
  a track shorter than that has a proportionally shorter overlap, so the
  fraction rule composes with crossfade with no special case. Natural
  gapless advancement reports a position at or near the track's full
  length, which also clears the bar.
- A track **resumed** from a saved queue starts its threshold count from
  zero this session: the part heard last time was already recorded then
  (or deliberately was not), and crediting it again on resume would be
  double-counting.

Accrual is by furthest position observed, evaluated when the current
entry changes (a skip, a gapless or crossfade advance), when the track
completes, and when the cubit closes (the app going away mid-track is
still a play if enough of it was heard).

## Decision: bounded at 100 contexts per profile, evict oldest-played

`CONTEXT.md` forbids unbounded local growth and "a year of listening is
not a useful list". The store keeps at most **100** context rows per
profile. Each `record` that inserts a *new* context trims the profile
back to the cap by deleting the rows with the oldest `last_played_at_ms`;
a `record` that only bumps an existing row cannot grow the count, so it
never evicts anything. A hundred distinct albums, artists and singles is
a deep "recently played" and a hard ceiling regardless of play volume.

## Decision: scoped to the signed-in profile, like downloads

Every row carries an `account_key` (`server_id/user_id`) in its primary
key, and `DriftListeningHistoryRepository` reads it from
`JellyfinSessionContext` and filters every read and write to it — the
exact seam and shape `DriftDownloadStore` uses (ADR-0023). One profile's
listening never appears under another's, and with nobody signed in a
read is empty and `record` is a no-op. No sign-out cleanup is needed:
scoping alone means a signed-out or switched profile sees nothing.

## Decision

- `lib/domain/media/` — `ListeningContext` (+ `ListeningContextKind`),
  `ListeningHistoryEntry`, `ListeningHistoryRepository` (+ `ListeningPlay`).
- `lib/infrastructure/persistence/media/DriftListeningHistoryRepository.dart`
  over `listening_history_entries` (schema v7), account-scoped and
  bounded.
- `AppDatabase` schema v7: the new table, plus `queue_entries` gaining
  `artists_json` and `album_item_id`. The v2→v3 step now issues a frozen
  `CREATE TABLE queue_entries`.
- `QueueEntry` gains `albumId` and `artists`; `DriftQueueRepository`
  persists and restores them.
- `PlaybackCubit` gains a `ListeningHistoryRepository` and records a play
  at the threshold above, deriving the context from the queue entry.

## Tests

- `drift_listening_history_repository_test` — first play, album collapse
  into one entry, return-visit reordering, a backwards clock, the
  100-entry bound and its eviction, a bump never evicting, profile
  isolation, signed-out no-op, album vs track contexts, `recent` limit
  and order.
- `playback_cubit_test` — a two-second skip not recorded, the 20 s floor,
  the 50% fraction both ways, completion always recording, a downloaded
  (`localOnly`) track recorded, an unavailable entry never recorded, an
  album played through collapsing to one entry, a no-album single as a
  track context, and a resumed queue crediting only the fresh session.
- `drift_queue_repository_test` — the album and artist ids surviving the
  round trip.
- `app_database_migration_test` — v6→v7 additive, and a queued track
  surviving the widening with the new columns null; the intermediate
  checks now validate at HEAD, as ADR-0023 already required for v6.

## Consequences

- A new local table that grows to at most 100 rows per profile and is
  never transmitted anywhere. It is a convenience for showing the user
  their own activity — not analytics — and no version in this arc may
  make it so.
- `PlaybackCubit` gains one dependency and a small amount of
  position-tracking state; the engine, queue, crossfade and normalization
  learn nothing new.
- Playlists are not yet a history context; v0.3.2's queue origin work is
  what adds them.
- Schema v7. `queue_entries` is the second existing table to be widened
  by a migration; the frozen-`CREATE` treatment now covers it too.
