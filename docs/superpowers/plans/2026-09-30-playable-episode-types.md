# Playable Episode Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let SPECIAL-type episodes (the bucket theatrical movies/剧场版 and extra specials land in) merge into the main episode grid, sorted together with MAIN episodes. OP/ED stay excluded.

**Architecture:** Add a new `SubjectEpisode.isPlayable` getter (`type == 'MAIN' || type == 'SPECIAL'`) alongside the existing `isMain` getter, then switch the one filter in `SubjectMainEpisodesController.build()` from `isMain` to `isPlayable`. No UI changes: `EpisodeNumberGrid` labels are already derived purely from `episode.sort`, a single ordering key spanning all episode types, so SPECIAL episodes fall into correct chronological position automatically once let through.

**Tech Stack:** Dart, Flutter, Riverpod (`@riverpod` codegen), `json_serializable`, `flutter_test` + `mocktail`.

**Reference spec:** `docs/superpowers/specs/2026-09-30-playable-episode-types-design.md`

---

## Task 1: Add `SubjectEpisode.isPlayable`

**Files:**
- Modify: `lib/data/subject/subject_episode_models.dart`
- Test: `test/data/subject/subject_episode_models_test.dart`

- [ ] **Step 1: Write the failing test**

Add a new group right after the existing `SubjectEpisode.isMain` group (after line 103, before the `SubjectEpisode.displayName` group) in `test/data/subject/subject_episode_models_test.dart`:

```dart
  group('SubjectEpisode.isPlayable', () {
    test('is true for MAIN and SPECIAL, false for OP/ED/absent', () {
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'MAIN').isPlayable,
        isTrue,
      );
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'SPECIAL').isPlayable,
        isTrue,
      );
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'OP').isPlayable,
        isFalse,
      );
      expect(
        SubjectEpisode.fromJson(baseJson()..['type'] = 'ED').isPlayable,
        isFalse,
      );
      expect(
        SubjectEpisode.fromJson(baseJson()..remove('type')).isPlayable,
        isFalse,
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/subject_episode_models_test.dart`
Expected: compile-time error, `The getter 'isPlayable' isn't defined for the class 'SubjectEpisode'`.

- [ ] **Step 3: Implement the getter**

In `lib/data/subject/subject_episode_models.dart`, update the doc comment on the `type` field (lines 58-59) and add the new getter right after `isMain` (line 73):

Replace:
```dart
  /// `MAIN` | `SPECIAL` | `OP` | `ED`. Only [isMain] entries are shown in
  /// the grid -- see `SubjectMainEpisodesController`.
  @JsonKey(defaultValue: '')
  final String type;
```
with:
```dart
  /// `MAIN` | `SPECIAL` | `OP` | `ED`. Only [isPlayable] entries are shown
  /// in the grid -- see `SubjectMainEpisodesController`.
  @JsonKey(defaultValue: '')
  final String type;
```

Replace:
```dart
  /// True for 正片 (main episodes) -- the only type the episode grid shows.
  bool get isMain => type == 'MAIN';
```
with:
```dart
  /// True for 正片 (main episodes). Used for [SubjectDetail.episodeCount]
  /// (the "话数" count), which deliberately stays MAIN-only -- see
  /// [isPlayable] for what the episode grid actually shows.
  bool get isMain => type == 'MAIN';

  /// True for episodes that should appear in the episode grid: 正片 (MAIN)
  /// plus SPECIAL entries -- the bucket theatrical movies/剧场版 and extra
  /// specials land in, since the backend's `type` enum has no dedicated
  /// movie value. OP/ED remain excluded -- they're theme songs, not
  /// watchable content.
  bool get isPlayable => type == 'MAIN' || type == 'SPECIAL';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/subject/subject_episode_models_test.dart`
