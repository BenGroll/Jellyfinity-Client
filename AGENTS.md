# Jellyfinity agent guide

Read this file first. It defines the complete context-loading workflow.

## Minimal context workflow

1. Read `CONTEXT.md` (the stable product and engineering constraints).
2. Find the requested version in `ROADMAP.md` if the version is between two minor versions there are fitting roadmap files for that (e.g. version 0.1.5 would be in "Roadmap to v0.2.md" etc. Use them if you are finding something that fits).
3. Read only that version's linked specification. Do not read an entire roadmap.
4. Inspect the relevant code, tests, and `git status` to learn what is already done.
5. Read only ADRs directly related to the files or decisions in scope. Use
   `docs/adr/README.md` as the index.

Do **not** preload `README.md`, `PHILOSOPHY.md`, `OUTLOOK.md`, `CHANGELOG.md`,
the historical roadmap, or every ADR. Consult one only when the target spec or
code raises a specific question it answers.

## Starting a version task

Before editing, report in at most eight bullets:

- the requested version's goal;
- its required deliverables and definition of done;
- what the repository already appears to implement;
- any genuinely blocking ambiguity.

Then implement and verify the work. Ask a question only when different answers
would materially change the implementation; otherwise state a reasonable
assumption and continue. The roadmap defines scope, but the code and tests are
the source of truth for current state.

## Working rules

- Keep changes inside the requested version. Treat stretch items and explicit
  non-goals as out of scope.
- Preserve the feature-first clean architecture and dependency direction in
  `CONTEXT.md`.
- Do not expose raw Jellyfin DTOs or exceptions to presentation code.
- Add or update behavior-focused tests with behavior changes.
- Update an ADR only for a significant architectural decision.
- Update `CHANGELOG.md` when the feature is complete.
- Do not overwrite unrelated working-tree changes.

## Prompt to use

```text
Implement Jellyfinity vX.Y.Z. Follow AGENTS.md. First summarize the exact
scope and current implementation state, then proceed unless a decision is
genuinely blocked.
```
