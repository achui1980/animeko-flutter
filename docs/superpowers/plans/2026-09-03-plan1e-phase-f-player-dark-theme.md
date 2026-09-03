# Plan 1e Phase F: Player Screen Forced Dark Theme

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lib/ui/player/player_screen.dart` always renders using the app's dark theme (`AppTheme.dark()`), regardless of the user's global theme mode setting -- a simplified version of the reference app's `alwaysDarkInEpisodePage` behavior (design doc: "播放页：仅接入深色主题... **不**改动播放控制条本身"). The player controls themselves (media_kit's `Video`/`AdaptiveVideoControls`) are not touched.

**Architecture:** No new providers, no codegen, no new data flow. `PlayerScreen.build()`'s existing `Scaffold(backgroundColor: Colors.black, body: SafeArea(child: playback.when(...)))` is wrapped in a `Theme(data: AppTheme.dark(), child: ...)` so that any Material widgets rendered inside it (the loading spinner, `ErrorRetryView`'s retry button/text) pick up dark-theme colors instead of whatever the ambient app theme happens to be. This reuses Phase A's `AppTheme.dark()` -- no new theme code.

**Testing note:** Unlike every other phase in this plan, `PlayerScreen` has zero existing test coverage and none is added here. It instantiates a real `media_kit` `Player()` in `initState()`, which requires native platform bindings (`MediaKit.ensureInitialized()`, called once in `main()`) that aren't available in the plain `flutter_test` widget-test sandbox -- this is why the screen has had no widget test since it was first built in Plan 1c, and remains true after this one-line wrapping change. Full-suite regression (`flutter test` + `flutter analyze`) is the only verification.

**Tech Stack:** No new dependencies. Reuses Phase A's `lib/app/theme/app_theme.dart` (`AppTheme.dark()`, already implemented and tested).

**Design doc:** `docs/superpowers/specs/2026-09-02-plan1e-ui-redesign-design.md` (Phase F section, "3. 页面级改动" table row for 播放页).

---

### Task 1: Wrap `PlayerScreen` in a forced dark `Theme`

**Files:**
- Modify: `lib/ui/player/player_screen.dart`

- [ ] **Step 1: Implement.**

In `lib/ui/player/player_screen.dart`:

1. Add the import: `import '../../app/theme/app_theme.dart';`
2. Wrap the `build()` method's returned `Scaffold` in a `Theme`:

```dart
return Theme(
  data: AppTheme.dark(),
  child: Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: playback.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorRetryView(
          message: '播放失败：$error',
          onRetry: _retry,
        ),
        data: (_) => _playbackError != null
            ? ErrorRetryView(
                message: '播放失败：$_playbackError',
                onRetry: _retry,
              )
            : Video(controller: _controller),
      ),
    ),
  ),
);
```

(Only the outer `return` statement changes -- everything inside `Scaffold(...)` is unchanged from the current file.)

- [ ] **Step 2: Full regression.**

```bash
flutter test
flutter analyze
```

Expected: `flutter test` passes in full at the current baseline (no new tests added -- see "Testing note" above). `flutter analyze` reports the same 3 known issue categories with an unchanged count (no new file, no new import of plain `riverpod`).

- [ ] **Step 3: Commit.**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): force dark theme on the player screen"
```

---

## Definition of Done

- `flutter test` passes in full at the current baseline (no new tests, per the "Testing note" above).
- `flutter analyze` reports only the same 3 known issue categories established throughout this session, with an unchanged count.
- The task commit is present in `git log` on `main`.
- Manual/non-blocking verification: run the app in light mode (设置 → 通用 → 浅色), open any episode's player screen, confirm the loading spinner and any error-retry button/text render with dark-theme colors instead of light-theme colors, and confirm this doesn't affect the rest of the app's theme.
- This is the last phase of Plan 1e (UI redesign). After this phase, Plan 1e is fully complete: Phase A (theme + component library), Phase B (account/settings/theme wiring), Phase C (Home/Search/Schedule), Phase D (subject detail immersive header), Phase E (My Collections), Phase F (player screen).
