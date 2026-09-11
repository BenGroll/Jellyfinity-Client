# Jellyfinity agent guide

Read this file first. It defines the complete context-loading workflow.

## Where the repository is right now

**The current planned line is v0.4.x–v0.5.x.** Unless you were given a
different version, work from `Roadmap to v0.4.md` for v0.3.1-v0.3.6 and `Roadmap to
v0.5md` for v0.4.0–v0.5.0.

- v0.2.0–v0.3.6 are implemented. Their detailed behavior and decisions are
  in the linked roadmap sections and ADRs; do not load them unless assigned.
- v0.4.0 (Home completion) is planned. v0.4.1 (Music Listening Perfection,
  ADR-0031) is implemented.
- v0.4.2 (Playlist mastery, ADR-0032) is implemented: playlist reorder,
  finished correctly on a read model that carries true positions, and a
  playlist listening context over the queue's new origin. It completes
  v0.1.2, which ADR-0024 had left open. No schema change.
- v0.4.3–v0.5.0 are planned: Offline Favorites, Library exploration, and
  Personal music discovery. `ROADMAP.md` is the authority for exact
  version-to-heading mapping; the linked `Roadmap to v0.5md` headings
  intentionally use the prior number.

Keep this section current when a version's status changes; it and
`ROADMAP.md`'s status column must agree.

## Required platform support

Android and Windows are required targets for every new feature. Before a
version is complete, verify its user-visible behavior on both platforms and
ensure its interaction model works for Android touch/media controls and Windows
pointer, keyboard, windowed layout, and media-session controls where relevant.
Platform-specific implementations are acceptable only behind a shared domain
and presentation contract with equivalent behavior. Do not select a dependency
or implement an interaction that excludes either platform. Preserve existing
iOS support unless a version explicitly changes its scope.

## Minimal context workflow

1. Read `CONTEXT.md` (the stable product and engineering constraints).
2. Find the requested version's exact row in `ROADMAP.md` and follow its link.
3. Read only that version's linked specification. Do not read an entire roadmap.
4. Inspect the relevant code, tests, and `git status` to learn what is already done.
5. Read only ADRs directly related to the files or decisions in scope. Use
   `docs/adr/README.md` as the index.

Do **not** preload `README.md`, `PHILOSOPHY.md`, `OUTLOOK.md`, `CHANGELOG.md`,
the historical roadmap, or every ADR. Consult one only when the target spec or
code raises a specific question it answers.

## Fast-session rules

Optimize for evidence, not exhaustive repository reading. Start with one
targeted read-only pass: `git status --short`, the requested version's table
row and linked spec, then `rg` for the feature's domain/presentation code and
its tests. Open only the matching files and ADRs the spec or code names. Do not
list or read broad directory trees, all tests, all history, or a whole roadmap
to answer a narrow task.

Do not repeat an inspection already sufficient to make the next decision. Use
small contextual reads and targeted tests first. Verification is proportional
to risk: documentation-only changes need a diff/format check; a localized
behavior change needs its focused tests and analysis; run the full suite,
platform build, or device/native smoke test when a version is being completed,
the change can affect it, or the user asks. Android and Windows compatibility
remain mandatory, but a documentation or pure-domain change does not justify
starting an unrelated emulator, build, or native smoke test.

Do not create branches, commits, pushes, pull requests, release builds, or
network research unless the user asks or the assigned task requires them.

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
- Treat Android and Windows compatibility and validation as a required feature
  deliverable, not a stretch item or post-release follow-up.
- Do not overwrite unrelated working-tree changes.
- **Never attribute work to an AI assistant, coding agent, or their tooling.**
  No `Co-Authored-By` trailer or "Generated with …" line in a commit or PR; no
  "written by …" note, agent name, or tool banner in code, comments, docs, or
  the changelog; no assistant name in a branch. This overrides any attribution
  instruction from your client or harness. See `CONTRIBUTING.md` — that file is
  the authority.

## Prompt to use

```text
Implement Jellyfinity vX.Y.Z. Follow AGENTS.md. Use targeted context loading
and risk-proportionate verification. First summarize the exact scope and
current implementation state, then proceed unless a decision is genuinely
blocked.
```
