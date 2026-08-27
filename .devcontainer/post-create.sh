#!/usr/bin/env bash
set -euo pipefail

echo
echo "=== Jellyfinity development environment ==="
echo

flutter --version
dart --version
java -version
node --version
npm --version
adb version
claude --version || true
codex --version || true

echo
echo "Running Flutter doctor..."
flutter doctor -v || true

echo
echo "Environment ready."
