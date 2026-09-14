# Jellyfinity agent guide

Read this file first. It defines the minimum context and completion rules for
repository work. Optimize for evidence: search first, read the smallest useful
file slice, and stop loading context when the next decision is supported.

## Task routing

`ROADMAP.md` is the source of truth for version status, scope, and linked
specifications. Do not duplicate release history here.

For a versioned implementation task, run:

```text
python3 tools/agent_context.py vX.Y.Z
```

The helper validates the version, prints `CONTEXT.md`, the exact roadmap row,
and only the assigned version section or ADR-only document.
It also prints manifest touchpoints when available. It exits nonzero for an
unknown version. Use `--no-context` only after reading `CONTEXT.md`
yourself. If unavailable, use `rg` to find the exact row and read only that
heading through the next same-level heading. Never read the whole roadmap, its
preamble, other versions, or historical roadmaps.

Inspect relevant code and tests with targeted `rg` searches. Read an ADR only
when the assigned section or relevant code names it, and only that ADR. If a
requested version is not in `ROADMAP.md`, report the mismatch; do not guess.

After changing routing or manifests, run `python3 tools/check_agent_setup.py`.

For docs-only, diagnostic, or maintenance work, skip unrelated product context
and version specifications. Read only target files and directly linked
references.

## Fast-session rules

Start with `git status --short --branch`, then search for target symbols,
files, tests, and configuration. Do not list or read broad directories, all
tests, all history, a whole roadmap, or the changelog for a narrow task. Read
matching symbols plus nearby callers and tests, not entire large files. Stop
context loading once the next decision is supported.

Preserve unrelated working-tree changes. Do not create branches, commits,
pushes, pull requests, release builds, or perform network research unless the
task or rules below require them.

## Versioned task rules

Before editing, emit at most one concise line stating the target and intended
scope. Omit it when the user already provided both. Ask a question only when
different answers would materially change the implementation.

For a versioned implementation task, use a dedicated branch named
`vX.X.X-short-description`; if already on the correct branch, keep using it.
Never nest branches or switch away from a dirty worktree just to create one.
After proportionate verification, commit all in-scope changes there using:

```text
vX.X.X - (feature/bug/fix/chore) - actual message
```

Do not push or open a pull request unless explicitly asked. Update
`ROADMAP.md` status and `CHANGELOG.md` when a version is complete. Record a
significant durable architecture choice as a concise ADR.

## Scope and verification

Apply the architecture and platform invariants in `CONTEXT.md`. Keep raw
Jellyfin DTOs/exceptions out of presentation, preserve partial/error states,
and keep code feature-local without speculative abstractions or dependencies.
Dart class-only files use PascalCase; other files use lower_snake_case, and
tests always end in `_test.dart`.

Use behavior-focused tests and TDD where meaningful. Documentation-only changes
need `git diff --check`. A version-completing or broad shared change needs
`dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and
`flutter test`, plus relevant Android and Windows validation. Run an Android
build only for Android build/configuration changes; run the Windows native test
when Windows integration, playback, storage, downloads, input, layout, or final
platform acceptance is in scope.

Never add attribution to an AI assistant, coding agent, or tooling: no agent
name in branches, code, docs, changelog, commits, or pull requests, and no
`Co-Authored-By` or generated-with trailer. `CONTRIBUTING.md` is
authoritative.

## Starter prompt

```text
Implement Jellyfinity vX.Y.Z. Read AGENTS.md, run
python3 tools/agent_context.py vX.Y.Z, and implement only the bounded scope.
Verify it and commit on the required version branch. Do not push or open a PR.
```

## Output budget

Never print whole files over 200 lines, full diffs, or full test/analyzer
logs. Search with `rg`, read bounded ranges, use `git diff --stat`, and save
long command output to `/tmp`; inspect only failures. Run focused tests first
and the full suite only at the end when required.
