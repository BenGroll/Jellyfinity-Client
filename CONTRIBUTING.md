# Contributing to Jellyfinity

Read `CONTEXT.md`, `ROADMAP.md`, `PHILOSOPHY.md`, and `OUTLOOK.md` before making significant changes.

## Scope

Work within the current roadmap milestone. Do not add speculative features or abstractions.

## Branches

Name a branch `vX.X.X-description-with-hyphens`, tying it to the roadmap
version it serves, e.g. `v0.0.7-media-domain` or
`v0.0.6-persistence-and-cache-foundation`. Always branch from an
up-to-date `main`:

```bash
git switch main && git pull
git switch -c v0.0.8-music-library
```

Never stack branches — branch from `main`, not from another unmerged
branch.

## Commit messages

```text
vX.X.X - (feature/bug/fix/chore) - actual message
```

Every commit ties to the roadmap version it belongs to, unless the
maintainer says otherwise for a given commit. The type is one of
`feature`, `bug`, `fix`, or `chore`. The message itself should read
naturally and vary between commits — avoid an obviously templated,
uniform, machine-generated cadence.

Example: `v0.0.7 - feature - add BaseItemMapper for Jellyfin item DTOs`

## File naming

A file that declares exactly one top-level class is named after that
class, in `PascalCase` (e.g. `class MediaId` lives in `MediaId.dart`).
This is Jellyfinity's one deliberate departure from Dart's usual
`lower_case_with_underscores` file-naming convention; `analysis_options.yaml`
disables `flutter_lints`' `file_names` rule for it.

Everything else keeps `lower_case_with_underscores`:

- files with no class (barrel/`library;` files, enums, extensions,
  typedefs, top-level-function files);
- files with more than one class;
- every `..._test.dart` file, regardless of what it declares — the
  `_test.dart` suffix is how `flutter test` discovers tests, so it is
  never renamed away.

## Before committing

Run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test

Run flutter build apk --debug when Android build configuration changes.
Changes
Keep commits focused. Update relevant documentation when behavior, setup, or architecture changes. Never commit credentials, tokens, local IDE settings, or agent state.

Create `CHANGELOG.md`:

```markdown
# Changelog

## Unreleased

- Initialized the Flutter Android and iOS application.
- Added the reproducible development container.
- Added Windows-hosted Android emulator support through ADB.