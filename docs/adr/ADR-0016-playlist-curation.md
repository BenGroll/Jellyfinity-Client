# ADR-0016: Playlist Curation

## Status

Accepted

## Context

`Roadmap to v0.2.md` sequences playlist curation as `v0.1.2`, right after
streaming quality (ADR-0015): "mostly repository/UI work with limited
playback-engine overlap, so it can proceed independently." The domain
layer already reserved the seam — `PlaylistRepository`'s doc comment
named this exact scope ("editing playlists ... belongs here and nowhere
near library browsing") — and `PlaylistRepository` itself stayed
read-only through v0.1.0/v0.1.1 on purpose.

Ben confirmed the scope up front:

- A **separate write-side contract** (`PlaylistEditor`), not more methods
  on `PlaylistRepository`.
- Bulk add-to-playlist from an **album, an artist, or another playlist**
  — not just a single track.
- A **playlist merge** feature, distinct from bulk add.
- **Jellyfin stays the source of truth**: no local optimistic playlist
  state to reconcile.

## Options Considered

### One contract or two

1. **A separate `PlaylistEditor` contract** (chosen). Read and write have
   different failure/consistency shapes worth keeping apart: a read can
   be served from `CachedPlaylistRepository`'s local copy when the server
   is down (ADR-0010), but a write has nowhere to go but the server and
   is never cached. Splitting them means `PlaylistRepository` — and every
   existing caller of it — is untouched by this release.
2. **Extend `PlaylistRepository` in place.** Rejected per Ben's direction
   above; it would also blur `CachedPlaylistRepository`'s cache-on-read
   behavior with a contract that now sometimes writes.

### Where bulk add and merge live

Both need to page through an entire source (an artist's whole
discography, say) before writing anything — more than a single Jellyfin
request, and more than `PlaylistEditor` (deliberately one Jellyfin call
per method, mirroring `JellyfinPlaylistRepository`) should know about.
`PlaylistCurationService` (`lib/app/playlists/`) is the same
architectural slot as `PlaybackCubit`: the one place that talks to more
than one narrow contract (`PlaylistEditor`, `PlaylistRepository`,
`MusicLibraryRepository`) to answer one user-facing action. It pages
internally (200 items at a time — large enough that even a big artist
discography takes a handful of requests, small enough that one window
decodes quickly) and skips rows a page could not read rather than
failing the whole bulk add, the same partial-success discipline
`BaseItemMapper`/`Page` already apply everywhere else.

### Merge: pick a target, or always create a new one

1. **Always create a brand-new destination playlist** (chosen).
   `PlaylistCurationService.mergePlaylists` creates the target first, then
   copies each source into it via the same `addPlaylist` bulk-add path,
   in the order given. A bad merge is undone by deleting the one new
   playlist; nothing about a playlist the user already had is ever
   at risk.
2. **Merge into an existing playlist.** Rejected: it would mean deciding
   where the merged tracks land relative to the target's existing ones,
   and a bad merge could only be undone by trying to reconstruct what the
   target used to contain.

Deleting the sources after a merge is opt-in (`deleteSources`) and, when
requested, only happens *after* every source has been fully copied — a
failure part-way through a merge never loses a source playlist, at worst
leaves the merge incomplete and retryable.

### Identifying a playlist entry for remove/reorder

Jellyfin's playlist mutation routes (`Playlists/{id}/Items` DELETE,
`Playlists/{id}/Items/{itemId}/Move/{newIndex}`) key off the playlist's
own per-entry id (`PlaylistItemId` on the item DTO), not the underlying
track's id — because a playlist can hold the same track more than once,
each occurrence needing to be removable/movable independently.
`BaseItemDto` gains `playlistItemId`; `BaseItemMapper.toTrack` carries it
into a new `Track.playlistEntryId`, populated only when a track is read
through `PlaylistRepository.tracks` (Jellyfin only sets the field on that
endpoint). `PlaylistEditor.removeEntries`/`moveEntry` take entry ids,
never track ids.

### Renaming without touching contents

Jellyfin's playlist update route (`POST /Playlists/{id}`) takes a body
where an absent field means "keep the current value" — confirmed against
the server's own `UpdatePlaylistDto` ("Fields set to `null` will not be
updated and keep their current values"). `JellyfinMediaApi.renamePlaylist`
sends only `{"Name": ...}`, so a rename can never accidentally replace or
clear a playlist's tracks.

### Editing a playlist's order/contents: windowed or whole

