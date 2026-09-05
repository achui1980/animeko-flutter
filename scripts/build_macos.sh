#!/usr/bin/env bash
#
# scripts/build_macos.sh
#
# Builds a release macOS .app bundle for AniMeow (animeko_flutter).
#
# What it does:
#   1. flutter pub get                                   (ensure deps match pubspec.lock)
#   2. dart run build_runner build --delete-conflicting-outputs
#                                                          (regenerate *.g.dart before compiling,
#                                                           so a stale codegen file never silently
#                                                           ships in the built app)
#   3. flutter build macos --release                       (produce the .app bundle)
#
# Usage:
#   ./scripts/build_macos.sh
#
# The resulting .app is left at:
#   build/macos/Build/Products/Release/AniMeow.app
#
# Run this script from anywhere; it always operates relative to the repo root
# (determined from this script's own location), not the caller's cwd.

set -euo pipefail

# Resolve the repo root as the parent of this script's directory, so the
# script works correctly no matter where it's invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

APP_NAME="AniMeow.app"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}"

echo "==> [1/3] flutter pub get"
flutter pub get

echo "==> [2/3] dart run build_runner build --delete-conflicting-outputs"
dart run build_runner build --delete-conflicting-outputs

echo "==> [3/3] flutter build macos --release"
flutter build macos --release

if [ -d "${APP_PATH}" ]; then
  echo ""
  echo "Build succeeded:"
  echo "  ${REPO_ROOT}/${APP_PATH}"
  echo ""
  echo "Open it with:"
  echo "  open \"${REPO_ROOT}/${APP_PATH}\""
else
  echo "ERROR: expected app bundle not found at ${APP_PATH}" >&2
  exit 1
fi
