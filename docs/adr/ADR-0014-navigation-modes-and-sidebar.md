# ADR-0014: Navigation Modes, Persistent Search & the App Sidebar

## Status

Accepted

## Context

Jellyfinity's shell has been a fixed two-tab bottom bar (Home, Music)
since v0.0.3/v0.0.8, with search a pushed page reached from a Music-tab
`AppBar` icon (`MusicSearchPage`, ADR-0012). Ben asked for that replaced
with a Spotify-style persistent header — a search field always visible
at the top of the UI, and a row of "pills" beneath it for switching which
media type Home/Library/search are scoped to (Music vs. a future Movies,
TV, Audiobooks, ...) — but explicitly **not** as the only way the shell
can look: high configurability is a stated product trait
(`PHILOSOPHY.md` §9, `OUTLOOK.md` §10/§11's customization vision), so the
pill design had to land as one of several swappable navigation
presentations, user-selectable and persisted, not a hardcoded redesign.

Ben also asked for a sidebar (a standard `Drawer` — default edge-swipe
plus a menu button) holding everything that is not a media-type concern:
account switching, settings, and whatever else joins later (social
features were named as an example, but nothing exists to back that yet,
so no placeholder entry ships for it).

Two scope decisions, confirmed with Ben, keep this release honest rather
than aspirational:

- **Only Music is a real pill.** Movies/TV are entities-only per
  ADR-0011; Audiobooks/Ebooks don't exist in the domain at all. No fake
  "coming soon" pills, no "Combine" UI — there is nothing to combine yet.
  The visible difference between the two navigation modes is therefore
  small today (a single, effectively inert "Music" pill shown or not);
  the payoff is the seam, which a second media type or a third mode slots
  into without restructuring anything above it.
- **Search stays inline, never a pushed page.** Ben was explicit: since
  the old Music tab (now Library) no longer owns its own `AppBar`, search
  has to live at the very top of the UI "no matter what," not behind a
  subscreen. `MusicSearchPage` is retired; its field and categorized
  results move into `InlineMusicSearch`, swapped in for the header in
  place.

## Options Considered

### How many navigation modes, and what do they do

1. **Two modes behind one `ShellNavigationMode` enum — `mediaPills` and
   `unified`** (chosen). `mediaPills` shows the pill row under search;
   `unified` does not. Both keep the same persistent search field and the
   same Home/Library bottom nav. Named `ShellNavigationMode`, not
   `NavigationMode`, because Flutter's own `widgets` library already
   exports a `NavigationMode` enum (keyboard vs. touch traversal) —
   colliding with it would force an import prefix at every call site.
2. A full pluggable-shell-strategy interface (swap entire shell widgets,
   not just a boolean flag). Rejected for now: with one real media type,
   there is no actual behavioral difference to justify a wider
   abstraction, and `PHILOSOPHY.md` §18 ("prefer complete vertical slices
   over half-finished features") argues against building generality no
   current mode needs. The enum is deliberately the smallest thing that
   is still genuinely swappable and user-facing.

### Where the mode preference lives

**`KeyValueStore`**, the same primitive v0.0.6 built for exactly this
(device id, active-account pointer). No new persistence layer.
`SettingsCubit` (`lib/app/settings/`) is the cubit — same architectural
slot as `SessionCubit`/`PlaybackCubit`, provided at the app root because
the shared header and sidebar read it from every tab.

### How the initial mode is resolved before first paint

**Read in `bootstrap()`, right after `configureDependencies()`, and
registered with `getIt` directly** — not an `@preResolve` `@module`
method. It was written as one first (mirroring `JellyfinTransportModule`'s
`JellyfinClientIdentity` device-id lookup, a `Future<T>` read that's safe
to repeat), but `injectable_generator` cannot resolve a module method
whose return type is an enum (`EnumElementImpl is not a subtype of
ClassElement` — a generator limitation, not a design choice). The
fallback is the same shape `PlaybackEngine` already uses in `bootstrap()`
(for an unrelated reason — `AudioService.init()` can only run once per
process), just for a different reason here. Either way, the mode is
known before `runApp`, so the first frame already renders correctly
instead of flashing the default and swapping.

### Media-type scope model

`lib/app/navigation/`: `MediaType` (enum, one case: `music`),
`MediaContext` (`{id, label, types: Set<MediaType>}` — already a set so a
future combined pill like "Movies + TV" is additive, not a reshape),
`MediaScopeCubit` (holds the context list and the active id). **Not
persisted**, unlike the navigation-mode preference: this is a session's
browsing context, not a durable setting, so it resets to Music on
restart the same way it starts there today.

### Where search actually renders

**Inline, swapped in for the header at the `AppShell` level** — not a
new route, not a widget nested inside a specific tab. `AppShell` holds a
local `_searching` bool; activating it replaces `HomeLibraryHeader` with
`InlineMusicSearch` in the same slot, so the bottom nav and mini-player
stay exactly where they were. `InlineMusicSearch` reuses
`MusicSearchCubit` and the categorized-results widgets unchanged from
`MusicSearchPage` — only the surrounding chrome (title, back button, its
own scaffold) is gone.

One real interaction bug surfaced here during implementation: a search
result (an artist, album, playlist row, or "Show all") pushes a route
that lives on the Library branch's own `Navigator` — but that branch
isn't what `AppShell` is currently displaying while `_searching` is
true, so the pushed page was invisible until the user manually closed
search. Fixed by having every navigating action in `InlineMusicSearch`
call the same `onClose` callback its own close button uses, immediately
before the `pushNamed` — closing search and revealing the branch (now
showing the freshly pushed page) in the same gesture. A track tap (which
starts playback, not a navigation) deliberately does not call it; search
stays open.

### The sidebar

A plain `Drawer`, attached via a new `drawer` parameter on `AppScaffold`
at the `AppShell` level. Flutter gives a `Drawer` its default left-edge
swipe and (paired with a menu `IconButton` calling
`Scaffold.of(context).openDrawer()`) an explicit open affordance for
free — no custom gesture code, per Ben's explicit steer away from a
bespoke swipe implementation. Contents: "Accounts" (pushes the existing
`AccountsPage`, unchanged — switching profile, signing out, and removing
a server were already there, so the sidebar doesn't reinvent any of it)
and "Settings" (new).

## Decision

### App — `lib/app/settings/`, `lib/app/navigation/`

- `ShellNavigationMode` (enum), `SettingsCubit` + `SettingsState`
  (persists via `KeyValueStore`), read at `bootstrap()` time as above.
- `MediaType`, `MediaContext`, `MediaScopeCubit` (session-scoped, seeded
  with one context: Music).
- Both cubits join `SessionCubit`/`PlaybackCubit` as `JellyfinityApp`
  constructor params, provided the same way.

### Presentation — `lib/features/shell/presentation/`

- `HomeLibraryHeader` — menu button + search field (always present,
  never navigates), pill row (one "Music" pill) shown only in
  `mediaPills` mode.
- `AppSidebar` — the `Drawer` described above.
- `AppShell` (now a `StatefulWidget`): renders the header above
  `navigationShell`/`InlineMusicSearch`, wires `AppSidebar` as its
  `drawer`, owns the `_searching` toggle.

### Presentation — Library rename

- `MusicPage.dart` → `lib/features/music/presentation/library/
  LibraryPage.dart`: identical Artists/Albums/Songs/Playlists `TabBar`
  content, minus its own `AppScaffold` title/search action (the shared
  header replaces both).
- `lib/features/music/presentation/search/InlineMusicSearch.dart`
  replaces `MusicSearchPage.dart` (deleted).
- Routes renamed to match: `RoutePaths.music`/`RouteNames.music` →
  `library`; `musicArtist`/`musicAlbum`/`musicPlaylist`/
  `musicSearchCategory` → `libraryArtist`/`libraryAlbum`/
  `libraryPlaylist`/`librarySearchCategory`. The standalone `musicSearch`
  route is removed — search has no route of its own now.
- `ShellDestination`'s second entry: Music → Library (same icon; Music
  is still the only thing in it).
- New `/settings` route → `SettingsPage`.

### Testing

- `flutter_test`'s default surface (800×600 — wider than tall) left too
  little height once the persistent header, mini-player and bottom nav
  were all present at once: a deep-navigation row (e.g. an album tile on
  `ArtistDetailPage`) could compute a center point that `find` locates
  but that doesn't hit-test onto that widget, because it falls outside
  the actually-visible/hittable area at that cramped size. `pumpApp`
  (`test/support/pump_app.dart`) now sets a realistic phone viewport
  (390×844) for every full-app test — the correct fix, since these
  screens are built for a phone, not an incidental default size.
- `pumpApp` gained a `router` parameter: a test that drives navigation
  directly (`router.config.go(...)`) must build its `AppRouter` from the
  same `scope.cubit` and hand it in, otherwise it is asserting against a
  second, disconnected router instance that was never wired into the
  pumped widget tree — a real bug caught while adapting the existing
  router/navigation tests to the rename.

## Consequences

- Jellyfinity's navigation is a genuine seam now, not a hardcoded shell —
  a second mode was added, persisted, and made a real Settings choice
  with no router rewrite, which is the intended payoff for later media
  types.
- The Music↔Library rename touches every route, test, and cross-reference
  that named the old Music section; done in this release rather than
  deferred, since the shared header retiring MusicPage's own title bar
  made the rename unavoidable anyway.
- No engine-picker-style deferral this time: unlike ADR-0013's playback
  engine seam, this Settings screen ships now — it's the mode toggle
  itself, not a future one.
- Movies, TV, Audiobooks and Ebooks remain unimplemented; the pill
  mechanic, the "Combine" affordance, and any coming-soon states for them
  are explicitly deferred to whenever a second media type actually ships
  content, not built speculatively here.
