# ADR-0003: Dependency Injection / Composition Root

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.2 scope requires selecting and implementing a
dependency-injection/composition strategy, avoiding hidden global state
where practical, with a clear composition root. ADR-0002 selects
`flutter_bloc` for state management, which — unlike Riverpod — has no
built-in dependency-wiring mechanism of its own, so DI is a genuinely
separate decision here.

## Options Considered

1. **Riverpod providers as the composition root** — not applicable on its
   own once Bloc (not Riverpod) was chosen for state in ADR-0002; adding
   Riverpod solely for DI would mean depending on two competing
   state/DI ecosystems at once. Rejected for that reason.
2. **`get_it` + `injectable`** (chosen) — `get_it` is a runtime service
   locator; `injectable` generates its registrations from annotations via
   `build_runner`, so most services need no hand-written registration
   code. Fully decoupled from state management, which fits pairing with
   Bloc. Registration correctness for annotated classes is checked at
   codegen time; resolution is still a runtime lookup.
3. **Manual constructor injection** — a hand-written composition root
   with no DI package. Zero dependency cost and fully compile-time safe,
   but every registration is hand-maintained, which was judged likely to
   become the largest source of composition-root boilerplate across the
   many services the roadmap anticipates (transport, auth, persistence,
   media repositories, playback, downloads).

## Decision

Jellyfinity uses **`get_it` + `injectable`**, chosen by the project owner
over Riverpod-as-DI and manual constructor injection.

Composition root: [`lib/app/di/service_locator.dart`](../../lib/app/di/service_locator.dart)
defines the single `GetIt` instance (`getIt`) and `configureDependencies()`,
which delegates to the `injectable`-generated `getIt.init()`
(`service_locator.config.dart`, generated — see below). [`lib/app/bootstrap.dart`](../../lib/app/bootstrap.dart)
is the only place that calls `configureDependencies()`, as part of application
startup, before `runApp` is called.

Conventions:

- A class becomes injectable by annotating it (`@injectable`,
  `@singleton`, or `@LazySingleton(as: AbstractType)` when binding an
  interface to an implementation) and depending on its constructor
  parameters, which `injectable` resolves recursively.
- Run `dart run build_runner build --delete-conflicting-outputs` after
  adding/changing an injectable annotation. The generated
  `service_locator.config.dart` is committed to the repository (no CI
  exists yet to regenerate it as part of a build), and must never be
  hand-edited.
- Values built from runtime/environment state rather than plain class
  dependencies (e.g. `AppConfig`, read from `--dart-define` — see
  ADR-0004's configuration section) are registered directly with `getIt`
  by `bootstrap()`, ahead of `configureDependencies()`, rather than via an
  injectable annotation. This keeps construction logic that depends on
  environment/process state next to the value it produces instead of
  spreading it across DI modules.
- Application code resolves dependencies through constructor injection.
  `getIt` itself is reached into directly only at composition edges
  (`bootstrap.dart`, and widget-tree wiring such as handing a resolved
  repository to a `BlocProvider`'s create callback) — not from inside
  domain, infrastructure, or presentation logic — to avoid the service
  locator becoming ambient hidden state throughout the codebase.
- Tests that need DI reset `GetIt.instance` (`getIt.reset()`) between
  cases and register only the fakes/mocks a given test needs, rather than
  relying on the full production graph.

## Consequences

- DI stays fully independent of the state-management choice: either
  could change later without forcing a change to the other.
- Most services need no hand-written registration code, which keeps the
  composition root small as the roadmap adds transport, auth,
  persistence, and media-domain services.
- A generated file is committed to the repository and must be
  regenerated (and reviewed) whenever an injectable annotation changes;
  forgetting to regenerate produces a stale registration that a codegen
  step, not the analyzer, would normally catch. Since there is no CI yet,
  this is a manual discipline point until CI is introduced.
- Registration correctness for `@injectable`-annotated classes is
  verified at build_runner time, but resolution failures for
  incorrectly-wired dependencies still surface at runtime (via `GetIt`),
  not at `dart analyze` time.
