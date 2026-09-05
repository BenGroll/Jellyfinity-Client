# ADR-0023: Offline library and recovery

## Status

Accepted

## Context

`Roadmap to v0.3.0md` v0.2.3 is the fourth release in the offline-music
arc: make downloaded music discoverable and trustworthy when the server
is unavailable or later changes. v0.2.0–v0.2.2 (ADR-0020, ADR-0021,
ADR-0022) built the engine, the owner-set reference counting, the four
owner kinds, the download-quality and Wi-Fi-only preferences, and the
Downloads screen. What did not exist: any way to find a download through
the normal library or search, any stored identity for a downloaded
collection, any isolation between two profiles on one server, any
handling of a database/file mismatch, and any warning before storage
runs out.

Five things had to be settled: what a download belongs to now that a
device can hold more than one profile's music; where a downloaded
collection's name and artwork live; how downloaded music surfaces through
the existing screens offline; how a server-side deletion is reflected
without destroying local media; and how a probe for free space fits the
existing seam conventions.

A sixth was added during implementation, at the project owner's request:
a deliberate "Work offline" switch and a preference for how much library
that shows. `CONTEXT.md` had said "offline is an item's availability
state, not a separate app mode"; this ADR revisits that (the
availability model stays — this is a convenience on top of it) and
`CONTEXT.md` and the roadmap non-goals are updated to match.

## Decision: a download belongs to one profile

Every row in `track_downloads`, `download_owners` and
`playlist_download_members` gains an `account_key` — the active server's
local id and the Jellyfin user id, joined — in its **primary key**
(schema v6, `TableMigration` on all three). `DriftDownloadStore` reads
`JellyfinSessionContext` (the same seam the media layer reads the session
through) and scopes every read and write to the signed-in profile's key;
with nobody signed in, reads are empty and writes are no-ops. A second
profile on the same server therefore keeps an entirely separate
collection, `ROADMAP.md` v0.2.3's "never expose one account's local media
to another account", and the reference counting stays correct per
profile — removing one profile's album never drops a claim another
profile's download holds.

`DownloadsCubit` subscribes to `SessionCubit` and rebuilds its catalog
whenever the active profile changes or signs out, abandoning any
in-flight transfer first so its completion cannot be written against
whichever profile is active by the time it lands.

Rows written before v0.2.3 keep their data with an empty `account_key`.
`DownloadsCubit.restore` calls `claimLegacyDownloads` once, which assigns
every unscoped row to the first profile to sign in after the upgrade —
the pre-v0.2.3 "one shared bucket" behaviour, carried forward rather than
lost. Re-adding a server that was removed mints a new local server id, so
its old download rows stay orphaned (undeleted, but unreachable); this
matches how the metadata cache already behaves and is left for a future
"reattach a re-added server" change.

### The three frozen `CREATE TABLE`s

v0.2.3 is the first release to change the shape of an existing table.
`SchemaVerifier.migrateAndValidate` runs the whole `onUpgrade` chain to
HEAD and then diffs against the target version's snapshot, tolerating
tables added later but flagging any change to a table the target already
had. So the historical `from < 4` and `from < 5` steps, which had used
the live table definitions, now issue frozen `CREATE TABLE` SQL for the
v4/v5 shapes; the `from < 6` step's `TableMigration` brings them up to
date. Every earlier migration step is now immutable, as drift's
step-by-step guidance recommends.

## Decision: a downloaded collection has its own stored identity

The new `downloaded_collections` table stores one row per downloaded
album, artist or playlist: its name, a lowercased `sort_name`, and a
flattened artwork pointer, scoped by `account_key`. It is written when
the collection is downloaded (`DownloadsCubit` has the `Album` / `Artist`
/ `Playlist` in hand) and refreshed whenever it is opened online. This
closes the gap ADR-0022 deferred: a downloaded playlist no longer shows a
generic "Downloaded playlist" label, and a collection is renderable
offline before any of its tracks have been browsed. `DownloadCatalog`
carries the identities and answers `collectionName` / `collectionImage`;
`DownloadsPage` reads them and falls back to reconstructing a name from
the track records only for a collection downloaded before v0.2.3 and not
reopened since.

## Decision: downloads surface through the existing screens, not a new one

`DownloadsLibrarySource` turns the per-track records and the collection
identities into ordinary `Page<Artist>` / `Page<Album>` / `Page<Track>` /
`Page<Playlist>` windows, marked `PageSource.cache`. It is **not** a
`MusicLibraryRepository` implementation — it answers a narrower question
and is only ever a filter or a fallback, and folding it into the contract
would force every caller to reason about a third source. Two callers
reach for it explicitly:

