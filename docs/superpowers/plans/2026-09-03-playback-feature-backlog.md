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

### High priority
1. **倍速播放 (Playback speed control)** — Add a speed-selection UI to the
   player screen using media_kit's `Player.setRate()` (common presets
   0.5x–2x), remember the last-selected speed. Lowest cost, near-universal
   expected feature.
2. **自动连播下一集 (Auto-play next episode)** — After playback completes,
   automatically navigate to the next episode (based on the existing
   `SubjectEpisodesController` episode list). Listen on
   `_player.stream.completed`; change localized to the player screen.
3. **记住播放位置 / 简易播放历史 (Remember playback position / simple local
   history, no cloud sync)** — Record playback position on exit, auto-jump
   to it next time. Local storage only (SQLite/local DB), skip the complex
   Bangumi cloud-sync subset for now.

### Medium priority
4. **手势控制 (Gesture controls)** — Swipe to adjust volume/brightness/seek
   position. media_kit's `MaterialVideoControlsThemeData` already reserves
   `onVolumeChanged`/`onBrightnessChanged`-style callback slots, so wiring
   cost is much lower than building from scratch.
5. **片源切换UI（轻量版） (Lightweight source-switching UI)** — When an
   episode has results from both anime1.me and Xifan, show a simple source
   switch tab/dropdown at the top of the player screen. Do NOT attempt to
   replicate the reference app's full MediaSelector engine (auto-selection,
   tiering, preference memory) — this is a low-cost pathfinder before
   deciding whether to invest in a full MediaSelector later.

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
