# ADR-0030: Offline music completion, finished

## Status

Accepted

## Context

`Roadmap to v0.3.md`'s v0.3.0 ("Offline music completion") shipped its
hardening half — the download-lifecycle bug fixes, CI, release hygiene —
and, folded in, the playlist curation v0.1.2 left unfinished (ADR-0024).
Its **feature** deliverables were listed as still outstanding, in
`ROADMAP.md` and at the tail of the v0.3.0 changelog entry:

1. **The entry-point audit.** Now Playing, the queue and the mini-player
   carry no download or offline state; inline search has no download
   action.
2. **Batch retry and batch removal** on the Downloads screen.
3. **Rendering `MediaAvailability.localOnly` as "Only on this device"** —
   v0.2.3 tracked the state (`TrackDownload.serverGone`) and promised the
   label; no widget ever drew it.
4. **Reclaiming downloaded files when an account or server is removed** —
   today the records and files stay on disk, naming an identity the app
   no longer has.

v0.3.6 is those four, and nothing else. It is one version because it is
one promise — "offline you can trust for travel" — finished, not four
unrelated features. The Home arc's own deferrals (playlist history
context, the offline favorite heart, playlist reorder) each keep their
own later version and their own ADR.

## Decision: `localOnly` is one line in the shared subtitle

`_MusicRow` already receives `MediaAvailability`. When it is
`localOnly`, `TrackRow` appends **"Only on this device"** to the row's
subtitle via the same `joinDetails` list that already joins artist and
album — "Miles Davis · Kind of Blue · Only on this device". No new
widget, no third line to overflow a fixed-height row, and it appears
everywhere `TrackRow` is used the moment a record's `serverGone` flag is
set: the Downloads screen (which builds rows from `record.toTrack()`),
an offline album page, search. Now Playing's `_SourceQualityRow` is left
alone — it already reports which quality is playing, and a downloaded
track there reads as on-device implicitly.

## Decision: the entry-point audit reuses the existing controls, marks rather than hides

- **Now Playing** gains a `TrackDownloadButton` in its top bar, beside
  the heart. "Keep this on my device" is a thought a person has while
  looking at the player; the control that shows the state and *is* the
  action is the same one every track row carries.
- **Inline search** song rows gain `downloadAction: TrackDownloadButton`
  — the full search results page (`SearchCategoryPage`) already had it;
  only the inline overlay was missing it.
- **The queue** and the **mini-player** get a read-only signal, not a
  management control: a `DownloadedMarker` when the track is on the
  device, and — offline, with no downloaded copy — the row dims and reads
  **"Not available offline"** rather than vanishing. Downloading is done
  from the library or the player, not from a transient queue; the queue's
  job here is only to be honest about what will actually play. This is
  the `CONTEXT.md` "never let the user conclude they have nothing" rule
  and the same treatment `TrackRow` already gives an unplayable library
  row.
- `QueueEntry` gained a `toTrack()` (the inverse of its existing
  `fromTrack`) so the queue and Now Playing can hand the download control
  a `Track` without a lookup.

## Decision: batch actions live in the Downloads screen's app-bar menu

Two actions only make sense across the whole screen rather than one
collection at a time, so they belong in an overflow menu, not on a tile:

- **"Retry failed downloads"** — `DownloadsCubit.retryFailedDownloads()`,
  a screen-wide `retryAll` keyed on nothing. Shown only when something is
  actually failed or paused. This is the one-tap recovery after a spell
  offline left several collections part-finished.
- **"Remove all downloads"** — `DownloadsCubit.removeAllDownloads()`,
  behind the same `confirmRemoveDownload` dialog every other removal
  uses, naming the song count and the bytes freed and repeating that
  nothing changes on the server and no playlist loses a track there.

Per-collection retry/remove (the tile menus, the header buttons) are
unchanged.

## Decision: reclamation lives in `SessionCubit`, not `AuthSessionManager`

The natural home is `AuthSessionManager.removeAccount` / `removeServer`,
right beside the existing `_mediaCache.clearServer(serverId)` call. But
`DownloadStore`'s implementation (`DriftDownloadStore`) reads
`JellyfinSessionContext`, and that context (`SessionJellyfinContext`)
reads `AuthSessionManager` — injecting the store into the manager is a
DI cycle, and `injectable`'s topological sort stack-overflows on it.

So:

- `AuthSessionManager.removeAccount` now **returns the removed
  `JellyfinAccount`** (it already looked it up); `removeServer` is
  unchanged (the caller knows the server id).
- `SessionCubit` gains `DownloadStore` + `DownloadStorage` and does the
  reclamation after the manager call. Nothing in that dependency chain
  points back to `SessionCubit`, so it is acyclic. `SessionCubit` is
  already the one place every top-level session transition goes through,
  which is where a "and also forget this identity's local data" step
  belongs.

## Decision: two purge methods, because the file is shared per server

`DownloadStorage` keys a download's directory by **server + item**, not
by account — two profiles on one server that both downloaded a track
share the one file. So:

- **`DownloadStore.purgeProfile({serverId, userId})`** deletes that
  account key's rows across all four download tables and **returns the
  ids no surviving profile still keeps**. `SessionCubit` then
  `DownloadStorage.discard`s each of those and no others.
- **`DownloadStore.purgeServer(serverId)`** deletes every row for the
  server outright, and `DownloadStorage.discardServer(serverId)` deletes
  every `<serverId>_*` directory — no reference counting, because every
  profile on the server is being removed with it.

A failure in either is logged, not surfaced: the profile or server is
already gone from the user's point of view, and a stranded file is a
storage nuisance, not a correctness bug worth a dialog.

## Consequences

- **No schema change.** The four download tables already carry
  `account_key` and `server_id`; the purge methods are new queries over
  columns that exist.
- `DownloadStore` gains two methods; `DownloadStorage` gains
  `discardServer`; `DownloadsCubit` gains two batch methods; `QueueEntry`
  gains `toTrack()`; `AuthSessionManager.removeAccount`'s return type
  widens from `void` to `JellyfinAccount?`; `SessionCubit`'s constructor
  gains two dependencies.
- `PagedCollectionView` is untouched. The presentation changes are
  additive — a subtitle segment, a marker, a control in a slot that was
  already optional.
- v0.3.0's "Done when" is now met, and `ROADMAP.md` marks it
  **Implemented**.
