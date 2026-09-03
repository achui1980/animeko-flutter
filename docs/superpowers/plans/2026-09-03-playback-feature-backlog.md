# Playback / Media-Source Feature Backlog

> This is a lightweight backlog/roadmap document, not a formal design spec or
> implementation plan. Each item should go through its own brainstorming →
> design (if non-trivial) → implementation cycle when picked up.

**Context:** After completing Plan 1e (UI redesign) and the Home
Carousel/Settings-Nav redesigns, the user asked for a gap analysis between
the reference Kotlin/Compose Animeko app (`/Users/portz/js/animeko/`) and
this Flutter port, focused on playback and media-source features (danmaku
explicitly excluded — deferred separately, see item 9).

## Gap analysis summary

| Feature | Reference has it | Flutter has it | Gap | Complexity |
|---|---|---|---|---|
| Custom player control bar/progress w/ frame preview | Yes (custom-drawn) | Partial (media_kit default `AdaptiveVideoControls`) | Partial | Medium |
| Danmaku | Yes (full system) | No | Excluded by decision | — |
| Multi-source selection/switching (MediaSelector) | Yes (auto-select, resolution/subtitle-group/route switching, tiering, preference memory) | No (each episode bound to a single source, no in-player switching) | Complete | Complex |
| Subtitle track switching | Yes | No | Complete | Medium (needs research: do anime1.me/Xifan even expose subtitle tracks?) |
| Subtitle styling | Weak in both | Weak | None | — |
| Playback speed control | Yes (slider + keyboard shortcuts) | No | Complete | **Simple** (media_kit `Player.setRate()` already exists) |
| Skip intro/outro | Yes (chapter-metadata + heuristics) | No | Complete | Medium/needs research (depends on chapter metadata availability) |
| Gesture controls (swipe volume/brightness/seek, gesture lock) | Yes (full custom gesture system) | No (library hooks exist but unwired) | Complete | Medium (media_kit's `MaterialVideoControlsThemeData` already reserves callback slots) |
| Picture-in-Picture | No | No | None | — |
| Background playback / lock-screen controls | No | No | None | — |
| Auto-play next episode | Yes | No | Complete | Simple/Medium (`SubjectEpisodesController`/`MergedEpisode` already has next-episode data) |
| Cache/offline download | Yes (self-built BitTorrent engine) | No | Complete | Complex + needs research (Flutter's sources are direct links, not BT — needs a different approach) |
| Screen casting (Cast/DLNA) | No (only inert bundled VLC plugin files) | No | None | — |
| Playback history / resume position | Yes (with Bangumi cloud sync) | No | Complete | Medium (local-only "remember position" subset is much cheaper than the cloud-sync version) |

## Recommended priority order (from cost/benefit analysis)

### High priority — ALL DONE
1. **倍速播放 (Playback speed control)** — DONE. Commits `bca2ef0` (data
   layer: `SettingsStorage.getPlaybackSpeed()/setPlaybackSpeed()` +
   `PlaybackSpeedController`) and `743994c` (UI: `_SpeedButton` popup menu
   on `PlayerScreen`, applies persisted speed via `Player.setRate()` on
   every new source open).
2. **自动连播下一集 (Auto-play next episode)** — DONE. Commit `92a8551`.
   `PlayerScreen` now takes `subjectId`/`subjectName`, listens on
   `_player.stream.completed`, matches the current episode within
   `SubjectEpisodesController`'s list via a `sourceId+title` composite key
   (no other stable identity exists on `MediaEpisode`), and
   `Navigator.pushReplacement`s to the next same-source episode.
3. **记住播放位置 / 简易播放历史 (Remember playback position, local-only)**
   — DONE. Commit `9e9f117`. New `PlaybackPositionStorage`
   (`lib/data/play/playback_position_storage.dart`, SharedPreferences-backed,
   keyed by the same `subjectId::sourceId::title` composite key), wired into
   `PlayerScreen` via a 5s periodic save timer + resume-on-open + clear-on-
   completion. Minimum resume thresholds at 5s to avoid saving/resuming
   trivial positions.

   Final verification after items 1-3: `flutter test` 326/326 passing,
   `flutter analyze` 23 known issues (same 3 established categories, +1
   `depend_on_referenced_packages` from `playback_speed_controller_test.dart`'s
   plain-riverpod import).

### Medium priority
4. **手势控制 (Gesture controls)** — **INVESTIGATED, DEFERRED (not a simple
   wiring task as originally assumed).** Read `media_kit_video-2.0.1`'s
   actual source (`material.dart`): `MaterialVideoControlsThemeData` does
   have `onVolumeChanged`/`onBrightnessChanged`/`initialVolume`/
   `initialBrightness` fields, and the mobile-style controls widget already
   implements the swipe gesture internally (`GestureDetector.onVerticalDragUpdate`
   at material.dart:933, on-screen percentage indicators). **But** this only
   tracks a local 0.0–1.0 UI value — it does NOT call any real OS volume/
   brightness API. Making it actually work requires: (a) adding new
   third-party native plugin dependencies (e.g. volume-controller-style and
   screen-brightness-style packages — zero such deps currently in
   `pubspec.yaml`, confirmed via grep), (b) verifying those plugins support
   macOS specifically (the only platform used for visual verification all
   session — desktop volume/brightness plugins are less commonly
   maintained for macOS than mobile), (c) possible platform
   permission/entitlement config, and (d) separately confirming whether
   `MaterialDesktopVideoControlsThemeData` (the desktop-style controls
   actually used by `AdaptiveVideoControls` on this app's tested platform)
   even has an equivalent gesture at all — NOT yet confirmed either way.
   **User's decision: "先跳过,但是要记录下来.等日后在做" (skip for now, but
   record it — revisit later).** Deferred, not started. When picked up
   again: first confirm desktop gesture support before deciding whether to
   take on the new native-plugin dependency, and consider whether a
   horizontal-drag-to-seek gesture (unconfirmed second `GestureDetector` at
   material.dart:1666) could be delivered independently/first without the
   volume/brightness plugin dependency, as a smaller first step.
5. **片源切换UI（轻量版） (Lightweight source-switching UI)** — NOT STARTED.
   When an episode has results from both anime1.me and Xifan, show a simple
   source switch tab/dropdown at the top of the player screen. Do NOT
   attempt to replicate the reference app's full MediaSelector engine
   (auto-selection, tiering, preference memory) — this is a low-cost
   pathfinder before deciding whether to invest in a full MediaSelector
   later. Architecturally self-contained, no new native dependencies
   needed — good candidate to pick up next instead of item 4.

### Low priority
6. **字幕轨道切换 (Subtitle track switching)** — Needs research first: do
   anime1.me/Xifan actually provide subtitle track data at all?
7. **跳过片头片尾 (Skip intro/outro)** — Needs research first: do the data
   sources provide chapter/duration metadata? Otherwise only a simplified
   "skip fixed N seconds" version is feasible.
8. **缓存/离线下载 (Cache/offline download)** — Needs architecture research.
   No BitTorrent source exists in this app (unlike the reference app), so
   the approach would have to be different — e.g. direct-link download +
   local file management, not BT streaming-while-downloading.
9. **弹幕功能 (Danmaku, Plan 1d)** — Explicitly deferred by the user
   throughout this session ("弹幕可以后面再做"/"弹幕放到最后"). Real
   Animeko self-hosted danmaku API confirmed (`GET/POST
   /v1/danmaku/{episodeId}`, based on Kotlin generated client
   `DanmakuAniApi.kt`) but blocked on an episode-ID-mapping problem: scraped
   anime1.me/Xifan episodes have no mapping to Bangumi's own `episodeId`
   used by this API. Needs that mapping problem solved before this can be
   picked up.

## Still-open backlog items (unrelated to playback, carried over from
earlier in the session — asked repeatedly, never answered by the user)
10. **是否推送 `main` 分支到 `origin/main`** — Local `main` is far ahead of
    `origin/main` and has never been pushed.
11. **确认此前两个bug修复是否已实测生效** — (a) 稀饭动漫(Xifan) native-player
    proxy fix (commit `03a59eb`, casts `player.platform as NativePlayer`
    and calls `setProperty('http-proxy', proxyUrl)` since media_kit's
    `PlayerConfiguration` has no proxy field and Dio's proxy config doesn't
    apply to the native player); (b) the Flutter-macOS
    `HardwareKeyboard`-state-corruption workaround for the proxy settings
    page's text-input bug (fixed by relaunching the preview app). Neither
    has been confirmed working by the user via a live retest.
