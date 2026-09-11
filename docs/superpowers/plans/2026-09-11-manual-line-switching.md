# 手动切换线路 / BT 释出版本 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users manually pick which playback candidate (CDN "line" for Xifan/Anime1, or subtitle-group/resolution "release" for Mikan BT) is used, instead of only relying on the player's silent automatic fallback.

**Architecture:** Add a generic `label` getter to `MediaPlaybackSource` (base returns `null`; `TorrentPlaybackSource` overrides with subtitle-group/resolution/language text). Add a new "线路" icon button to `PlayerBottomBar` that opens a new `LineSwitchSheet` bottom-sheet widget listing the current candidates. Wire a `_switchToCandidate()` method into the existing `_PlayerScreenState` that disposes the old candidate, opens the new one via the existing `_openCandidate()`, and re-seeks to the in-memory position captured before the switch. No new Riverpod providers or state-management abstractions; everything reuses the existing `_candidates`/`_candidateIndex`/`_openCandidate()` machinery already in `_PlayerScreenState`.

**Tech Stack:** Flutter, Riverpod (codegen), media_kit, mocktail (tests), flutter_test.

**Design doc:** `docs/superpowers/specs/2026-09-11-manual-line-switching-design.md` (Approved)

## Global Constraints

- No new automated tests for `_PlayerScreenState`'s internal state machine — the codebase's existing convention (confirmed: no `player_screen_test.dart` exists) only writes automated widget tests for pure, props-driven widgets (`PlayerBottomBar`, and the new `LineSwitchSheet`). Task 5's `_PlayerScreenState` wiring is verified via `flutter analyze` + full `flutter test` regression + manual verification steps, not new unit tests.
- Preserve the existing `unawaited(candidate.dispose())` fire-and-forget pattern already used by the automatic-fallback error listener, `_handleBufferTimeout()`, and `_retry()` in `lib/ui/player/player_screen.dart` — dispose failures must never block opening the new candidate.
- `_retry()` behavior is unchanged: it still resets to candidate index 0 and fully re-invalidates the provider. Do not make it preserve the user's manual selection.
- Run `dart format lib test` and `flutter analyze` before every commit; both must be clean (analyze: zero errors — pre-existing infos are fine).
- Follow Conventional Commits with scope, e.g. `feat(player): ...`.

---

### Task 1: `MediaPlaybackSource.label` base getter

**Files:**
- Modify: `lib/domain/media/media_source.dart`
- Test: `test/domain/media/media_source_test.dart`

**Interfaces:**
- Produces: `MediaPlaybackSource.label` — `String? get label => null;` (instance getter on the abstract base class, inherited by every existing and future subclass unless overridden).

- [ ] **Step 1: Write the failing test**

Add this test at the end of `test/domain/media/media_source_test.dart` (inside `void main() { ... }`, after the existing `'MediaPlaybackSource.dispose() defaults to a no-op'` test):

```dart
  test('MediaPlaybackSource.label defaults to null', () async {
    const source = _FakePlaybackSource();
    expect(source.label, isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/media/media_source_test.dart`
