# Rating Histogram Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a small 1-10 score-distribution bar chart ("评分柱状分布图") to the top of the subject-detail page's right sidebar, filling the space deliberately left blank by the two-column redesign.

**Architecture:** Add a nullable `Map<String, int>? scoreDetails` field to the existing `SubjectDetail` model (parsed from a field the backend already returns but the model currently ignores), then add a new `_RatingHistogramSection` widget that reads it from the already-fetched `subjectDetailControllerProvider` and renders a hand-rolled vertical bar chart. No new API calls, Dio clients, or Riverpod providers.

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod`), `json_serializable` codegen, `flutter_test`.

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-09-08-rating-histogram-design.md` (commit `b2054fb`), approved.
- `scoreDetails` is `Map<String, int>?`, **nullable, no default** (unlike `aliases`, which defaults to `[]`) — the widget's own null/empty check treats "missing" and "empty map" identically, so no default value is needed on the model.
- Do NOT touch `lib/ui/subject/episode_source_grid.dart`, `episode_source_sheet.dart`, `lib/domain/play/subject_episodes_controller.dart`, `lib/domain/media/media_registry.dart` — unrelated, still used by `PlayerScreen`'s in-player drawer.
- Do NOT change `_StaffSection`, `_CharacterSection`, `_WorkInfoSection`, `_BangumiEpisodesSection`, `_SubjectInfoSection`, `_HeaderInfo`, `_RatingSection`, `_CollectionButtons` — only add a new class and change one line in `SubjectDetailScreen.build()`.
- No new pubspec dependency (no charting package) — hand-roll bars with `Container`, matching this codebase's existing convention (`RatingStars`, `SubjectTagsRow`).
- `_RatingHistogramSection` must follow the exact same silent-hide convention as `_StaffSection`/`_CharacterSection`: `loading: () => const SizedBox.shrink()`, `error: (error, stack) => const SizedBox.shrink()`, and `SizedBox.shrink()` again if the resolved data has nothing to show.
- Run `dart run build_runner build --delete-conflicting-outputs` after Task 1 (the only task with an `@JsonSerializable` shape change).
- **CRITICAL SESSION-WIDE LESSON: any `dart format` invocation MUST be scoped only to the exact files touched by that task — NEVER run `dart format lib test` on the whole tree** (an earlier task this session accidentally reformatted 85+ unrelated files this way; it required manual cleanup).
- `flutter analyze` must show 0 errors and `flutter test` must show all tests passing after every task that touches `lib/` or `test/`. Baseline before this plan: **433 tests passing, 0 analyze errors, 28 pre-existing info-level issues** (unchanged since commit `b94e305`).
- Conventional Commits with scope. One commit per task except the final task (verification only, no commit).
- No new test file is added for `subject_detail_screen.dart` itself — this file has zero pre-existing widget-test coverage (an accepted, already-established gap from every prior addition to this file this session).

## File Structure

- Modify: `lib/data/subject/subject_models.dart` — add `scoreDetails` field to `SubjectDetail`.
- Modify: `test/data/subject/subject_models_test.dart` — add 2 tests for `scoreDetails`.
- Modify: `lib/ui/subject/subject_detail_screen.dart` — add `_RatingHistogramSection` + `_HistogramBar` widgets, wire into the right column.

---

### Task 1: Add `SubjectDetail.scoreDetails` field

