# Subject Detail + Player Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the nested-`ExpansionTile` episode/source sheet with a flat chip-filtered grid, and replace the player's default `AdaptiveVideoControls` + scattered floating buttons with a fully custom top/bottom bar plus a collapsible in-player episode/source drawer that hot-swaps playback without rebuilding the screen.

**Architecture:** A new stateless `EpisodeSourceGrid` widget (source filter chips + episode pill grid) is shared between the subject-detail bottom sheet and a new in-player drawer. Two new prop-driven bars (`PlayerTopBar`, `PlayerBottomBar`) replace `media_kit_video`'s default controls. `PlayerScreen` gains a mutable `_currentEpisode` field so episode/source switching updates state instead of pushing a new route, letting the existing `Player`/`VideoController` instance be reused (`_player.open(...)` on the same instance).

**Tech Stack:** Flutter, Riverpod 3.x (`@riverpod` codegen), `media_kit`/`media_kit_video`, `flutter_test`.

---

## Task 1: `EpisodeSourceGrid` widget (chip-filtered episode grid)

**Files:**
- Create: `lib/ui/subject/episode_source_grid.dart`
- Test: `test/ui/subject/episode_source_grid_test.dart`

- [ ] **Step 1: Write the failing test file**

```dart
// test/ui/subject/episode_source_grid_test.dart
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/episode_source_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});

  @override
  final String sourceId;

  @override
  final String title;
}

class _FakeSource implements MediaSource {
  const _FakeSource({required this.id, required this.displayName});

  @override
  final String id;

  @override
  final String displayName;

  @override
  Future<List<MediaCandidate>> search(String title) async => const [];

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async =>
      const [];

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) {
    throw UnimplementedError();
  }
}

void main() {
  final episode1 = MergedEpisode(
    episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
    sourceId: 'anime1',
  );
  final episode2 = MergedEpisode(
    episode: const _FakeEpisode(sourceId: 'xifan', title: '第1集'),
    sourceId: 'xifan',
  );
  const sources = [
    _FakeSource(id: 'anime1', displayName: 'anime1.me'),
    _FakeSource(id: 'xifan', displayName: '稀饭动漫'),
  ];

  group('sourceLabel', () {
    test('falls back to the raw sourceId when no source matches', () {
      expect(sourceLabel(const [], 'unknown'), 'unknown');
    });

    test('returns the matching source displayName', () {
      expect(sourceLabel(sources, 'anime1'), 'anime1.me');
    });
  });

  group('EpisodeSourceGrid', () {
    testWidgets('shows an "全部" chip plus one chip per distinct source', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.widgetWithText(ChoiceChip, '全部'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'anime1.me'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '稀饭动漫'), findsOneWidget);
      expect(find.text('第1集'), findsNWidgets(2));
    });

    testWidgets('tapping a source chip filters the episode grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, '稀饭动漫'));
      await tester.pump();

      expect(find.text('第1集'), findsOneWidget);
    });

    testWidgets('tapping "全部" after filtering restores every episode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, '稀饭动漫'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
      await tester.pump();

      expect(find.text('第1集'), findsNWidgets(2));
    });

    testWidgets('highlights the current episode with a filled pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
              currentEpisode: episode2,
            ),
          ),
        ),
      );

      expect(find.widgetWithText(FilledButton, '第1集'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '第1集'), findsOneWidget);
    });

    testWidgets('tapping an episode calls onEpisodeSelected with that episode', (
      tester,
    ) async {
      MergedEpisode? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1],
              sources: sources,
              onEpisodeSelected: (episode) => selected = episode,
            ),
          ),
        ),
      );

      await tester.tap(find.text('第1集'));

      expect(selected, same(episode1));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/subject/episode_source_grid_test.dart`
Expected: FAIL with `Error: Couldn't resolve the package 'animeko_flutter' in 'package:animeko_flutter/ui/subject/episode_source_grid.dart'` (or an equivalent "target of URI doesn't exist" compile error), since the file does not exist yet.

- [ ] **Step 3: Write the `EpisodeSourceGrid` implementation**

