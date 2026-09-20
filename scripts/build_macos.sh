#!/usr/bin/env bash
#
# scripts/build_macos.sh
#
# Builds a release macOS .app bundle for AniMeow (animeko_flutter).
#
# What it does:
#   1. purge generated macOS state                         (macos/Flutter/ephemeral plus
#                                                           macos/Pods/Manifest.lock — see below)
#   2. flutter pub get                                   (ensure deps match pubspec.lock)
#   3. dart run build_runner build                         (regenerate *.g.dart before compiling,
#                                                           so a stale codegen file never silently
#                                                           ships in the built app; hang-proofed,
#                                                           see run_codegen below)
#   4. flutter build macos --release                       (produce the .app bundle)
#
# Why step 1 exists:
#   flutter pub get does NOT rewrite macos/Flutter/ephemeral/Flutter-Generated.xcconfig
#   or flutter_export_environment.sh when they already exist, so a FLUTTER_ROOT
#   (and SwiftPM vs CocoaPods plugin layout) written by a *different* Flutter SDK
#   sticks around and breaks the build with errors like:
#     target 'wakelock_plus' referenced in product 'wakelock-plus' is empty
#   Purging the directory makes every build start from the SDK on PATH.
#
#   The purge also deletes macos/Flutter/ephemeral/.symlinks, which is recreated
#   ONLY by `pod install` (flutter_install_plugin_pods in the SDK's podhelper.rb).
#   Flutter skips pod install whenever macos/Podfile.lock and macos/Pods/Manifest.lock
#   agree, so the purge alone leaves the CocoaPods-generated Xcode targets copying
#   plugin xcframeworks from symlinks that no longer exist:
#     rsync: .../Ass.xcframework/macos-arm64_x86_64/*: (l)stat: No such file or directory
#     ** BUILD FAILED **
#   Deleting Manifest.lock forces pod install to run and recreate the symlinks.
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

# How long a single build_runner attempt may take before we treat it as hung.
# A cold full codegen run on this repo is ~30s, so 10 minutes is a wide margin.
CODEGEN_TIMEOUT_SECS="${CODEGEN_TIMEOUT_SECS:-600}"

# build_runner serialises on .dart_tool/build/lock. When a previous build was
# interrupted (Ctrl-C, closed terminal, killed CI job) an orphaned
# dartaotruntime can keep holding that lock, and every later run then prints
# only "Waiting for already-running build_runner." and blocks forever.
release_stale_codegen_lock() {
  local lock_dir=".dart_tool/build/lock"
  [ -d "${lock_dir}" ] || return 0
  local pids
  pids="$(lsof -t +D "${lock_dir}" 2>/dev/null || true)"
  [ -n "${pids}" ] || return 0
  echo "    stale build_runner lock held by PID(s): ${pids} — terminating"
  # shellcheck disable=SC2086  # intentional word splitting: one kill per PID
  kill -TERM ${pids} 2>/dev/null || true
  sleep 2
  pids="$(lsof -t +D "${lock_dir}" 2>/dev/null || true)"
  if [ -n "${pids}" ]; then
    # shellcheck disable=SC2086
    kill -9 ${pids} 2>/dev/null || true
    sleep 1
  fi
}

# Run codegen with a watchdog, and recover from a corrupt incremental state.
# A damaged .dart_tool/build asset graph can deadlock the generator: it parks in
# its isolate event loop at 0% CPU, holding the lock, and never exits. There is
# no error to catch, so the only reliable signal is elapsed time, and the only
# reliable recovery is to delete .dart_tool/build and generate from scratch.
run_codegen() {
  local attempt rc br_pid watchdog_pid
  for attempt in 1 2; do
    release_stale_codegen_lock

    dart run build_runner build &
    br_pid=$!
    ( sleep "${CODEGEN_TIMEOUT_SECS}"; kill -9 "${br_pid}" 2>/dev/null ) &
    watchdog_pid=$!

    rc=0
    wait "${br_pid}" || rc=$?

    kill "${watchdog_pid}" 2>/dev/null || true
    wait "${watchdog_pid}" 2>/dev/null || true

    if [ "${rc}" -eq 0 ]; then
      return 0
    fi

    # The watchdog kills `dart run` but not the dartaotruntime worker it spawned,
    # so clear the lock before touching .dart_tool/build or retrying.
    release_stale_codegen_lock

    if [ "${attempt}" -eq 2 ]; then
      echo "ERROR: build_runner failed twice (last exit code ${rc})" >&2
      return 1
    fi

    echo "    codegen attempt ${attempt} failed (exit ${rc}); wiping .dart_tool/build" \
         "and retrying from a clean state" >&2
    rm -rf .dart_tool/build
  done
}

# Log which toolchain is actually being used — makes a mismatched SDK obvious in
# build logs when several developers (or several local installs) are involved.
echo "==> flutter: $(command -v flutter)"
flutter --version | head -n 1

echo "==> [1/4] purge stale generated macOS state (ephemeral + Pods manifest)"
rm -rf macos/Flutter/ephemeral
# Forces `pod install`, which is the only thing that recreates
# macos/Flutter/ephemeral/.symlinks — without it the purge above breaks the
# Xcode copy phases that read plugin xcframeworks through those symlinks.
rm -f macos/Pods/Manifest.lock

echo "==> [2/4] flutter pub get"
flutter pub get

echo "==> [3/4] dart run build_runner build"
run_codegen

echo "==> [4/4] flutter build macos --release"
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