`PlaylistDetailPage` browses a playlist the same windowed way every other
list in the app does (`PlaylistTracksCubit`). Reordering and removing are
different: a drag-and-drop reorder needs the whole ordered list on hand,
not a scrolling window of it. `PlaylistEditCubit` is a second, edit-mode
cubit that pages through the entire playlist once when edit mode starts
(the same internal-paging shape as `PlaylistCurationService`), and is
the only place that talks to `PlaylistEditor`'s remove/reorder methods.
Ordinary browsing never pays this cost — only opening edit mode does.

A reorder/remove updates `PlaylistEditCubit`'s in-memory list immediately
(so a drag feels instant, the same UX principle `PlaybackCubit`'s queue
mutations already use) and confirms against `PlaylistEditor` in the
background; a failed confirmation re-loads the whole playlist from the
server rather than trying to reverse the local edit, keeping "Jellyfin is
the source of truth" true even when a mutation fails partway.

## Decision

### Domain — `lib/domain/media/`

- `PlaylistEditor` (new): `create`, `rename`, `delete`, `addTracks`,
  `removeEntries`, `moveEntry`. `PlaylistRepository` is unchanged.
- `Track` gains `playlistEntryId` (nullable).

### Infrastructure — `lib/infrastructure/jellyfin/media/`

- `BaseItemDto` gains `playlistItemId`; `BaseItemMapper.toTrack` maps it.
- `JellyfinMediaApi` gains the playlist mutation routes (create/rename/
  delete/add-items/remove-items/move-item), each confirmed against
  Jellyfin's own controller source rather than assumed, plus batching
  (200 ids/request) for add/remove so a large bulk operation cannot build
  one unbounded URL.
- `JellyfinPlaylistEditor` (new): the sole `PlaylistEditor` implementation,
  registered directly (no caching decorator — nothing here is cached).

### App — `lib/app/playlists/`

- `PlaylistCurationService` (new): `createPlaylist`, `renamePlaylist`,
  `deletePlaylist`, `addTrack`, `addAlbum`, `addArtist`, `addPlaylist`,
  `mergePlaylists`.

### Presentation

- `music_rows.dart`: `TrackRow` gains `onAddToPlaylist` (third overflow
  action, alongside Play Next/Add to Queue); `PlaylistRow` gains
  `onRename`/`onDelete` (its own overflow menu). The overflow-sheet
  builder is factored out (`showOverflowSheet`/`OverflowAction`) so both
  rows share it.
- `PlaylistPickerSheet` + `addToPlaylistFlow`: the shared "pick a
  playlist (or create one), then do X" flow every add-to-playlist entry
  point uses — a single track, or a whole album/artist/playlist's bulk
  add.
- `LibraryPage`'s Playlists tab gains New Playlist and (with 2+
  playlists) Merge actions; each row's overflow gains Rename/Delete.
- `AlbumDetailPage`/`ArtistDetailPage`/`PlaylistDetailPage` headers gain
  an Add to Playlist button next to Play, wired to the bulk-add methods
  above.
- `PlaylistDetailPage` gains an edit-mode toggle (`PlaylistEditCubit`)
  for reorder/remove, and Rename/Delete in its app bar.
- `MergePlaylistsPage` (new): pick 2+ playlists, name the result, opt
  into deleting the sources.

## Tests

- `jellyfin_playlist_editor_test`: request shape for every mutation
  (create seeding, rename leaves contents alone, delete via the generic
  item route, add/remove batching, move), and cross-server id rejection.
- `playlist_curation_service_test`: bulk add pages through a whole
  source and skips unavailable rows; merge creates-then-copies in order
  and never deletes a source it failed to copy.
- `playlist_edit_cubit_test`: full-playlist load across pages, optimistic
  reorder/remove, reconciliation after a failed mutation.
- `playlist_curation_widget_test`: create/rename/delete from the
  Playlists tab, add-to-playlist from a track's overflow menu, and an
  end-to-end merge through the real router.
- Existing `jellyfin_playlist_repository_test`/`cached_playlist_repository_test`
  are unchanged — the read side was not touched.

## Consequences

- `PlaylistRepository` callers (search, browsing, offline cache) are
  entirely unaffected — this release only adds a new contract alongside
  it.
- Every mutation is a direct, uncached write to Jellyfin; there is no
  offline playlist editing and no conflict-resolution story to reason
  about, matching Ben's direction and the roadmap's suggested default.
- Editing a very large playlist loads the whole thing into memory once
  (edit mode only) — acceptable for a user's own curated playlist, not
  appropriate for a library-scale list, which is why edit mode is
  `PlaylistDetailPage`-only and nothing else in the app pages this way.
- `Track.playlistEntryId` is `null` everywhere except a page just read
  through `PlaylistRepository.tracks` — any code trying to remove/reorder
  from a track read elsewhere gets nothing to act on by construction,
  rather than acting on the wrong id.
