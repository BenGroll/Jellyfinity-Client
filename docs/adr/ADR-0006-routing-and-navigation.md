# ADR-0006: Routing & Navigation

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.3 scope requires selecting and configuring the
routing/navigation solution and recording the decision in an ADR. The
router has to support, at minimum: an application root, an
authenticated-vs-unauthenticated split, nested navigation, future
deep-link support, and future tab-based navigation.

The authentication feature does not exist yet (v0.0.5), so v0.0.3 needs a
router architecture that already has an auth gate but is driven by a
stubbed session, not a real one.

## Options Considered

1. **`go_router`** (chosen) — declarative, URL-first routing maintained by
   the Flutter team (`flutter/packages`). First-class `redirect` for auth
   gating, `refreshListenable` to re-run redirects on state change,
   `StatefulShellRoute` for tab navigation where each tab keeps its own
   navigator stack, and deep links handled by the same route table. No
   code generation.
2. **`auto_route`** — similar capability set, with typed route arguments
   and nested routing driven by `build_runner` code generation. Rejected
   for v0.0.3: it adds a second codegen target alongside `injectable`, and
   Jellyfinity does not yet have the route-argument complexity that most
   justifies it. Reconsider if typed args become a real pain point.
3. **Raw Navigator 2.0 / a hand-written `RouterDelegate`** — no
   dependency, maximum control. Rejected: the redirect/guard, deep-link
   parsing, and per-tab stack plumbing would all be hand-built and
   hand-tested, which is exactly the "labor-intensive infrastructure"
   `PHILOSOPHY.md` §14 says to take a dependency for.

## Decision

Jellyfinity uses **`go_router`**.

Structure:

- [`lib/app/router/app_router.dart`](../../lib/app/router/app_router.dart)
  (`AppRouter`, a `@lazySingleton`) owns the single `GoRouter`. It lives in
  `lib/app` because it is a composition-root object — it wires feature
  pages together and is the one place navigation reads `getIt`. Feature
  code navigates with `context.go`/`context.push` and the constants in
  [`route_paths.dart`](../../lib/app/router/route_paths.dart), never with
  string literals.
- **Auth gate.** `GoRouter.redirect` keys entirely off
  [`SessionStatus`](../../lib/app/session/session_status.dart)
  (`unknown` → splash, `unauthenticated` → welcome, `authenticated` →
  shell). [`SessionCubit`](../../lib/app/session/session_cubit.dart) holds
  that status; a
  [`GoRouterRefreshStream`](../../lib/app/router/go_router_refresh_stream.dart)
  adapter turns its stream into the router's `refreshListenable`, so a
  session change re-runs the redirect with no manual navigation. In
  v0.0.3 `SessionCubit` is a stub with no dependencies, moved only by the
  development welcome screen; v0.0.5 replaces its body with real Jellyfin
  authentication without the router changing.
- **Shell.** `StatefulShellRoute.indexedStack` builds one branch per entry
  in [`shellDestinations`](../../lib/features/shell/presentation/shell_destination.dart).
  v0.0.3 ships exactly one section (Home); the shell's navigation bar is
  only rendered once a second section exists, honouring the roadmap's "do
  not fully implement empty future sections" rule while keeping the
  structure ready.
- **Not found.** `GoRouter.errorBuilder` renders `NotFoundPage`; there is
  also an explicit `/404` path constant for intentional navigation to it.
- **Deep links.** Not implemented in v0.0.3, but the flat, URL-shaped
  route table is the foundation for it — no extra architecture needed
  later, just `Uri` parsing into existing paths.

State management for navigation-adjacent feature state still follows
ADR-0002 (Bloc/Cubit); `go_router` is only the routing mechanism.

## Consequences

- Auth-gated navigation is declarative and centralised: one `redirect`
  function is the whole policy, and it is unit-testable by driving
  `SessionCubit` and asserting the visible page.
- Each shell section keeps its own navigation stack and scroll position
  across tab switches (via `StatefulShellRoute`), which matches the
  "premium, predictable" bar Jellyfinity sets for itself.
- Adding a section later is a `shellDestinations` entry plus a `path →
  page` case in `AppRouter` — the nav bar and shell wiring pick it up.
- `go_router` is a dependency on the Flutter team's own package: low
  abandonment risk, but its major versions do occasionally reshape the
  API, so upgrades need a read of the changelog.
- The `SessionCubit`/router seam is deliberately shaped now so v0.0.5's
  real authentication slots in behind an unchanged interface.
