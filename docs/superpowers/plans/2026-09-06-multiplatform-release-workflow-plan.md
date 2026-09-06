# Multi-Platform Release Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Android + Windows platform scaffolding, brand them as "AniMeow", and add a GitHub Actions workflow that builds macOS/Windows/Android release artifacts and publishes a GitHub Release with a git-cliff changelog whenever a `v*` tag is pushed.

**Architecture:** Two independent additions layered on top of each other: (1) local repo changes — new `android/` and `windows/` platform dirs via `flutter create`, text-only branding edits, and a root `cliff.toml` — verified to build locally where possible; (2) a new `.github/workflows/release.yml` ported from the sibling `comic-reader` project's proven-working workflow, with product-name substitutions and one added `build_runner` codegen step per job (this repo's Riverpod/Drift codegen makes that step mandatory, unlike comic-reader).

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 (stable channel), GitHub Actions (`subosito/flutter-action@v2`, `actions/setup-java@v4`, `orhun/git-cliff-action@v4`, `softprops/action-gh-release@v2`), git-cliff (Conventional Commits changelog), `create-dmg` (macOS packaging).

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-09-06-multiplatform-release-workflow-design.md` — this plan implements it exactly, with two refinements discovered during planning (documented in Task 2 and Task 3 below) that the spec didn't anticipate.
- Product/app name for Windows and Android must be **"AniMeow"** (text only — no new icon assets for these two platforms in this task).
- Android release builds must use **debug signing** (no keystore, no GitHub Secrets).
- No changes to `scripts/build_macos.sh` or `tools/build_dmg.sh` (existing local macOS tooling stays as-is).
- No Linux/web platform work.
- After every codegen-affecting change, `dart run build_runner build --delete-conflicting-outputs` must be run before `flutter build`/`flutter analyze`/`flutter test`, per root `AGENTS.md`.
- `flutter analyze` must stay clean of errors and `flutter test` must stay green (359+ tests) after every task that touches `lib/`, `pubspec.yaml`, or adds new platform dirs — these are the only two gates per `AGENTS.md`.
- Commit style: Conventional Commits with scope (e.g. `feat(android): ...`, `chore(ci): ...`), matching existing `git log` history.
- Repo remote is `git@github.com-achui:achui1980/animeko-flutter.git` (GitHub) — `softprops/action-gh-release@v2` and `orhun/git-cliff-action@v4` will run against this repo once the workflow file is pushed; no repo-side GitHub configuration (Actions permissions, branch protection) is expected to need changes for this to work, since `permissions: contents: write` is set directly in the workflow's `release` job.

---

### Task 1: Scaffold Android + Windows platform folders

**Files:**
- Create (via `flutter create`, not hand-written): `android/**`, `windows/**`
- Modify (side effect of `flutter create`): `.metadata` (Flutter appends new platform entries automatically)

**Interfaces:**
- Produces: `android/app/build.gradle.kts` (consumed by Task 2), `android/app/src/main/AndroidManifest.xml` (consumed by Task 3), `windows/CMakeLists.txt`, `windows/runner/Runner.rc`, `windows/runner/main.cpp` (all consumed by Task 3).

- [ ] **Step 1: Confirm platform dirs don't exist yet**

Run: `ls android windows 2>&1`
Expected: `ls: android: No such file or directory` and `ls: windows: No such file or directory` (both missing — confirms starting state).

- [ ] **Step 2: Run flutter create to scaffold both platforms**

Run (from repo root `/Users/portz/js/animeko-flutter`):
```bash
flutter create --platforms=android,windows --org org.openani .
```
Expected: Output ends with `Wrote N files.` and no errors. This only adds `android/` and `windows/`; it does not touch `lib/`, `ios/`, `macos/`, or `pubspec.yaml` (verify in Step 3).

- [ ] **Step 3: Verify no existing tracked files were modified**

Run: `git status --short`
Expected: Only new untracked entries for `android/` and `windows/`, plus `.metadata` shown as modified (Flutter's own bookkeeping file — expected). No modifications to any file under `lib/`, `ios/`, `macos/`, `test/`, or `pubspec.yaml`. If any of those show as modified, stop and investigate before proceeding — that would indicate `flutter create` altered existing app code unexpectedly.

- [ ] **Step 4: Verify Android applicationId and Windows binary name match expectations**

Run:
```bash
grep -n "applicationId\|namespace" android/app/build.gradle.kts
grep -n "BINARY_NAME" windows/CMakeLists.txt
```
Expected: `namespace = "org.openani.animeko_flutter"` and `applicationId = namespace` (or an explicit matching string) in the gradle output; `set(BINARY_NAME "animeko_flutter")` in the CMake output. These are the pre-rename defaults that Task 3 will change.

- [ ] **Step 5: Commit the raw scaffold**

```bash
git add android windows .metadata
git commit -m "chore(android,windows): scaffold platform folders via flutter create"
```

---

### Task 2: Verify Android debug signing configuration

**Files:**
- Modify (only if needed — see Step 1): `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: `android/app/build.gradle.kts` produced by Task 1.
- Produces: confirmed (or corrected) debug-signed release buildType, consumed implicitly by Task 4's local build and by the CI Android job.

> **Note on plan vs. spec:** The design spec (§1) states this needs an explicit edit to set `signingConfig = signingConfigs.getByName("debug")`. A throwaway probe scaffold (same Flutter 3.41.6, same org/project name, done during plan-writing and since discarded) showed that **Flutter's own `flutter create` template already sets this by default** for the release buildType — no edit was needed in the probe. This task therefore starts with a verification step; only fall through to an edit if the verification doesn't match.

- [ ] **Step 1: Inspect the release buildType's signing config**

Run: `grep -n -A 15 "buildTypes" android/app/build.gradle.kts`
Expected: a `release { ... }` block containing a line equivalent to:
```kotlin
signingConfig = signingConfigs.getByName("debug")
```
(possibly with a comment like `// TODO: Add your own signing config for the release build.` above it — that comment is fine to leave as-is).

- [ ] **Step 2: If and only if Step 1's expected line is missing, add it**

If the `release { }` block does NOT already contain `signingConfig = signingConfigs.getByName("debug")`, open `android/app/build.gradle.kts` and add that exact line inside the `release { }` block under `buildTypes { }`, e.g.:
```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```
If Step 1 already confirmed the line is present, skip this step entirely — no file change, no commit needed for this task.

- [ ] **Step 3: Record the outcome**

If Step 2 was skipped (line already present): no commit needed, proceed to Task 3.
If Step 2 made an edit: `git add android/app/build.gradle.kts && git commit -m "fix(android): explicitly debug-sign release builds"`.

---

### Task 3: Branding rename — Windows + Android → "AniMeow"

**Files:**
- Modify: `windows/CMakeLists.txt`
- Modify: `windows/runner/Runner.rc`
- Modify: `windows/runner/main.cpp`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: files produced by Task 1 (post-`flutter create`, pre-rename state: binary/label read `animeko_flutter`).
- Produces: Windows binary named `AniMeow.exe` with window title "AniMeow"; Android app drawer label "AniMeow". Consumed by Task 4 (local Android verification) and by the CI workflow (Task 6), which expects `AniMeow.app`/`AniMeow.exe`/APK naming to already reflect this branding.

> **Note on plan vs. spec:** The design spec (§2) calls out `windows/CMakeLists.txt` and `windows/runner/Runner.rc` but does not mention `windows/runner/main.cpp`. That file was found (via the same probe scaffold) to contain the actual window-title string set at runtime — `Runner.rc` only carries embedded version-info metadata (visible in Windows Explorer's file properties dialog, not the window title bar). Both must be edited for the running app to visibly show "AniMeow".

- [ ] **Step 1: Rename Windows binary name in CMakeLists.txt**

In `windows/CMakeLists.txt`, find:
```cmake
set(BINARY_NAME "animeko_flutter")
```
Replace with:
```cmake
set(BINARY_NAME "AniMeow")
```

- [ ] **Step 2: Rename Windows version-info strings in Runner.rc**

In `windows/runner/Runner.rc`, find the four `VALUE` lines under the `StringFileInfo` block referencing the old name and update them:
```rc
            VALUE "FileDescription", "animeko_flutter" "\0"
```
→
```rc
            VALUE "FileDescription", "AniMeow" "\0"
```
```rc
            VALUE "InternalName", "animeko_flutter" "\0"
```
→
```rc
            VALUE "InternalName", "AniMeow" "\0"
```
```rc
            VALUE "OriginalFilename", "animeko_flutter.exe" "\0"
```
→
```rc
            VALUE "OriginalFilename", "AniMeow.exe" "\0"
```
```rc
            VALUE "ProductName", "animeko_flutter" "\0"
```
→
```rc
            VALUE "ProductName", "AniMeow" "\0"
```
Leave `CompanyName` and `LegalCopyright` (both reference `org.openani`) unchanged. Exact surrounding indentation/quoting may differ slightly from the snippets above depending on the generated template — match whatever `flutter create` actually produced; only the string values change, not the structure.

- [ ] **Step 3: Rename the window title string in main.cpp**

In `windows/runner/main.cpp`, find:
```cpp
  if (!window.Create(L"animeko_flutter", origin, size)) {
```
Replace with:
```cpp
  if (!window.Create(L"AniMeow", origin, size)) {
```

- [ ] **Step 4: Rename the Android app label**

In `android/app/src/main/AndroidManifest.xml`, find:
```xml
        android:label="animeko_flutter"
```
Replace with:
```xml
        android:label="AniMeow"
```

- [ ] **Step 5: Verify all four renames landed correctly**

Run:
```bash
grep -n "AniMeow" windows/CMakeLists.txt windows/runner/Runner.rc windows/runner/main.cpp android/app/src/main/AndroidManifest.xml
grep -n "animeko_flutter" windows/CMakeLists.txt windows/runner/Runner.rc windows/runner/main.cpp android/app/src/main/AndroidManifest.xml
```
Expected: the first command shows one match per file (or four matches in `Runner.rc`); the second command shows **no output** for `BINARY_NAME`, the window title, or `android:label` — i.e. no remaining `animeko_flutter` strings in those specific fields. (`Runner.rc`'s `CompanyName`/`LegalCopyright` won't match `animeko_flutter` anyway since they reference `org.openani`, so this check is unambiguous.)

- [ ] **Step 6: Commit the branding rename**

```bash
git add windows/CMakeLists.txt windows/runner/Runner.rc windows/runner/main.cpp android/app/src/main/AndroidManifest.xml
git commit -m "feat(android,windows): rename app to AniMeow (window title, app label, binary name)"
```

---

### Task 4: Local verification build (Android) + regression check

**Files:** none created/modified — this task only runs commands.

**Interfaces:**
- Consumes: Tasks 1–3's output (scaffolded + branded + signing-verified Android project).
- Produces: confidence signal (pass/fail) consumed by the decision of whether to proceed to Task 6 as-is or to fix issues first. No code interface produced.

- [ ] **Step 1: Install dependencies**

Run: `flutter pub get`
Expected: exits 0, "Got dependencies!" or similar, no errors about missing/incompatible plugin platform support (this is the first real signal that `media_kit`/`flutter_secure_storage`/etc. all declare Android support correctly).

- [ ] **Step 2: Regenerate codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, ends with a summary like `[INFO] Succeeded after ...` and no `[SEVERE]` lines.

- [ ] **Step 3: Attempt a real release APK build**

`ANDROID_HOME` is already set on this machine (`/Users/portz/Library/Android/sdk`, confirmed via `echo $ANDROID_HOME` and `which adb` during planning) so a full build is expected to work, not just a partial/codegen-only check.

Run: `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --build-name=1.0.0`
Expected: exits 0, ends with a summary listing the built APK paths under `build/app/outputs/flutter-apk/` (e.g. `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`).

If this step fails with a plugin-specific Gradle error (most likely candidate: `media_kit_libs_video`'s Android native library packaging), capture the exact error text, do not proceed to Task 6 until it's resolved or explicitly deferred with the user's sign-off — this is exactly the risk flagged in the design spec's "Risks / Known Unknowns" section.

- [ ] **Step 4: Regression check — analyze**

Run: `flutter analyze`
Expected: no errors (pre-existing infos are acceptable per `AGENTS.md`). Confirms adding `android/`/`windows/` dirs didn't break static analysis of `lib/`.

- [ ] **Step 5: Regression check — test suite**

Run: `flutter test`
Expected: all tests pass (359+ tests as of the last known full-suite count; exact count may have grown since — check that the pass count matches the total count with zero failures).

- [ ] **Step 6: Clean up build artifacts and commit nothing new**

No file changes are expected from this task (build output lives under `build/`, which is gitignored). Run `git status --short` and confirm it's clean relative to Task 3's commit. Nothing to commit for this task — it exists purely to produce a verified go/no-go signal before writing CI.

---

### Task 5: Add `cliff.toml` for changelog generation

**Files:**
- Create: `cliff.toml`

**Interfaces:**
- Produces: a git-cliff config file consumed by the `orhun/git-cliff-action@v4` step in the `release` job of `.github/workflows/release.yml` (Task 6), via `config: cliff.toml`.

- [ ] **Step 1: Create cliff.toml at repo root**

Create `/Users/portz/js/animeko-flutter/cliff.toml` with exactly this content (adapted from the sibling `comic-reader` project's own `cliff.toml`, header comment genericized to this repo, no other changes — the Tera template and Conventional-Commits parser config need zero modification since this repo already uses the same commit style):

```toml
# git-cliff configuration ~ https://git-cliff.org/docs/configuration
#
# 用途：为 GitHub Release 自动生成"本次更新"分组变更列表。
# 版本大标题(## AniMeow vX.X.X)已经在 .github/workflows/release.yml 的
# Create Release 步骤里手写，这里的 body 模板只输出按类型分组后的提交列表，
# 不重复渲染版本标题/日期。

[changelog]
header = ""
body = """
{% for group, commits in commits | group_by(attribute="group") %}
### {{ group | striptags | trim }}
{% for commit in commits %}
- {% if commit.scope %}**{{ commit.scope }}**: {% endif %}{{ commit.message | split(pat="\n") | first | upper_first }} ({{ commit.id | truncate(length=7, end="") }})
{% endfor %}
{% endfor %}
"""
footer = ""
trim = true
render_always = true

[git]
# 按 Conventional Commits 规范解析 commit message
conventional_commits = true
# 不过滤不符合规范的 commit（保留兜底分组，避免遗漏）
filter_unconventional = false
require_conventional = false
split_commits = false
commit_preprocessors = []
# 分组顺序通过 <!-- N --> 前缀控制，渲染时用 striptags 过滤掉
commit_parsers = [
  { message = "^feat", group = "<!-- 0 -->✨ 新功能" },
  { message = "^fix", group = "<!-- 1 -->🐛 修复" },
  { message = "^perf", group = "<!-- 2 -->⚡ 性能优化" },
  { message = "^refactor", group = "<!-- 3 -->♻️ 重构" },
  { message = "^docs", group = "<!-- 4 -->📝 文档" },
  { message = "^test", group = "<!-- 5 -->✅ 测试" },
  { message = "^chore\\(release\\)", skip = true },
  { message = "^style", group = "<!-- 6 -->💄 样式" },
  { message = "^ci", group = "<!-- 7 -->👷 CI" },
  { message = "^chore", group = "<!-- 8 -->🔧 其他" },
  { message = ".*", group = "<!-- 9 -->🔨 其他改动" },
]
protect_breaking_commits = false
filter_commits = false
tag_pattern = "v[0-9]*"
sort_commits = "oldest"
```

- [ ] **Step 2: Sanity-check the TOML parses (optional local tool check)**

Run: `python3 -c "import tomllib; tomllib.load(open('cliff.toml','rb')); print('OK')"`
Expected: `OK` (confirms valid TOML syntax before it ever reaches CI; Python 3.11+ ships `tomllib` in the standard library — if this machine's `python3` is older, this step will fail with `ModuleNotFoundError: No module named 'tomllib'`, in which case skip it and rely on the CI run itself to validate).

- [ ] **Step 3: Commit**

```bash
git add cliff.toml
git commit -m "chore(ci): add git-cliff config for release changelog generation"
```

---

### Task 6: Add `.github/workflows/release.yml`

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `cliff.toml` (Task 5), the branded `AniMeow.app`/`AniMeow.exe`/APK build outputs (Tasks 1–3), `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png` (pre-existing, confirmed present at that exact path), `macos/Runner/Release.entitlements` (pre-existing, confirmed present).
- Produces: on any `v*` tag push (or manual `workflow_dispatch`), a GitHub Release with three platform artifacts attached and a changelog body. No other code in this repo consumes this file — it's a terminal CI artifact.

This is a direct, structural port of the sibling `comic-reader` project's `.github/workflows/release.yml` (read verbatim from `/Users/portz/js/comic/comic-reader/.github/workflows/release.yml` during planning), with exactly these deltas:
1. Every product-name string changed: `comic_reader`/`ComicReader`/`Comic Reader` → `AniMeow`/`AniMeow.app`(or `.exe`)/`AniMeow`.
2. One new step, `Generate code (Riverpod/Drift)` running `dart run build_runner build --delete-conflicting-outputs`, inserted after `flutter pub get` in all three build jobs (macos/windows/android) — comic-reader doesn't need this since it has no Riverpod/Drift codegen, but this repo's `AGENTS.md` mandates it before any build.
3. Explicit `Install dependencies` step (`flutter pub get`) added before the codegen step in each build job — comic-reader's version relies on `flutter build` running `pub get` implicitly; making it an explicit named step keeps the codegen step's ordering unambiguous.

Everything else — triggers, three-tier version resolution, macOS ad-hoc codesign + entitlements + icns/DMG generation, Windows zip packaging, Android split-per-ABI APK build (excluding x86_64) + rename, the `release` job's `needs`/`if` gating, anti-clobber `-build.N` tag suffix logic, previous-build-tag lookup, git-cliff invocation, and the Chinese-language release body template (including the macOS quarantine-removal instructions and Windows unzip instructions) — is structurally identical to the reference, only with names substituted.

- [ ] **Step 1: Create the workflow directory and file**

Create `/Users/portz/js/animeko-flutter/.github/workflows/release.yml` with exactly this content:

```yaml
# AniMeow - 多平台发布 workflow
# 触发方式:
#   1. 手动触发: Actions -> Release Build -> Run workflow
#   2. 打 tag: git tag v1.0.0 && git push --tags
#
# 产物: macOS DMG + Windows zip + Android APK(按 ABI 拆分)，自动上传到 GitHub Release

name: Release Build

on:
  workflow_dispatch:
    inputs:
      version:
        description: '版本号 (留空则从 pubspec.yaml 读取)'
        required: false
        default: ''
      platform:
        description: '构建平台'
        required: false
        default: 'all'
        type: choice
        options:
          - all
          - macos
          - windows
          - android
  push:
    tags:
      - 'v*'

jobs:
  # ===== macOS 构建 =====
  build-macos:
    runs-on: macos-latest
    if: github.event.inputs.platform == 'macos' || github.event.inputs.platform == 'all' || github.event.inputs.platform == ''
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Get version
        id: version
        run: |
          # 优先级: 手动输入的版本号 > push 的 tag 名 > pubspec.yaml
          if [ -n "${{ github.event.inputs.version }}" ]; then
            VERSION="${{ github.event.inputs.version }}"
          elif [ "${{ github.ref_type }}" = "tag" ]; then
            VERSION="${GITHUB_REF_NAME#v}"
          else
            VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code (Riverpod/Drift)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build macOS
        run: flutter build macos --release --build-name=${{ steps.version.outputs.version }}

      - name: Ad-hoc re-sign app bundle
        run: |
          APP="build/macos/Build/Products/Release/AniMeow.app"
          ENTITLEMENTS="macos/Runner/Release.entitlements"
          # 先对所有内嵌的 framework / dylib 逐个 ad-hoc 签名（由内到外）
          find "$APP/Contents/Frameworks" \
            \( -name "*.dylib" -o -name "*.framework" \) -print0 2>/dev/null \
            | while IFS= read -r -d '' item; do
                codesign --force --sign - --timestamp=none "$item" || true
              done
          # 最后对 app 主体深度签名，附带 entitlements
          codesign --force --deep --sign - \
            --entitlements "$ENTITLEMENTS" \
            --timestamp=none "$APP"
          # 验证签名结构完整（ad-hoc 不做严格 Gatekeeper 校验）
          codesign --verify --deep --verbose=2 "$APP"

      - name: Install create-dmg
        run: brew install create-dmg

      - name: Generate .icns for DMG
        run: |
          ICON_SOURCE="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
          mkdir -p /tmp/icon.iconset
          sips -z 16 16     "$ICON_SOURCE" --out /tmp/icon.iconset/icon_16x16.png      > /dev/null 2>&1
          sips -z 32 32     "$ICON_SOURCE" --out /tmp/icon.iconset/icon_16x16@2x.png   > /dev/null 2>&1
          sips -z 32 32     "$ICON_SOURCE" --out /tmp/icon.iconset/icon_32x32.png      > /dev/null 2>&1
          sips -z 64 64     "$ICON_SOURCE" --out /tmp/icon.iconset/icon_32x32@2x.png   > /dev/null 2>&1
          sips -z 128 128   "$ICON_SOURCE" --out /tmp/icon.iconset/icon_128x128.png    > /dev/null 2>&1
          sips -z 256 256   "$ICON_SOURCE" --out /tmp/icon.iconset/icon_128x128@2x.png > /dev/null 2>&1
          sips -z 256 256   "$ICON_SOURCE" --out /tmp/icon.iconset/icon_256x256.png    > /dev/null 2>&1
          sips -z 512 512   "$ICON_SOURCE" --out /tmp/icon.iconset/icon_256x256@2x.png > /dev/null 2>&1
          sips -z 512 512   "$ICON_SOURCE" --out /tmp/icon.iconset/icon_512x512.png    > /dev/null 2>&1
          cp "$ICON_SOURCE"              /tmp/icon.iconset/icon_512x512@2x.png
          iconutil -c icns /tmp/icon.iconset -o /tmp/app_icon.icns

      - name: Create DMG
        run: |
          create-dmg \
            --volname "AniMeow" \
            --volicon "/tmp/app_icon.icns" \
            --window-size 600 400 \
            --icon-size 128 \
            --icon "AniMeow.app" 150 200 \
            --app-drop-link 450 200 \
            --no-internet-enable \
            "AniMeow-${{ steps.version.outputs.version }}-macOS.dmg" \
            "build/macos/Build/Products/Release/AniMeow.app"

      - name: Upload macOS artifact
        uses: actions/upload-artifact@v4
        with:
          name: macos-dmg
          path: "*.dmg"

  # ===== Windows 构建 =====
  build-windows:
    runs-on: windows-latest
    if: github.event.inputs.platform == 'windows' || github.event.inputs.platform == 'all' || github.event.inputs.platform == ''
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Get version
        id: version
        shell: bash
        run: |
          # 优先级: 手动输入的版本号 > push 的 tag 名 > pubspec.yaml
          if [ -n "${{ github.event.inputs.version }}" ]; then
            VERSION="${{ github.event.inputs.version }}"
          elif [ "${{ github.ref_type }}" = "tag" ]; then
            VERSION="${GITHUB_REF_NAME#v}"
          else
            VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code (Riverpod/Drift)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build Windows
        run: flutter build windows --release --build-name=${{ steps.version.outputs.version }}

      - name: Package Windows zip
        shell: pwsh
        run: |
          $version = "${{ steps.version.outputs.version }}"
          Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "AniMeow-${version}-Windows.zip"

      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-zip
          path: "*.zip"

  # ===== Android 构建 =====
  build-android:
    runs-on: ubuntu-latest
    if: github.event.inputs.platform == 'android' || github.event.inputs.platform == 'all' || github.event.inputs.platform == ''
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Get version
        id: version
        run: |
          # 优先级: 手动输入的版本号 > push 的 tag 名 > pubspec.yaml
          if [ -n "${{ github.event.inputs.version }}" ]; then
            VERSION="${{ github.event.inputs.version }}"
          elif [ "${{ github.ref_type }}" = "tag" ]; then
            VERSION="${GITHUB_REF_NAME#v}"
          else
            VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code (Riverpod/Drift)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build APK (split per ABI)
        # 按架构拆分产出独立 APK，用户只需下载自己手机对应的那一份。
        # 排除 x86_64：真实 Android 手机几乎不用这个架构（主要是模拟器/极少数 x86 平板）。
        run: |
          flutter build apk --release --split-per-abi \
            --target-platform android-arm,android-arm64 \
            --build-name=${{ steps.version.outputs.version }}

      - name: Rename APK
        run: |
          cd build/app/outputs/flutter-apk
          mv app-armeabi-v7a-release.apk "../../../../AniMeow-${{ steps.version.outputs.version }}-Android-armeabi-v7a.apk"
          mv app-arm64-v8a-release.apk "../../../../AniMeow-${{ steps.version.outputs.version }}-Android-arm64-v8a.apk"

      - name: Upload Android artifact
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: "*.apk"

  # ===== 发布到 GitHub Release =====
  release:
    needs: [build-macos, build-windows, build-android]
    runs-on: ubuntu-latest
    if: |
      always() &&
      (startsWith(github.ref, 'refs/tags/v') || github.event_name == 'workflow_dispatch') &&
      !contains(needs.*.result, 'failure')
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          # generate_release_notes 需要完整历史与全部 tag 才能对比生成 changelog
          fetch-depth: 0

      - name: Get version
        id: version
        run: |
          # 优先级: 手动输入的版本号 > push 的 tag 名 > pubspec.yaml
          if [ -n "${{ github.event.inputs.version }}" ]; then
            VERSION="${{ github.event.inputs.version }}"
          elif [ "${{ github.ref_type }}" = "tag" ]; then
            # push tag 触发: 直接用 tag 名(去掉前缀 v),tag 本身唯一,不会覆盖历史 release
            VERSION="${GITHUB_REF_NAME#v}"
          else
            VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
          fi
          # 防止 tag 覆盖: 若目标 tag 已存在(手动触发常见,因 pubspec 版本长期不变),
          # 自动追加 build 号(本次 run number),保证每次都是新的唯一 tag/release,历史不被顶掉。
          if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
            echo "tag v${VERSION} already exists, appending build number to avoid overwriting"
            VERSION="${VERSION}-build.${{ github.run_number }}"
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Resolved version: $VERSION"

      - name: Get previous build tag
        id: prevtag
        run: |
          # 找上一个 build tag 作为 changelog 起点。
          # 用 -build.N 后缀筛选，是因为每次 release 实际创建的 tag 都带这个后缀
          # （见上一步注释：语义 tag 已存在时会自动追加 build 号）。
          # grep -v 排除本次即将创建的 tag，防御 run_number 重复等极端情况。
          PREV_TAG=$(git tag --sort=-creatordate --merged HEAD | grep -E '\-build\.[0-9]+$' | grep -v "^v${{ steps.version.outputs.version }}$" | head -1 || true)
          echo "prev_tag=$PREV_TAG" >> $GITHUB_OUTPUT
          echo "Previous build tag: ${PREV_TAG:-<none, using full history>}"

      - name: Generate changelog
        uses: orhun/git-cliff-action@v4
        id: changelog
        with:
          config: cliff.toml
          args: --strip header ${{ steps.prevtag.outputs.prev_tag != '' && format('{0}..HEAD', steps.prevtag.outputs.prev_tag) || '' }}

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: v${{ steps.version.outputs.version }}
          name: AniMeow v${{ steps.version.outputs.version }}
          draft: false
          prerelease: false
          # 自动根据两个 tag 之间的 commit 生成 changelog（含贡献者、Full Changelog 链接）
          generate_release_notes: true
          # 关键：append_body 让下面的 body 追加到自动生成的 changelog 之后，
          # 而不是覆盖它。若不设，body 会替换掉 generate_release_notes 生成的内容，导致没有 changelog。
          append_body: true
          files: |
            artifacts/macos-dmg/*.dmg
            artifacts/windows-zip/*.zip
            artifacts/android-apk/*.apk
          body: |
            ## AniMeow v${{ steps.version.outputs.version }}

            ### 本次更新
            ${{ steps.changelog.outputs.content }}

            ### 下载

            | 平台 | 文件 | 说明 |
            |------|------|------|
            | macOS | `AniMeow-${{ steps.version.outputs.version }}-macOS.dmg` | 要求 macOS 11.0+，仅支持 Apple Silicon (M系列芯片) |
            | Windows | `AniMeow-${{ steps.version.outputs.version }}-Windows.zip` | 解压即用 |
            | Android | `AniMeow-${{ steps.version.outputs.version }}-Android-arm64-v8a.apk` | 绝大多数 2018 年后的手机选这个 |
            | Android | `AniMeow-${{ steps.version.outputs.version }}-Android-armeabi-v7a.apk` | 老款 32 位手机选这个 |

            > Android 不确定选哪个？大多数现代手机都是 arm64-v8a，直接下这个即可。

            ### macOS 安装说明（未签名应用）
            本应用未经 Apple 公证，从浏览器下载后会被系统标记隔离，首次打开需手动去除：
            1. 双击 DMG → 拖 `AniMeow.app` 到「应用程序」文件夹
            2. **打开「终端」执行（最可靠）**：
               ```
               sudo xattr -rd com.apple.quarantine /Applications/AniMeow.app
               ```
            3. 然后正常双击打开（若仍提示，可再尝试右键点击 app → 打开 → 确认）

            > 较新 macOS（Sequoia 等）收紧了「右键打开」绕过，若直接双击提示「已损坏」或「无法验证开发者」，请务必先执行上面的终端命令。

            ### Windows 安装说明
            1. 解压 zip 到任意目录
            2. 双击 `AniMeow.exe` 运行
```

- [ ] **Step 2: Validate YAML syntax locally**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('OK')"`
Expected: `OK`. If `python3` lacks the `yaml` module (`ModuleNotFoundError: No module named 'yaml'`), fall back to: `ruby -ryaml -e "YAML.load_file('.github/workflows/release.yml'); puts 'OK'"` (Ruby's YAML stdlib ships by default on macOS). Either confirms the file parses as valid YAML before it's ever pushed to GitHub.

- [ ] **Step 3: Diff-check product-name substitution completeness**

Run: `grep -n "comic_reader\|ComicReader\|Comic Reader" .github/workflows/release.yml`
Expected: **no output** — confirms no leftover reference-project strings remain in the ported file.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat(ci): add multi-platform release workflow (macOS/Windows/Android)"
```

---

### Task 7: Final end-to-end sanity pass

**Files:** none — verification only.

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: final go/no-go confirmation that the repo is ready for its first `v*` tag push.

- [ ] **Step 1: Full regression check**

Run: `flutter analyze && flutter test`
Expected: `flutter analyze` reports no errors; `flutter test` shows all tests passing, zero failures.

- [ ] **Step 2: Confirm working tree is clean and all task commits are present**

Run: `git status --short && git log --oneline -8`
Expected: clean working tree; the log shows (top to bottom, newest first) commits from Task 6, Task 5, Task 3, Task 1 (and Task 2 only if it made an edit), each with the exact commit messages specified in those tasks.

- [ ] **Step 3: Report the actual next step to the user (not to be executed automatically)**

This plan does **not** include pushing a tag or triggering the workflow — that is the user's decision once they've reviewed the committed changes. Report back that the repo is ready, and that the first real trigger will be:
```bash
git tag v1.0.0
git push origin v1.0.0
```
(or via `Actions → Release Build → Run workflow` for a manual dry run first, which is lower-risk since it doesn't create a permanent tag/release unless the `release` job's own tag-creation logic runs — note: `workflow_dispatch` runs also pass the `release` job's `if` condition since it accepts `github.event_name == 'workflow_dispatch'`, so a manual dispatch run **will** create a real tag and GitHub Release, not just build artifacts. Flag this explicitly to the user before they click "Run workflow" for a "dry run" — there is no artifact-only dry-run mode in this workflow, matching the reference design.)
