# Subject-Detail Episode Selection & Player Controls Redesign — Design

**Status:** Approved (verbal, section-by-section), pending written-spec review.

## Motivation

The user, now treating this project as a daily-use product rather than a learning exercise,
reported that the subject detail page and the video player feel too simple compared to
mature reference apps (Kazumi, and the original Kotlin Multiplatform Animeko/Ani app):

- There is no real data-source selection UI — episodes from all registered `MediaSource`s
  (anime1.me, 稀饭动漫/Xifan) are merged into one list and only implicitly grouped.
- Episode selection is a nested, visually noisy `ExpansionTile`-grouped-by-source bottom
  sheet.
- The player's controls are scattered: play/pause, seek bar, and fullscreen come from
  media_kit_video's default `AdaptiveVideoControls` (position controlled by the package,
  not the app), while the app's own back/source/speed/screenshot buttons float as separate
  `Positioned` widgets in two different corners with no unifying bar. Switching source or
  episode replaces the entire `PlayerScreen` (`Navigator.pushReplacement`), destroying and
  recreating the `Player`/`VideoController`.

This design addresses all three complaints together, as one combined spec (per the user's
explicit preference — see Decisions).

## Scope

One combined spec covering:

1. A redesigned, flattened episode/source selection widget, shared between the subject-detail
   bottom sheet and a new in-player drawer.
2. A fully custom player top bar + bottom bar, replacing media_kit_video's default controls
   entirely.
3. A new in-player episode/source drawer, plus an architecture change so switching
   episode/source hot-swaps the existing `Player` instance instead of rebuilding the whole
   screen.
4. An explicit non-goals list, reaffirming several already-deferred features so this redesign
   doesn't silently expand into them.

Out of scope: any change to `lib/domain/media/`, `lib/domain/play/`'s merge/matching logic,
`lib/domain/subject/` (collection/rating), or any other screen (Home/Search/Schedule/
Settings/Collection). This is a UI-layer redesign of selection presentation and player
control layout; the underlying data (merged `MergedEpisode` list, source registry, playback
URL resolution) is unchanged.

## Decisions (from brainstorming Q&A)

1. **Single combined spec**, not two separate specs for subject-detail and player.
2. **Source/episode selection model stays "merge-and-display."** No source-first hierarchical
   picker, no auto-pick-best-source-into-player, no `MediaSelector`-style auto-tiering/
   preference-memory engine (as already decided when Xifan was added — see
   `2026-09-01-xifan-media-source-design.md`). Only the *presentation* of the merged list
   changes.
3. **Player controls are a fully custom top+bottom bar**, completely replacing
   `AdaptiveVideoControls` — not a rearrangement of the existing floating buttons around the
   default bar.
4. **Approach chosen: collapsible drawer panel** (see Approaches Considered below), over a
   permanent side panel or a minimal-unification-only approach.
5. Mid-brainstorm, the user asked to continue the rest of the conversation in Chinese; this
   doc remains in English to match the existing spec corpus, per established convention.

### Approaches considered

- **Minimal unification** — flatten the sheet's internals (chips + grid) and give the player
  custom bars, but keep source/episode switching as a popup/modal reusing the same sheet.
  Cheapest, but leaves in-player episode switching exactly as scattered/indirect as today.
- **Persistent side panel** — Kazumi/Animeko-style two-pane layout, episode/source panel
  always visible beside the video. Closest to both reference apps, but permanently narrows
  the video area and is the largest implementation lift; rejected because this app is
  macOS-desktop-only with no need to match Kazumi's phone-first layout trade-offs.
