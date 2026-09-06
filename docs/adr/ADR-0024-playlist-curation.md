# ADR-0024: Playlist curation

## Status

Accepted

## Context

`Roadmap to v0.2.md` v0.1.2 asked for write contracts covering create,
rename, delete, add tracks, remove tracks, and reorder, plus the UI to
drive them. Only `addTracks` was ever built, added in v0.1.6 for the
"Add to playlist" menu and shipped with a comment saying the rest was
still outstanding. Three later versions and a whole offline-music arc
shipped around the gap: by v0.2.3 a user could download a playlist, keep
it current against the server, and play it on a plane — but could not
make one, name one, or take a song out of one without opening Jellyfin's
web UI.

v0.3.0 sweeps it up rather than giving it a version of its own. The
missing pieces are an oversight, not a feature.

Two questions had to be settled: what a removal actually names, and
whether an edit is applied optimistically or only after the server
agrees. A third — how reorder works — is deliberately left open.

## Decision: a removal names an entry, not a track

A playlist is a list of entries, not a set of tracks. Jellyfin lets the
same song appear in a playlist any number of times, gives each appearance
its own `PlaylistItemId`, and keys its remove and move endpoints on that
id rather than on the item id. "Remove So What from this playlist" is
therefore not a well-formed request when So What is in it twice.

So `PlaylistRepository.removeEntries` takes entry ids, and the entry id
reaches presentation as **`PlaylistTrack`, a subtype of `Track`**:

```dart
class PlaylistTrack extends Track {
  final String entryId;
}
```

Three shapes were considered:

- **A nullable `playlistEntryId` on `Track`.** Rejected: an entry id is
  meaningful only for a track read through a playlist, and every other
  `Track` in the app — library rows, queue entries, download records —
  would carry a permanently null slot for a concept that does not apply
  to it.
- **A separate `PlaylistEntry` wrapper with its own paged read.** The
  most literal model, and rejected on cost: `PagedCollectionState` is
  bound to `MediaItem`, so a wrapper would need its own cubit, its own
  page type, and its own path through the cache, for a gain the subtype
  already delivers.
- **Position-based removal**, with the index taken from the rendered
  list. Rejected as incorrect. `BaseItemMapper.toPage` splits entries it
  cannot map into a separate `unavailable` list, so the index of a row on
  screen is not the index of that row in the playlist whenever the
  playlist contains something that is not a song. Removing by position
  would remove the wrong entry, silently, on exactly the playlists most
  likely to have accumulated oddities.

The contract still declares `Future<Result<Page<Track>>> tracks(...)`,
and that does real work rather than being a compromise. The Jellyfin read
produces `PlaylistTrack`s; a read served from the offline metadata cache
or from a download snapshot produces plain `Track`s, because neither
stores entry ids. So `row is PlaylistTrack` is simultaneously "does this
row know its entry id" and "can this row be edited right now" — and
offline, where editing is impossible anyway, the answer is honestly no.
A row the server sent without a `PlaylistItemId` degrades the same way:
it stays in the list, playable and uneditable, rather than vanishing.

## Decision: edits go straight to the server

v0.1.2 asked for edits to be applied directly to Jellyfin "unless a
concrete requirement justifies optimistic local state and reconciliation"
and for a non-obvious choice to be documented. No such requirement
appeared, and the reasoning is worth recording because the offline
machinery next door makes the opposite look tempting.

A playlist edit is an instruction to the server, not a piece of local
state. Jellyfinity already holds durable local state for downloads
(ADR-0020) and a durable membership snapshot for downloaded playlists
(ADR-0021) — but those describe *this device's copy*, which is a
different thing from the playlist itself. An optimistic local edit would
have to be reconciled against the server later, and ADR-0021's reconcile
already exists to resolve *server-side* changes against a local snapshot;
adding a second, opposite flow would give two writers to the same
membership with no principled winner.

So every write in `PlaylistRepository` reaches the server or fails, and
`CachedPlaylistRepository` passes each one straight through. Offline they
fail honestly; the UI does not offer the ones it knows cannot work.

The saved copy is not invalidated on a write, either. A mutation that
succeeded proves the server is reachable, so the caller reloads the list
it just changed and that read overwrites the cached page on its way
through. Invalidating as well would only widen the window in which an
offline reader sees nothing rather than something slightly stale.

## Decision: reorder is deferred, not attempted

Reorder is the one v0.1.2 requirement this change does not deliver, and
the reason is the same one that ruled out position-based removal.
Jellyfin's move endpoint takes an absolute destination index into the
playlist. The page model hands presentation a list with unmappable
entries removed, so the only index the UI can compute is an index into
the mappable rows — equal to the real one only when the playlist happens
to contain nothing but readable songs.

Shipping that would mean a drag that lands the song in the right place on
most playlists and the wrong place on the rest, with no signal to the
user either way. Removing by entry id has no such ambiguity, which is why
it ships here and reorder does not.

Doing it properly needs the read model to expose true positions —
either by interleaving unavailable entries back into the ordered page, or
by the `PlaylistEntry`-with-its-own-read shape rejected above. That is a
design change to a seam three features already depend on, and it belongs
in a version that can carry it.

## Consequences

- A playlist can be created, renamed, deleted, filled and thinned out
  entirely from inside Jellyfinity. v0.1.2's "Done when" is met except
  for reorder.
- `BaseItemDto` gains `playlistItemId`, and `BaseItemMapper` gains
  `toPlaylistTrack`. No schema migration: entry ids are live-read only
  and are deliberately never cached.
- Editing is an online-only capability, visibly so. Every affordance that
  needs the server is hidden or absent when Jellyfinity is offline rather
  than failing on tap.
- `PlaylistRepository` now mixes reads and writes. It stays one contract
  rather than splitting into a sibling write contract — the alternative
  v0.1.2 permitted — because five methods is not enough to justify two
  seams, and every caller that writes to a playlist is already reading
  one.
- Reorder remains open, and `ROADMAP.md` says so rather than marking
  v0.1.2 complete.
