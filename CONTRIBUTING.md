# Contributing to Jellyfinity

Read `CONTEXT.md`, `ROADMAP.md`, `PHILOSOPHY.md`, and `OUTLOOK.md` before making significant changes.

## Scope

Work within the current roadmap milestone. Do not add speculative features or abstractions.

## Branches

Use focused branches:

- `feature/...`
- `fix/...`
- `refactor/...`
- `docs/...`
- `chore/...`

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