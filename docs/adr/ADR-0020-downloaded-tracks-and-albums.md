# ADR-0020: Downloaded tracks and albums

## Status

Accepted

## Context

`Roadmap to v0.3.0md`'s v0.2.0 opens the offline-music arc: let a
listener keep individual tracks and whole albums on the device and play
them reliably without a server. Nothing in the repository did any of
this yet — no domain contracts, no download tables, no engine, no UI.
`MediaAvailability`'s own doc comment said as much: "Downloads do not
exist yet (post-v0.1.0)."

Three questions had to be settled before writing code: where downloads
sit in the architecture, how a downloaded file gets onto the device, and
how playback learns to prefer it. A fourth, forced by environment rather
than design — the roadmap requires an Android+iOS resume/cancellation
proof before adopting a background-transfer dependency, and this change
was authored in a container with neither device available.

## Decision: architecture

Downloads get their own vocabulary in `lib/domain/downloads/`, parallel
to — not folded into — `lib/domain/media/` and `lib/domain/playback/`:

- `TrackDownload` is a denormalized snapshot of one track plus its
  progress, the same shape `QueueEntry` already uses for the same
  reason: a download has to render and be queueable with the server
  unreachable, so it cannot depend on a lookup into the media cache
  (which is disposable and may never have seen the item at all — a
  track downloaded from search results was never part of a cached
  collection window).
- `DownloadOwner` / `DownloadOwnerKind` model *why* a file is being
  kept, as a set rather than a single requester. The same song can be
  wanted because it was downloaded on its own and because its album
  was. Removing one reason must not delete a file another reason still
  wants — the reference-counting `ROADMAP.md` makes explicit in v0.2.2
  is present from the first version as an owner set, so later download
  targets (a playlist, an artist) are new `DownloadOwnerKind` values,
  not a redesign.
- `DownloadStore` (durable records) and `DownloadEngine` (the transfer
  mechanism) are the two seams, mirroring `QueueRepository` and
  `PlaybackEngine`'s split between "what we mean to have" and "the thing
  that makes it true."
- `DownloadsCubit` (`lib/app/downloads/`) sits at the same architectural
  level as `PlaybackCubit`: cross-cutting application state a track row,
  an album header, and (from v0.2.2) a Downloads screen all read, rather
  than feature-owned state. It owns the *rules* — who wants a file, what
  order work happens in, what a failure means, one transfer at a time —
  while `DownloadEngine` owns only the mechanism.
- `LocalFirstAudioSourceResolver` decorates the existing
  `AudioSourceResolver` rather than changing `PlaybackCubit`: preferring
  a local file is what "downloaded" *means*, not a playback rule, so the
  queue, crossfade, normalization, and failure handling stay exactly as
  ADR-0013/0016/0017 left them. The Jellyfin-backed resolver is
  registered under the injectable name `remoteAudioSourceResolver`
  (declared on the domain contract, so infrastructure does not import
  `lib/app`) and the decorator becomes the unnamed, default
  `AudioSourceResolver` — everything that just wants to play a track
  keeps asking for the bare contract; only the download engine itself
  asks for the named, always-remote one.

## Decision: storage layout

