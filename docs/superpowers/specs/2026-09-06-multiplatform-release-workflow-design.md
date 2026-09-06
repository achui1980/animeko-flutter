# Multi-Platform Release Workflow Design

**Date:** 2026-09-06
**Status:** Approved (pending final spec review sign-off)

## Goal

On pushing a `v*` git tag, automatically build release artifacts for macOS,
Windows, and Android, and publish them as a GitHub Release with an
auto-generated changelog. Modeled directly on the reference workflow at
`/Users/portz/js/comic/comic-reader/.github/workflows/release.yml`, which has
been verified (via `gh run list`) to succeed on all three platforms in that
sibling project.

This repo currently has no `.github/` directory, and is missing the
`android/` and `windows/` platform folders entirely (per the Phase 1
macOS-only migration design in
`docs/superpowers/specs/2026-08-27-flutter-migration-phase1-design.md`).
Scaffolding those platforms is in scope for this task, ahead of the
originally planned Phase 5 platform-expansion order — the user explicitly
requested and approved this.

## Scope

In scope:
- Scaffold `android/` and `windows/` platform directories via `flutter
  create`.
- Rename Windows/Android app name to "AniMeow" (text only, no new icons).
- Set Android release builds to use debug signing (no keystore secrets).
- Add `.github/workflows/release.yml` building macOS `.dmg`, Windows `.zip`,
  and Android `.apk` (split per ABI) artifacts and publishing a GitHub
  Release with a git-cliff-generated changelog.
- Add `cliff.toml` at repo root, adapted from comic-reader's.
- Local verification of the Android scaffold/build before writing CI (per
  approved Approach B).

Out of scope:
- Custom launcher icons for Android/Windows (ship with Flutter defaults).
- Real Android release signing (keystore + GitHub Secrets) — debug signing
  only, matching comic-reader's own approach.
- Linux, web platforms — not requested.
- Any change to the existing macOS-only local build scripts
  (`scripts/build_macos.sh`, `tools/build_dmg.sh`) — they remain as-is for
  local dev use; the new CI workflow is independent tooling.
- Local verification of the Windows build — impossible on this macOS dev
  machine; its first real test is the CI run itself.

## 1. Platform Scaffolding