**Files:**
- Modify: `lib/data/subject/subject_models.dart:34-71` (the `SubjectDetail` class's doc comment and constructor/field list)
- Test: `test/data/subject/subject_models_test.dart` (append 2 tests to the existing `SubjectDetail` group, after the existing `aliases` tests at lines 90-100)

**Interfaces:**
- Produces: `SubjectDetail.scoreDetails` (`Map<String, int>?`), consumed by Task 2's `_RatingHistogramSection`.

- [ ] **Step 1: Write the failing tests**

Append these 2 tests inside the existing `group('SubjectDetail', () { ... })` block in `test/data/subject/subject_models_test.dart`, directly after the existing `'defaults aliases to an empty list when absent from JSON'` test (which currently ends at line 100 with `});`):

```dart
    test('parses scoreDetails when present', () {
      final json = baseJson()
        ..['scoreDetails'] = {
          '1': 130,
          '2': 37,
          '3': 51,
          '4': 111,
          '5': 352,
          '6': 1081,
          '7': 3659,
          '8': 10440,
          '9': 12845,
          '10': 7445,
        };
      final detail = SubjectDetail.fromJson(json);
      expect(detail.scoreDetails, {
        '1': 130,
        '2': 37,
        '3': 51,
        '4': 111,
        '5': 352,
        '6': 1081,
        '7': 3659,
        '8': 10440,
        '9': 12845,
        '10': 7445,
      });
    });

    test('scoreDetails is null when absent from JSON', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.scoreDetails, isNull);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: FAIL — `The named parameter 'scoreDetails' isn't defined` (or similar compile error), since the field doesn't exist yet.

- [ ] **Step 3: Add the field to `SubjectDetail`**

Current code (`lib/data/subject/subject_models.dart:34-71`):

```dart
/// Response of `GET /v2/subjects/{subjectId}` -- verified against the
/// real `AniSubjectCollection` model. This is a deliberately lean subset
/// (the real wire shape also has `type`/`nsfw`/`aliases`/`favorite`/
/// `metaTags`/`scoreDetails`/`episodes`/`relations`/`infobox`/`platform`/
/// `airingInfo`/`updatedAt`, none of which the UI needs) --
/// json_serializable's generated `fromJson` ignores undeclared keys, so
/// omitting fields is safe.
@JsonSerializable()
class SubjectDetail {
  const SubjectDetail({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.tags,
    this.score,
    this.rank,
    this.collectionType,
    required this.selfRating,
    this.aliases = const [],
  });

  final int id;
  final String name;
  final String nameCn;
  final String summary;
  final String airDate;
  final List<SubjectTag> tags;

  /// Alternate titles for this subject (e.g. original Japanese title,
  /// English title). Parsed from the `aliases` field already present in
  /// the raw `api.animeko.org` `/v2/subjects/{id}` response but not
  /// previously modeled here. Defaults to an empty list when the key is
  /// absent, so existing test fixtures/responses without this key still
  /// parse cleanly.
  @JsonKey(defaultValue: <String>[])
  final List<String> aliases;

  /// Official rating, string-encoded float (e.g. `"8.4"`) or null if the
  /// subject has too few ratings.
  final String? score;
  final int? rank;
```

Replace with:

```dart
/// Response of `GET /v2/subjects/{subjectId}` -- verified against the
/// real `AniSubjectCollection` model. This is a deliberately lean subset
/// (the real wire shape also has `type`/`nsfw`/`favorite`/`metaTags`/
/// `episodes`/`relations`/`infobox`/`platform`/`airingInfo`/`updatedAt`,
/// none of which the UI needs) -- json_serializable's generated
/// `fromJson` ignores undeclared keys, so omitting fields is safe.
@JsonSerializable()
class SubjectDetail {
  const SubjectDetail({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.tags,
    this.score,
    this.rank,
    this.collectionType,
    required this.selfRating,
    this.aliases = const [],
    this.scoreDetails,
  });

  final int id;
  final String name;
  final String nameCn;
  final String summary;
  final String airDate;
  final List<SubjectTag> tags;

  /// Alternate titles for this subject (e.g. original Japanese title,
  /// English title). Parsed from the `aliases` field already present in
  /// the raw `api.animeko.org` `/v2/subjects/{id}` response but not
  /// previously modeled here. Defaults to an empty list when the key is
  /// absent, so existing test fixtures/responses without this key still
  /// parse cleanly.
  @JsonKey(defaultValue: <String>[])
  final List<String> aliases;

  /// Per-score-bucket vote counts (keys `"1"` through `"10"`, values are
  /// vote counts), parsed from the `scoreDetails` field already present
  /// in the raw `api.animeko.org` `/v2/subjects/{id}` response but not
  /// previously modeled here. Verified live to match Bangumi's own
  /// public `rating.count` field for the same subject almost exactly
  /// (negligible caching lag). Null (not defaulted to an empty map) when
  /// the key is absent -- consumers must null-check, matching the map's
  /// natural "no data yet" meaning.
  final Map<String, int>? scoreDetails;

  /// Official rating, string-encoded float (e.g. `"8.4"`) or null if the
  /// subject has too few ratings.
  final String? score;
  final int? rank;
```

- [ ] **Step 4: Regenerate codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, `subject_models.g.dart` is regenerated to include `scoreDetails` in `_$SubjectDetailFromJson`/`_$SubjectDetailToJson`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: PASS — all tests in this file pass, including the 2 new ones.

- [ ] **Step 6: Run full verification**

Run: `flutter analyze lib/data/subject/subject_models.dart`
Expected: no issues.

Run: `flutter test`
Expected: all tests pass (433 baseline + 2 new = 435).

- [ ] **Step 7: Commit**

Scope `dart format` to only the files this task touched (do NOT run it on `lib`/`test` as a whole):

```bash
dart format lib/data/subject/subject_models.dart lib/data/subject/subject_models.g.dart test/data/subject/subject_models_test.dart
git add lib/data/subject/subject_models.dart lib/data/subject/subject_models.g.dart test/data/subject/subject_models_test.dart
git commit -m "feat(subject): add SubjectDetail.scoreDetails field"
```

---

### Task 2: Add `_RatingHistogramSection` widget to the detail page's right sidebar

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart:60` (the right-column `Expanded` in `SubjectDetailScreen.build()`)
- Modify: `lib/ui/subject/subject_detail_screen.dart` — add two new private classes, `_RatingHistogramSection` and `_HistogramBar`, immediately before the existing `_StaffSection` class (currently starting at line 600)
- Modify: `lib/ui/subject/subject_detail_screen.dart:1-3` (imports — add `dart:math`)

**Interfaces:**
- Consumes: `SubjectDetail.scoreDetails` (Task 1), `subjectDetailControllerProvider` (existing, unchanged, already imported/used by `_WorkInfoSection`/`_SubjectInfoSection`).
- Produces: `_RatingHistogramSection({required int subjectId})` widget, consumed only by `SubjectDetailScreen.build()` in this same file.

- [ ] **Step 1: Add the `dart:math` import**

Current code (`lib/ui/subject/subject_detail_screen.dart:1-3`):

```dart
// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

Replace with:

```dart
// lib/ui/subject/subject_detail_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

- [ ] **Step 2: Wire the new section into the right column**

Current code (`lib/ui/subject/subject_detail_screen.dart:60`):

```dart
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _StaffSection(subjectId: subjectId)),
```

Replace with:

```dart
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RatingHistogramSection(subjectId: subjectId),
                      _StaffSection(subjectId: subjectId),
                    ],
                  ),
                ),
