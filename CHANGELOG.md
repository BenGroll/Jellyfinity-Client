# Changelog

All notable changes to Jellyfinity are documented here.

## Unreleased

- Initialized the Flutter Android and iOS application.
- Added the reproducible development container.
- Added Windows-hosted Android emulator support through ADB.
- Added the initial Jellyfinity development shell.
- Added the application architecture core: feature-first Clean
  Architecture direction (ADR-0001), `flutter_bloc` state management
  (ADR-0002), `get_it`/`injectable` dependency composition (ADR-0003), a
  shared `Result`/`Failure`/`Partial` model (ADR-0004), and privacy-safe
  logging/configuration conventions (ADR-0005), each with focused tests.
- Added navigation with `go_router` (ADR-0006): a composition-root
  `AppRouter`, an auth gate driven by a stubbed `SessionCubit`
  (`unauthenticated` → welcome, `authenticated` → shell), a
  `StatefulShellRoute` app shell (Home section only for now), and a
  not-found route.
- Added the `lib/design/` design system (ADR-0007): semantic tokens for
  colour, spacing, radii, typography, elevation, and motion, delivered as
  a `ThemeExtension` and read through `context.tokens`; dark-first light
  and dark themes; and shared UX primitives — `AppScaffold`, shimmering
  `AppSkeleton`/`AppSkeletonList`, `EmptyStateView`, `ErrorStateView`
  (with failure-aware retry), `UnavailableContent`, and `AppButton`.
- Replaced the placeholder development shell with the real welcome and
  Home screens built on the design system.
- Added the Jellyfin transport layer (ADR-0008) under
  `lib/infrastructure/jellyfin/`: a `dio`-based `JellyfinHttpClient` whose
  request surface returns `Result` and never leaks a `DioException`;
  centralized `JellyfinClientIdentity` building the Jellyfin
  `Authorization` header, with an `AuthTokenProvider` seam for v0.0.5;
  `dio` interceptors for the identity/auth header, debug request
  correlation, and bounded GET-only retry; `JellyfinServerUrl`
  normalization; `ServerVersion` plus a one-line `MinimumServerVersionPolicy`
  (floor: Jellyfin 10.11.6); a `json_serializable` `PublicSystemInfoDto`;
  `TransportErrorMapper` normalizing transport failures to the ADR-0004
  model; and `JellyfinServerProbe.validate()` to check a server is
  reachable, really Jellyfin, and supported.
- Added `UnauthorizedFailure` and `UnsupportedServerFailure` to the core
  `Failure` hierarchy (note added to ADR-0004).
- Added `dio`, `json_annotation`, and `json_serializable` (dev)
  dependencies.