- **Collapsible drawer panel (chosen)** — custom top+bottom bars, plus a right-side drawer
  (closed by default) holding the shared selection widget. Video stays full-width at all
  times; in-player episode/source switching becomes a real, discoverable feature (unlike
  today's tiny popup) without the permanent-narrowing cost of the side-panel approach.

## Reference-app research summary

- **Kazumi** (`lib/pages/player/player_item.dart`, `video_page.dart`): uses
  `Video(controls: NoVideoControls)` and implements 100% custom top/bottom bars (both
  `SlideTransition`-animated, hidden together via a `Visibility`/`lockPanel` flag). Episode
  selection ("选集") and comments live in an always-visible tabbed panel beside/below the
  video, not a modal. Source switching ("roads") happens inside that same panel. Also has a
  panel lock and long-press-to-2.5x-speed gesture — both already deferred in this repo's
  backlog and reaffirmed out of scope here (see Non-goals).
- **Animeko/open-ani (KMP, not in this repo)**: `EpisodePage.kt` composes `EpisodeVideo.kt`
  alongside `EpisodeDetails.kt` (episode list, danmaku list, comments, stats) — same
  "video + persistent info panel" shape as Kazumi. A dedicated `ui-mediaselect` module has
  `MediaSelectorSummaryBanner.kt`, a small tappable summary of the current source/resolution/
  subtitle-group that expands to reveal alternatives — this directly informed the
  "merge-and-display with improved presentation" approach for source selection here, as
  opposed to either a full hierarchical picker or today's nested `ExpansionTile` sheet. A
  separate `ui-settings/mediasource/selector/episode/` pane configures the auto-selector's
  ranking rules — part of the auto-tiering engine already excluded from scope (Decision 2).
  Fullscreen lives in the bottom-right of the custom bottom bar.

Common pattern adopted here: fully custom top/bottom bars (Section 2), and episode/source
selection in a panel next to the video rather than an ephemeral popup (Section 3, as a
collapsible drawer rather than Animeko/Kazumi's permanent panel, per the chosen approach).

## Architecture

### Section 1 — Shared `EpisodeSourceGrid` widget

New file `lib/ui/subject/episode_source_grid.dart`, a stateless widget replacing the current
nested-`ExpansionTile` internals of `episode_source_sheet.dart`. It is reused unchanged as the
content of both the subject-detail bottom sheet and the new in-player drawer (Section 3).

- **Inputs**: `List<MergedEpisode> episodes`, `List<MediaSource> sources` (for
  `sourceLabel()`), `void Function(MergedEpisode) onEpisodeSelected`, and an optional
  `MergedEpisode? currentEpisode` (null when opened from the subject-detail page, where there
  is no "currently playing" episode yet; set when opened from the in-player drawer).
- **Layout, top row**: a horizontally-scrollable `Wrap`/`ListView` of `ChoiceChip`s — `"全部"`
  plus one chip per distinct `sourceId` present in `episodes`, labeled via the existing
  `sourceLabel(sources, sourceId)` helper. Selecting a chip is a pure client-side filter over
  the already-fetched list; no new query is issued and no filter choice is persisted across
  opens (matches Decision 2 — no preference-memory engine).
- **Layout, below**: the existing wrapping grid of `OutlinedButton` episode pills, now driven
  by the filtered list instead of one list per `ExpansionTile` group.
- **New capability**: when `currentEpisode` is non-null, the pill matching it (same
  `MergedEpisode` identity/title+sourceId) renders in a filled/highlighted state instead of
  the default outlined state — a capability the current sheet has no equivalent for.

`lib/ui/subject/episode_source_sheet.dart` becomes a thin wrapper: a
`DraggableScrollableSheet` with a header (`"选择集数"`) containing an `EpisodeSourceGrid`
(with `currentEpisode: null`). Its existing `onEpisodeSelected` callback and the
`SubjectDetailScreen`'s "开始观看" button → `context.push('/subject/:id/play', extra: episode)`
navigation are unchanged.

### Section 2 — Custom player top bar + bottom bar

`lib/ui/player/player_screen.dart`'s `Video(controller: _controller)` gains
`controls: NoVideoControls`, fully disabling `AdaptiveVideoControls`. Two new bar widgets are
extracted into their own files (splitting the current 778-line monolith, consistent with the
"smaller, well-bounded units" principle):

- **`lib/ui/player/player_top_bar.dart`** — slides down when visible: back button (left, pops
  the player — identical behavior to today's `_BackButton`); episode/subject title (center-
  left, single-line ellipsis); screenshot icon (right — identical behavior to today's
  `_ScreenshotButton`).
- **`lib/ui/player/player_bottom_bar.dart`** — slides up, shown/hidden together with the top
  bar: play/pause icon (leftmost); current position / total duration time labels; a
  draggable `Expanded` seek/progress bar (new — replaces the invisible default one, built
  with a plain `GestureDetector`+`Slider`-style widget, no attempt at the reference app's
  unified swipe+bar seek-cancel-region system — see Non-goals); speed button (same popup menu
  as today's `_SpeedButton`, relocated into this bar); a **new** episode/source drawer-toggle
  icon (opens Section 3's drawer; replaces today's `_SourceButton` popup entirely — all
  source switching now goes through the drawer); fullscreen toggle icon (rightmost, newly
  custom-built — today fullscreen is only reachable via media_kit's default bar or the `F`
  key). Both bars share the same show/hide trigger as today: tapping anywhere on the video
  toggles visibility, plus the existing inactivity auto-hide timer.

Unchanged: keyboard shortcuts (Space/←/→/↑/↓/F), the volume/brightness swipe gesture and its
`_AdjustmentHud`, `isFullscreen`/`enterFullscreen`/`exitFullscreen` helpers underneath the new
fullscreen button, playback-position persistence, and proxy forwarding.

### Section 3 — In-player drawer + in-place hot-swap architecture

**Drawer.** A right-side slide-in overlay (`AnimatedContainer` or `Drawer`-style widget),
closed by default, triggered by the new bottom-bar drawer icon (Section 2) or a keyboard
shortcut (`E`). Its content is `EpisodeSourceGrid` with `currentEpisode` set to the player's
current episode, so the active pill is highlighted. The drawer overlays on top of the video —
video width never shrinks, which is the reason this approach was chosen over a permanent side
panel. Closes via: tapping the drawer icon again, tapping the video area outside the drawer,
or `Esc`.

**Hot-swap architecture change.** Today, `_SourceButton` selection and auto-advance-to-next-
episode both call `Navigator.pushReplacement(MaterialPageRoute(builder: (_) =>
PlayerScreen(episode: target, ...)))`, destroying and recreating the `Player`/
`VideoController`. The new design gives `_PlayerScreenState` a mutable `MergedEpisode
_currentEpisode` field (seeded from `widget.episode`, no longer treated as fixed). Selecting
an episode/source in the drawer calls `setState(() => _currentEpisode = target)`; the existing
`ref.listen(episodePlayControllerProvider(_currentEpisode), ...)` side effect re-resolves the
playback URL and calls `_player.open(...)` on the *same* `Player` instance — no widget rebuild,
no new `Navigator` route. `_maybePlayNextEpisode` (auto-advance) is updated to use this same
state-update path instead of `pushReplacement`. `PlaybackPositionStorage` resume/save behavior
is unchanged; it no longer depends on a fresh page instance being created to fire.

## Testing strategy

- `test/ui/subject/episode_source_grid_test.dart` (new) — chip filtering (tapping a source
  chip narrows the grid; "全部" restores it), current-episode highlight rendering, and
  `onEpisodeSelected` callback firing with the correct `MergedEpisode`.
- `test/ui/subject/episode_source_sheet_test.dart` — update to reflect the thin-wrapper
  structure (header + `EpisodeSourceGrid`); existing "shows all episodes"/"tapping an episode
  invokes callback" tests adapt to the flattened chip+grid layout instead of asserting
  `ExpansionTile` groups.
- `test/ui/player/player_top_bar_test.dart`, `test/ui/player/player_bottom_bar_test.dart`
  (new) — button presence/tap behavior in isolation (back, screenshot, play/pause, speed
  popup, drawer toggle, fullscreen toggle), independent of a real `Player`/video surface.
- `test/ui/player/player_screen_test.dart` — update: assert `NoVideoControls` is passed to
  `Video`; assert tapping the drawer-toggle bottom-bar icon opens the drawer showing
  `EpisodeSourceGrid`; assert selecting an episode/source in the drawer updates
  `_currentEpisode`/triggers a new `episodePlayControllerProvider` read *without* a new
  `Navigator` push (i.e. the same `PlayerScreen` widget instance survives — verify via a
  `GlobalKey` or by asserting `Navigator` history length is unchanged); keep existing
  keyboard-shortcut and swipe-gesture tests as-is since those code paths are untouched.
- No new test is added for the removed `_SourceButton` popup — its behavior is fully
  superseded by the drawer tests above (YAGNI).

## Non-goals (explicit, reaffirming prior decisions)

- **Subtitle track selection UI** — needs research first: unclear whether anime1.me/Xifan
  expose subtitle tracks at all (already flagged as a research gap in
  `2026-09-03-playback-feature-backlog.md`).
- **Gesture-lock panel** — already deferred in the playback backlog doc.
- **Long-press-to-2.5x-speed gesture** — already deferred, same doc.
- **Full `MediaSelector` auto-tiering/preference-memory engine** (auto resolution/subtitle-
  group ranking, cross-session source preference) — excluded per Decision 2; this redesign
  only improves presentation of the existing merge-and-display model.
- **Danmaku** — already deferred per the Plan 1d investigation.
- **`PlayerStatsOverlay`-style decoder/bitrate/resolution debug overlay** — an advanced,
  power-user feature of the reference KMP app; not requested and out of scope here.
- **Unified swipe-seek + progress-bar-seek cancel-region system** (as in reference-app PR
  #3161) — this redesign builds a basic draggable progress bar only, not that refined
  gesture/bar unification.
- **Responsive/adaptive compact-vs-wide layout switching** — this project is macOS-desktop-
  only (Phase 1); only one wide-screen layout is designed, with no phone-compact variant.

## Out of scope

- `lib/domain/media/` (source registry, `MediaSource` interfaces), `lib/domain/play/`'s
  episode-merge/title-matching logic, and `lib/domain/subject/` (collection/rating) are all
  unchanged.
- No changes to Home/Search/Schedule/Collection/Settings screens.
- No changes to the subject-detail page's header/tags/summary/cast-staff/collection/rating
  sections — only the episode-selection entry point (`EpisodeSourceSheet`'s internals) is
  touched.

## Spec self-review (performed inline)

- **Placeholder scan**: no TBD/TODO markers remain.
- **Internal consistency**: Section 1's `EpisodeSourceGrid` contract (inputs, highlight
  behavior) matches how it's reused in both Section 1's sheet wrapper and Section 3's drawer;
  Section 3's hot-swap change matches the testing strategy's assertion approach (same widget
  instance, no new Navigator push); the non-goals list matches every deferred feature
  mentioned during reference-app research, with no contradictions.
- **Scope check**: combined per the user's explicit request (Decision 1); the three pieces
  (shared grid widget, custom bars, drawer+hot-swap) are tightly coupled — the drawer depends
  on the grid widget, and the drawer icon depends on the new bottom bar — so keeping them in
  one spec (and, per the user's likely next choice, one implementation plan or a tightly
  sequenced set of plan tasks) is appropriate rather than a sign of over-scoping.
- **Ambiguity check**: the previously-open question of "is source-switching modal or
  persistent" is resolved explicitly as "collapsible drawer" (Decision 4); "does the video
  shrink" is resolved explicitly as "no, drawer overlays" (Section 3).
