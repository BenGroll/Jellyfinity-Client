# Jellyfinity agent routing

For a version task, run this once:

```text
python3 tools/agent_context.py vX.Y.Z
```

Use its bounded packet and listed touchpoints. Do not read the whole roadmap,
README, changelog, ADR index, or unrelated files. Search first and inspect only
matching symbols, callers, and tests. An unknown version is a hard stop: report
it instead of guessing.

Do not provide a plan or restate the task. Implement the bounded scope, run
focused checks, and commit on `vX.X.X-short-description` with the repository
format. Do not push or open a pull request. Preserve unrelated worktree
changes. For broader repository rules, use `CONTRIBUTING.md` only when needed.

Never print whole files over 200 lines, full diffs, or full test logs. Use
`rg`, bounded ranges, and focused tests; save long output under `/tmp` and
inspect only failures.
