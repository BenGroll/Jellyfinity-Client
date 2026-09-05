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

- The **"Downloaded" filter** on the library tabs and the search screen.
  A `DownloadedFilter` mixin on the collection cubits, and a flag on
  `MusicSearchCubit`, switch the data source; the contract is unchanged,
  so no repository or remote implementation learns about the filter.
- The **offline search fallback**. A music search that fails every
  category because the server is unreachable retries against the
  downloads, and shows those results *only if they match something* — an
  offline search with no local hits still says "search needs the server"
  rather than a misleading "no matches".

Normal offline browsing is unchanged: the metadata cache still serves the
collections a user has actually browsed. The filter is how the full
downloaded set is found offline.

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
- The playback pipeline, queue, crossfade and normalization learn nothing
  new: a "only on this device" track plays through the exact v0.2.0
  local-first path, and the offline library windows are ordinary `Page`s.
- Accurate, continuous storage enforcement (and a per-request size
  estimate) would need a richer platform probe; the 500 MB threshold is
  a foreground best-effort, disclosed here and in the changelog, the same
  kind of documented gap as the foreground download engine (ADR-0020).
