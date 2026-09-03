# ADR-0002: State Management

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.2 scope requires selecting the primary Flutter
state-management approach and recording the choice, evaluated for
testability, async state representation, lifecycle behavior, contributor
ergonomics, scalability, and dependency cost. This choice underpins every
later feature (music library browsing at ~130k songs, playback/queue
state, download state), so it is treated as durable rather than decided
silently.

Jellyfinity's product rules place unusual weight on **state fidelity**:
`CONTEXT.md` requires distinguishing loading, empty, partial, offline,
cached, unavailable, failed, unauthorized, downloading, and downloaded
states, and requires that a persistent playback queue survive navigation
and background execution. Whatever is chosen needs to make those states
easy to represent correctly and consistently, not just possible.

## Options Considered

1. **Riverpod** — provider-based, context-independent, ships an async
   union type (`AsyncValue`) that maps closely onto
   loading/data/error/partial states; strong test-container-based
   testability; can also serve as the dependency-injection mechanism.
2. **flutter_bloc (Bloc/Cubit)** (chosen) — explicit event/method →
   immutable-state model. No built-in async union type (state classes are
   hand-modeled per feature, e.g. sealed `Loading`/`Loaded`/`Partial`/
   `Error` variants), which is more boilerplate per feature but keeps
   every state transition explicit and independently testable via
   `bloc_test`. Does not provide dependency injection; requires a
   separate DI mechanism (see ADR-0003).
3. **`ChangeNotifier` + `provider`** — Flutter's own primitive plus the
   `provider` package. Lowest dependency cost and learning curve, but no
   structured async/partial-state representation; requires the most
   hand-rolled discipline to keep loading/partial/error states
   consistent at library scale.

## Decision

Jellyfinity uses **flutter_bloc** (`Bloc` for multi-event/complex flows,
`Cubit` for simpler direct-method state changes) as its state-management
approach, evaluated and chosen by the project owner over Riverpod and
`ChangeNotifier`/`provider`.

Conventions:

- Each feature that needs non-trivial state defines its own
  Bloc/Cubit(s) under its feature folder (`lib/features/<feature>/...`),
  scoped no more broadly than the feature needs.
- State classes are immutable and use `equatable` for value equality
  (already a `flutter_bloc` companion dependency).
- Async/partial/error states are modeled explicitly per feature as sealed
  state classes (or sealed sub-states within one state class), built on
  the shared `Result`/`Failure`/`Partial` types from ADR-0004 rather than
  each feature inventing its own success/failure shape. A Bloc's
  event handler typically calls a use case/repository returning
  `Result<T>` and maps `Ok`/`Err` onto its own state types via
  `Result.when`.
- Blocs/Cubits are provided into the widget tree via `BlocProvider`
  (`MultiBlocProvider` where a screen needs several), scoped to the
  narrowest widget subtree that needs them. Cross-cutting state that must
  outlive individual screens (e.g. the eventual playback queue) is
  provided high enough in the tree to survive navigation — this is
  established starting with the feature that introduces it, not
  speculatively now.
- Blocs/Cubits depend on repository/use-case **contracts** (domain layer,
  per ADR-0001), resolved through the DI composition root (ADR-0003), not
  on infrastructure implementations directly.
- Tests use `bloc_test`'s `blocTest()` to assert exact state-emission
  sequences from a given sequence of events/inputs.

No concrete product Bloc/Cubit is introduced in v0.0.2 itself — see
ADR-0004 and the v0.0.2 test suite for how the pattern is proven without a
permanent fake feature.

## Consequences

- Every state transition in the app is an explicit, independently
  testable unit (an event or Cubit method → an emitted state), which
  fits the "never leave the user guessing" product rule well: reviewers
  can see every state a screen can be in by reading its state class.
- More boilerplate per feature than Riverpod's `AsyncValue` would have
  provided; this is accepted in exchange for explicitness and the wide
  existing familiarity/tooling around Bloc in production Flutter apps.
- State management and dependency injection are separate concerns/
  packages (see ADR-0003), which keeps them independently replaceable
  but means there are two conventions to learn instead of one.
- Widgets depend on `flutter_bloc`'s `BuildContext`-based providers
  (`BlocProvider.of`/`context.read`/`context.watch`), which is consistent
  with Flutter's own idioms and requires no special test harness beyond
  normal widget testing plus `bloc_test` for the Bloc/Cubit logic itself.
