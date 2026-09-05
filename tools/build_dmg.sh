#!/usr/bin/env bash
#
# tools/build_dmg.sh
#
# Builds a release macOS .app and packages it into a distributable,
# fancy .dmg disk image (using create-dmg) with a drag-to-Applications
# installer layout.
#
# What it does:
#   1. Runs scripts/build_macos.sh to produce a fresh release .app build
#      (flutter pub get + codegen + `flutter build macos --release`).
#   2. Copies just the .app into a clean staging folder, so nothing else
#      that might be sitting in build/macos/Build/Products/Release/
#      (e.g. leftover .dSYM bundles from a previous build) ends up
#      inside the dmg.
#   3. Runs create-dmg against that staging folder to produce a
#      volume named "AniMeow" with the app icon on the left and an
#      Applications drop-link on the right.
#
# Requirements:
#   - create-dmg (install with: brew install create-dmg)
#
# Usage:
#   ./tools/build_dmg.sh
#
# The resulting .dmg is left at:
#   build/dmg/AniMeow.dmg
#
# Run this script from anywhere; it always operates relative to the repo
# root (determined from this script's own location), not the caller's cwd.

set -euo pipefail

# Resolve the repo root as the parent of this script's directory, so the
# script works correctly no matter where it's invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg is not installed." >&2
  echo "Install it with: brew install create-dmg" >&2
  exit 1
fi

APP_NAME="AniMeow.app"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}"
DMG_DIR="build/dmg"
DMG_NAME="AniMeow.dmg"
DMG_PATH="${DMG_DIR}/${DMG_NAME}"
STAGING_DIR="${DMG_DIR}/staging"

echo "==> [1/3] Building release .app via scripts/build_macos.sh"
"${REPO_ROOT}/scripts/build_macos.sh"

if [ ! -d "${APP_PATH}" ]; then
  echo "ERROR: expected app bundle not found at ${APP_PATH} after build" >&2
  exit 1
fi

echo "==> [2/3] Staging a clean copy of ${APP_NAME}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"

echo "==> [3/3] Packaging into ${DMG_NAME} with create-dmg"
rm -f "${DMG_PATH}"

create-dmg \
  --volname "AniMeow" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}" 150 190 \
  --hide-extension "${APP_NAME}" \
  --app-drop-link 450 190 \
  "${DMG_PATH}" \
  "${STAGING_DIR}/" \
  || true
# create-dmg returns a non-zero exit code even on success in some
# environments (its Finder-prettifying AppleScript step can fail on
# machines without Finder automation permissions granted), so we check
# for the actual output file below rather than trusting its exit code.

rm -rf "${STAGING_DIR}"

if [ -f "${DMG_PATH}" ]; then
  echo ""
  echo "DMG created:"
  echo "  ${REPO_ROOT}/${DMG_PATH}"
  echo ""
  echo "Open it with:"
  echo "  open \"${REPO_ROOT}/${DMG_PATH}\""
else
  echo "ERROR: expected dmg not found at ${DMG_PATH}" >&2
  exit 1
fi