- The **`DownloadedFilter` mixin** on the collection cubits (and a flag on
  `MusicSearchCubit`) switches the data source; the contract is unchanged,
  so no repository or remote implementation learns about it. There is no
  manual "Downloaded" toggle in the UI yet — it was removed as redundant
  and returns with library sort/filter in a later release; today the
  filter is driven only by the offline "Downloads only" scope.
- The **offline search fallback**. A music search that fails every
  category because the server is unreachable retries against the
  downloads, and shows those results *only if they match something* — an
  offline search with no local hits still says "search needs the server"
  rather than a misleading "no matches".

`DownloadsLibrarySource.artists` and `.albums` do **not** just read the
`downloaded_collections` rows — a whole-artist or whole-album download.
They also reconstruct an artist or album from any completed **track**
download's denormalized `artists` / `albumId` / `albumName`: one kept song
is enough to make its artist and album browsable offline. The merge is in
memory, which would be wrong for the 130k-song server library but is fine
here — a profile's downloads are bounded by what the user chose to keep.

The same source answers a **single** artist / album / playlist header
(`artist(id)`, `album(id)`, `playlist(id)`) and a scoped track or album
window (`albumTracks`, `artistAlbums`). `CachedMusicLibraryRepository` and
`CachedMediaMetadataRepository` reach for these as the last step of the
cache-fallback chain — after the metadata cache misses, before returning
the failure — so an artist found only through a downloaded track opens
instead of dead-ending on a wifi error. What the downloads cannot supply
is reported, not hidden: when the caller knows the real total (a cached
album's `trackCount`, a cached discography's count, a playlist's snapshot
length) the shortfall rides back as `offlineUnavailableReason` entries in
the page's `unavailable` list, and `PagedCollectionView` collapses them
into one "N songs / albums not available offline" line — the count is
honest, a row per never-downloaded title would not be.

Normal offline browsing is unchanged: the metadata cache still serves the
collections a user has actually browsed.

Smaller surface changes go with it:

- A downloaded album, artist or playlist carries a small marker on its
  library tile/row and detail header (`DownloadedMarker`, off
  `DownloadCatalog.statusFor`).
- A downloaded track plays from a tap even where its row reads
  "unavailable" — the library, album, playlist and search track rows, and
  the Downloads screen's own song rows, gate playback on
  `catalog.isDownloaded(id)` as well as remote availability, since
  playback already resolves local-first.
- A track that genuinely cannot play — offline, never downloaded — is
  greyed out and non-interactive in place (`TrackRow.playable`), rather
  than shown identically to a playable one. This is the per-item dimming
  the `SavedCopyNotice` era had suppressed.
- The per-list "showing your saved copy" notice is gone, and so is the
  library page's separate "downloads only" line. One offline line sits
  under the shared search field for every Home/Library tab
  (`HomeLibraryHeader`); its wording switches on the "Offline library"
  scope rather than a second banner stacking under it. The search
  screen's "server unreachable" state is one line under its field rather
  than a full-page error plus a per-category failure line.

### Crossing on-/offline reloads what is on screen

`OfflineReload`, a mixin on `PagedCollectionCubit`, `MediaDetailCubit`,
`MusicSearchCubit` and `ArtistStatsCubit`, subscribes each to
`OfflineMode.changes` and re-reads on the transitions that flip
`isOffline` (an unopened tab is left alone). Without it a screen already
rendered would keep showing the server's list after the user went offline,
or the saved copy after they came back.

The offline switch and the "Downloads only" scope both change what
`fetch` answers, and on the offline↔online transition both fire a reload
on the same frame — the mixin's, and the library page's `showDownloadedOnly`
call. `PagedCollectionCubit` previously dropped the second (its `_busy`
guard bailed a `reload` that a fetch was mid-flight for, leaving the
screen on the stale window). It now queues that reload and runs it once
the in-flight fetch lands, discarding the window read under the
now-superseded parameters. `MediaDetailCubit` guards the same race with a
generation counter.

## Decision: the user can switch the whole app offline

`OfflineMode` (domain seam) exposes one `OfflineStatus` —
`isManual || !isConnected` — behind `PersistedOfflineMode`, which reads
`NetworkCondition` for the connection and `KeyValueStore` for the switch,
the same replaceable-seam shape as the storage probe. `OfflineCubit`
makes it a bloc for the sidebar switch and the offline banners; the
cached music and playlist repositories read the seam directly and, when
it is active, skip the server and answer from the same cache-fallback
path a real timeout takes (a synthetic `RecoverableFailure`, so nothing
downstream needs a new code path).

