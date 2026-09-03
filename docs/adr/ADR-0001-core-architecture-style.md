# ADR-0001: Core Architecture Style

## Status

Accepted

## Context

Jellyfinity is starting its application-architecture core (v0.0.2) before
any transport, authentication, persistence, or media feature exists. Every
later milestone (transport, auth, persistence, media domain, music library,
playback, and eventually movies/TV) needs a shared, consistent shape to
build against, or each feature will invent its own layering, error
handling, and dependency conventions independently.

`CONTEXT.md` and `PHILOSOPHY.md` already state a preferred direction:
feature-first Clean Architecture with shared modules only where they
genuinely span features, and a one-directional dependency flow. This ADR
formalizes that direction as the binding convention for the codebase.

## Options Considered

1. **Feature-first Clean Architecture** (chosen) — each feature owns its
   own presentation/domain/infrastructure code; genuinely cross-feature
   concerns graduate into shared `core`/`domain`/`infrastructure` modules.
2. **Layer-first ("horizontal") architecture** — top-level folders per
   technical layer (`controllers/`, `models/`, `views/`,
   `repositories/`), with every feature's code interleaved inside each.
   Rejected: `CONTEXT.md` explicitly calls this out as "global folder
   dumping" to avoid; it scales poorly past a handful of features and
   makes feature boundaries (and eventual feature removal/rework) hard to
   see.
3. **Full plugin/module framework** — features as dynamically
   loaded/isolated modules with a formal plugin API. Rejected as
   premature: `CONTEXT.md` explicitly says not to prematurely build a
   plugin framework; Jellyfinity has no current requirement for
   runtime-pluggable features.

## Decision

Jellyfinity uses **feature-first Clean Architecture with shared
domain/infrastructure modules where they genuinely span features**.

Dependency direction (all layers):

```text
UI
 ↓
Presentation
 ↓
Domain / Repository Contracts
 ↑
Infrastructure Implementations
```

- UI depends on Presentation.
- Presentation depends on Domain (repository/use-case **contracts**, not
  concrete infrastructure).
- Infrastructure implements Domain contracts; Domain never depends on
  Infrastructure.
- Widgets never consume raw Jellyfin API DTOs directly. Layers keep
  distinct model types: Jellyfin API models (infrastructure), Jellyfinity
  domain models, presentation state, and persistence models are separate
  types, with explicit mapping between them at layer boundaries.

Folder shape:

- `lib/features/<feature>/` — a feature's own presentation, and any
  domain/infrastructure code that is genuinely specific to that feature
  only. Most product features live here.
- `lib/domain/` — domain models and repository/use-case **contracts**
  that are genuinely shared across more than one feature.
- `lib/infrastructure/` — infrastructure implementations that are
  genuinely shared across more than one feature (e.g. the Jellyfin HTTP
  client, once it exists).
- `lib/core/` — architecture-level primitives with no feature or product
  meaning of their own (Result/error model, logging, configuration). Code
  here must not depend on `lib/domain`, `lib/infrastructure`, or
  `lib/features`.
- `lib/app/` — the composition root: bootstrap and dependency wiring.
  Depends on everything; nothing depends on it.
- `lib/design/` — design tokens/primitives (introduced starting v0.0.3).

A module only moves from a feature into `lib/domain`/`lib/infrastructure`
once a second feature genuinely needs it — shared modules are extracted
when duplication becomes real, not speculatively.

## Consequences

- Feature folders can be read, reviewed, and eventually removed or
  reworked in isolation.
- Contributors have one place to look for cross-cutting primitives
  (`lib/core`) and one place to look for the composition root
  (`lib/app`), rather than every feature re-solving bootstrap/DI/logging.
- Domain code stays free of Jellyfin transport/DTO concerns, which keeps
  it testable without a server and keeps the API surface swappable.
- This requires discipline: a feature must not reach into another
  feature's internals, and shared code must not accumulate
  feature-specific special cases. Reviews should watch for both.
- No empty speculative folders are created ahead of need; `lib/domain` and
  `lib/infrastructure` may stay nearly empty until the transport (v0.0.4)
  and media-domain (v0.0.7) milestones give them real content.
