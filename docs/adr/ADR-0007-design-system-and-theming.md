# ADR-0007: Design System & Theming

## Status

Accepted

## Context

`ROADMAP.md`'s v0.0.3 scope requires semantic design tokens (colours,
surfaces, text roles, spacing, radii, typography, elevation, motion), a
first theme abstraction, and shared UX primitives (loading skeletons,
empty/error/retry states, disabled/unavailable content, a standard page
structure), so that later features do not each invent their own visual
language.

`PHILOSOPHY.md` §9 and `OUTLOOK.md` §10 set a hard long-term requirement:
deep user theme customization through a *structured token system* with
serializable, shareable themes — never arbitrary CSS or executable theme
code. Whatever v0.0.3 builds must be the thing that customization layer
later plugs into, not something it has to replace.

`CONTEXT.md`'s "never leave the user guessing" rule means the
loading/empty/error/partial/unavailable states are a shared concern, not a
per-feature one.

## Options Considered

### Token delivery

1. **Token objects carried on `ThemeData` as a `ThemeExtension`, read via a
   `context.tokens` helper** (chosen) — one `AppTokens` extension bundles
   immutable token groups (`AppColors`, `AppSpacing`, `AppRadii`,
   `AppTypography`, `AppElevation`, `AppMotion`). Flutter animates it
   between light/dark via `lerp`. A matching Material `ColorScheme` and
   `TextTheme` are derived from the same palette so the Material widgets
   Jellyfinity does use stay consistent.
2. **A bespoke `InheritedWidget` theme, independent of `ThemeData`** —
   total control over token shape, but loses Material's built-in
   theme animation and forces every Material widget (text fields,
   switches, dialogs, `NavigationBar`) to be re-skinned or replaced.
   Rejected as more work for no v0.0.3 benefit; the `ThemeExtension`
   approach can still evolve toward this if Material ever gets in the way.
3. **Raw `ThemeData` only (Material's own `ColorScheme`/`TextTheme`)** —
   no custom tokens. Rejected: Material's semantic vocabulary
   (`primary`, `surfaceContainerHighest`, …) does not match Jellyfinity's
   (`accent`, `surfaceElevated`, `skeletonHighlight`, `textDisabled` for
   unavailable media), and it offers nothing for spacing/radii/motion.

### Shared UX primitives

Chosen: a small set of concrete widgets in `lib/design/components/`
(`AppScaffold`, `AppSkeleton`/`AppSkeletonList`, `StatusView` →
`EmptyStateView`/`ErrorStateView`, `UnavailableContent`/`UnavailableBadge`,
`AppButton`), each consuming only tokens. `ErrorStateView.forFailure`
reads the ADR-0004 `Failure` subtype to decide whether to offer retry
(`RecoverableFailure` → yes). Not chosen: a generic
`AsyncValue`-style view-state widget — per ADR-0002 each feature models its
own sealed Bloc states, so a one-size state switcher would fight that.

## Decision

- **`lib/design/`** holds the design system, exported through
  [`design.dart`](../../lib/design/design.dart). Feature widgets import
  that one file.
- **Tokens** (`lib/design/tokens/`) are immutable value types
  (`Equatable`), each with a static `lerp`. They carry no `BuildContext`
  and no Material dependency beyond `dart:ui`/`painting` types.
- **`AppTokens`** (`lib/design/theme/AppTokens.dart`) is the
  `ThemeExtension` bundling all groups.
  [`AppTheme`](../../lib/design/theme/AppTheme.dart) builds the light and
  dark `ThemeData`, each with its `AppTokens` plus a derived
  `ColorScheme`/`TextTheme`. Raw colour literals are allowed **only** in
  [`Palette.dart`](../../lib/design/theme/Palette.dart).
- **Access.** Widgets read
  [`context.tokens`](../../lib/design/theme/theme_context.dart) (or the
  `context.colors` / `context.spacing` / … shorthands). They must not read
  `Theme.of(context).colorScheme.*` or hard-code visual constants;
  reviews enforce this.
- **Dark-first.** `MaterialApp.themeMode` ships `ThemeMode.dark`
  (`PHILOSOPHY.md`'s "premium streaming app" intent). A light theme is
  fully defined; a future settings screen can expose the choice.
- **Motion** tokens are respected against the OS "reduce motion" setting
  (`MediaQuery.disableAnimationsOf`) — `AppSkeleton` and `AppButton`
  already do this.
- **Customization path.** A future theme-customization feature produces
  alternative `AppColors`/`AppTokens` instances (from a serializable
  representation) and swaps the extension. No feature widget changes,
  because none of them name a colour value directly. This ADR does not
  design that serialization format — that is a later decision — it only
  guarantees the seam exists.

## Consequences

- Every screen from v0.0.3 on has one place to get spacing, colour, type,
  and motion, and one set of loading/empty/error/unavailable widgets —
  the coherence `PHILOSOPHY.md` §2–3 demands is structurally enforced,
  not left to discipline per feature.
- Material widgets used incidentally still look right, because their
  `ColorScheme`/`TextTheme` come from the same palette.
- `ThemeExtension` requires hand-written `copyWith`/`lerp` and a `lerp`
  per token group — accepted boilerplate, isolated to `lib/design/`.
- The token set is intentionally small; groups gain fields when a real
  screen needs them, not speculatively.
- Committing to Material 3 `ThemeData` underneath means a future move to a
  fully bespoke theme tree (option 2) would be a real migration. Judged
  unlikely to be needed, and the `context.tokens` indirection means
  feature code would survive it.
