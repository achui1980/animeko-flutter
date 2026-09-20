# Schedule Rating Badge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show each scheduled anime's valid Bangumi aggregate score as a bottom-right cover badge without delaying or failing the schedule page.

**Architecture:** A keep-alive Riverpod family provider fetches and validates one subject's aggregate score through the existing `SubjectApi`. `ScheduleScreen` watches that provider per card and passes a resolved score to a new optional `AnimeCoverCard.scoreBadge` overlay; loading, failure, and invalid scores omit the badge without changing schedule state.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, Riverpod 3.x with `riverpod_annotation`/`build_runner`, mocktail, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-20-schedule-rating-badge-design.md`

## Global Constraints

- Reuse `GET /v2/subjects/{subjectId}` through `SubjectApi.getSubject`; do not alter the schedule endpoint or its generated models.
- Preserve the existing `第{episode}话 · HH:mm` subtitle and 260dp schedule row height.
- Display only a finite numeric aggregate score greater than zero, formatted to at most one decimal place with a trailing `.0` removed.
- On score loading, failure, or invalid data, render no badge and do not fail or retry the schedule page.
- Only `ScheduleScreen` supplies the score badge; Home, Search, and My Collection cards remain unchanged.
- Run `dart run build_runner build --delete-conflicting-outputs` after adding the annotated provider and commit its generated `.g.dart` file.

---

## File Structure

- Create: `lib/domain/schedule/schedule_subject_score.dart` - pure score formatter plus the cached, failure-isolating score provider.
- Create: `lib/domain/schedule/schedule_subject_score.g.dart` - Riverpod-generated provider definition.
- Modify: `lib/ui/common/anime_cover_card.dart` - optional bottom-right score overlay inside the cover image.
- Modify: `lib/ui/schedule/schedule_screen.dart` - watches score state per schedule card and supplies only resolved badge values.
- Create: `test/domain/schedule/schedule_subject_score_test.dart` - score validation, provider caching, and failure-isolation tests.
- Modify: `test/ui/common/anime_cover_card_test.dart` - verifies badge visibility and absence.
- Modify: `test/ui/schedule/schedule_screen_test.dart` - verifies a resolved score appears on a schedule card while subtitle remains.

### Task 1: Score Provider and Formatting

**Files:**
- Create: `lib/domain/schedule/schedule_subject_score.dart`
- Create: `test/domain/schedule/schedule_subject_score_test.dart`
- Generate: `lib/domain/schedule/schedule_subject_score.g.dart`

**Interfaces:**
- Consumes: `SubjectApi.getSubject(int subjectId) -> Future<SubjectDetail>` and `SubjectDetail.score -> String?` from `lib/data/subject/subject_api.dart` and `lib/data/subject/subject_models.dart`.
- Produces: `String? formatScheduleSubjectScore(String? score)` and `scheduleSubjectScoreProvider(int subjectId)`, whose future resolves to `String?` and never throws for a subject-detail failure.

- [ ] **Step 1: Write the failing formatter and provider tests**

Create `test/domain/schedule/schedule_subject_score_test.dart` with a `MockSubjectApi`, a minimal `SubjectDetail` fixture, and these cases:

```dart
test('formats valid aggregate scores for a compact badge', () {
  expect(formatScheduleSubjectScore('7.8'), '7.8');
  expect(formatScheduleSubjectScore('8.0'), '8');
});

test('omits unavailable and invalid aggregate scores', () {
  for (final score in [null, '', 'bad', 'NaN', 'Infinity', '0', '-1']) {
    expect(formatScheduleSubjectScore(score), isNull);
  }
});

test('caches one successful subject-detail request per id', () async {
  when(() => api.getSubject(1)).thenAnswer((_) async => detailWithScore('7.8'));

  expect(await container.read(scheduleSubjectScoreProvider(1).future), '7.8');
  expect(await container.read(scheduleSubjectScoreProvider(1).future), '7.8');
  verify(() => api.getSubject(1)).called(1);
});

test('converts a detail failure to an omitted badge', () async {
  when(() => api.getSubject(1)).thenThrow(Exception('network unavailable'));

  expect(await container.read(scheduleSubjectScoreProvider(1).future), isNull);
});
```

Set up the container with `subjectApiProvider.overrideWithValue(api)` and `retry: (retryCount, error) => null`, matching existing subject-controller tests.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/schedule/schedule_subject_score_test.dart`

Expected: compilation failure because `formatScheduleSubjectScore` and `scheduleSubjectScoreProvider` do not exist.

- [ ] **Step 3: Implement score validation and the keep-alive provider**

Create `lib/domain/schedule/schedule_subject_score.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/subject_api.dart';

