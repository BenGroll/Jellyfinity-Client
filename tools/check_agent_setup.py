#!/usr/bin/env python3
"""Validate the shared agent-routing inputs without verbose output."""

from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
roadmap = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")
versions = re.findall(r"^\| (v\d+\.\d+\.\d+) \|", roadmap, re.MULTILINE)
manifest = json.loads((ROOT / "tools" / "task_manifest.json").read_text(encoding="utf-8"))

for version in versions:
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "agent_context.py"), version, "--no-context"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode:
        print(result.stderr.strip(), file=sys.stderr)
        raise SystemExit(1)

for version, entry in manifest.items():
    if version not in versions:
        print(f"manifest version is not in ROADMAP.md: {version}", file=sys.stderr)
        raise SystemExit(1)
    for category in ("touchpoints", "tests"):
        for item in entry.get(category, []):
            if not (ROOT / item).exists():
                print(f"missing {category} path for {version}: {item}", file=sys.stderr)
                raise SystemExit(1)

for required in ("AGENTS.md", "CLAUDE.md", "CONTEXT.md", "prompt.md"):
    if not (ROOT / required).is_file():
        print(f"missing agent entry point: {required}", file=sys.stderr)
        raise SystemExit(1)

print(f"agent setup: OK ({len(versions)} roadmap routes, {len(manifest)} manifests)")