Expected: PASS, all tests green (existing `isMain` tests unaffected since `isMain` didn't change).

- [ ] **Step 5: Commit**

```bash
git add lib/data/subject/subject_episode_models.dart test/data/subject/subject_episode_models_test.dart
git commit -m "feat(subject): add SubjectEpisode.isPlayable for MAIN+SPECIAL episodes"
```

---

## Task 2: Merge SPECIAL episodes into the main episode grid

**Files:**
- Modify: `lib/domain/subject/subject_main_episodes_controller.dart`
- Test: `test/domain/subject/subject_main_episodes_controller_test.dart`

- [ ] **Step 1: Rewrite the affected tests to describe the new behavior**

In `test/domain/subject/subject_main_episodes_controller_test.dart`, make three edits:

**Edit A** — rename/rewrite the "keeps only MAIN" test (currently lines 55-69):

Replace:
```dart
    test('keeps only MAIN episodes, dropping SPECIAL/OP/ED', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          episode(id: 1, sort: 1),
          episode(id: 2, sort: 2, type: 'SPECIAL'),
          episode(id: 3, sort: 3, type: 'OP'),
          episode(id: 4, sort: 4, type: 'ED'),
          episode(id: 5, sort: 5),
        ]),
      );

      final result = await read();

      expect(result.map((e) => e.episodeId), [1, 5]);
    });
```
with:
```dart
    test('keeps MAIN and SPECIAL episodes, dropping OP/ED', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          episode(id: 1, sort: 1),
          episode(id: 2, sort: 2, type: 'SPECIAL'),
          episode(id: 3, sort: 3, type: 'OP'),
          episode(id: 4, sort: 4, type: 'ED'),
          episode(id: 5, sort: 5),
        ]),
      );

      final result = await read();

      expect(result.map((e) => e.episodeId), [1, 2, 5]);
    });
```

**Edit B** — the existing "sorts the surviving episodes ascending by sort" test (currently lines 73-86) has a fixture bug that this change exposes: it contains two different episodes both at `sort: 2` (one `SPECIAL`, one default `MAIN`), relying on the old MAIN-only filter to silently drop the SPECIAL one down to 3 surviving episodes. Once SPECIAL survives, this becomes 4 episodes with a duplicate sort value, breaking the `[1, 2, 3]` assertion. Fix the fixture to use a distinct sort value for the SPECIAL entry so the interleaving is unambiguous:

Replace:
```dart
    test('sorts the surviving episodes ascending by sort', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          episode(id: 3, sort: 3),
          episode(id: 1, sort: 1),
          episode(id: 2, sort: 2, type: 'SPECIAL'),
          episode(id: 2, sort: 2),
        ]),
      );

      final result = await read();

      expect(result.map((e) => e.sort), [1, 2, 3]);
    });
```
with:
```dart
    test('sorts the surviving episodes ascending by sort', () async {
      when(() => api.getSubject(1)).thenAnswer(
        (_) async => detailWith([
          episode(id: 3, sort: 3),
          episode(id: 1, sort: 1),
          episode(id: 20, sort: 2.5, type: 'SPECIAL'),
          episode(id: 2, sort: 2),
        ]),
      );

      final result = await read();

      expect(result.map((e) => e.sort), [1, 2, 2.5, 3]);
    });
```

**Edit C** — rename/rewrite the "returns an empty list when every episode is a non-MAIN type" test (currently lines 111-120), switching its fixture from a single SPECIAL episode (which would no longer produce an empty result) to an OP/ED-only fixture:

Replace:
```dart
    test(
      'returns an empty list when every episode is a non-MAIN type',
      () async {
        when(() => api.getSubject(1)).thenAnswer(
          (_) async => detailWith([episode(id: 1, sort: 1, type: 'SPECIAL')]),
        );

        expect(await read(), isEmpty);
      },
    );
```
with:
```dart
    test(
      'returns an empty list when every episode is a non-playable type',
      () async {
        when(() => api.getSubject(1)).thenAnswer(
          (_) async => detailWith([
            episode(id: 1, sort: 1, type: 'OP'),
            episode(id: 2, sort: 2, type: 'ED'),
          ]),
        );

        expect(await read(), isEmpty);
      },
    );
```

- [ ] **Step 2: Run tests to verify the expected failures**

Run: `flutter test test/domain/subject/subject_main_episodes_controller_test.dart`
Expected: FAIL on the three edited tests (the controller still filters on `isMain`, so the SPECIAL episodes in Edit A and Edit B are still being dropped, and the OP/ED fixture in Edit C still passes but for the wrong reason -- confirm the other two visibly fail):
- `keeps MAIN and SPECIAL episodes, dropping OP/ED` — expected `[1, 2, 5]`, actual `[1, 5]`.
- `sorts the surviving episodes ascending by sort` — expected `[1, 2, 2.5, 3]`, actual `[1, 2, 3]`.

- [ ] **Step 3: Update the controller**

In `lib/domain/subject/subject_main_episodes_controller.dart`:

Replace the class doc comment's closing bullet (lines 29-30):
```dart
///  * The "is this a 正片" test is now `type == 'MAIN'` rather than Bangumi's
///    numeric `type == 0`.
```
with:
```dart
///  * The "should this appear in the grid" test is now
///    `type == 'MAIN' || type == 'SPECIAL'` (`SubjectEpisode.isPlayable`)
///    rather than Bangumi's numeric `type == 0`. SPECIAL is where
///    theatrical movies/剧场版 and extra specials get tagged by the
///    backend, since it has no dedicated movie type; OP/ED stay excluded
///    since they're theme songs, not watchable content.
```

Replace the filter line and its preceding comment (lines 46-49):
```dart
    // The backend returns MAIN and SPECIAL entries interleaved and in no
    // guaranteed order, so sorting is required, not defensive polish.
    return episodes.where((episode) => episode.isMain).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
```
with:
```dart
    // The backend returns MAIN and SPECIAL entries interleaved and in no
    // guaranteed order, so sorting is required, not defensive polish.
    return episodes.where((episode) => episode.isPlayable).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/domain/subject/subject_main_episodes_controller_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/subject/subject_main_episodes_controller.dart test/domain/subject/subject_main_episodes_controller_test.dart
git commit -m "fix(subject): merge SPECIAL episodes into the main episode grid"
```

---

## Task 3: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: no new errors introduced by this change (pre-existing infos are fine per project convention).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all ~359+ tests pass, including the modified files from Tasks 1-2.

- [ ] **Step 3: Confirm no other consumer of `isMain` needs to change**

Run: `rtk grep "isMain" lib/`
Expected: only two remaining hits outside the files touched in Tasks 1-2 --
`lib/data/subject/subject_models.dart:264` (`SubjectDetail.episodeCount`, the "话数" count) and any doc-comment mentions in `lib/ui/subject/subject_meta_text.dart` / `lib/ui/subject/subject_title_block.dart`. Per the spec's Non-goals, these must NOT be changed -- `episodeCount` is a distinct "count of proper main-story episodes" concept, independent from what the grid displays. If this grep turns up any other production code path filtering episodes by `isMain`, stop and flag it before proceeding (it would mean the spec's Non-goals were incomplete).

No commit needed for this task (verification only, no files changed). If Task 3 uncovers a genuine gap, do not fix it silently -- surface it for a decision, since it would be new scope beyond the approved spec.