With no connection the switch is shown on and disabled — the app is
already offline, honestly labelled. The switch never deletes anything and
never touches the server; turning it off restores the exact pre-v0.2.3
behaviour.

The `SettingsCubit` `offlineLibraryScope` preference
(`unlimited` / `limited`) decides what offline shows: the whole cached
library with markers, or only downloads. It is consulted **only while
offline** — online, the library is always the full one — and it is
enforced in the presentation layer (the library page and the search view
force the `DownloadedFilter`), so no repository or cubit contract learns
about it.

## Decision: a server-side deletion is a state, not a removal

`track_downloads` gains a `server_gone` flag. It is set **only** when the
server has been reached and explicitly does not list a downloaded track —
never from a merely unreachable server. `TrackDownload.toTrack` then
reports `MediaAvailability.localOnly`, which the UI already renders as
"Only on this device": the file is kept and still plays. The mark is
cleared if the track reappears.

Three reconcile points feed it, all gated on a non-cached server read:
`reconcilePlaylist` (already existed for membership) now also marks
removed-but-kept members; `ReconcileDownloadedCollection` runs on an
album detail page's first online open, off the track list it already
loads; and `reconcileArtist` pages the artist's tracks itself (the
artist screen loads no flat track list) when a downloaded artist page is
opened online. Nothing here ever deletes a record.

`restore` also verifies each completed record still has its file
(`DownloadEngine.locate`) and re-queues any whose file has vanished, so a
database/file mismatch can no longer leave a phantom "downloaded" track
that plays silence.

## Decision: the storage probe is another `NetworkCondition`-shaped seam

`DownloadStorageProbe` exposes the one fact needed — is there enough room
left that a download is worth starting — behind a replaceable seam, the
same shape as `NetworkCondition`. `DiskSpaceStorageProbe` implements it
over `disk_space_plus` (platform-channel work behind a replaceable seam,
the kind `CONTEXT.md` says a dependency should be, and the same precedent
`connectivity_plus` set in ADR-0022; it needs no Android permission).
`availableBytes` returns `null` when the platform will not say, and the
warning then simply does not fire — the same "don't pre-empt on a guess"
stance the Wi-Fi-only preference takes when it is off.

`DownloadsCubit.storageWarning` compares free space to a round, conservative
500 MB threshold — not a computed estimate of what a specific request
needs. The album, artist and playlist download controls check it before a
request and ask the user to confirm past a warning. The warning is
advisory: `ROADMAP.md` v0.2.3 adds no automatic cleanup, so a confirmed
download proceeds.

## Consequences

- Schema v6, the first migration to reshape existing tables. Real upgrade
  paths (v1–v5 → v6) are covered; the intermediate-version migration
  tests now assert the current schema because `migrateAndValidate`
  always runs the chain to HEAD.
- `disk_space_plus` is a new dependency, behind `DownloadStorageProbe`.
- `DownloadsCubit` now depends on `SessionCubit` and `DownloadStorageProbe`
  and owns a third `StreamSubscription` it cancels on close.
- `OfflineMode` is a new domain seam with a `NetworkCondition` +
  `KeyValueStore` implementation; `OfflineCubit` joins the
  `JellyfinityApp`-level providers. The cached music and playlist
  repositories gain an `OfflineMode` dependency, and every music
  list/detail/search cubit gains one too (for `OfflineReload`).
  `CONTEXT.md`'s "not a separate app mode" invariant and the arc's
  "offline-only app mode" non-goal are amended, not silently broken.
- `SavedCopyNotice` and the library page's "downloads only" line are both
  deleted; the shell header owns the one offline line, its wording driven
  by the "Offline library" scope.
- `CachedMusicLibraryRepository` and `CachedMediaMetadataRepository` gain
  a `DownloadsLibrarySource` dependency as the tail of the cache-fallback
  chain; `CachedMediaMetadataRepository` also gains `OfflineMode` (it
  short-circuits offline now, like the other two). No cycle —
  `DownloadsLibrarySource` needs only the `DownloadStore`.
- The playback pipeline, queue, crossfade and normalization learn nothing
  new: a "only on this device" track plays through the exact v0.2.0
  local-first path, and the offline library windows are ordinary `Page`s.
- Accurate, continuous storage enforcement (and a per-request size
  estimate) would need a richer platform probe; the 500 MB threshold is
  a foreground best-effort, disclosed here and in the changelog, the same
  kind of documented gap as the foreground download engine (ADR-0020).
