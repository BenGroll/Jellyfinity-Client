# ADR-0005: Logging and Configuration Conventions

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.2 scope requires a logging abstraction suitable for
development and production that respects the privacy philosophy (no
credentials/tokens ever logged), and configuration conventions "without
introducing unnecessary build complexity." Neither needs a durable,
hard-to-reverse third-party choice the way state management/DI did, but
both are cross-cutting enough to warrant a documented convention up
front rather than each feature inventing its own.

## Decision

### Logging

[`lib/core/logging/Logger.dart`](../../lib/core/logging/Logger.dart)
defines an abstract `Logger` (`debug`/`info`/`warning`/`error`), resolved
through DI (ADR-0003) rather than called as a global. Call sites depend
on the abstraction, never on a concrete logger.

[`ConsoleLogger`](../../lib/core/logging/ConsoleLogger.dart) is the only
implementation for now: it writes to the console via `debugPrint`, with
`debug`-level messages suppressed outside `kDebugMode`. This is
sufficient for local development; a production-appropriate sink (e.g. a
file, or a crash-report integration) can be added later as a second
`Logger` implementation without changing any call site, consistent with
the project's "no unnecessary telemetry" rule — nothing beyond local
console output is wired up in v0.0.2.

**Privacy rule** (documented directly on `Logger`): no credentials, auth
tokens, session identifiers, or other sensitive user data may be passed
to a `Logger` method, at any level, including `debug`. Where a value's
presence (not its content) is a useful diagnostic, `redact()` masks all
but a short prefix instead of logging the value in full. This rule is
enforced by code review, not automated tooling, in v0.0.2; automated
enforcement (e.g. a lint) can be revisited if the codebase's real usage
shows it's needed once transport/auth (v0.0.4/v0.0.5) start handling
actual tokens.

### Configuration

[`lib/core/config/AppConfig.dart`](../../lib/core/config/AppConfig.dart)
defines `AppConfig`, read via `--dart-define` compile-time environment
variables (`AppConfig.fromEnvironment()`), with development-friendly
defaults so the app runs correctly with zero flags. No build-flavor
system (e.g. separate Android/iOS build flavors, per-environment
entrypoints) is introduced in v0.0.2 — `ROADMAP.md` explicitly asks for
configuration conventions "without unnecessary build complexity," and
nothing in the roadmap up to v0.1.0 currently requires flavors.

`AppConfig` is registered directly by `bootstrap()` (see ADR-0003) rather
than resolved via an injectable annotation, since its construction reads
process environment state rather than depending on other injectable
classes.

`AppConfig` is scoped to build/environment-level configuration only. It
must not grow into a general user-preferences store — user-facing
settings (e.g. saved servers, playback preferences) belong to the
persistence-layer feature introduced at the v0.0.6 milestone.

## Consequences

- Adding a second `Logger` implementation (e.g. for production
  diagnostics) later requires no change to any call site.
- The privacy rule lives in one place (`Logger`'s documentation) that
  every future feature touching tokens/credentials (starting at v0.0.4/
  v0.0.5) can be reviewed against.
- Configuration stays a single small class read at startup; if the
  project later genuinely needs build flavors (e.g. distinct
  debug/staging/release app IDs), that is a new decision to make then,
  not one this ADR forecloses.
