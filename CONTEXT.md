# Jellyfinity context

Jellyfinity is a free, open-source Flutter client for Jellyfin, primarily for
Android and iOS. Its promise is to make a self-hosted server feel like a
polished streaming service. Minimum supported server: **Jellyfin 10.11.6**.

This file contains only constraints that commonly affect implementation. Read
`PHILOSOPHY.md` for product rationale or `OUTLOOK.md` for uncommitted future
ideas only when a concrete decision requires them.

## Product invariants

- Never leave users guessing. Distinguish loading, empty, partial, offline,
  cached, unavailable, unauthorized, and failed states. Prefer usable partial
  results to failing a whole screen.
- UX feedback, loading behavior, error handling, and perceived reliability are
  part of feature completion.
- Music is the initial focus; movies and TV remain future first-class media.
- Offline is primarily an item's availability state. A user may also switch the
  whole app offline deliberately ("Work offline"), and choose whether that view
  is the full cached library or downloads only (v0.2.3, ADR-0023); this is a
  convenience over the availability model, not a rebuild of it. Downloaded media
  is first-class local media and is not disposable cache.
- No ads, paid tiers, unnecessary telemetry, or unnecessary cloud dependency.
- Treat roughly 130k songs, 500 movies, and 4k episodes as normal scale. Use
  pagination, lazy/virtualized lists, server-side filtering, indexed storage,
  and bounded caches; never load a whole library into memory.

## Architecture invariants

Use feature-first Clean Architecture with shared modules only for concepts that
genuinely span features:

```text
UI -> presentation -> domain contracts <- infrastructure implementations
```

- Widgets must not consume raw Jellyfin JSON/API DTOs.
- Keep transport, domain, presentation, and persistence models distinct.
- Keep `Server`, `User`, credentials, session, saved account, and active account
  distinct.
- The playback queue belongs to Jellyfinity's application/domain state, not to
  an audio package.
- Prefer feature-local code. Do not build speculative abstractions or a plugin
  framework.
- Dependencies should handle substantial infrastructure work, remain
  replaceable, and not substitute for trivial local code.

## Engineering invariants

- Use TDD where meaningful and test behavior/contracts rather than coverage.
- Preserve useful partial state and normalize failures; never leak raw
  exceptions into UI.
- Record significant, durable architecture choices as concise ADRs.
- Keep `main` releasable; use focused changes, meaningful commits, CI, semantic
  versions, and changelog updates.
- Before a major decision, check mobile support, large-library behavior,
  testability, offline implications, dependency direction, and replaceability.

## Documentation routing

- `AGENTS.md`: mandatory minimal workflow for implementation agents.
- `ROADMAP.md`: version/status index and links to exact specifications.
- `docs/adr/README.md`: architecture decision index.
- `README.md`: human development-environment setup.
- `PHILOSOPHY.md`: detailed rationale; consult on product ambiguity.
- `OUTLOOK.md`: uncommitted future ideas; not current scope.
- `CHANGELOG.md`: implemented history; search it when current state is unclear.