```

- [ ] **Step 3: Add `_RatingHistogramSection` and `_HistogramBar`**

Insert the following two classes immediately before the existing `_StaffSection` class (i.e. directly above the doc comment block that currently starts at line 595, `/// original order. Deliberately NOT deduplicated by role -- ...`):

```dart
/// Shows a small 1-10 score-distribution bar chart at the top of the
/// right sidebar, using [SubjectDetail.scoreDetails] -- data the app's
/// own backend already returns inside the same response
/// [subjectDetailControllerProvider] already fetches, so this needs no
/// new API call/provider. Silently hides (matching [_StaffSection]'s
/// convention) while loading, on error, or when `scoreDetails` is null
/// or empty (e.g. a subject with too few ratings to have a breakdown).
class _RatingHistogramSection extends ConsumerWidget {
  const _RatingHistogramSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(
      subjectDetailControllerProvider(subjectId: subjectId),
    );

    return subjectAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (subject) {
        final details = subject.scoreDetails;
        if (details == null || details.isEmpty) {
          return const SizedBox.shrink();
        }

        final total = details.values.fold(0, (sum, count) => sum + count);
        final maxCount = details.values.reduce(max);
        if (total == 0 || maxCount == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${subject.score ?? '--'}分 · $total人评价',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var score = 1; score <= 10; score++)
                    _HistogramBar(
                      score: score,
                      count: details['$score'] ?? 0,
                      maxCount: maxCount,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistogramBar extends StatelessWidget {
  const _HistogramBar({
    required this.score,
    required this.count,
    required this.maxCount,
  });

  final int score;
  final int count;
  final int maxCount;

  static const double _maxBarHeight = 48;
  static const double _minBarHeight = 2;

  @override
  Widget build(BuildContext context) {
    final barHeight = count == 0
        ? _minBarHeight
        : max(_minBarHeight, _maxBarHeight * count / maxCount);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 12,
          height: barHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text('$score', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

```