part 'schedule_subject_score.g.dart';

String? formatScheduleSubjectScore(String? score) {
  final value = double.tryParse(score?.trim() ?? '');
  if (value == null || !value.isFinite || value <= 0) return null;
  return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}

@Riverpod(keepAlive: true)
Future<String?> scheduleSubjectScore(Ref ref, int subjectId) async {
  try {
    final detail = await ref.watch(subjectApiProvider).getSubject(subjectId);
    return formatScheduleSubjectScore(detail.score);
  } catch (_) {
    return null;
  }
}
```

The `keepAlive: true` family provider retains one result for each subject ID during the app's `ProviderScope` lifecycle, allowing repeated calendar appearances to reuse the request rather than refetch after a card scrolls off-screen.

- [ ] **Step 4: Generate provider code**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: `lib/domain/schedule/schedule_subject_score.g.dart` is generated with `scheduleSubjectScoreProvider(int subjectId)`.

- [ ] **Step 5: Run the focused provider test to verify it passes**

Run: `flutter test test/domain/schedule/schedule_subject_score_test.dart`

Expected: PASS; one subject ID results in one API call, and a thrown API error resolves to null.

- [ ] **Step 6: Commit the provider task**

```bash
git add lib/domain/schedule/schedule_subject_score.dart lib/domain/schedule/schedule_subject_score.g.dart test/domain/schedule/schedule_subject_score_test.dart
git commit -m "feat(schedule): load card ratings"
```

### Task 2: Cover Badge Presentation

**Files:**
- Modify: `lib/ui/common/anime_cover_card.dart:7-85`
- Modify: `test/ui/common/anime_cover_card_test.dart:6-67`

**Interfaces:**
- Consumes: optional `String? scoreBadge` supplied by a caller.
- Produces: `AnimeCoverCard({..., String? scoreBadge})`, which places non-empty content at the cover image's bottom-right without changing the outer card layout.

- [ ] **Step 1: Write failing widget tests for the optional badge**

Append these tests to `test/ui/common/anime_cover_card_test.dart`:

```dart
testWidgets('AnimeCoverCard renders a supplied score badge on the cover', (
  tester,
) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 150,
        child: AnimeCoverCard(
          imageUrl: 'https://example.com/cover.jpg',
          title: 'Frieren',
          scoreBadge: '7.8',
        ),
      ),
    ),
  ));

  expect(find.text('7.8'), findsOneWidget);
  expect(find.byType(Stack), findsOneWidget);
});

testWidgets('AnimeCoverCard omits an empty score badge', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 150,
        child: AnimeCoverCard(
          imageUrl: 'https://example.com/cover.jpg',
          title: 'Frieren',
        ),
      ),
    ),
  ));

  expect(find.byType(Positioned), findsNothing);
});
```

- [ ] **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/ui/common/anime_cover_card_test.dart`

Expected: compilation failure because `AnimeCoverCard.scoreBadge` does not exist.

- [ ] **Step 3: Add the cover-local badge overlay**

Add `this.scoreBadge` to the `AnimeCoverCard` constructor and `final String? scoreBadge;` next to `subtitle`. Replace the cover's direct `ClipRRect` child with this layout while preserving the existing `AspectRatio` and image error builder:

```dart
Stack(
  fit: StackFit.expand,
  children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    ),
    if (scoreBadge case final score? when score.isNotEmpty)
      Positioned(
        right: 6,
        bottom: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              score,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
  ],
)
```

- [ ] **Step 4: Run the widget test to verify it passes**

Run: `flutter test test/ui/common/anime_cover_card_test.dart`

Expected: PASS; existing aspect-ratio, tap, and subtitle tests remain green.

- [ ] **Step 5: Commit the badge task**

```bash
git add lib/ui/common/anime_cover_card.dart test/ui/common/anime_cover_card_test.dart
git commit -m "feat(schedule): add rating badge to cover cards"
```

### Task 3: Connect Schedule Cards to Scores

**Files:**
- Modify: `lib/ui/schedule/schedule_screen.dart:99-114`
- Modify: `test/ui/schedule/schedule_screen_test.dart:1-176`

**Interfaces:**
- Consumes: `scheduleSubjectScoreProvider(int subjectId) -> AsyncValue<String?>` and `AnimeCoverCard.scoreBadge`.
- Produces: schedule cards that show the resolved score badge only; loading/error/null states supply no badge.

- [ ] **Step 1: Write the failing schedule-screen widget test**

