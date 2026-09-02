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