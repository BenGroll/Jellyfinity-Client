#!/usr/bin/env bash
#
# build_apk.sh — build debug AND release APKs of whatever is checked out.
#
#   ./build_apk.sh              # arm64 only (small, fits most phones), debug + release
#   ABI=all ./build_apk.sh      # one fat APK per mode, every ABI
#   ABI=android-arm,android-arm64 ./build_apk.sh   # explicit ABI list
#   CLEAN=1 ./build_apk.sh      # flutter clean first
#
# Output: build/apk/jellyfinity-<branch>-<sha>[-dirty]-<abi>-<mode>.apk
# Release APKs are signed with the debug key (see android/app/build.gradle.kts),
# so they install and run standalone but are not Play-Store uploadable as-is.

set -euo pipefail

cd "$(dirname "$0")"
[ -f pubspec.yaml ] || { echo "build_apk.sh: run me from the Flutter project root" >&2; exit 1; }

ABI="${ABI:-android-arm64}"
OUT_DIR="build/apk"

# --- provenance so you can tell the APKs apart -----------------------------
if git rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git rev-parse --abbrev-ref HEAD)"
  sha="$(git rev-parse --short HEAD)"
  if git diff --quiet && git diff --cached --quiet; then dirty=""; else dirty="-dirty"; fi
else
  branch="nogit"; sha="nogit"; dirty=""
fi
stamp="${branch//\//-}-${sha}${dirty}"

# --- build args -----------------------------------------------------------
build_args=()
if [ "$ABI" != "all" ]; then
  build_args=(--split-per-abi --target-platform "$ABI")
fi

echo "==> Jellyfinity APK build"
echo "    tree : $stamp"
echo "    abi  : $ABI"
flutter --version | head -1

[ "${CLEAN:-0}" = "1" ] && flutter clean
flutter pub get

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

aapt2="$(ls /opt/android-sdk/build-tools/*/aapt2 "${ANDROID_HOME:-/nonexistent}"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)"

split_mode=$([ ${#build_args[@]} -gt 0 ] && echo 1 || echo 0)

for mode in debug release; do
  echo
  echo "==> flutter build apk --$mode ${build_args[*]:-}"
  rm -f build/app/outputs/flutter-apk/*.apk
  flutter build apk "--$mode" ${build_args[@]+"${build_args[@]}"}

  shopt -s nullglob
  for f in build/app/outputs/flutter-apk/*"${mode}".apk; do
    # In --split-per-abi builds Flutter also drops a universal app-<mode>.apk;
    # skip it so an `ABI=android-arm64` run yields only the arm64 APK.
    [ "$split_mode" = 1 ] && [ "${f##*/}" = "app-${mode}.apk" ] && continue
    dest="$OUT_DIR/jellyfinity-${stamp}-${f##*/app-}"
    cp "$f" "$dest"
    echo "    -> $dest"
    if [ -n "$aapt2" ]; then
      "$aapt2" dump badging "$dest" 2>/dev/null \
        | awk -F"'" '/^package:/            {print "       versionName " $6}
                     /uses-permission.*INTERNET/ {print "       INTERNET permission: present"}'
    fi
  done
  shopt -u nullglob
done

echo
echo "==> Done."
ls -lh "$OUT_DIR"/*.apk