- [ ] **Step 4: Run analyze and full test suite**

Run: `flutter analyze lib/ui/subject/subject_detail_screen.dart`
Expected: no issues.

Run: `flutter test`
Expected: all tests pass (435, unchanged from Task 1's count, since this task adds no new tests — `subject_detail_screen.dart` has no pre-existing test file, per Global Constraints).

- [ ] **Step 5: Commit**

Scope `dart format` to only the file this task touched:

```bash
dart format lib/ui/subject/subject_detail_screen.dart
git add lib/ui/subject/subject_detail_screen.dart
git commit -m "feat(subject): add rating histogram to detail page right sidebar"
```

---

### Task 3: Final sanity pass

**Files:** none — verification only, no commit.

- [ ] **Step 1: Regenerate codegen (safety net)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, 0 new outputs (no drift beyond what Task 1 already generated).

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: 0 errors, ~28 pre-existing info-level issues (same set as the established baseline throughout this session), no new issues.

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: 435 tests passing, 0 failures.

- [ ] **Step 4: Git state check**

Run: `git status --short && git log --oneline -6`
Expected: clean tree except the 2 pre-existing unrelated untracked items (`android/build/`, `assets/icon/image.png`, present since before this session). Commit log newest-first: Task 2's commit → Task 1's commit → `b2054fb` (rating-histogram design spec) → `b94e305` (two-column redesign Task 3) → ...

- [ ] **Step 5: Report to the user**

Report completion to the user in Chinese: the rating histogram is now live in the top-right sidebar of the subject detail page, using data the backend was already returning; no new API/provider was needed; `flutter analyze`/`flutter test` are clean.

## Self-Review

**Spec coverage:** Design spec (`docs/superpowers/specs/2026-09-08-rating-histogram-design.md`) Section "范围内" items 1-6 map to: item 1 (model field) → Task 1; items 2-4 (widget, chart, header line) → Task 2 Step 3; item 5 (silent-hide) → Task 2 Step 3's `.when(...)` + null/empty/zero checks; item 6 (placement before `_StaffSection`) → Task 2 Step 2. "范围外" items are all satisfied by omission (no new widgets/files touch any of the named out-of-scope components).

**Placeholder scan:** No TBD/TODO/"add appropriate X" phrasing anywhere in the task steps above; every step has complete, literal code.

**Type consistency:** `_RatingHistogramSection(subjectId: subjectId)` constructor call (Task 2 Step 2) matches the class definition `const _RatingHistogramSection({required this.subjectId})` (Task 2 Step 3) exactly. `SubjectDetail.scoreDetails` (`Map<String, int>?`, Task 1) matches how it's read in `_RatingHistogramSection` (`subject.scoreDetails`, `details['$score']`, Task 2 Step 3) exactly — no type mismatch.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-08-rating-histogram-plan.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
