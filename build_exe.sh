#!/usr/bin/env bash
#
# Build the checked-out app with Windows Flutter from Git Bash/MSYS2.
#
#   ./build_exe.sh              # release build
#   MODE=debug ./build_exe.sh   # debug build (also supports profile)
#   CLEAN=1 ./build_exe.sh      # flutter clean first
#   PUB_GET=1 ./build_exe.sh    # refresh dependencies before building
#
# Output: build/exe/jellyfinity-<branch>-<sha>[-dirty]-windows-x64-<mode>-<id>/
# Run jellyfinity.exe there. Distribute the whole directory, including DLLs/data.

set -euo pipefail

cd "$(dirname "$0")"
[ -f pubspec.yaml ] || { echo "build_exe.sh: Flutter project root not found" >&2; exit 1; }

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) echo "build_exe.sh: use Git Bash on Windows with Windows Flutter and Visual Studio C++ installed (not WSL)." >&2; exit 1 ;;
esac

MODE="${MODE:-release}"
case "$MODE" in
  release) configuration=Release ;;
  debug) configuration=Debug ;;
  profile) configuration=Profile ;;
  *) echo "build_exe.sh: MODE must be release, debug, or profile" >&2; exit 1 ;;
esac
command -v flutter >/dev/null || { echo "build_exe.sh: add Windows Flutter's bin directory to PATH" >&2; exit 1; }

if git rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git rev-parse --abbrev-ref HEAD)"
  sha="$(git rev-parse --short HEAD)"
  if [ -z "$(git status --porcelain --untracked-files=normal)" ]; then dirty=""; else dirty="-dirty"; fi
else
  branch=nogit; sha=nogit; dirty=""
fi
# Git branch names can contain characters that Windows filenames cannot.
branch="$(printf '%s' "$branch" | LC_ALL=C tr -c 'a-zA-Z0-9._-' '-')"
stamp="${branch:0:80}-${sha}${dirty}"

echo "==> Jellyfinity Windows build"
echo "    tree : $stamp"
echo "    mode : $MODE"
flutter --version

if [ "${CLEAN:-0}" = 1 ]; then flutter clean; fi
if [ "${PUB_GET:-0}" = 1 ] || [ ! -f .dart_tool/package_config.json ]; then
  flutter pub get
else
  echo "    deps : reusing .dart_tool/package_config.json (set PUB_GET=1 to refresh)"
fi

echo
echo "==> flutter build windows --$MODE --no-pub"
flutter build windows "--$MODE" --no-pub

source_dir="build/windows/x64/runner/$configuration"
[ -f "$source_dir/jellyfinity.exe" ] || { echo "build_exe.sh: expected executable missing from $source_dir" >&2; exit 1; }
[ -f "$source_dir/flutter_windows.dll" ] && [ -d "$source_dir/data" ] || {
  echo "build_exe.sh: incomplete Windows runtime in $source_dir" >&2; exit 1;
}

# A fresh directory avoids mixing stale DLLs with a new build and keeps previous
# exports available. CLEAN=1 removes them as part of Flutter's build cleanup.
mkdir -p build/exe
destination="$(mktemp -d "build/exe/jellyfinity-${stamp}-windows-x64-${MODE}-XXXXXX")"
cp -R "$source_dir/." "$destination/"

echo
echo "==> Done. Run: $destination/jellyfinity.exe"
echo "    Share the entire folder, including DLLs and data."
ls -lh "$destination/jellyfinity.exe"