Run:
```
flutter create --platforms=android,windows --org org.openani .
```
This only adds `android/` and `windows/` directories; it does not touch
`lib/`, `ios/`, `macos/`, or any existing app code. Resulting Android
`applicationId` will be `org.openani.animeko_flutter` (flutter normalizes
the project name from `pubspec.yaml`'s `animeko_flutter`). This does not
need to match iOS/macOS's `org.openani.animekoFlutter` — each platform's
bundle/application ID is independent.

Android release signing: in `android/app/build.gradle.kts`, set the
`release` buildType's `signingConfig = signingConfigs.getByName("debug")`,
matching comic-reader's `android/app/build.gradle.kts:37`. This avoids any
keystore/secrets management in CI. Trade-off: the APK is not suitable for
Play Store distribution as-is; acceptable since this is a sideload-style
GitHub Release distribution, same as comic-reader's.

No custom launcher icons are added for either platform in this task —
both ship with Flutter's default generated icon set until a follow-up task
addresses icon design for Android/Windows.

## 2. Branding Rename (Windows/Android → "AniMeow")

After scaffolding, apply a branding rename analogous to what commit
`9e42125` (`feat: rename app to AniMeow`) did for macOS, but text-only (no
icon changes):

- **Windows:** `windows/CMakeLists.txt` — update `BINARY_NAME` from
  `animeko_flutter` to `AniMeow`. `windows/runner/Runner.rc` — update the
  `FileDescription`, `ProductName`, and window title strings to "AniMeow".
- **Android:** `android/app/src/main/AndroidManifest.xml` — update
  `android:label` from the default to `"AniMeow"`.

This ensures the shipped `.exe` and Android app drawer both display
"AniMeow" rather than the raw Dart package name `animeko_flutter`.

## 3. Local Verification (before writing CI)

After scaffolding + rename + signing config change:
1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs`
3. Attempt `flutter build apk --debug` (or `--release` if a usable Android
   SDK/toolchain is available on this machine) to catch obvious scaffolding
   or native-dependency issues (e.g. `media_kit`'s Android native libs)
   before touching CI.

Windows cannot be built or verified on this macOS machine at all (no
Windows toolchain available locally). This is a known, accepted risk: the
Windows CI job's first real test will be the actual GitHub Actions run on
`windows-latest`. comic-reader's own workflow — which has a similar
dependency footprint including native libmpv/media_kit-style libraries via
Flutter plugins — has a 100% success rate on `windows-latest` per the `gh
run list` history check, which gives reasonable confidence but is not a
guarantee for this specific pubspec's dependency set.

## 4. GitHub Actions Workflow (`.github/workflows/release.yml`)

Directly modeled on comic-reader's `release.yml`, with the following
deltas called out explicitly (everything else is a straight port,
substituting product/package names):

### Triggers
- `workflow_dispatch` with inputs `version` (optional string override) and
  `platform` (choice: `all` / `macos` / `windows` / `android`, default
  `all`).
- `push: tags: ['v*']`.

### Common per-platform version resolution
Same three-tier priority as reference, in every build job and the release
job:
1. Manual `workflow_dispatch` `version` input, if provided.
2. Git tag (`${GITHUB_REF_NAME#v}`) when `github.ref_type == 'tag'`.
3. Parsed from `pubspec.yaml` (`grep '^version:' pubspec.yaml | awk
   '{print $2}' | cut -d'+' -f1`).

### build-macos (runs-on: macos-latest)
- checkout → `subosito/flutter-action@v2` (channel stable) → version step
  → `flutter pub get` → **`dart run build_runner build
  --delete-conflicting-outputs`** (new step, required for this repo's
  Riverpod/Drift codegen — not present in the reference workflow) →
  `flutter build macos --release --build-name=<version>`.
- Ad-hoc re-sign each dylib/framework under `Contents/Frameworks`
  individually, then deep-sign the whole `AniMeow.app` with
  `macos/Runner/Release.entitlements`, `--timestamp=none`, then verify —
  identical to reference, just pointed at `AniMeow.app` instead of
  `comic_reader.app`.
- `brew install create-dmg`.
- Generate `.icns` from the existing 1024px source at
  `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png` via
  `sips` (resize to the standard iconset sizes) + `iconutil -c icns` — this
  asset chain already exists in this repo and matches exactly what the
  reference step expects.
- `create-dmg --volname AniMeow --volicon /tmp/app_icon.icns ... "AniMeow-<version>-macOS.dmg" build/macos/Build/Products/Release/AniMeow.app`.
  (This CI job keeps the `--volicon` custom DMG icon step from the
  reference, even though the *existing local* `tools/build_dmg.sh` script
  skips it for simplicity — the two are independent tools serving
  different purposes, and CI can afford the extra polish step.)
- `upload-artifact@v4` name=`macos-dmg`, path=`*.dmg`.

### build-windows (runs-on: windows-latest)
- checkout → flutter-action → version step (bash shell) → `flutter pub
  get` → **`dart run build_runner build --delete-conflicting-outputs`**
  (new step) → `flutter build windows --release
  --build-name=<version>`.
- pwsh: `Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath AniMeow-<version>-Windows.zip`.
- `upload-artifact@v4` name=`windows-zip`.

### build-android (runs-on: ubuntu-latest)
- checkout → `actions/setup-java@v4` (zulu, java 17) → flutter-action →
  version step → `flutter pub get` → **`dart run build_runner build
  --delete-conflicting-outputs`** (new step) → `flutter build apk
  --release --split-per-abi --target-platform android-arm,android-arm64
  --build-name=<version>` (x86_64 intentionally excluded, same rationale
  as reference: real phones rarely use it, and per-ABI native libs bloat
  size).
- Rename outputs to `AniMeow-<version>-Android-armeabi-v7a.apk` and
  `AniMeow-<version>-Android-arm64-v8a.apk`.
- `upload-artifact@v4` name=`android-apk`.

### release (needs: [build-macos, build-windows, build-android])
- runs-on: ubuntu-latest, permissions: `contents: write`.
- `if: always() && (startsWith(github.ref, 'refs/tags/v') ||
  github.event_name == 'workflow_dispatch') &&
  !contains(needs.*.result, 'failure')`.
- checkout with `fetch-depth: 0` (needed for full tag/changelog history).
- Version-resolution step (same three-tier priority) **plus** the
  reference's anti-clobber guard: if tag `v<version>` already exists,
  append `-build.<github.run_number>`. This logic is inert on this repo's
  first-ever release (zero existing tags) but is copied verbatim since it's
  harmless and protects future manual re-runs.
- "Get previous build tag" step: same `git tag --sort=-creatordate --merged
  HEAD | grep -E '...-build\.[0-9]+$'` lookup, used as the changelog diff
  start point.
- `orhun/git-cliff-action@v4` using the new root `cliff.toml`, `args:
  --strip header <prevtag>..HEAD` (or full history if no previous tag —
  which will be the case on the very first release).
- `download-artifact@v4` (path=`artifacts`) to pull all three platform
  artifacts.
- `softprops/action-gh-release@v2`: `tag_name: v<version>`, `name: AniMeow
  v<version>`, `draft: false`, `prerelease: false`, `generate_release_notes:
  true`, `append_body: true` (required so the custom `body:` appends after,
  rather than overwrites, GitHub's auto-generated notes). `files:` globs
  for the three artifact dirs.
- `body:` — same Chinese-language template as reference: title, "###
  本次更新" section with `${{ steps.changelog.outputs.content }}`, a "###
  下载" table with each platform's filename + one-line description, then
  install instructions. Keep the macOS unsigned/not-notarized note
  (`sudo xattr -rd com.apple.quarantine /Applications/AniMeow.app`) since
  this repo's macOS build is also ad-hoc-signed only, matching the local
  `tools/build_dmg.sh` distribution model. Keep the simple Windows
  unzip-and-run instructions.

## 5. `cliff.toml`

Add at repo root, adapted from comic-reader's (same Tera template structure,
same `[git] conventional_commits = true` settings) — this repo's commits
already follow Conventional Commits per the top-level `AGENTS.md` ("Commit
style: Conventional Commits with scope"), so the existing grouping/template
logic should apply without modification beyond cosmetic references to the
project name.

## Risks / Known Unknowns

- **Windows build is untestable locally.** First real signal comes from the
  actual CI run. If it fails, debugging happens via CI logs only (slower
  iteration than local).
- **Android local verification depends on toolchain availability** on this
  machine; if no Android SDK is present locally, that verification step
  degrades to "does `flutter build apk` at least get past codegen and
  Gradle sync" rather than a full successful build — will be reported
  honestly rather than assumed.
- **`media_kit` native library bundling on Windows/Android** is unverified
  for this specific pubspec dependency set (`media_kit`,
  `media_kit_video`, `media_kit_libs_video`) — comic-reader's own
  successful CI history doesn't necessarily include this same plugin, so
  it's cited only as loose supporting evidence, not proof.
