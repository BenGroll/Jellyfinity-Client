# ADR-0021: Downloadable playlists

## Status

Accepted

## Context

`Roadmap to v0.3.0md` v0.2.1 continues the offline-music arc: make a
playlist a reliable offline listening set, and keep it current when the
server is reachable. v0.2.0 (ADR-0020) already built the whole download
system — the `DownloadEngine`/`DownloadStore` seams, `DownloadsCubit`,
the owner-set reference counting, `LocalFirstAudioSourceResolver`, and
the track/album controls. A playlist row already showed the per-track
download button. What did not exist: a playlist-level download, a
`DownloadOwnerKind` for it, any record of a playlist's membership, or any
reconcile against later server-side edits.

Three questions had to be settled: how a playlist download differs from
an album download, where the ordered membership lives, and when a
downloaded playlist reconciles against the server.

## Decision: a playlist is another owner kind, plus a membership snapshot

An album download is "keep every track on this album." Its order and
membership are properties of the tracks themselves (disc/track number),
recoverable from metadata without storing anything extra. A playlist is
different on both counts: its membership is the user's arrangement, its
order is arbitrary and server-owned, and it changes independently of any
track.

So a playlist download is **two records**, not one:

- `DownloadOwnerKind.playlist` — a `download_owners` row per member
  track, exactly the same reference counting an `album` owner already
  does. "Remove this playlist" drops the playlist owner from each track;
  a file another owner (a standalone track download, another playlist)
  still wants survives. No change to `DownloadOwner`'s shape, as ADR-0020
  anticipated.
- `playlist_download_members` (schema **v5**) — the ordered membership
  *snapshot*. One row per downloadable member: `(server_id,
  playlist_item_id, position, track_item_id)`. This is the durable record
  of order, the same reason `cached_collection_entries` exists rather
  than re-sorting the metadata cache — Jellyfinity must not invent its
  own version of the user's arrangement offline.

`position` counts the playlist's *downloadable* tracks in playlist order.
A non-track entry, or one the server could not describe, has nothing to
download and takes no position in the snapshot; the browse view
(`PlaylistRepository.tracks`, unchanged) still keeps the full numbering
with those entries in place.

Schema v5 is purely additive per ADR-0010's policy: one new table,
starting empty, so an upgrading install keeps every track and album
download it had.

## Decision: offline playback falls back through the snapshot

`CachedPlaylistRepository.tracks` already served an offline playlist from
the metadata cache. That cache is disposable (ADR-0010's "temporary
cache" / "persisted metadata" — either way, evictable). A *downloaded*
playlist is not: `CONTEXT.md` calls downloaded media first-class local
media. So the fallback chain gains a final step — server → metadata cache
→ **download snapshot** — reading `playlist_download_members` and
rebuilding each track from its `TrackDownload` record. The snapshot's
answer is marked `PageSource.cache` like any other offline read, and a
member whose record has gone is skipped rather than left as a hole.

`CachedPlaylistRepository` gains a `DownloadStore` dependency for this —
infrastructure depending on a domain contract, the same direction
everything else in that layer already points.

## Decision: reconcile on explicit refresh and on opening online

`ROADMAP.md` v0.2.1 asks that a downloaded playlist be reconciled against
Jellyfin "on a user-requested refresh and when the playlist is opened
online," queuing new members, dropping the claim on removed ones (keeping
a file another download owns), and reporting what changed — while *not*
spending storage through "background auto-sync."

`DownloadsCubit.reconcilePlaylist` does exactly the diff:
`current membership − snapshot = added` (requested for download),
`snapshot − current = removed` (playlist owner released, file deleted
only if nothing else wants it), then the snapshot is rewritten to the
server's current order. It refuses to run against a `PageSource.cache`
read — reconciling against a stale copy would treat it as authoritative —
and returns a `PlaylistDownloadChange` (plain counts) the UI reports in a
dismissible SnackBar.

Both triggers are foreground and user-initiated: an explicit "Check for
changes" action in the playlist download menu, and opening a downloaded
playlist's detail screen while online (once per visit). Opening a screen
the user navigated to is not the "background auto-sync" the roadmap rules
out — that would be syncing playlists nobody is looking at, which
Jellyfinity does not do. Queuing the new members on open is the "keep it
current when the server is available" the goal states, and the download
queue is visible and serial, so it is not silent.

## Decision: what a playlist download costs at request time

Unchanged from ADR-0020: members are fetched at `StreamQuality.original`.
The configurable download-quality preference, and Wi-Fi-only gating, are
v0.2.2's — a playlist download is subject to whatever those add when they
land, with no change here.

## Consequences

- `downloadPlaylist` pages the playlist and requests each page as it
  arrives rather than accumulating the whole track list first, so its
  memory cost is one page plus the tiny member tuples. `reconcilePlaylist`
  does hold the full current membership to diff it — a playlist is a
  user-curated, bounded collection, the same assumption `downloadAlbum`
  already makes about an album; an artist, which is not bounded, gets its
  own paged treatment in v0.2.2.
- A track repeated in a playlist (Jellyfin allows it) is downloaded once
  and appears once in the snapshot, at its first position — consistent
  with "duplicate requests do not duplicate files."
- A partial snapshot (a page failed after the first succeeded) is not an
  error: the next online open reconciles it, sees the missing members as
  "added," and completes it. A removed-then-partial case cannot delete a
  file wrongly because removal only ever runs against a full server
  answer.
- The playlist header gains a download control mirroring the album's,
  differing only where a playlist must: "downloaded" is whether a
  snapshot exists (an empty or all-unavailable playlist is still
  downloaded), and the menu offers "Check for changes."
- No new engine, resolver, or playback behaviour: a downloaded playlist
  member plays through the exact v0.2.0 local-first path, and the queue,
  crossfade and normalization pipeline never learns a playlist was
  involved.