Expected: FAIL with something like "The getter 'label' isn't defined for the type '_FakePlaybackSource'" (compile error, since `label` doesn't exist yet).

- [ ] **Step 3: Add the `label` getter to the abstract base class**

In `lib/domain/media/media_source.dart`, insert the new getter between the existing `headers` getter and the `prepare()` method:

```dart
abstract class MediaPlaybackSource {
  const MediaPlaybackSource();

  String get url;

  Map<String, String> get headers;

  /// Display text for a manual line/release picker (see
  /// `PlayerBottomBar`'s line-switch button). Returns null when this
  /// source has no descriptive metadata, in which case the UI falls
  /// back to a 1-indexed "线路 N" label based on list position.
  String? get label => null;

  Future<String> prepare() async => url;

  Future<void> dispose() async {}
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/media/media_source_test.dart`
Expected: PASS (all 4 tests in the file, including the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/media/media_source.dart test/domain/media/media_source_test.dart
git commit -m "feat(media): add MediaPlaybackSource.label for manual line picker"
```

---

### Task 2: `TorrentPlaybackSource.label` override

**Files:**
- Modify: `lib/data/torrent/torrent_playback_source.dart`
- Test: `test/data/torrent/torrent_playback_source_test.dart`

**Interfaces:**
- Consumes: `MediaPlaybackSource.label` (Task 1), `RssRelease.parsed` (`ParsedTitle` with `String alliance`, `String? resolution`, `List<String> subtitleLanguages` — from `lib/domain/media/title_parser.dart`), `parseTitle(String rawTitle)` (test helper to build `ParsedTitle` fixtures).
- Produces: `TorrentPlaybackSource.label` — `String?`, joining non-empty `alliance`/`resolution`/`subtitleLanguages` with single spaces (languages joined with `/`), or `null` if all three are absent.

- [ ] **Step 1: Write the failing tests**

Add this group at the end of `test/data/torrent/torrent_playback_source_test.dart` (inside `void main() { ... }`, as a sibling to the existing `group`s — it needs no `dio`/`engine` mocking since `label` only reads `release.parsed` synchronously):

```dart
  group('label', () {
    TorrentPlaybackSource sourceFor(String rawTitle) {
      return TorrentPlaybackSource(
        release: RssRelease(
          item: RssItem(
            title: rawTitle,
            torrentUrl: 'https://mikan.tangbai.cc/Download/x/x.torrent',
            contentLength: 1000,
          ),
          parsed: parseTitle(rawTitle),
        ),
        engine: MockRqbitEngine(),
      );
    }

    test('joins alliance, resolution, and languages when all present', () {
      final source = sourceFor('[绿茶字幕组][Show][10][1080P][简体]');
      expect(source.label, '绿茶字幕组 1080P 简体');
    });

    test('skips alliance when title has no brackets', () {
      final source = sourceFor('Show 10 1080P 简体');
      expect(source.label, isNot(contains('Show 10 1080P 简体')));
      expect(source.label, '1080P 简体');
    });

    test('skips resolution when unparseable', () {
      final source = sourceFor('[绿茶字幕组][Show][10][简体]');
      expect(source.label, '绿茶字幕组 简体');
    });

    test('skips languages when none detected', () {
      final source = sourceFor('[绿茶字幕组][Show][10][1080P]');
      expect(source.label, '绿茶字幕组 1080P');
    });

    test('returns null when alliance, resolution, and languages are all absent', () {
      final source = sourceFor('Show 10');
      expect(source.label, isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/torrent/torrent_playback_source_test.dart`
Expected: FAIL with "The getter 'label' isn't defined for the type 'TorrentPlaybackSource'" (compile error). If any of the assumed parse outputs for the fixture titles above turn out wrong once `label` exists (e.g. `1080P` case-normalized differently, or `简体` not recognized), adjust the expected string in the test to match `parseTitle`'s actual output — do not change `parseTitle` itself; it is out of scope (see design doc's "范围外").

- [ ] **Step 3: Add the `label` override**

In `lib/data/torrent/torrent_playback_source.dart`, insert between the `headers` getter and `prepare()`:

```dart
  @override
  String? get label {
    final parsed = release.parsed;
    final parts = <String>[
      if (parsed.alliance.isNotEmpty) parsed.alliance,
      if (parsed.resolution != null) parsed.resolution!,
      if (parsed.subtitleLanguages.isNotEmpty)
        parsed.subtitleLanguages.join('/'),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/torrent/torrent_playback_source_test.dart`
Expected: PASS (all tests in the file, including the new `label` group). If a fixture title's actual parse result differs from what Step 1 assumed, fix the test expectation now (not the implementation) and re-run.

- [ ] **Step 5: Commit**

```bash
git add lib/data/torrent/torrent_playback_source.dart test/data/torrent/torrent_playback_source_test.dart
git commit -m "feat(torrent): override label with subtitle group/resolution/language"
```

---

### Task 3: `LineSwitchSheet` widget

**Files:**
- Create: `lib/ui/player/line_switch_sheet.dart`
- Create: `test/ui/player/line_switch_sheet_test.dart`

**Interfaces:**
- Consumes: `MediaPlaybackSource` (`lib/domain/media/media_source.dart`, incl. `.label` from Task 1), `TorrentPlaybackSource` (`lib/data/torrent/torrent_playback_source.dart`, incl. `.release.item.title` from Task 2's unchanged fields).
- Produces: `LineSwitchSheet` — a `StatelessWidget` with constructor `LineSwitchSheet({required List<MediaPlaybackSource> candidates, required int currentIndex, required ValueChanged<int> onSelect})`. Task 5 will construct this inside `showModalBottomSheet`.

- [ ] **Step 1: Write the failing test file**

Create `test/ui/player/line_switch_sheet_test.dart`:

```dart
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/media/title_parser.dart';
import 'package:animeko_flutter/ui/player/line_switch_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRqbitEngine extends Mock implements RqbitEngine {}

class _LabeledSource extends MediaPlaybackSource {
  const _LabeledSource(this._label);
  final String? _label;
  @override
  String get url => 'https://example.com/video.mp4';
  @override
  Map<String, String> get headers => const {};
  @override
  String? get label => _label;
}

void main() {
  Widget buildSheet({
    required List<MediaPlaybackSource> candidates,
    int currentIndex = 0,
    ValueChanged<int>? onSelect,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LineSwitchSheet(
          candidates: candidates,
          currentIndex: currentIndex,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('falls back to "线路 N" when label is null', (tester) async {
    await tester.pumpWidget(
      buildSheet(candidates: const [_LabeledSource(null), _LabeledSource(null)]),
    );
    expect(find.text('线路 1'), findsOneWidget);
    expect(find.text('线路 2'), findsOneWidget);
  });

  testWidgets('shows label text when present', (tester) async {
    await tester.pumpWidget(
      buildSheet(candidates: const [_LabeledSource('绿茶字幕组 1080P')]),
    );
    expect(find.text('绿茶字幕组 1080P'), findsOneWidget);
    expect(find.text('线路 1'), findsNothing);
  });

  testWidgets('highlights the current index with a check icon', (tester) async {
    await tester.pumpWidget(
      buildSheet(
        candidates: const [_LabeledSource('A'), _LabeledSource('B')],
        currentIndex: 1,
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles[0].selected, isFalse);
    expect(tiles[1].selected, isTrue);
  });

  testWidgets('tapping a tile invokes onSelect with its index', (tester) async {
    int? selected;
    await tester.pumpWidget(
      buildSheet(
        candidates: const [_LabeledSource('A'), _LabeledSource('B')],
        onSelect: (i) => selected = i,
      ),
    );
    await tester.tap(find.text('B'));
    expect(selected, 1);
  });

  testWidgets('shows original release title as subtitle for BT candidates', (
    tester,
  ) async {
    final engine = MockRqbitEngine();
    final release = RssRelease(
      item: const RssItem(
        title: '[绿茶字幕组][Show][10][1080P]',
        torrentUrl: 'https://mikan.tangbai.cc/Download/x/x.torrent',
        contentLength: 1000,
      ),
      parsed: parseTitle('[绿茶字幕组][Show][10][1080P]'),
    );
    final torrentSource = TorrentPlaybackSource(release: release, engine: engine);

    await tester.pumpWidget(
      buildSheet(candidates: [torrentSource, const _LabeledSource(null)]),
    );

    expect(find.text('[绿茶字幕组][Show][10][1080P]'), findsOneWidget);
    // Non-BT candidate ("线路 2") has no subtitle.
    expect(find.text('线路 2'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/player/line_switch_sheet_test.dart`
Expected: FAIL with "Error: Error when reading 'lib/ui/player/line_switch_sheet.dart': No such file or directory" (or an unresolved import error), since the widget doesn't exist yet.

- [ ] **Step 3: Create the widget**

Create `lib/ui/player/line_switch_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../data/torrent/torrent_playback_source.dart';
import '../../domain/media/media_source.dart';

/// Bottom-sheet content listing the current playback candidates for
/// manual selection (see `PlayerBottomBar`'s "线路" button). Pure,
/// props-driven widget — all switching logic lives in the caller.
class LineSwitchSheet extends StatelessWidget {
  const LineSwitchSheet({
    super.key,
    required this.candidates,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<MediaPlaybackSource> candidates;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          final isSelected = index == currentIndex;
          final subtitle = candidate is TorrentPlaybackSource
              ? Text(candidate.release.item.title)
              : null;
          return ListTile(
            title: Text(candidate.label ?? '线路 ${index + 1}'),
            subtitle: subtitle,
            selected: isSelected,
            trailing: isSelected ? const Icon(Icons.check) : null,
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/player/line_switch_sheet_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/line_switch_sheet.dart test/ui/player/line_switch_sheet_test.dart
git commit -m "feat(player): add LineSwitchSheet widget for manual candidate picker"
```

---

### Task 4: `PlayerBottomBar` line-switch button

**Files:**
- Modify: `lib/ui/player/player_bottom_bar.dart`
- Test: `test/ui/player/player_bottom_bar_test.dart`

**Interfaces:**
- Produces: `PlayerBottomBar.onLineSwitch` — new constructor field `final VoidCallback? onLineSwitch;` (nullable, unlike the bar's other `required` non-nullable callbacks — `null` renders the button disabled). Task 5 will pass this from `_PlayerScreenState`.

- [ ] **Step 1: Write the failing tests**

In `test/ui/player/player_bottom_bar_test.dart`, update the `buildBar` helper to accept and forward the new parameter, and add new test cases. Modify the helper's signature and body:

```dart
  Widget buildBar({
    bool isPlaying = false,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 10),
    VoidCallback? onPlayPause,
    ValueChanged<Duration>? onSeek,
    double currentSpeed = 1.0,
    ValueChanged<double>? onSpeedSelected,
    VoidCallback? onLineSwitch,
    VoidCallback? onDrawerToggle,
    VoidCallback? onFullscreenToggle,
    bool isFullscreen = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PlayerBottomBar(
          isPlaying: isPlaying,
          position: position,
          duration: duration,
          onPlayPause: onPlayPause ?? () {},
          onSeek: onSeek ?? (_) {},
          currentSpeed: currentSpeed,
          speedOptions: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
          onSpeedSelected: onSpeedSelected ?? (_) {},
          onLineSwitch: onLineSwitch,
          onDrawerToggle: onDrawerToggle ?? () {},
          onFullscreenToggle: onFullscreenToggle ?? () {},
          isFullscreen: isFullscreen,
        ),
      ),
    );
  }
```

Note `onLineSwitch` deliberately has **no** `?? () {}` fallback — leaving it `null` by default lets the new disabled-state test below exercise the real `null` case.

Then add these tests (anywhere after the helper, alongside the other `testWidgets` cases):

```dart
  testWidgets('shows a line-switch icon', (tester) async {
    await tester.pumpWidget(buildBar());
    expect(find.byIcon(Icons.alt_route), findsOneWidget);
  });

  testWidgets('tapping the line-switch icon invokes onLineSwitch', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(buildBar(onLineSwitch: () => tapped = true));
    await tester.tap(find.byIcon(Icons.alt_route));
    expect(tapped, isTrue);
  });

  testWidgets('line-switch icon is disabled when onLineSwitch is null', (
    tester,
  ) async {
    await tester.pumpWidget(buildBar());
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.alt_route),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/player/player_bottom_bar_test.dart`
Expected: FAIL — "The named parameter 'onLineSwitch' isn't defined" (compile error), since `PlayerBottomBar` doesn't have the field yet.

- [ ] **Step 3: Add the field and button**

In `lib/ui/player/player_bottom_bar.dart`, update the constructor and field list:

```dart
class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.currentSpeed,
    required this.speedOptions,
    required this.onSpeedSelected,
    required this.onLineSwitch,
    required this.onDrawerToggle,
    required this.onFullscreenToggle,
    required this.isFullscreen,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final double currentSpeed;
  final List<double> speedOptions;
  final ValueChanged<double> onSpeedSelected;
  final VoidCallback? onLineSwitch;
  final VoidCallback onDrawerToggle;
  final VoidCallback onFullscreenToggle;
  final bool isFullscreen;
```

(`onLineSwitch` stays `required` in the constructor — callers must pass it explicitly, even though the value itself can be `null` — this matches the test helper's `required` positioning and keeps every field explicit at call sites.)

Then insert the new button in `build()`, between the speed `PopupMenuButton` and the existing 选集 `IconButton`:

```dart
            IconButton(
              icon: const Icon(Icons.alt_route, color: Colors.white),
              tooltip: '线路',
              onPressed: onLineSwitch,
            ),
            IconButton(
              icon: const Icon(Icons.playlist_play, color: Colors.white),
              tooltip: '选集',
              onPressed: onDrawerToggle,
            ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/player/player_bottom_bar_test.dart`
Expected: PASS (all existing tests plus the 3 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/player_bottom_bar.dart test/ui/player/player_bottom_bar_test.dart
git commit -m "feat(player): add line-switch button to PlayerBottomBar"
```

---

### Task 5: Wire manual switching into `PlayerScreen`

**Files:**
- Modify: `lib/ui/player/player_screen.dart`

**Interfaces:**
- Consumes: `LineSwitchSheet` (Task 3), `PlayerBottomBar.onLineSwitch` (Task 4), existing `_candidates`/`_candidateIndex`/`_openCandidate()` fields/methods already in `_PlayerScreenState`.
- Produces: `_PlayerScreenState._switchToCandidate(int newIndex)` and `_PlayerScreenState._showLineSwitchSheet()` (both private; no external consumers).

This task has no automated test per the Global Constraints (no `_PlayerScreenState` internal-state-machine tests in this codebase). Verify via `flutter analyze`, the full `flutter test` regression suite, and the manual steps below.

- [ ] **Step 1: Add the import**

At the top of `lib/ui/player/player_screen.dart`, alongside the existing imports, add:

```dart
import 'line_switch_sheet.dart';
```

- [ ] **Step 2: Add `_switchToCandidate` and `_showLineSwitchSheet`**

Insert these two methods immediately after the existing `_openCandidate` method (which currently ends right before `_handleBufferTimeout`):

```dart
  /// Manually switches to a different playback candidate at [newIndex]
  /// (e.g. a different BT release/subtitle group, or a different CDN
  /// line), preserving the current in-memory playback position. Disposes
  /// the previously-open candidate first, matching the fire-and-forget
  /// `unawaited(dispose())` pattern used by the automatic fallback paths
  /// above and by `_retry()`.
  Future<void> _switchToCandidate(int newIndex) async {
    final candidates = _candidates;
    if (candidates == null || newIndex == _candidateIndex) return;
    final capturedPosition = _player.state.position;
    final previous = candidates[_candidateIndex];
    unawaited(previous.dispose());
    _candidateIndex = newIndex;
    await _openCandidate(candidates[newIndex]);
    // `_openCandidate` -> `_maybeResumePosition()` seeks to the
    // last *persisted* (SharedPreferences) position, not the in-memory
    // position at the moment of switching -- overwrite it with the
    // captured value so manual line switches preserve exactly where
    // playback was, matching mainstream video players' behavior.
    await _player.seek(capturedPosition);
  }

  void _showLineSwitchSheet() {
    final candidates = _candidates;
    if (candidates == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => LineSwitchSheet(
        candidates: candidates,
        currentIndex: _candidateIndex,
        onSelect: (index) {
          Navigator.pop(sheetContext);
          _switchToCandidate(index);
        },
      ),
    );
  }
```

- [ ] **Step 3: Pass `onLineSwitch` to `PlayerBottomBar`**

Find the `PlayerBottomBar(` instantiation inside the nested `StreamBuilder<Duration>` (duration) builder callback. Add a new `onLineSwitch` argument right after `onSpeedSelected`'s closing `},` and before `onDrawerToggle: _toggleDrawer,`:

```dart
                                        onSpeedSelected: (value) async {
                                          await _player.setRate(value);
                                          await ref
                                              .read(
                                                playbackSpeedControllerProvider
                                                    .notifier,
                                              )
                                              .setPlaybackSpeed(value);
                                        },
                                        onLineSwitch:
                                            (_candidates?.length ?? 0) > 1
                                            ? _showLineSwitchSheet
                                            : null,
                                        onDrawerToggle: _toggleDrawer,
                                        onFullscreenToggle: _toggleFullscreen,
                                        isFullscreen: isFullscreen(context),
```

- [ ] **Step 4: Format, analyze, and run the full test suite**

```bash
dart format lib test
flutter analyze
flutter test
```

Expected: `dart format` reports no changes needed (or auto-fixes trivial whitespace); `flutter analyze` reports zero errors (pre-existing infos are fine); `flutter test` passes all ~359+ tests (the exact count will have grown by the new tests added in Tasks 1–4).

- [ ] **Step 5: Manual verification**

Since `_PlayerScreenState` has no automated test coverage, manually verify on macOS (`flutter run -d macos`):

1. Play an episode from a source with multiple candidates (e.g. search Mikan/BT for a title with several subtitle-group releases, or Xifan with multiple CDN lines).
2. Confirm the new "线路" icon button (`Icons.alt_route`) appears in the bottom bar, enabled.
3. Tap it — confirm a bottom sheet opens listing every candidate, with BT releases showing "字幕组 分辨率 语言"-style labels and a subtitle line with the raw release title, and non-BT candidates showing "线路 N".
4. Confirm the currently-playing candidate is highlighted with a check icon.
5. Let playback advance a bit, then tap a different candidate in the sheet — confirm: the sheet closes, playback switches to the new candidate, and resumes at (approximately) the same position it was at before switching (not restarted from 0, not jumping to a stale persisted position).
6. Play an episode from a source with only one candidate (e.g. Anime1) — confirm the "线路" button is visible but greyed out/disabled and does nothing when tapped.
7. After manually switching, force a playback failure or let the new candidate exhaust naturally (e.g. temporarily disconnect network) — confirm automatic fallback continues from the manually-selected index forward, not restarting from index 0.
8. Tap "重试" after a full failure — confirm it resets to index 0 and fully re-resolves (does not preserve the prior manual selection).

If any manual check fails, fix the relevant code from Steps 1–3 before proceeding.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): wire manual line-switch sheet into PlayerScreen"
```

---

## Self-Review Notes

- **Spec coverage:** All "范围内" (in-scope) items from the design doc are covered: `label` getter (Task 1), `TorrentPlaybackSource` override (Task 2), bottom-sheet UI (Task 3), bottom-bar button incl. disabled state when candidates ≤ 1 (Task 4), manual switch with position preservation + dispose-before-prepare + fallback continuing from manual index + `_retry()` untouched (Task 5). "范围外" items (cross-vendor UI, rqbit engine, RSS/title parsing, new providers) are explicitly not touched by any task.
- **Type consistency:** `LineSwitchSheet(candidates, currentIndex, onSelect)` constructor signature in Task 3 matches its usage in Task 5's `_showLineSwitchSheet()`. `PlayerBottomBar.onLineSwitch` (`VoidCallback?`) in Task 4 matches the argument passed in Task 5 Step 3. `MediaPlaybackSource.label` (Task 1) and `TorrentPlaybackSource.label` (Task 2) both use `String?`.
- **No placeholders:** every step has literal, complete code; no "TBD"/"handle appropriately" language.