Downloaded audio lives under the platform's **application support**
directory (`path_provider`'s `getApplicationSupportDirectory`), not the
caches directory `flutter_cache_manager` uses for artwork. `CONTEXT.md`
is explicit that downloaded media is first-class local media, not
disposable cache; the OS is free to reclaim a caches directory under
storage pressure, which would silently break the "still playable on a
flight" promise the whole feature exists for.

Each track gets its own directory, `<server id>_<item id>/`, holding at
most `audio.part` (in flight) or `audio.<extension>` (finished).
Completion is a rename of `audio.part` to its final name — atomic on
both platforms, and what makes `DownloadStorage.completedFile` either
see nothing or the whole file, never a half-written one under the
finished name. Removing a download is one recursive directory delete
that cannot leave a stray partial behind. The extension comes from the
response's content type when the server gives one, so iOS's
AVFoundation (which leans on it to pick a decoder) gets something
useful; Android's ExoPlayer sniffs the container either way.

## Decision: the transfer engine (and the resume-proof gap)

**`HttpDownloadEngine`: a foreground `dio`-based engine with HTTP Range
resume, run while the app process is alive** (chosen for v0.2.0).

`ROADMAP.md`'s "Decisions to settle during implementation" section
requires selecting the background-transfer implementation only after an
Android+iOS resume/cancellation proof of behavior, and allows "a
documented foreground-only implementation" when that proof cannot be
produced, provided it "still delivers a safe, useful download flow."
This implementation was authored in a Linux container with no Android or
iOS device available, so that proof cannot be produced here — the
documented-foreground-only path is the one the roadmap itself names for
exactly this situation.

`HttpDownloadEngine` still satisfies every behavioral requirement the
roadmap lists for the seam:

- **Resume**: a transfer appends to `audio.part` and asks for the rest
  with a `Range: bytes=<offset>-` header. If the server ignores the
  range and answers `200` instead of `206`, the partial file is
  discarded and the transfer restarts from zero rather than risking a
  duplicated prefix (which would produce a file that *looks* complete
  and plays as noise).
- **Cancellation**: `abort` cancels the in-flight `dio` request via a
  `CancelToken` and keeps the partial file; `discard` cancels and then
  deletes everything.
- **Atomic completion**: see storage layout above.
- **Stale-session failure and partial cleanup**: a transport failure or
  a filesystem error both come back as a typed `Result`, never a thrown
  exception (ADR-0004); the partial file is left exactly where the
  failure occurred, ready to resume.
- **Restart recovery**: `DownloadsCubit.restore()` treats any record
  still marked `downloading` after a fresh process start as
  interrupted — there is no transfer actually running in a new
  process — and requeues it, re-reading the partial byte count from
  disk so its progress does not reset to zero.

What it does **not** do is keep transferring once the OS suspends or
kills the app in the background — the gap the roadmap's escape hatch
acknowledges. It survives that case rather than losing work (the
partial file and the database record both persist, and the transfer
resumes on next launch), but it will not finish an album unattended
while the app is backgrounded for a long stretch. Everything above the
`DownloadEngine` interface — the store, the owner model, the cubit, the
UI — is unaware of this distinction, so replacing it with a proven
platform background-transfer package later is a matter of writing a
second `DownloadEngine` and swapping the DI registration, not a
redesign.

## Decision: schema

Schema v4 (`drift_schemas/drift_schema_v4.json`) adds two tables,
additive per ADR-0010's migration policy:

- `track_downloads`: one row per requested track, keyed by
  `(server_id, item_id)` like every other media table, carrying its
  state, byte progress, and the same denormalized display fields
  `queue_entries` carries, for the same offline-rendering reason.
- `download_owners`: one row per `(track, owner kind, owner id)`,
  answering "why is this kept" and "what did downloading X ask for."
  Deliberately not a database foreign key onto `track_downloads` — like
  `saved_accounts.server_id`, the delete has to remove a file as well as
  rows, so it is orchestrated by `DownloadsCubit`/`DriftDownloadStore`
  rather than half by a cascade the code cannot see.

`DriftDownloadStore.save` rewrites a track's entire owner set inside one
transaction, so "the album no longer wants this" is a single call rather
than a separately forgettable delete.

## Decision: what a download costs at request time

Files are fetched at `StreamQuality.original` unconditionally in
v0.2.0 — `ROADMAP.md`'s own "intended safe starting point ... because it
never silently changes what a user gets." A configurable download-quality
preference, independent of the streaming one, is explicitly v0.2.2's.

## Consequences

- A downloaded track plays offline through the *existing* queue,
  crossfade, and normalization pipeline unchanged — `PlaybackCubit`
  never learns whether a source came from disk or the network.
- Downloads are strictly serial. This trades away any speed a phone's
  radio might gain from parallel transfers for a simpler mental model (a
  visible, ordered queue) and half as many partial files to recover after
  an interruption. Later versions can revisit this if measurement shows
  it costs real time on typical connections.
- `InsufficientStorageFailure` joins the core `Failure` hierarchy
  (ADR-0004) alongside `UnauthorizedFailure`/`UnsupportedServerFailure`:
  running out of device space is a distinct, expected outcome with its
  own user-facing answer ("free some up"), and folding it into
  `RecoverableFailure` would offer a retry that cannot succeed until the
  user acts.
- The v0.2.0 UI adds a track-row and album-header control (v0.2.0 has no
  standalone Downloads screen — that is v0.2.2's). An album's aggregate
  status names failed and paused tracks rather than averaging them into
  one percentage, per `CONTEXT.md`'s "never leave users guessing."
- Because the resume-proof this ADR could not produce is exactly the
  gate `ROADMAP.md` puts before adopting a background-transfer
  dependency, that evaluation remains open work for a session with real
  Android and iOS devices, tracked against v0.2.2 (which is where the
  roadmap's Wi-Fi-only and management concerns first depend on it).
