#!/usr/bin/env python3
"""Print the minimum version context needed by an implementation agent."""

from pathlib import Path
import json
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
VERSION_RE = re.compile(r"v\d+\.\d+\.\d+")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


def fail(message):
    print(f"agent-context: {message}", file=sys.stderr)
    raise SystemExit(2)


def normalized(value):
    value = re.sub(r"v(\d+)\.(\d+)\.(\d+)", r"v\1\2\3", value.lower())
    return re.sub(r"[^a-z0-9]+", "-", value).strip("-")


args = sys.argv[1:]
if len(args) not in (1, 2) or args[0] in ("-h", "--help"):
    print("usage: agent_context.py vX.Y.Z [--no-context]")
    raise SystemExit(0 if args and args[0].startswith("-") else 2)

version = args[0]
if not VERSION_RE.fullmatch(version) or (len(args) == 2 and args[1] != "--no-context"):
    fail("expected a version such as v0.5.6")

roadmap = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")
row = next((line for line in roadmap.splitlines()
            if line.startswith(f"| {version} |")), None)
if row is None:
    fail(f"{version} is not in ROADMAP.md")

links = re.findall(r"\[[^]]+\]\(([^)]+)\)", row)
if not links:
    fail(f"{version} has no linked specification")
link = links[0]
target, _, anchor = link.partition("#")
target = unquote(target)
spec_path = ROOT / target
if not spec_path.is_file():
    fail(f"linked file does not exist: {target}")

print(f"# Bounded context: {version}")
print(row)

manifest_path = ROOT / "tools" / "task_manifest.json"
if manifest_path.is_file():
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entry = manifest.get(version)
    if entry:
        print("\n## Start here")
        print("Touchpoints:")
        for item in entry.get("touchpoints", []):
            print(f"- {item}")
        print("Tests:")
        for item in entry.get("tests", []):
            print(f"- {item}")
        print("Non-goals:")
        for item in entry.get("non_goals", []):
            print(f"- {item}")

if "--no-context" not in args:
    print("\n## CONTEXT.md")
    print((ROOT / "CONTEXT.md").read_text(encoding="utf-8").rstrip())

text = spec_path.read_text(encoding="utf-8").splitlines()
if target.startswith("docs/adr/"):
    print(f"\n## {target}")
    print("\n".join(text).rstrip())
    raise SystemExit(0)

start = None
level = None
wanted_anchor = normalized(unquote(anchor))
for index, line in enumerate(text):
    match = HEADING_RE.match(line)
    if not match:
        continue
    title = match.group(2)
    if title.startswith(version) or (wanted_anchor and normalized(title) == wanted_anchor):
        start = index
        level = len(match.group(1))
        break
if start is None:
    fail(f"could not find the linked section for {version} in {target}")

end = len(text)
for index in range(start + 1, len(text)):
    match = HEADING_RE.match(text[index])
    if match and len(match.group(1)) == level:
        end = index
        break

print(f"\n## {target} — assigned section")
print("\n".join(text[start:end]).rstrip())
