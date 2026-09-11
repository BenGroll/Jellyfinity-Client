# ADR-0032: Playlist mastery

## Status

Accepted

## Context

`Roadmap to v0.5md`'s "Playlist mastery" (v0.4.2) asks for playlists that
do not send a user back to Jellyfin Web. Two things stood between
Jellyfinity and that, and both were deferred on purpose by an earlier
release rather than overlooked.

1. **Reorder.** ADR-0024 shipped create, rename, delete, add and remove,
   and deliberately left reorder out. Jellyfin's move endpoint takes an
   absolute index into the playlist; `BaseItemMapper.toPage` splits rows
   it cannot read into `Partial.unavailable`, so the only index the UI
   could compute was an index into the *readable* rows. On a playlist
   holding anything that is not a readable song the two differ, and a
   drag would have moved the wrong entry with no signal to anyone.
2. **Playlist listening context.** ADR-0025 attributed a play to the
   track's album, else its artist, else the track, and noted that
   playlists need a "queue origin" because nothing about a song says
   which playlist it was picked from. ADR-0026 then declined to add one,
   calling it a new subsystem that a Home section should not carry. It
   has been outstanding since.

Both are the same kind of problem: a fact the server has that
Jellyfinity's model threw away.

## Decision: positions are read, not inferred

The playlist read model now states where each row sits.

- `PlaylistTrack` gains `position` — its absolute, zero-based index in
  the playlist, counted the way Jellyfin counts it, with unreadable
  entries still occupying their slots.
- `UnavailableItem` gains a nullable `position`, so a row that could not
  be read still says which slot it held. This is on the shared type
  rather than a playlist-only one because it is the general fact
  `Partial` was losing: separating readable rows from unreadable ones
  discards how they were interleaved, which is harmless for a grid of
  covers and wrong for any ordered list.
- `BaseItemMapper.toPlaylistPage` replaces `toPage(map: toPlaylistTrack)`
  for playlist windows. A playlist row is the one collection member whose
  index is part of what it is, so it gets its own mapping rather than a
  flag on the general one.

A drag therefore never computes a destination. It reads one off the row
being displaced: the moved row lands at that row's `position`. Moving
down, the server lifts the row out first, so the target's own index
becomes the slot just after it; moving up, the target has not moved and
the row takes its place. Either way the entries Jellyfinity cannot read
keep the slots they had.

The alternative — deriving positions in the UI by counting unavailable
entries — was rejected. It works, but it puts the playlist's own
numbering in presentation, has to be re-derived per screen, and silently
produces wrong numbers the moment a source cannot supply the
interleaving.

## Decision: position and entry id answer different questions

ADR-0024 made `row is PlaylistTrack` mean both "knows its entry id" and
"can be edited", because the live Jellyfin read was then the only source
that produced one. Numbering an offline playlist correctly needs
positions from the cache too, so the two are now separate:

- **Position** comes from every source that knows the order. The metadata
  cache keeps each window's interleaving (it always recorded unreadable
  entries; now it records *where*), and a downloaded playlist's snapshot
  is ordered by construction. `CachedPlaylistRepository` restores
  positions onto both, so an offline playlist numbers itself exactly as
  it did online.
- **`entryId` is now nullable**, and `PlaylistTrack.isEditable` is the
  question every affordance asks. Only a read that reached the server has
  one. ADR-0024's rules are unchanged in substance: a write reaches the
  server or fails, nothing local is treated as an edit, and an offline
  playlist is playable and uneditable — it is just no longer expressed by
  the absence of a subtype.

Deriving the positions inside `CachedPlaylistRepository` rather than in
`MediaCacheStore` keeps the store collection-agnostic. It stores order;
only the playlist repository knows that a playlist's order is part of
each row's identity.

## Decision: reorder is optimistic on screen and authoritative on the server

`PlaylistTracksCubit.moveEntry` reorders its own list, sends the move,
and puts the list back if the server refuses. On success it re-reads,
because every row after the move has a new position and one of them may
be an entry the screen never showed.

This does not reopen ADR-0024's "edits go straight to the server". The
local reorder is a frame of presentation state, never written down and
never reconciled; a drag that snapped back until a round trip finished
would simply be a worse way to show the same truth.

## Decision: the queue carries what started it

`QueueOrigin` is the queue-origin ADR-0026 deferred, deliberately no
bigger than the question it answers: a queue has an origin exactly when a
playlist started it, and `null` every other time. An album or artist
needs none — every entry already names both.

It rides `KeyValueStore` beside the shuffled play order (ADR-0031),
because it is one fact about the queue as a whole rather than a property
of any entry. **No schema change**, which is the main reason this is a
release rather than another deferral.

Two consequences are worth stating plainly:

- Listening history gains `ListeningContextKind.playlist`, and the origin
  **wins over the album**. A listener who put on *Late Night* listened to
  *Late Night*, not to the nine albums it draws from.
- The origin is queue-level, so a track added by hand mid-session is
  credited to the playlist too. That is the deliberate trade: the precise
  alternative is an origin column on every queue row plus a schema
  migration, to correct an attribution that is arguably right anyway —
  the song was played as part of that session.

A restored queue keeps its origin, which is what makes the playlist
session resumable: the playlist page offers to carry on the queue *it*
started, and knows it is the same session because the queue says so, not
because the track happens to appear in the list.

## Decision: reorder is reachable without a drag

`SliverReorderableList` inside `PagedCollectionView` gives the drag; an
explicit grip starts it, so a tap still plays the row (the rule
`QueuePage` already follows). `ReorderableListView`'s default desktop
handles are not used, so Android touch and Windows pointer get the same
affordance in the same place.

"Move up" and "move down" in the row's overflow menu are the same
reorder without a drag. `CONTEXT.md` requires Windows keyboard and
pointer conventions to reach every feature, and press-and-drag is the one
interaction that has no keyboard form — so the menu is the accessible
path on both platforms rather than a Windows special case.

## Consequences

- `PlaylistRepository` gains `moveEntry(playlistId, entryId, newIndex)`,
  keyed on the entry for the reason removal is: a playlist may list the
  same song three times.
- Downloading is unchanged and stays a statement about the *track*: two
  rows for the same song show the same download state, because there is
  one file. Only reorder, removal and playback start are per-entry, which
  is exactly where the entry id is used.
- A playlist read offline is numbered like the playlist and says, per
  row, that it cannot be edited. `MediaCacheStore` preserves interleaving
  for every collection, not just playlists.
- v0.1.2 is finally complete. `ROADMAP.md`'s note about reorder goes.
- `ListeningContextKind` has a fourth value; every `switch` over it is
  exhaustive, so Home's rows, labels and offline rules were updated by
  the compiler rather than by search.
- Home's "recently played" can now show a playlist, and does, with no new
  section and no new read.
