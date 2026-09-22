# ADR-0048: Bulk music selection and playlist actions

## Status

Accepted

## Context

`Roadmap to v0.7.md`'s v0.7.0 asks for multi-select "in song lists, search
results, album tracks, artist songs, Favorites, Downloads, and playlist
rows where the action is valid," adding the selection to a playlist "in
displayed order, with explicit handling for duplicates, unavailable rows,
partial success, cancel, navigation, and account switch." No selection
state existed anywhere in the app before this version — a repo-wide
search for `isEditing`/`editMode`/`selectionMode`-style state found
nothing.

Two things needed a decision before touching any screen: what
`PlaylistRepository.addTracks(playlistId, trackIds)` — a single call for
the whole batch, not per-item results — means for "explicit handling of
... partial success," and where a selection surface with no browsable
list today (artist songs) should get one.

## Decision: `TrackSelectionCubit` is screen-scoped, not app-wide

`TrackSelectionCubit` (`lib/features/music/presentation/selection/`) is
built directly from the already-provided `SessionCubit`
(`TrackSelectionCubit(context.read<SessionCubit>())`) inside each
screen's own `BlocProvider`, the same way `SongsCubit`/`AlbumsCubit` are
already created per screen — not a `getIt`-registered factory or a
`@lazySingleton`. A fresh instance per screen gives "scoped to the active
page" for free: it lives and dies with the widget that opened it, and
navigating away clears it without any explicit code. It still takes
`SessionCubit` and compares `account.id` across session events
(mirroring `DownloadsCubit`'s `_activeAccountId` check) so a profile or
server switch clears an in-progress selection even if the screen that
started it stays open across the switch, and a same-account event (a
token refresh) does not.

State is `{ active: bool, selected: Set<MediaId> }` rather than inferring
selection mode from a non-empty set: a keyboard, pointer, or D-pad user
needs to enter selection mode from a button before checking anything, and
`active` alone lets them do that (`enter()`) without `selected` needing a
placeholder value. A touch long-press instead calls `toggle(id)` directly
— it both activates and checks the row in one gesture.

## Decision: pre-filter client-side; the server call stays all-or-nothing

`PlaylistRepository.addTracks` was not extended with per-item results.
Duplicate ids are impossible by construction (`selected` is a `Set`).
"Unavailable rows" and "partial success" are both resolved before the
repository is ever called: `TrackRow.onSelectToggle` is `null` for a row
that is not playable, the same convention `onTap`/`onPlayNext` already
use, so an unplayable row can never enter `selected` in the first place.
At add time, `addSelectedTracksToPlaylist`
(`lib/features/music/presentation/selection/bulk_playlist_selection
.dart`) intersects `selected` against the screen's *current* loaded,
playable tracks (in displayed order) — a row selected earlier and gone
unavailable since (a refresh, a reconnect) is silently dropped from what
gets sent, and the result message says how many were skipped. What
remains after that filter is sent as one `addTracks` call and treated as
genuinely all-or-nothing: a failure keeps the filtered (not the original)
selection so a retry does not resend ids the server was never asked
about, via `TrackSelectionCubit.retainOnly`.

This keeps the domain contract unchanged and keeps "partial success"
honest at the layer that actually knows about staleness — the UI already
has to recompute the playable set on every rebuild for row rendering, so
reusing it for the add is not new work, and a client-observed staleness
between selecting and adding is not the same claim as the server
partially accepting a batch it was fully asked to add.

## Decision: an app-bar "Select" action, not always an inline one

`TrackSelectionBar` (the "N selected / Cancel / Add to playlist" row)
defaults to also showing a lone "Select" entry button inline above the
list when selection is off. Every screen with an `AppScaffold` action row
(Album, Playlist, Search results, Downloads, Artist) instead gets a
persistent "Select songs" icon there and passes
`showEntryButton: false` — a fixed app-bar icon costs no scroll height,
where the inline button unconditionally added one row's worth of height
to every song list, all the time, even while not selecting. That
regressed `PlaylistDetailPage`'s existing widget tests against the
default test viewport for a two- and three-song playlist (the
unavailable-row assertions moved just past the default `CustomScrollView`
cache extent). The three screens with no app bar of their own (Library
and Favorites' Songs tabs, inline search) keep the inline button, since
they have nowhere else to put one.

## Decision: artist songs get a new section, not a new tab

`ArtistDetailPage` had no browsable song list before this version —
`SongsCubit.forArtist` was loaded only to back the header's song count
and Play/Shuffle buttons. Asked directly, the answer chosen was to add
one (`_ArtistSongsSection`) rather than skip the surface: a "Songs"
heading and row list appended to the existing albums scroll, backed by
the same already-loading `SongsCubit`, with its own "Show more songs"
(no auto-scroll pagination — selection must never load a whole result set
merely because it started, and this section already sits below
everything else on the page). A second tab was considered and rejected:
the page's header (art, stats, Play/Shuffle, download) is expensive and
tab-specific duplication would either show it twice or need a larger
restructure (`NestedScrollView` + pinned header) to share it, well beyond
this version's bounded scope. `_ArtistPresenceReconciler`'s
album-triggered `reconcileArtist` call already reconciles the whole
artist's downloaded tracks regardless of whether they render as a flat
list, so this section needed no reconciliation changes.

## Tests

`test/features/music/selection/track_selection_cubit_test.dart` covers
`enter`/`toggle`/`exit`/`retainOnly` and the account-switch/same-account
distinction directly against the cubit. `test/features/music/
track_row_test.dart` covers touch tap-to-toggle, long-press entry, the
checked/unchecked/not-selectable indicator states, and that selection
mode hides the overflow menu. `test/features/music/selection/
bulk_selection_test.dart` drives `PlaylistDetailPage` end to end:
displayed-order addition regardless of tap order, Cancel, Escape-key exit
while active (the same key TV-remote back and Android system back resolve
to), an unavailable row refusing selection, a row going unavailable
between selection and add (partial success), and a failed add retaining
the still-valid selection.

## Consequences

- `TrackSelectionBar`/`SelectionExitGuard`/`bulk_playlist_selection.dart`
  are the one reusable path every required surface goes through; a future
  multi-select surface should extend this rather than build its own.
- `SelectionExitGuard` claims focus on itself the instant selection mode
  turns on, since `CallbackShortcuts` only resolves a key event when a
  descendant already holds focus — worth remembering before reusing the
  bare `PopScope` + `CallbackShortcuts` pattern (as `AppShell`'s search
  does) anywhere selection is not always entered through something that
  already autofocuses.
- No schema change, no new wire message, no new domain contract.
