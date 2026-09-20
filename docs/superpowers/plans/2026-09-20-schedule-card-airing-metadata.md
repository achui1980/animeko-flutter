# Schedule Card Airing Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize the schedule title and show each scheduled episode's number and local airing time beneath its card title.

**Architecture:** Preserve per-episode schedule metadata while mapping the API model into the existing `SubjectCard` domain type. `ScheduleScreen` formats that metadata and supplies it as an optional subtitle to the shared cover card, so all non-schedule card callers retain their current appearance.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_test, mocktail.

**Spec:** `docs/superpowers/specs/2026-09-20-schedule-card-airing-metadata-design.md`

## Global Constraints

- Change the schedule title to the exact Chinese copy `追番日历`.
- Display schedule-only metadata as `第{episode}话 · HH:mm`.
- Interpret API `airingTime` values as ISO-8601 UTC timestamps and render device-local time.
- Omit metadata for missing or malformed values; do not show blank lines or separators.
- Do not add localization infrastructure or alter non-schedule card layouts.
- Reuse `formatEpisodeNumber` from `lib/ui/subject/subject_meta_text.dart`.

---

### Task 1: Preserve Schedule Metadata in the Domain Card

**Files:**
- Modify: `lib/domain/subject_card.dart:18-67`
- Modify: `lib/domain/schedule/schedule_controller.dart:52-57`
- Test: `test/domain/subject_card_test.dart`
- Test: `test/domain/schedule/schedule_controller_test.dart`

**Interfaces:**
- Consumes: `ScheduledAnimeEpisode.episode.sort` and `.airingTime`, both `String`.
- Produces: `SubjectCard.episodeSort` and `.airingTime`, both nullable `String`; `SubjectCard.fromScheduledSubject(..., {String? episodeSort, String? airingTime})`.

- [ ] **Step 1: Write the failing domain tests**

Add a full-field `SubjectCard` expectation and extend the schedule-controller fixture assertions:

```dart
expect(card.episodeSort, '1');
expect(card.airingTime, '2026-08-28T22:00:00Z');

expect(result.single.subjects.single.episodeSort, '1');
expect(result.single.subjects.single.airingTime, '2026-08-28T22:00:00Z');
```

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `flutter test test/domain/subject_card_test.dart test/domain/schedule/schedule_controller_test.dart`

Expected: FAIL because `SubjectCard` does not yet expose `episodeSort` or `airingTime`.

- [ ] **Step 3: Add the optional fields and forward API metadata**

Add optional fields/constructor parameters to `SubjectCard`, accept the two optional values in `fromScheduledSubject`, and forward them from the controller:

```dart
subjects: day.list
    .map(
      (episode) => SubjectCard.fromScheduledSubject(
        episode.subject,
        episodeSort: episode.episode.sort,
        airingTime: episode.airingTime,
      ),
    )
    .toList(),
```

- [ ] **Step 4: Run the focused tests to verify success**

Run: `flutter test test/domain/subject_card_test.dart test/domain/schedule/schedule_controller_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the domain-data flow change**

```bash
git add lib/domain/subject_card.dart lib/domain/schedule/schedule_controller.dart test/domain/subject_card_test.dart test/domain/schedule/schedule_controller_test.dart
git commit -m "feat(schedule): retain episode airing metadata"
```

### Task 2: Render the Localized Schedule Metadata

**Files:**
- Modify: `lib/ui/common/anime_cover_card.dart:7-68`
- Modify: `lib/ui/schedule/schedule_screen.dart:13-100`
- Test: `test/ui/common/anime_cover_card_test.dart`
- Test: `test/ui/schedule/schedule_screen_test.dart`

**Interfaces:**
- Consumes: nullable `SubjectCard.episodeSort` and `.airingTime`; `formatEpisodeNumber(num)`.
- Produces: `String? formatScheduleEpisodeMetadata({String? episodeSort, String? airingTime})`; optional `AnimeCoverCard.subtitle`.

- [ ] **Step 1: Write failing formatting and widget tests**

Add pure tests for a valid time, decimal episode sort, and invalid/missing metadata. Add widget assertions for the localized AppBar title and visible subtitle:

```dart
expect(
  formatScheduleEpisodeMetadata(
    episodeSort: '1',
    airingTime: '2026-08-28T22:00:00Z',
  ),
  '第1话 · 22:00',
);
expect(find.text('追番日历'), findsOneWidget);
expect(find.text('第1话 · 22:00'), findsOneWidget);
```

Use `DateTime(...).toUtc().toIso8601String()` to construct the test timestamp for local-time assertions, so it is deterministic across test environments.

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `flutter test test/ui/common/anime_cover_card_test.dart test/ui/schedule/schedule_screen_test.dart`

Expected: FAIL because the formatter and `subtitle` property do not exist and the title remains English.

- [ ] **Step 3: Add card subtitle support**

Add `String? subtitle` to `AnimeCoverCard`. When it is non-null and non-empty, render it below the title with a single line, ellipsis overflow, and a subdued `bodySmall` style. Existing callers do not pass this value.

- [ ] **Step 4: Format and supply schedule metadata**

Import `formatEpisodeNumber`, add `formatScheduleEpisodeMetadata`, and implement it with `num.tryParse`, `DateTime.tryParse`, `.toLocal()`, and zero-padded hours/minutes. Change the AppBar title to `追番日历`, provide the formatter result to `AnimeCoverCard.subtitle`, and increase the schedule card-row height only as much as needed for the subtitle.

```dart
final episode = num.tryParse(episodeSort ?? '');
final time = airingTime == null ? null : DateTime.tryParse(airingTime);
if (episode == null || time == null) return null;
final local = time.toLocal();
return '第${formatEpisodeNumber(episode)}话 · '
    '${local.hour.toString().padLeft(2, '0')}:'
    '${local.minute.toString().padLeft(2, '0')}';
```

- [ ] **Step 5: Run focused tests to verify success**

Run: `flutter test test/ui/common/anime_cover_card_test.dart test/ui/schedule/schedule_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Format and run project gates**

Run: `dart format lib/domain/subject_card.dart lib/domain/schedule/schedule_controller.dart lib/ui/common/anime_cover_card.dart lib/ui/schedule/schedule_screen.dart test/domain/subject_card_test.dart test/domain/schedule/schedule_controller_test.dart test/ui/common/anime_cover_card_test.dart test/ui/schedule/schedule_screen_test.dart && flutter analyze && flutter test`

Expected: formatter completes, analyzer has no errors, and the full test suite passes.

- [ ] **Step 7: Commit the UI change**

```bash
git add lib/ui/common/anime_cover_card.dart lib/ui/schedule/schedule_screen.dart test/ui/common/anime_cover_card_test.dart test/ui/schedule/schedule_screen_test.dart
git commit -m "feat(schedule): show episode airing time on cards"
```