```dart
// lib/ui/subject/episode_source_grid.dart
import 'package:flutter/material.dart';

import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';

/// Returns the display name for [sourceId] looked up in [sources], falling
/// back to the raw [sourceId] if no source matches.
String sourceLabel(List<MediaSource> sources, String sourceId) {
  for (final source in sources) {
    if (source.id == sourceId) {
      return source.displayName;
    }
  }
  return sourceId;
}

/// Flat, chip-filterable grid of [MergedEpisode]s.
///
/// Shown inside [EpisodeSourceSheet] (subject-detail page) and inside the
/// player's episode/source drawer. Filtering by source is a pure
/// client-side operation over the already-fetched [episodes] list; no
/// filter choice is persisted across opens.
class EpisodeSourceGrid extends StatefulWidget {
  const EpisodeSourceGrid({
    super.key,
    required this.episodes,
    required this.sources,
    required this.onEpisodeSelected,
    this.currentEpisode,
  });

  final List<MergedEpisode> episodes;
  final List<MediaSource> sources;
  final ValueChanged<MergedEpisode> onEpisodeSelected;

  /// The episode currently playing, if any. When set, the matching pill
  /// (by sourceId + title) renders filled instead of outlined.
  final MergedEpisode? currentEpisode;

  @override
  State<EpisodeSourceGrid> createState() => _EpisodeSourceGridState();
}

class _EpisodeSourceGridState extends State<EpisodeSourceGrid> {
  String? _selectedSourceId;

  List<String> get _sourceIds {
    final seen = <String>{};
    final ids = <String>[];
    for (final episode in widget.episodes) {
      if (seen.add(episode.sourceId)) {
        ids.add(episode.sourceId);
      }
    }
    return ids;
  }

  bool _isCurrent(MergedEpisode episode) {
    final current = widget.currentEpisode;
    if (current == null) return false;
    return current.sourceId == episode.sourceId &&
        current.title == episode.title;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedSourceId == null
        ? widget.episodes
        : widget.episodes
              .where((episode) => episode.sourceId == _selectedSourceId)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('全部'),
                  selected: _selectedSourceId == null,
                  onSelected: (_) => setState(() => _selectedSourceId = null),
                ),
              ),
              for (final sourceId in _sourceIds)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(sourceLabel(widget.sources, sourceId)),
                    selected: _selectedSourceId == sourceId,
                    onSelected: (_) =>
                        setState(() => _selectedSourceId = sourceId),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final episode in filtered)
              _EpisodePill(
                episode: episode,
                isCurrent: _isCurrent(episode),
                onTap: () => widget.onEpisodeSelected(episode),
              ),
          ],
        ),
      ],
    );
  }
}

class _EpisodePill extends StatelessWidget {
  const _EpisodePill({
    required this.episode,
    required this.isCurrent,
    required this.onTap,
  });

  final MergedEpisode episode;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      episode.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (isCurrent) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/subject/episode_source_grid_test.dart`
Expected: PASS (all 7 tests green)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/subject/episode_source_grid.dart test/ui/subject/episode_source_grid_test.dart
git commit -m "feat(subject): add chip-filtered EpisodeSourceGrid widget"
```

---

## Task 2: Rewrite `EpisodeSourceSheet` as a thin wrapper around `EpisodeSourceGrid`

**Files:**
- Modify: `lib/ui/subject/episode_source_sheet.dart` (full rewrite, 110 lines)
- Modify: `test/ui/subject/episode_source_sheet_test.dart` (full rewrite, 110 lines)

- [ ] **Step 1: Write the failing (updated) test file**

```dart
// test/ui/subject/episode_source_sheet_test.dart
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/episode_source_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});

  @override
  final String sourceId;

  @override
  final String title;
}

class _FakeSource implements MediaSource {
  const _FakeSource({required this.id, required this.displayName});

  @override
  final String id;

  @override
  final String displayName;

  @override
  Future<List<MediaCandidate>> search(String title) async => const [];

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async =>
      const [];

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) {
    throw UnimplementedError();
  }
}