Import `schedule_subject_score.dart`. Extend `_wrap` to accept `List<Override> overrides = const []` and append that list after its fake schedule-controller override. Add this test:

```dart
testWidgets('shows a resolved subject score as a schedule cover badge', (
  tester,
) async {
  await tester.pumpWidget(_wrap(
    const [
      ScheduleDay(
        date: '2024-01-01',
        subjects: [SubjectCard(id: 1, name: 'Foo')],
      ),
    ],
    overrides: [
      scheduleSubjectScoreProvider(1).overrideWith((ref) async => '7.8'),
    ],
  ));
  await tester.pumpAndSettle();

  expect(find.text('7.8'), findsOneWidget);
  expect(find.text('Foo'), findsOneWidget);
});
```

Also add an assertion to the existing horizontal-row test that `第1话 · 22:00` still appears after the score-provider integration.

- [ ] **Step 2: Run the schedule-screen test to verify it fails**

Run: `flutter test test/ui/schedule/schedule_screen_test.dart`

Expected: the resolved provider override has no visible consumer yet, so `find.text('7.8')` fails.

- [ ] **Step 3: Watch the score provider per schedule card**

Inside the horizontal list's item builder, keep the existing `Padding` and `SizedBox`, but wrap `AnimeCoverCard` in a `Consumer`. For valid IDs, read the resolved value with `.valueOrNull`; a null ID passes no badge and must not instantiate a provider.

```dart
child: Consumer(
  builder: (context, ref, _) {
    final scoreBadge = card.id == null
        ? null
        : ref.watch(scheduleSubjectScoreProvider(card.id!)).valueOrNull;
    return AnimeCoverCard(
      imageUrl: card.imageUrl ?? '',
      title: card.nameCn ?? card.name,
      subtitle: formatScheduleEpisodeMetadata(
        episodeSort: card.episodeSort,
        airingTime: card.airingTime,
      ),
      scoreBadge: scoreBadge,
      onTap: () => openSubjectDetail(context, card),
    );
  },
),
```

Add `import '../../domain/schedule/schedule_subject_score.dart';` to the screen. The provider catches API errors itself; `.valueOrNull` also ensures loading has no spinner and no layout change.

- [ ] **Step 4: Run the schedule-screen test to verify it passes**

Run: `flutter test test/ui/schedule/schedule_screen_test.dart`

Expected: PASS; resolved score is visible as a badge and existing title/date/subtitle behavior remains green.

- [ ] **Step 5: Run targeted regression tests and static analysis**

Run: `flutter test test/domain/schedule/schedule_subject_score_test.dart test/ui/common/anime_cover_card_test.dart test/ui/schedule/schedule_screen_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: no new errors. Existing repository informational diagnostics may remain.

- [ ] **Step 6: Commit the integration task**

```bash
git add lib/ui/schedule/schedule_screen.dart test/ui/schedule/schedule_screen_test.dart
git commit -m "feat(schedule): show Bangumi rating badges"
```

### Task 4: Full Verification

**Files:**
- Verify only; no source changes expected.

**Interfaces:**
- Consumes: all completed rating-badge changes.
- Produces: evidence that code generation, formatting, analyzer, unit/widget tests, and a macOS debug build are compatible.

- [ ] **Step 1: Format all modified Dart files**

Run:

```bash
dart format lib/domain/schedule/schedule_subject_score.dart lib/ui/common/anime_cover_card.dart lib/ui/schedule/schedule_screen.dart test/domain/schedule/schedule_subject_score_test.dart test/ui/common/anime_cover_card_test.dart test/ui/schedule/schedule_screen_test.dart
```

Expected: formatter reports all listed files formatted.

- [ ] **Step 2: Run the complete test suite**

Run: `flutter test`

Expected: PASS with zero failures.

- [ ] **Step 3: Build the macOS debug application**

Run: `flutter build macos --debug`

Expected: produces `build/macos/Build/Products/Debug/AniMeow.app` without linker errors.

- [ ] **Step 4: Check the final diff**

Run: `git diff --check`

Expected: no output.

- [ ] **Step 5: Commit any formatter-only changes**

```bash
git add lib/domain/schedule/schedule_subject_score.dart lib/domain/schedule/schedule_subject_score.g.dart lib/ui/common/anime_cover_card.dart lib/ui/schedule/schedule_screen.dart test/domain/schedule/schedule_subject_score_test.dart test/ui/common/anime_cover_card_test.dart test/ui/schedule/schedule_screen_test.dart
git diff --cached --check
git commit -m "test(schedule): verify rating badge behavior"
```

Only create this commit if formatting or verification required additional tracked changes not already committed in Tasks 1-3.