void main() {
  group('EpisodeSourceSheet', () {
    testWidgets(
      'shows a filter chip per source and all episodes by default',
      (tester) async {
        final episodes = [
          MergedEpisode(
            episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
            sourceId: 'anime1',
          ),
          MergedEpisode(
            episode: const _FakeEpisode(sourceId: 'xifan', title: '第1集'),
            sourceId: 'xifan',
          ),
        ];
        const sources = [
          _FakeSource(id: 'anime1', displayName: 'anime1.me'),
          _FakeSource(id: 'xifan', displayName: '稀饭动漫'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EpisodeSourceSheet(
                episodes: episodes,
                sources: sources,
                onEpisodeSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('选择集数'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'anime1.me'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, '稀饭动漫'), findsOneWidget);
        expect(find.text('第1集'), findsNWidgets(2));
      },
    );

    testWidgets('tapping an episode calls onEpisodeSelected with that episode', (
      tester,
    ) async {
      MergedEpisode? selected;
      final episode = MergedEpisode(
        episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
        sourceId: 'anime1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceSheet(
              episodes: [episode],
              sources: const [
                _FakeSource(id: 'anime1', displayName: 'anime1.me'),
              ],
              onEpisodeSelected: (e) => selected = e,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('第1集'));

      expect(selected, same(episode));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/subject/episode_source_sheet_test.dart`
Expected: FAIL — `find.text('选择集数')` finds nothing (current header text is `'选集'`) and `find.widgetWithText(ChoiceChip, ...)` finds nothing (current sheet renders `ExpansionTile`s, not `ChoiceChip`s).

- [ ] **Step 3: Rewrite `EpisodeSourceSheet`**

```dart
// lib/ui/subject/episode_source_sheet.dart
import 'package:flutter/material.dart';

import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';
import 'episode_source_grid.dart';

/// Modal bottom sheet for picking an episode (and, implicitly, its
/// source) from the subject-detail page. Wraps [EpisodeSourceGrid] with
/// a [DraggableScrollableSheet] and a header.
class EpisodeSourceSheet extends StatelessWidget {
  const EpisodeSourceSheet({
    super.key,
    required this.episodes,
    required this.sources,
    required this.onEpisodeSelected,
  });

  final List<MergedEpisode> episodes;
  final List<MediaSource> sources;
  final ValueChanged<MergedEpisode> onEpisodeSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '选择集数',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: EpisodeSourceGrid(
                episodes: episodes,
                sources: sources,
                onEpisodeSelected: onEpisodeSelected,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/subject/episode_source_sheet_test.dart`
Expected: PASS (both tests green)

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `flutter test`
Expected: PASS (no other file references the removed `ExpansionTile`/grouped-`Map` internals; `SubjectDetailScreen`'s `_openEpisodeSheet` only calls `EpisodeSourceSheet(episodes:, sources:, onEpisodeSelected:)`, whose signature is unchanged)

- [ ] **Step 6: Commit**

```bash
git add lib/ui/subject/episode_source_sheet.dart test/ui/subject/episode_source_sheet_test.dart
git commit -m "feat(subject): flatten EpisodeSourceSheet to chips + grid"
```

---

## Task 3: `PlayerTopBar` widget

**Files:**
- Create: `lib/ui/player/player_top_bar.dart`
- Test: `test/ui/player/player_top_bar_test.dart`

- [ ] **Step 1: Write the failing test file**

```dart
// test/ui/player/player_top_bar_test.dart
import 'package:animeko_flutter/ui/player/player_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the title and triggers callbacks on tap', (
    tester,
  ) async {
    var backTapped = false;
    var screenshotTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTopBar(
            title: '测试标题',
            onBack: () => backTapped = true,
            onScreenshot: () => screenshotTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('测试标题'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backTapped, isTrue);

    await tester.tap(find.byIcon(Icons.camera_alt));
    expect(screenshotTapped, isTrue);
  });

  testWidgets('ellipsizes a long title instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: PlayerTopBar(
              title: '一个非常非常非常非常非常非常长的剧集标题用于测试省略号效果',
              onBack: () {},
              onScreenshot: () {},
            ),
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(
      find.text('一个非常非常非常非常非常非常长的剧集标题用于测试省略号效果'),
    );
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/player/player_top_bar_test.dart`
Expected: FAIL — `lib/ui/player/player_top_bar.dart` does not exist yet (compile error).

- [ ] **Step 3: Write the `PlayerTopBar` implementation**

```dart
// lib/ui/player/player_top_bar.dart
import 'package:flutter/material.dart';

/// Custom top bar for [PlayerScreen], replacing the floating back button
/// that used to sit alone in the top-left corner.
///
/// Purely prop-driven so it is testable without a real [Player] or
/// Riverpod [ProviderScope].
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onScreenshot,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onScreenshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: '返回',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              tooltip: '截图',
              onPressed: onScreenshot,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/player/player_top_bar_test.dart`
Expected: PASS (both tests green)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/player_top_bar.dart test/ui/player/player_top_bar_test.dart
git commit -m "feat(player): add prop-driven PlayerTopBar widget"
```

---

## Task 4: `PlayerBottomBar` widget

**Files:**
- Create: `lib/ui/player/player_bottom_bar.dart`
- Test: `test/ui/player/player_bottom_bar_test.dart`

- [ ] **Step 1: Write the failing test file**

```dart
// test/ui/player/player_bottom_bar_test.dart
import 'package:animeko_flutter/ui/player/player_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildBar({
    bool isPlaying = false,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 10),
    VoidCallback? onPlayPause,
    ValueChanged<Duration>? onSeek,
    double currentSpeed = 1.0,
    ValueChanged<double>? onSpeedSelected,
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
          onDrawerToggle: onDrawerToggle ?? () {},
          onFullscreenToggle: onFullscreenToggle ?? () {},
          isFullscreen: isFullscreen,
        ),
      ),
    );
  }

  testWidgets('shows play icon when paused and pause icon when playing', (
    tester,
  ) async {
    await tester.pumpWidget(buildBar(isPlaying: false));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.pumpWidget(buildBar(isPlaying: true));
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('tapping play/pause invokes onPlayPause', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildBar(onPlayPause: () => tapped = true));

    await tester.tap(find.byIcon(Icons.play_arrow));

    expect(tapped, isTrue);
  });

  testWidgets('shows formatted position and duration labels', (tester) async {
    await tester.pumpWidget(
      buildBar(
        position: const Duration(minutes: 1, seconds: 5),
        duration: const Duration(minutes: 10),
      ),
    );

    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('dragging the progress bar invokes onSeek', (tester) async {
    Duration? seekedTo;
    await tester.pumpWidget(
      buildBar(
        duration: const Duration(minutes: 10),
        onSeek: (value) => seekedTo = value,
      ),
    );

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(50, 0));

    expect(seekedTo, isNotNull);
  });

  testWidgets('selecting a speed from the popup invokes onSpeedSelected', (
    tester,
  ) async {
    double? selectedSpeed;
    await tester.pumpWidget(
      buildBar(currentSpeed: 1.0, onSpeedSelected: (v) => selectedSpeed = v),
    );

    expect(find.text('1.0x'), findsOneWidget);

    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2.0x').last);
    await tester.pumpAndSettle();

    expect(selectedSpeed, 2.0);
  });

  testWidgets('tapping the drawer icon invokes onDrawerToggle', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(buildBar(onDrawerToggle: () => tapped = true));

    await tester.tap(find.byIcon(Icons.playlist_play));

    expect(tapped, isTrue);
  });

  testWidgets(
    'shows fullscreen icon when not fullscreen and fullscreen_exit when fullscreen',
    (tester) async {
      await tester.pumpWidget(buildBar(isFullscreen: false));
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      await tester.pumpWidget(buildBar(isFullscreen: true));
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    },
  );

  testWidgets('tapping the fullscreen icon invokes onFullscreenToggle', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      buildBar(onFullscreenToggle: () => tapped = true),
    );

    await tester.tap(find.byIcon(Icons.fullscreen));

    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/player/player_bottom_bar_test.dart`
Expected: FAIL — `lib/ui/player/player_bottom_bar.dart` does not exist yet (compile error).

- [ ] **Step 3: Write the `PlayerBottomBar` implementation**

```dart
// lib/ui/player/player_bottom_bar.dart
import 'package:flutter/material.dart';

/// Custom bottom bar for [PlayerScreen], replacing both media_kit_video's
/// default `AdaptiveVideoControls` bar and the app's old floating
/// top-right button row (`_SourceButton`/`_SpeedButton`/`_ScreenshotButton`).
///
/// Purely prop-driven so it is testable without a real [Player] or
/// Riverpod [ProviderScope]. `_PlayerScreenState` is responsible for
/// reading/writing the actual [Player] and providers and passing the
/// resulting values in as props.
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
  final VoidCallback onDrawerToggle;
  final VoidCallback onFullscreenToggle;
  final bool isFullscreen;

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = duration.inMilliseconds;
    final sliderMax = durationMs > 0 ? durationMs.toDouble() : 1.0;
    final sliderValue = durationMs > 0
        ? position.inMilliseconds.clamp(0, durationMs).toDouble()
        : 0.0;

    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              tooltip: isPlaying ? '暂停' : '播放',
              onPressed: onPlayPause,
            ),
            Text(
              _formatDuration(position),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: sliderValue,
                max: sliderMax,
                onChanged: durationMs > 0
                    ? (value) =>
                          onSeek(Duration(milliseconds: value.round()))
                    : null,
              ),
            ),
            Text(
              _formatDuration(duration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            PopupMenuButton<double>(
              tooltip: '播放速度',
              onSelected: onSpeedSelected,
              itemBuilder: (context) => [
                for (final speed in speedOptions)
                  PopupMenuItem<double>(value: speed, child: Text('${speed}x')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${currentSpeed}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.playlist_play, color: Colors.white),
              tooltip: '选集',
              onPressed: onDrawerToggle,
            ),
            IconButton(
              icon: Icon(
                isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              tooltip: isFullscreen ? '退出全屏' : '全屏',
              onPressed: onFullscreenToggle,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/player/player_bottom_bar_test.dart`
Expected: PASS (all 8 tests green)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/player_bottom_bar.dart test/ui/player/player_bottom_bar_test.dart
git commit -m "feat(player): add prop-driven PlayerBottomBar widget"
```

---

## Task 5: Disable `media_kit_video`'s default controls

**Files:**
- Modify: `lib/ui/player/player_screen.dart:464`

- [ ] **Step 1: Replace the bare `Video` widget with `controls: NoVideoControls`**

Find this line inside `build()`'s `playback.when(... data: (_) => ...)` branch:

```dart
                    : Video(controller: _controller),
```

Replace it with:

```dart
                    : Video(controller: _controller, controls: NoVideoControls),
```

(`NoVideoControls` is a top-level constant exported by `package:media_kit_video/media_kit_video.dart`, already imported at the top of this file — no new import needed.)

- [ ] **Step 2: Verify with static analysis**

Run: `flutter analyze lib/ui/player/player_screen.dart`
Expected: `No issues found!` (there is no automated widget test for `PlayerScreen` — see Task 6's note on why — so this task is verified by analysis only)

- [ ] **Step 3: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): disable media_kit_video's default AdaptiveVideoControls"
```

---

## Task 6: Add a mutable `_currentEpisode` field and re-point all `widget.episode` reads

**Note on test coverage for this and all remaining `player_screen.dart` tasks:** `PlayerScreen` has zero automated test coverage today (`test/ui/player/` does not exist). `_player = Player()` (media_kit) is constructed unconditionally as an instance field initializer with no dependency-injection seam, and requires `MediaKit.ensureInitialized()` (called only in `lib/app/main.dart`) plus native libmpv bindings that are unavailable inside the `flutter test` harness. Writing a widget test that pumps `PlayerScreen` would attempt to construct a real native player and is not feasible in this codebase as currently structured. Tasks 6–9 are therefore verified via `flutter analyze` (static correctness) instead of a new automated test — this is an intentional, pre-existing gap being preserved, not a shortcut introduced by this plan.

**Files:**
- Modify: `lib/ui/player/player_screen.dart:53-91` (field), `:97-98` (`_positionKey`), `:100-140` (`initState`), `:340-369` (`_maybePlayNextEpisode`), `:406-409` (`_retry`), `:411-433` (`build`'s `provider` line)

- [ ] **Step 1: Add the mutable field**

In `_PlayerScreenState`, immediately after the existing field:

```dart
  late final _controller = VideoController(_player);
```

add:

```dart
  late MergedEpisode _currentEpisode;
```

- [ ] **Step 2: Seed it in `initState`**

At the top of `initState()` (before the existing `_storageFuture = ...` line), add:

```dart
    _currentEpisode = widget.episode;
```

- [ ] **Step 3: Verify with static analysis**

Run: `flutter analyze lib/ui/player/player_screen.dart`
Expected: `No issues found!` (an unused-field warning would appear if this step were skipped and later steps didn't reference `_currentEpisode` — confirm there is no such warning)

- [ ] **Step 4: Update `_positionKey` to follow the current episode**

Replace:

```dart
  String get _positionKey =>
      '${widget.subjectId}::${widget.episode.sourceId}::${widget.episode.title}';
```

with:

```dart
  String get _positionKey =>
      '${widget.subjectId}::${_currentEpisode.sourceId}::${_currentEpisode.title}';
```

- [ ] **Step 5: Update `_retry` to re-resolve the current episode**

Replace:

```dart
  void _retry() {
    setState(() => _playbackError = null);
    ref.invalidate(episodePlayControllerProvider(episode: widget.episode));
  }
```

with:

```dart
  void _retry() {
    setState(() => _playbackError = null);
    ref.invalidate(episodePlayControllerProvider(episode: _currentEpisode));
  }
```

- [ ] **Step 6: Update `build()`'s provider lookup**

Replace:

```dart
    final provider = episodePlayControllerProvider(episode: widget.episode);
```

with:

```dart
    final provider = episodePlayControllerProvider(episode: _currentEpisode);
```

- [ ] **Step 7: Update `_maybePlayNextEpisode` to read and update `_currentEpisode` instead of pushing a new route**

Replace the whole method body. Before:

```dart
  void _maybePlayNextEpisode() {
    if (_hasAdvancedToNextEpisode || !mounted) return;
    final episodes = ref
        .read(
          subjectEpisodesControllerProvider(
            subjectId: widget.subjectId,
            subjectName: widget.subjectName,
          ),
        )
        .value;
    if (episodes == null) return;
    final sameSource = episodes
        .where((e) => e.sourceId == widget.episode.sourceId)
        .toList();
    final currentIndex = sameSource.indexWhere(
      (e) => e.title == widget.episode.title,
    );
    if (currentIndex == -1 || currentIndex + 1 >= sameSource.length) return;
    _hasAdvancedToNextEpisode = true;
    final next = sameSource[currentIndex + 1];
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          episode: next,
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
        ),
      ),
    );
  }
```

After:

```dart
  void _maybePlayNextEpisode() {
    if (_hasAdvancedToNextEpisode || !mounted) return;
    final episodes = ref
        .read(
          subjectEpisodesControllerProvider(
            subjectId: widget.subjectId,
            subjectName: widget.subjectName,
          ),
        )
        .value;
    if (episodes == null) return;
    final sameSource = episodes
        .where((e) => e.sourceId == _currentEpisode.sourceId)
        .toList();
    final currentIndex = sameSource.indexWhere(
      (e) => e.title == _currentEpisode.title,
    );
    if (currentIndex == -1 || currentIndex + 1 >= sameSource.length) return;
    final next = sameSource[currentIndex + 1];
    setState(() {
      _currentEpisode = next;
      _hasAdvancedToNextEpisode = false;
    });
  }
```

(`_hasAdvancedToNextEpisode` is reset to `false` rather than left `true`, because one `PlayerScreen` instance now lives across multiple episodes — the guard must re-arm for the new current episode so auto-advance can fire again later.)

- [ ] **Step 8: Verify with static analysis**

Run: `flutter analyze lib/ui/player/player_screen.dart`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "refactor(player): track current episode as mutable state"
```

---

## Task 7: Episode/source drawer + hot-swap wiring

**Files:**
- Modify: `lib/ui/player/player_screen.dart` (add `_drawerOpen` field, `_toggleDrawer()`, `_buildDrawer()`, wire into `build()`'s `Stack`)

- [ ] **Step 1: Add drawer-open state**

Next to `_currentEpisode` (added in Task 6), add:

```dart
  bool _drawerOpen = false;
```

- [ ] **Step 2: Add a toggle method**

Add a new private method anywhere among the other private methods (e.g. next to `_toggleFullscreen`):

```dart
  void _toggleDrawer() {
    setState(() => _drawerOpen = !_drawerOpen);
  }
```

- [ ] **Step 3: Add the drawer-building method**

Add a new private method that builds the slide-in panel, reusing `EpisodeSourceGrid` and the same providers the old `_SourceButton` watched:

```dart
  Widget _buildDrawer() {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _drawerOpen ? 320 : 0,
        color: Colors.black87,
        child: _drawerOpen
            ? SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) {
                      final episodesAsync = ref.watch(
                        subjectEpisodesControllerProvider(
                          subjectId: widget.subjectId,
                          subjectName: widget.subjectName,
                        ),
                      );
                      final sources = ref.watch(mediaSourcesProvider);
                      return episodesAsync.when(
                        data: (episodes) => EpisodeSourceGrid(
                          episodes: episodes,
                          sources: sources,
                          currentEpisode: _currentEpisode,
                          onEpisodeSelected: (episode) {
                            setState(() {
                              _currentEpisode = episode;
                              _hasAdvancedToNextEpisode = false;
                              _drawerOpen = false;
                            });
                          },
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Text(
                          '加载失败：$error',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              )
            : null,
      ),
    );
  }
```

(`ref` is available directly because `_PlayerScreenState extends ConsumerState<PlayerScreen>` — no extra `Consumer` wrapper is needed.)

- [ ] **Step 4: Add the import for `EpisodeSourceGrid`**

At the top of `lib/ui/player/player_screen.dart`, alongside the other relative imports (near the `subject_episodes_controller.dart` import), add:

```dart
import '../subject/episode_source_grid.dart';
```

- [ ] **Step 5: Wire `_buildDrawer()` into the `Stack`**

Inside `build()`, in the `Stack`'s `children` list, add `_buildDrawer()` as the last child (so it renders on top of everything else), right after the screenshot-flash `IgnorePointer` child and before the (soon to be removed, in Task 8) back-button/top-right-row children:

```dart
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _screenshotFlash ? 0.6 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(color: Colors.white),
                ),
              ),
              _buildDrawer(),
```

- [ ] **Step 6: Add keyboard shortcuts for the drawer**

In `_handleKeyEvent`'s `switch`, add two new cases before the `default:` case:

```dart
      case LogicalKeyboardKey.keyE:
        _toggleDrawer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_drawerOpen) {
          setState(() => _drawerOpen = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
```

- [ ] **Step 7: Verify with static analysis**

Run: `flutter analyze lib/ui/player/player_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): add collapsible episode/source drawer with in-place hot-swap"
```

---

## Task 8: Wire `PlayerTopBar` + `PlayerBottomBar` into `PlayerScreen`, remove the old floating buttons

**Files:**
- Modify: `lib/ui/player/player_screen.dart` (imports, `build()`'s `Stack`, delete `_BackButton`/`_SourceButton`/`_SpeedButton`/`_ScreenshotButton` classes and the `Positioned` blocks that used them)

- [ ] **Step 1: Add imports for the two new bar widgets**

At the top of `lib/ui/player/player_screen.dart`, add:

```dart
import 'player_bottom_bar.dart';
import 'player_top_bar.dart';
```

- [ ] **Step 2: Add a bars-visible flag and inactivity timer**

Next to `_drawerOpen` (added in Task 7), add:

```dart
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
```

- [ ] **Step 3: Add show/hide helper methods**

Add these private methods next to `_toggleDrawer`:

```dart
  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (_drawerOpen) {
      setState(() => _drawerOpen = false);
      return;
    }
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHideControls();
    } else {
      _hideControlsTimer?.cancel();
    }
  }
```

- [ ] **Step 4: Start the auto-hide timer in `initState`**

At the end of `initState()` (after the existing `unawaited(_initVolumeAndBrightness());` line), add:

```dart
    _scheduleHideControls();
```

- [ ] **Step 5: Cancel the timer in `dispose`**

In `dispose()`, alongside the existing `_savePositionTimer?.cancel();` line, add:

```dart
    _hideControlsTimer?.cancel();
```

- [ ] **Step 6: Wire tap-to-toggle onto the existing `GestureDetector`**

Find the `GestureDetector` in `build()` (it currently has `behavior: HitTestBehavior.translucent, onVerticalDragStart: ..., onVerticalDragUpdate: ...` and no `onTap`). Add an `onTap` parameter:

```dart
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                onVerticalDragStart: _handleVerticalDragStart,
                onVerticalDragUpdate: _handleVerticalDragUpdate,
```

- [ ] **Step 7: Replace the back-button and top-right-row `Positioned` blocks with the new bars**

Delete these two `Positioned` children from the `Stack`:

```dart
              Positioned(
                top: 8,
                left: 8,
                child: _BackButton(onPressed: () => Navigator.of(context).pop()),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SourceButton(...),
                    const SizedBox(width: 8),
                    _SpeedButton(...),
                    const SizedBox(width: 8),
                    _ScreenshotButton(...),
                  ],
                ),
              ),
```

Replace them with a top bar and a bottom bar, each visibility-gated and each fed live `Player` data via nested `StreamBuilder`s:

```dart
              if (_controlsVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: PlayerTopBar(
                    title: '${widget.subjectName} · ${_currentEpisode.title}',
                    onBack: () => Navigator.of(context).pop(),
                    onScreenshot: _takeScreenshot,
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final speed =
                          ref.watch(playbackSpeedControllerProvider).value ??
                          1.0;
                      return StreamBuilder<bool>(
                        stream: _player.stream.playing,
                        initialData: _player.state.playing,
                        builder: (context, playingSnapshot) {
                          return StreamBuilder<Duration>(
                            stream: _player.stream.position,
                            initialData: _player.state.position,
                            builder: (context, positionSnapshot) {
                              return StreamBuilder<Duration>(
                                stream: _player.stream.duration,
                                initialData: _player.state.duration,
                                builder: (context, durationSnapshot) {
                                  return PlayerBottomBar(
                                    isPlaying: playingSnapshot.data ?? false,
                                    position:
                                        positionSnapshot.data ?? Duration.zero,
                                    duration:
                                        durationSnapshot.data ?? Duration.zero,
                                    onPlayPause: _player.playOrPause,
                                    onSeek: _player.seek,
                                    currentSpeed: speed,
                                    speedOptions: _playbackSpeeds,
                                    onSpeedSelected: (value) async {
                                      await _player.setRate(value);
                                      await ref
                                          .read(
                                            playbackSpeedControllerProvider
                                                .notifier,
                                          )
                                          .setPlaybackSpeed(value);
                                    },
                                    onDrawerToggle: _toggleDrawer,
                                    onFullscreenToggle: _toggleFullscreen,
                                    isFullscreen: isFullscreen(context),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
```

- [ ] **Step 8: Delete the now-unused private widget classes**

Delete the `_BackButton`, `_ScreenshotButton`, `_SpeedButton`, and `_SourceButton` class definitions entirely from the bottom of `lib/ui/player/player_screen.dart` (their behavior is now fully covered by `PlayerTopBar`, `PlayerBottomBar`, and the drawer from Task 7).

- [ ] **Step 9: Verify with static analysis**

Run: `flutter analyze lib/ui/player/player_screen.dart`
Expected: `No issues found!` (confirms no leftover references to the deleted classes, and that `Consumer`/`StreamBuilder` imports resolve — `Consumer` comes from the already-imported `flutter_riverpod/flutter_riverpod.dart`, `StreamBuilder` from `flutter/material.dart`, both already imported)

- [ ] **Step 10: Run the full test suite to check for regressions**

Run: `flutter test`
Expected: PASS (no existing test references the deleted private classes; `PlayerScreen` itself still has no automated tests, per the note in Task 6)

- [ ] **Step 11: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): replace floating buttons with custom top/bottom bars"
```

---

## Task 9: Manual QA pass

**Files:** none (verification-only task; no code changes)

- [ ] **Step 1: Run the app and manually verify the redesigned flows**

Run: `flutter run -d macos`

Manually verify, from the running app:
1. Open a subject with episodes from both `anime1.me` and `稀饭动漫` (e.g. via Search). Tap "开始观看" — the sheet now shows two `ChoiceChip`s plus "全部", and tapping a chip filters the grid.
2. Start playback. Confirm no default media_kit control bar appears (no built-in seek bar/play button flashes on tap) — only the new top bar (back + title + screenshot) and bottom bar (play/pause + time labels + seek bar + speed + drawer icon + fullscreen icon) appear.
3. Tap anywhere on the video: both bars fade out; tap again: both bars fade back in. Leave the video untouched for 3+ seconds while bars are visible: they auto-hide.
4. Tap the drawer icon (or press `E`): the right-side drawer slides in showing the same chip+grid UI, with the currently-playing episode's pill highlighted (filled). Tap a different episode/source: playback hot-swaps (URL changes, but the app does NOT navigate to a new screen — confirm by checking the OS window/back-navigation stack is unchanged) and the drawer closes.
5. Press `Esc` while the drawer is open: it closes without affecting playback. Tap outside the drawer while it's open: it also closes.
6. Let an episode play to completion (or seek near the end): the next episode from the same source auto-plays in place (still no new screen/navigation), and the drawer's highlighted pill (if reopened) reflects the new current episode.
7. Verify the seek bar, speed popup, screenshot button, and fullscreen button (bottom-right of the bottom bar) all behave the same as before the redesign (dragging the bar seeks; selecting a speed changes playback rate and persists via `playbackSpeedControllerProvider`; screenshot saves/flashes; fullscreen toggles via both the new icon and the `F` key).

- [ ] **Step 2: Record the outcome**

If all checks in Step 1 pass, no further action is needed — this task has no automated verification to run. If any check fails, file it as a follow-up (do not silently patch code outside of this plan's tasks; open a new task/plan revision instead).

---

## Self-Review

**Spec coverage:**
- Section 1 (shared `EpisodeSourceGrid`, flattened sheet) → Tasks 1–2.
- Section 2 (custom top/bottom bars, `NoVideoControls`) → Tasks 3, 4, 5, 8.
- Section 3 (drawer + in-place hot-swap architecture) → Tasks 6, 7.
- Testing strategy → `episode_source_grid_test.dart` (Task 1), updated `episode_source_sheet_test.dart` (Task 2), `player_top_bar_test.dart` (Task 3), `player_bottom_bar_test.dart` (Task 4); the spec's originally-assumed `player_screen_test.dart` update was found during research to target a file that doesn't exist and can't exist given `Player`'s lack of a DI seam — Task 6's note documents this and redirects verification to `flutter analyze` + Task 9's manual QA, which is the correct, honest resolution of that testing-strategy item.
- Non-goals (subtitle UI, gesture lock, long-press speed, MediaSelector auto-tiering, danmaku, stats overlay, unified seek-cancel-region, responsive layouts) → deliberately absent from every task above; no task touches `lib/domain/media/`, `lib/domain/play/` merge logic, or `lib/domain/subject/`.

**Placeholder scan:** No TBD/TODO/"add appropriate error handling" strings; every code block is complete, real Dart; every "Run" step has an exact command and exact expected output.

**Type/signature consistency:** `MergedEpisode` (`episode`, `sourceId`, `title`), `MediaSource` (`id`, `displayName`), `MediaEpisode` (`sourceId`, `title`), `subjectEpisodesControllerProvider(subjectId:, subjectName:)`, `mediaSourcesProvider`, `episodePlayControllerProvider(episode:)`, `playbackSpeedControllerProvider`/`.notifier.setPlaybackSpeed(double)` are used identically across Tasks 1, 2, 6, 7, and 8, matching their verified real definitions in `lib/domain/play/subject_episodes_controller.dart`, `lib/domain/play/episode_play_controller.dart`, `lib/domain/media/media_registry.dart`, `lib/domain/media/media_source.dart`, and `lib/domain/settings/playback_speed_controller.dart`. `PlayerBottomBar`'s constructor parameters in Task 4's test/implementation match exactly how Task 8 constructs it. `_player.stream.playing`/`.position`/`.duration` and `_player.state.playing`/`.position`/`.duration` (used in Task 8) are confirmed members of media_kit 1.2.6's `PlayerStream`/`PlayerState` classes. `NoVideoControls` (used in Task 5) is confirmed as a `const ... = null;` top-level value of type `VideoControlsBuilder?`, exported by `media_kit_video` 2.0.1 and already imported in `player_screen.dart`.

---

## Execution Handoff

Two execution options:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration. Required sub-skill: `superpowers:subagent-driven-development`.
2. **Inline Execution** — execute tasks in this session using `executing-plans`, batch execution with checkpoints. Required sub-skill: `superpowers:executing-plans`.
