# Mikan 番剧 Feed 与字幕组发现 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Mikan media source fetch a subject's full per-bangumi RSS feed (`/RSS/Bangumi?bangumiId=<id>`) instead of a single keyword search, so every subtitle group that released a given episode shows up in the 线路 list.

**Architecture:** A new `MikanSubjectLocator` (HTML-scrapes `/Home/Search`, then verifies a `bgm.tv/subject/<id>` back-link on `/Home/Bangumi/<id>`) resolves a Bangumi `subjectId` to a Mikan `bangumiId`; the result is cached forever (positive) or for 7 days (negative) in a new Drift table via `MikanSubjectMappingRepository`. `MediaSource.search` gains an optional `subjectId` so `RssMediaSource` can use that mapping to hit the per-bangumi feed, silently falling back to today's keyword search whenever the mapping is unavailable. Downstream parsing (`parseRssFeed` → `groupByEpisode` → `listEpisodes`/`resolvePlayback`/`LineSwitchSheet`) is untouched; `title_parser` is extended so releases titled `S01E09` / `第09话` / `09v2` are no longer discarded.

**Tech Stack:** dio, package:html, drift 2.31.0, riverpod 3.x (`@riverpod` codegen), xml, flutter_test + mocktail.

**Design doc:** `docs/superpowers/specs/2026-09-11-mikan-subgroup-discovery-design.md` (Approved)

## Global Constraints

- Riverpod 3.x `@riverpod` codegen only (no manual `Provider` declarations); run `dart run build_runner build --delete-conflicting-outputs` after touching any `@riverpod` provider or any Drift table, **before** running tests.
- `lib/domain/**` must stay free of `package:flutter` imports (Tasks 1, 2 and 6 all touch `lib/domain/**`).
- All new tests must be fully offline: fixtures under `test/fixtures/mikan/` plus `MockDio`; no live network, no real filesystem DB (`NativeDatabase.memory()` only).
- Mikan requests must reuse the existing `mikanRssDio` provider (process-level proxy `HttpOverrides`, `User-Agent`, 10s connect/receive timeouts). Do not construct a fresh `Dio()`, and do not capture a `Ref` inside `findProxy` (see `docs/superpowers/specs/2026-09-01-proxy-settings-design.md:214`).
- The locator must never throw: every failure path (timeout, 404, no cards, back-link mismatch, changed HTML) returns `null` and `RssMediaSource` falls back to keyword search.
- `dart format lib test`, then `flutter analyze` (zero errors; pre-existing infos are fine), then `flutter test` (full suite) must pass before each commit.
- Conventional Commits with scope, in English, e.g. `feat(mikan): ...`, `feat(media): ...`, `fix(mikan): ...`.
- Known-and-accepted gap (verified against the current code, do NOT "fix" it in this plan): nothing in `lib/` currently writes the Drift `Subjects` table, so `readJapaneseName` returns `null` in practice today and the locator's second keyword candidate (the Japanese name) is effectively dormant. The design doc explicitly specifies that path as "skip the candidate when the row is absent, with no extra request", so this is correct behavior — populating `Subjects` from the Bangumi API is out of scope here.
- Explicit non-goals (from the design doc — do not implement): parsing Mikan's 字幕组 sidebar or `subgroupid` feeds; fixing the year-as-episode-number bug (`… 2026 [07]`); fixing `resolvePlayback`'s string-based resolution sort (`'720P'` before `'1080P'`); resolution/language/subtitle-group preference settings or a full MediaSelector.

---

## File Structure

| File | Created / Modified | Single responsibility |
|---|---|---|
| `lib/domain/media/title_matcher.dart` | Modified | Expose `titleSimilarity(a, b)` publicly (extracted from private `_similarity`) so non-`MediaCandidate` `(id, title)` pairs can be ranked; `matchBest` behavior unchanged. |
| `lib/domain/media/title_parser.dart` | Modified | Additionally recognize `S01E09` / `E09`, `第09话|集|話` and `09v2` episode formats. |
| `lib/data/local_database.dart` | Modified | New `MikanSubjectMappings` table; `schemaVersion` 2 → 3 with a `from < 3` migration. |
| `lib/data/rss/mikan_subject_mapping_repository.dart` | Created | Persistent `subjectId → mikanBangumiId` cache (positive = forever, negative = 7-day TTL) + local Japanese-name lookup. |
| `lib/data/rss/mikan_subject_locator.dart` | Created | Resolve a Bangumi `subjectId` to a Mikan `bangumiId` via `/Home/Search` + `bgm.tv` back-link verification; never throws. |
| `lib/domain/media/media_source.dart` | Modified | `search` signature gains optional `subjectId`. |
| `lib/domain/media/media_registry.dart` | Modified | Update the 4 adapter `search` overrides; inject locator + mapping repository into `RssMediaSource`. |
| `lib/domain/play/subject_episodes_controller.dart` | Modified | Pass the `subjectId` it already holds into `MediaSource.search`. |
| `lib/data/rss/rss_media_source.dart` | Modified | `RssSourceConfig.subjectSearchUrl`/`bangumiFeedUrl`; `search()` resolves the mapping and fetches the per-bangumi feed, falling back to keyword search; `mikanSubjectLocator` provider. |
| `test/fixtures/mikan/home_search_4012.html` | Created | Trimmed `/Home/Search` result page with two 条目 cards (decoy first). |
| `test/fixtures/mikan/home_search_empty.html` | Created | Trimmed `/Home/Search` page with no 条目 cards. |
| `test/fixtures/mikan/home_bangumi_4012.html` | Created | Trimmed `/Home/Bangumi/4012` page with the `bgm.tv/subject/545008` back-link. |
| `test/fixtures/mikan/home_bangumi_3999.html` | Created | Trimmed `/Home/Bangumi/3999` page with a *different* back-link (negative case). |
| `test/fixtures/mikan/rss_bangumi_4012.xml` | Created | Small `/RSS/Bangumi` feed: 3 groups on episode 1 (incl. an `S01E01` title) + 1 on episode 2. |
| `test/domain/media/title_matcher_test.dart` | Modified | Unit tests for `titleSimilarity`. |
| `test/domain/media/title_parser_test.dart` | Modified | Tests for the 3 new formats + regressions for the existing ones. |
| `test/data/local_database_test.dart` | Modified | `schemaVersion == 3`, new-table round-trip, real `from = 2` upgrade test. |
| `test/data/rss/mikan_subject_mapping_repository_test.dart` | Created | Hit / miss / fresh-negative / expired-negative / upsert / Japanese-name lookup. |
| `test/data/rss/mikan_subject_locator_test.dart` | Created | Card parsing, keyword-candidate generation, ranking, back-link verification, every failure path. |
| `test/data/rss/rss_media_source_test.dart` | Modified | Assert `/RSS/Bangumi?bangumiId=` with a mapping and `/RSS/Search?searchstr=` without one. |
| `test/domain/media/media_source_test.dart` | Modified | `_FakeSource.search` signature. |
| `test/domain/media/media_registry_test.dart` | Modified | Override `appDatabaseProvider` when reading `mediaSourcesProvider`. |
| `test/domain/play/subject_episodes_controller_test.dart` | Modified | Stubs/verification for the new `subjectId` named argument. |
| `test/ui/subject/episode_playback_sheet_test.dart` | Modified | Stubs for the new `subjectId` named argument. |
| `test/ui/subject/episode_source_sheet_test.dart` | Modified | `_FakeSource.search` signature. |
| `test/ui/subject/episode_source_grid_test.dart` | Modified | `_FakeSource.search` signature. |

---

### Task 1: Extract a public `titleSimilarity` helper

**Files:**
- Modify: `lib/domain/media/title_matcher.dart:4`, `lib/domain/media/title_matcher.dart:241-276`
- Test: `test/domain/media/title_matcher_test.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `double titleSimilarity(String a, String b)` — top-level public function in `lib/domain/media/title_matcher.dart`, returns a score in `[0, 1]`. Used by Task 5's locator to rank `(bangumiId, mikanTitle)` pairs.

- [ ] **Step 1: Write the failing test**

Append this group to `test/domain/media/title_matcher_test.dart`, inside `void main() { ... }`, after the existing `group('matchBest', ...)`:

```dart
  group('titleSimilarity', () {
    test('identical strings score 1.0', () {
      expect(titleSimilarity('恶女不才，请多关照', '恶女不才，请多关照'), 1.0);
    });

    test('empty input scores 0', () {
      expect(titleSimilarity('', '恶女不才'), 0);
      expect(titleSimilarity('恶女不才', ''), 0);
    });

    test('containment scores by length ratio', () {
      expect(titleSimilarity('abcd', 'ab'), 0.5);
      expect(titleSimilarity('ab', 'abcd'), 0.5);
    });

    test('disjoint character sets score 0', () {
      expect(titleSimilarity('abc', 'xyz'), 0);
    });

    test('partial overlap scores by character-set ratio', () {
      // {a,b,c} vs {a,b,d}: intersection 2, union 4.
      expect(titleSimilarity('abc', 'abd'), 0.5);
    });

    test('an unrelated Mikan title scores lower than the exact title', () {
      const subjectName = '恶女不才，请多关照 ～雏宫蝶鼠换身传～';
      expect(
        titleSimilarity('不完美恶女 剧场版', subjectName),
        lessThan(titleSimilarity(subjectName, subjectName)),
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/media/title_matcher_test.dart`
Expected: FAIL with a compile error like "The function 'titleSimilarity' isn't defined" (it is currently the private `_similarity`).

- [ ] **Step 3: Write minimal implementation**

In `lib/domain/media/title_matcher.dart`, rename the private `_similarity` to a public `titleSimilarity` and update its two references. Replace lines 241-276 (the `_bestSimilarity` doc comment through the end of `_similarity`) with:

```dart
/// The highest [titleSimilarity] score across every combination of [a]'s
/// and [b]'s [_segments]. This lets a title's short "core" name match a
/// candidate even when one side carries extra subtitle text that would
/// otherwise dilute a whole-string character-overlap score below
/// [matchThreshold] (see design doc's follow-up note on word-order and
/// subtitle mismatches).
double _bestSimilarity(String a, String b) {
  var best = 0.0;
  for (final segmentA in _segments(a)) {
    for (final segmentB in _segments(b)) {
      final score = titleSimilarity(segmentA, segmentB);
      if (score > best) best = score;
    }
  }
  return best;
}

/// Deliberately simple, non-academic similarity score in `[0, 1]`:
/// containment (one string fully contains the other) scores by
/// length-ratio, otherwise falls back to a character-set overlap ratio.
/// See design doc "标题匹配策略" for why Levenshtein/Jaro-Winkler are
/// deliberately not used here.
///
/// Public (rather than private to [matchBest]) so callers that rank
/// plain `(id, title)` pairs instead of [MediaCandidate]s can reuse the
/// exact same scoring -- see `MikanSubjectLocator`, which ranks Mikan
/// 条目 search cards. Callers that only need to pick the best
/// [MediaCandidate] should keep using [matchBest]: unlike this function,
/// it also normalizes (case/width/Simplified-vs-Traditional) and
/// segment-splits both sides first.
double titleSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (a.contains(b) || b.contains(a)) {
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length <= b.length ? b : a;
    return shorter.length / longer.length;
  }
  final setA = a.runes.toSet();
  final setB = b.runes.toSet();
  final union = setA.union(setB).length;
  if (union == 0) return 0;
  return setA.intersection(setB).length / union;
}
```

Also fix the stale doc reference on line 4 — replace:

```dart
/// Minimum similarity score (see [_similarity]) for a candidate to be
```

with:

```dart
/// Minimum similarity score (see [titleSimilarity]) for a candidate to be
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/media/title_matcher_test.dart`
Expected: PASS — the 6 new tests plus every pre-existing `matchBest` test (proving the extraction is behavior-neutral).

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/domain/media/title_matcher.dart test/domain/media/title_matcher_test.dart
git commit -m "refactor(media): expose titleSimilarity for non-candidate ranking"
```

---

### Task 2: Recognize `S01E09` / `第09话` / `09v2` episode formats

**Files:**
- Modify: `lib/domain/media/title_parser.dart:36-40` (pattern constants), `lib/domain/media/title_parser.dart:122-146` (`_tryParseEpisode`)
- Test: `test/domain/media/title_parser_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: no new API. `parseTitle(String rawTitle)` → `ParsedTitle` now returns a non-null `episodeRange` for the three additional formats. Task 7's feed test relies on `S01E01` parsing to episode 1.

- [ ] **Step 1: Write the failing test**

Append these tests to `test/domain/media/title_parser_test.dart`, inside the existing `group('parseTitle', ...)`, after the `'recognizes 720p as a resolution'` test:

```dart
    test('parses a SxxExx title (Nix-Raws style)', () {
      const title =
          '[Nix-Raws] ふつつかな悪女ではございますが S01E09 '
          '(Baha 1920x1080 AVC AAC MP4)';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(9), isTrue);
      expect(parsed.episodeRange!.expand(), [9]);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, 'Nix-Raws');
    });

    test('parses a bare Exx title', () {
      const title = '[SomeRaws] 恶女不才，请多关照 E09 [1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.expand(), [9]);
    });

    test('parses a lowercase sxxexx title', () {
      const title = '[SomeRaws] 恶女不才，请多关照 s01e09 [1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.expand(), [9]);
    });

    test('parses 第09话 / 第9集 / 第09話', () {
      for (final word in ['第09话', '第9集', '第09話']) {
        final parsed = parseTitle('[桜都字幕组] 恶女不才，请多关照 [$word][1080P][简体]');

        expect(parsed.episodeRange, isNotNull, reason: word);
        expect(parsed.episodeRange!.expand(), [9], reason: word);
      }
    });

    test('parses a v2 re-release episode number (TSDM style)', () {
      const title = '[TSDM字幕组][恶女不才，请多关照][09v2][1080p][简中]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.expand(), [9]);
      expect(parsed.alliance, 'TSDM字幕组');
      expect(parsed.resolution, '1080P');
    });

    test('regression: the pre-existing bare-number formats still parse', () {
      expect(
        parseTitle('[ANi] 恶女不才，请多关照 - 09 [1080P][Baha][CHT][MP4]')
            .episodeRange!
            .expand(),
        [9],
      );
      expect(
        parseTitle('[ExileSub][恶女不才，请多关照][10][繁体][1080P]')
            .episodeRange!
            .expand(),
        [10],
      );
      expect(
        parseTitle('【澄空学园】★07月新番[恶女不才，请多关照][07-10][1080P][简体][MP4]')
            .episodeRange!
            .expand(),
        [7, 8, 9, 10],
      );
    });

    test('regression: a resolution-only title still has no episode', () {
      expect(parseTitle('[Group][Show][1080P][MP4]').episodeRange, isNull);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/media/title_parser_test.dart`
Expected: FAIL — the 5 new-format tests fail with "Expected: not null / Actual: <null>" (their `episodeRange` is currently `null`); the two regression tests already pass.

- [ ] **Step 3: Write minimal implementation**

In `lib/domain/media/title_parser.dart`, replace lines 36-40 (the pattern constants) with:

```dart
final _bracketPattern = RegExp(r'\[(.+?)\]|【(.+?)】');
final _rangeWordPattern = RegExp(r'^(\d{1,4})\s*[-~～]{1,2}\s*(\d{1,4})$');
final _singleEpisodeWordPattern = RegExp(r'^\d{1,4}$');

/// `S01E09` / `s1e9` / `E09`. The season prefix is optional and
/// deliberately ignored: this project groups releases by episode number
/// only (see [EpisodeRange]), and a Mikan per-bangumi feed already scopes
/// results to one season.
final _seasonEpisodeWordPattern = RegExp(
  r'^(?:S\d{1,2})?E(\d{1,4})$',
  caseSensitive: false,
);

/// `第09话` / `第9集` / `第09話`.
final _chineseEpisodeWordPattern = RegExp(r'^第(\d{1,4})[话集話]$');

/// `09v2` -- a re-released ("v2"/"v3") cut of episode 9. The version
/// suffix is dropped, so a re-release lands in the same episode bucket as
/// the original.
final _versionedEpisodeWordPattern = RegExp(
  r'^(\d{1,4})v\d{1,2}$',
  caseSensitive: false,
);

final _resolutionXPattern = RegExp(r'(\d{3,4})[xX](\d{3,4})');
final _resolutionPPattern = RegExp(r'(\d{3,4})[Pp]\b');
```

Then replace `_tryParseEpisode` (lines 122-146) with:

```dart
EpisodeRange? _tryParseEpisode(String rawWord) {
  final word = rawWord.startsWith('-') ? rawWord.substring(1).trim() : rawWord;
  if (word.isEmpty) return null;

  final rangeMatch = _rangeWordPattern.firstMatch(word);
  if (rangeMatch != null) {
    final start = int.tryParse(rangeMatch.group(1)!);
    final end = int.tryParse(rangeMatch.group(2)!);
    if (start != null &&
        end != null &&
        !_resolutionNumbers.contains(start) &&
        !_resolutionNumbers.contains(end)) {
      return EpisodeRange.range(start, end);
    }
    return null;
  }

  if (_singleEpisodeWordPattern.hasMatch(word)) {
    final value = int.tryParse(word);
    if (value != null && !_resolutionNumbers.contains(value)) {
      return EpisodeRange.single(value);
    }
  }

  // The two explicitly-marked forms below need no [_resolutionNumbers]
  // guard: an `E`/`第…话` marker is never how a resolution is written, so
  // there is no bare-number ambiguity to protect against.
  final seasonEpisodeMatch = _seasonEpisodeWordPattern.firstMatch(word);
  if (seasonEpisodeMatch != null) {
    final value = int.tryParse(seasonEpisodeMatch.group(1)!);
    if (value != null) return EpisodeRange.single(value);
  }

  final chineseEpisodeMatch = _chineseEpisodeWordPattern.firstMatch(word);
  if (chineseEpisodeMatch != null) {
    final value = int.tryParse(chineseEpisodeMatch.group(1)!);
    if (value != null) return EpisodeRange.single(value);
  }

  final versionedMatch = _versionedEpisodeWordPattern.firstMatch(word);
  if (versionedMatch != null) {
    final value = int.tryParse(versionedMatch.group(1)!);
    if (value != null && !_resolutionNumbers.contains(value)) {
      return EpisodeRange.single(value);
    }
  }

  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/media/title_parser_test.dart`
Expected: PASS (all tests in the file, old and new).

Then run the wider media/RSS suites to prove no grouping regression:

Run: `flutter test test/domain/media test/data/rss`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/domain/media/title_parser.dart test/domain/media/title_parser_test.dart
git commit -m "feat(media): parse SxxExx, 第x话 and vN episode title formats"
```

---

### Task 3: `MikanSubjectMappings` Drift table + schema 2 → 3 migration

**Files:**
- Modify: `lib/data/local_database.dart:76-108` (new table class after `SubjectImageCache`, `@DriftDatabase` table list, `schemaVersion`, `onUpgrade`)
- Test: `test/data/local_database_test.dart:104-106` (schemaVersion expectation) plus new tests

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class MikanSubjectMappings extends Table` with `subjectId` (int, PK), `mikanBangumiId` (int, nullable), `resolvedAt` (DateTime, non-null).
  - Generated: `db.mikanSubjectMappings`, `MikanSubjectMapping` row class, `MikanSubjectMappingsCompanion.insert({Value<int> subjectId, Value<int?> mikanBangumiId, required DateTime resolvedAt})`.
  - `AppDatabase.schemaVersion == 3`.

- [ ] **Step 1: Write the failing test**

In `test/data/local_database_test.dart`, add the `Migrator`/`Value` imports and a v2-upgrade helper at the top of the file. Replace lines 1-13 with:

```dart
import 'package:animeko_flutter/data/local_database.dart';
import 'package:drift/drift.dart' show Migrator, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());
```

Replace the existing schemaVersion test (lines 104-106) with:

```dart
  test('AppDatabase.schemaVersion is 3 (bumped for mikanSubjectMappings)', () {
    expect(db.schemaVersion, 3);
  });

  test('mikanSubjectMappings table round-trips a resolved row', () async {
    await db
        .into(db.mikanSubjectMappings)
        .insert(
          MikanSubjectMappingsCompanion.insert(
            subjectId: const Value(545008),
            mikanBangumiId: const Value(4012),
            resolvedAt: DateTime(2026, 9, 11),
          ),
        );

    final rows = await db.select(db.mikanSubjectMappings).get();

    expect(rows, hasLength(1));
    expect(rows.single.subjectId, 545008);
    expect(rows.single.mikanBangumiId, 4012);
    expect(rows.single.resolvedAt, DateTime(2026, 9, 11));
  });

  test('mikanSubjectMappings accepts a null mikanBangumiId (confirmed '
      'absent from Mikan)', () async {
    await db
        .into(db.mikanSubjectMappings)
        .insert(
          MikanSubjectMappingsCompanion.insert(
            subjectId: const Value(1),
            resolvedAt: DateTime(2026, 9, 11),
          ),
        );

    final rows = await db.select(db.mikanSubjectMappings).get();

    expect(rows.single.mikanBangumiId, isNull);
  });

  test('mikanSubjectMappings does NOT require a matching Subjects row '
      '(no FK: a subject may never have been cached locally)', () async {
    await db
        .into(db.mikanSubjectMappings)
        .insert(
          MikanSubjectMappingsCompanion.insert(
            subjectId: const Value(999999),
            resolvedAt: DateTime(2026, 9, 11),
          ),
        );

    expect(await db.select(db.mikanSubjectMappings).get(), hasLength(1));
  });

  test('onUpgrade from schema 2 creates the mikanSubjectMappings table', () async {
    // A fresh in-memory database is created at the current schema, so drop
    // the new table to simulate a schema-2 database, then run the real
    // onUpgrade callback for the 2 -> 3 step.
    await db.customStatement('DROP TABLE mikan_subject_mappings');

    await db.migration.onUpgrade(Migrator(db), 2, 3);

    await db
        .into(db.mikanSubjectMappings)
        .insert(
          MikanSubjectMappingsCompanion.insert(
            subjectId: const Value(545008),
            mikanBangumiId: const Value(4012),
            resolvedAt: DateTime(2026, 9, 11),
          ),
        );
    expect(await db.select(db.mikanSubjectMappings).get(), hasLength(1));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/local_database_test.dart`
Expected: FAIL with compile errors like "The getter 'mikanSubjectMappings' isn't defined for the type 'AppDatabase'" and "Undefined name 'MikanSubjectMappingsCompanion'".

- [ ] **Step 3: Write minimal implementation**

In `lib/data/local_database.dart`, insert this class immediately after the `SubjectImageCache` class (i.e. after line 76, before the `@DriftDatabase` annotation):

```dart
/// Persistent cache of the `Bangumi subjectId -> Mikan bangumiId` mapping
/// resolved by `MikanSubjectLocator` (see
/// `lib/data/rss/mikan_subject_locator.dart`). Resolving costs up to 4 HTTP
/// requests (one 条目 search plus up to three back-link verifications), so
/// the result is cached and re-used on every later visit to the same
/// subject.
///
/// [mikanBangumiId] is nullable and `null` means "confirmed *not* findable
/// on Mikan", which is a real, cacheable answer (the source then falls back
/// to keyword search) -- but only for 7 days, since a newly-aired subject
/// can show up on Mikan later (see
/// `MikanSubjectMappingRepository.negativeTtl`). Positive results never
/// expire.
///
/// Deliberately has NO foreign key to [Subjects]: `PRAGMA foreign_keys` is
/// ON for this connection (see [AppDatabase.migration]) and nothing in the
/// app currently writes [Subjects], so a `references(Subjects, #id)` here
/// would make every mapping insert fail.
class MikanSubjectMappings extends Table {
  IntColumn get subjectId => integer()();
  IntColumn get mikanBangumiId => integer().nullable()();
  DateTimeColumn get resolvedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {subjectId};
}
```

Then update the `@DriftDatabase` annotation, `schemaVersion` and `onUpgrade` (lines 78-108) to:

```dart
@DriftDatabase(
  tables: [
    Subjects,
    Episodes,
    SubjectCollections,
    SearchHistory,
    SubjectImageCache,
    MikanSubjectMappings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  /// SQLite does not enforce declared FOREIGN KEY constraints unless this
  /// pragma is turned on for the connection -- drift does not do this
  /// automatically. Without it, `Episodes.subjectId`/`SubjectCollections.subjectId`
  /// referencing a non-existent `Subjects.id` would silently succeed instead
  /// of throwing.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(subjectImageCache);
      }
      if (from < 3) {
        await m.createTable(mikanSubjectMappings);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
```

- [ ] **Step 4: Run codegen, then run test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/data/local_database.g.dart` with `$MikanSubjectMappingsTable`, `MikanSubjectMapping` and `MikanSubjectMappingsCompanion`.

Run: `flutter test test/data/local_database_test.dart`
Expected: PASS (all tests, including the 2 → 3 upgrade test).

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/data/local_database.dart lib/data/local_database.g.dart test/data/local_database_test.dart
git commit -m "feat(data): add MikanSubjectMappings table and schema 3 migration"
```

---

### Task 4: `MikanSubjectMappingRepository`

**Files:**
- Create: `lib/data/rss/mikan_subject_mapping_repository.dart`
- Test: `test/data/rss/mikan_subject_mapping_repository_test.dart`

**Interfaces:**
- Consumes: `db.mikanSubjectMappings`, `MikanSubjectMappingsCompanion` (Task 3); `db.subjects` (existing).
- Produces:
  - `class CachedMikanMapping { const CachedMikanMapping(this.bangumiId); final int? bangumiId; }`
  - `class MikanSubjectMappingRepository`:
    - `MikanSubjectMappingRepository(AppDatabase db, {DateTime Function() now = DateTime.now})`
    - `static const Duration negativeTtl = Duration(days: 7)`
    - `Future<CachedMikanMapping?> lookup(int subjectId)` — `null` = no usable cache (never resolved, or an expired negative)
    - `Future<void> save(int subjectId, int? mikanBangumiId)`
    - `Future<String?> readJapaneseName(int subjectId)`
  - `mikanSubjectMappingRepositoryProvider` (`@riverpod`).

- [ ] **Step 1: Write the failing test**

Create `test/data/rss/mikan_subject_mapping_repository_test.dart`:

```dart
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/data/rss/mikan_subject_mapping_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  /// Fixed "current time" so the 7-day negative TTL is deterministic.
  final now = DateTime(2026, 9, 11, 12);

  MikanSubjectMappingRepository repositoryAt(DateTime clock) =>
      MikanSubjectMappingRepository(db, now: () => clock);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('lookup', () {
    test('returns null when the subject was never resolved', () async {
      expect(await repositoryAt(now).lookup(545008), isNull);
    });

    test('returns the cached positive mapping', () async {
      await repositoryAt(now).save(545008, 4012);

      final cached = await repositoryAt(now).lookup(545008);

      expect(cached, isNotNull);
      expect(cached!.bangumiId, 4012);
    });

    test('a positive mapping never expires', () async {
      await repositoryAt(now).save(545008, 4012);

      final cached = await repositoryAt(
        now.add(const Duration(days: 3650)),
      ).lookup(545008);

      expect(cached?.bangumiId, 4012);
    });

    test('returns a fresh negative result as a usable cache entry', () async {
      await repositoryAt(now).save(545008, null);

      final cached = await repositoryAt(
        now.add(const Duration(days: 6, hours: 23)),
      ).lookup(545008);

      expect(cached, isNotNull);
      expect(cached!.bangumiId, isNull);
    });

    test('treats a negative result older than 7 days as a cache miss', () async {
      await repositoryAt(now).save(545008, null);

      final cached = await repositoryAt(
        now.add(const Duration(days: 7, seconds: 1)),
      ).lookup(545008);

      expect(cached, isNull);
    });
  });

  group('save', () {
    test('upserts: a later save overwrites the earlier value', () async {
      await repositoryAt(now).save(545008, null);
      await repositoryAt(now.add(const Duration(days: 1))).save(545008, 4012);

      final rows = await db.select(db.mikanSubjectMappings).get();

      expect(rows, hasLength(1));
      expect(rows.single.mikanBangumiId, 4012);
      expect(rows.single.resolvedAt, now.add(const Duration(days: 1)));
    });

    test('stamps resolvedAt with the injected clock', () async {
      await repositoryAt(now).save(545008, 4012);

      final rows = await db.select(db.mikanSubjectMappings).get();

      expect(rows.single.resolvedAt, now);
    });
  });

  group('readJapaneseName', () {
    test('returns null when the subject is not cached locally', () async {
      expect(await repositoryAt(now).readJapaneseName(545008), isNull);
    });

    test('returns the Subjects.name column for a cached subject', () async {
      await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: const Value(545008),
              name: 'ふつつかな悪女ではございますが ～雛宮蝶鼠伝奇～',
              nameCn: '恶女不才，请多关照 ～雏宫蝶鼠换身传～',
            ),
          );

      expect(
        await repositoryAt(now).readJapaneseName(545008),
        'ふつつかな悪女ではございますが ～雛宮蝶鼠伝奇～',
      );
    });

    test('returns null for a blank name', () async {
      await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: const Value(545008),
              name: '   ',
              nameCn: '恶女不才，请多关照',
            ),
          );

      expect(await repositoryAt(now).readJapaneseName(545008), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/rss/mikan_subject_mapping_repository_test.dart`
Expected: FAIL with "Error: Couldn't resolve the package 'animeko_flutter' ... mikan_subject_mapping_repository.dart" / "Undefined name 'MikanSubjectMappingRepository'" (the file does not exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `lib/data/rss/mikan_subject_mapping_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local_database.dart';

part 'mikan_subject_mapping_repository.g.dart';

/// A usable cached `subjectId -> Mikan bangumiId` answer.
///
/// [bangumiId] `null` means "confirmed absent from Mikan, and that negative
/// answer has not expired yet" -- distinct from
/// [MikanSubjectMappingRepository.lookup] returning `null`, which means
/// "no usable cache, go ask the network".
class CachedMikanMapping {
  const CachedMikanMapping(this.bangumiId);

  final int? bangumiId;
}

/// Read/write access to the persistent `subjectId -> Mikan bangumiId`
/// mapping cache (see [MikanSubjectMappings]), plus the local Japanese-name
/// lookup the locator needs for its second search-keyword candidate.
///
/// The Japanese-name read lives here (rather than injecting [AppDatabase]
/// into `RssMediaSource`) so the media source has exactly one collaborator
/// for all of its local-database needs.
class MikanSubjectMappingRepository {
  MikanSubjectMappingRepository(
    this._db, {
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// How long a negative ("not on Mikan") answer stays valid. A subject can
  /// be added to Mikan after it starts airing, so a miss must be retried
  /// eventually -- but not on every single visit.
  static const negativeTtl = Duration(days: 7);

  /// Returns the cached answer for [subjectId], or `null` when there is no
  /// usable cache: either nothing was ever stored, or the stored answer is a
  /// negative one that has since expired.
  Future<CachedMikanMapping?> lookup(int subjectId) async {
    final row =
        await (_db.select(_db.mikanSubjectMappings)
              ..where((t) => t.subjectId.equals(subjectId)))
            .getSingleOrNull();
    if (row == null) return null;

    final bangumiId = row.mikanBangumiId;
    if (bangumiId != null) return CachedMikanMapping(bangumiId);

    if (_now().difference(row.resolvedAt) >= negativeTtl) return null;
    return const CachedMikanMapping(null);
  }

  /// Stores the resolution result for [subjectId], overwriting any previous
  /// answer. Pass a `null` [mikanBangumiId] to record a negative result.
  Future<void> save(int subjectId, int? mikanBangumiId) async {
    await _db
        .into(_db.mikanSubjectMappings)
        .insertOnConflictUpdate(
          MikanSubjectMappingsCompanion.insert(
            subjectId: Value(subjectId),
            mikanBangumiId: Value(mikanBangumiId),
            resolvedAt: _now(),
          ),
        );
  }

  /// The subject's original (usually Japanese) name from the local
  /// [Subjects] cache, or `null` when the subject was never cached locally
  /// or its name is blank. Mikan indexes Japanese titles too, so this is the
  /// locator's second keyword candidate -- when it is `null` that candidate
  /// is simply skipped, with no extra HTTP request.
  Future<String?> readJapaneseName(int subjectId) async {
    final row =
        await (_db.select(_db.subjects)
              ..where((t) => t.id.equals(subjectId)))
            .getSingleOrNull();
    final name = row?.name.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }
}

@riverpod
MikanSubjectMappingRepository mikanSubjectMappingRepository(Ref ref) =>
    MikanSubjectMappingRepository(ref.watch(appDatabaseProvider));
```

- [ ] **Step 4: Run codegen, then run test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: creates `lib/data/rss/mikan_subject_mapping_repository.g.dart` with `mikanSubjectMappingRepositoryProvider`.

Run: `flutter test test/data/rss/mikan_subject_mapping_repository_test.dart`
Expected: PASS (12 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/data/rss/mikan_subject_mapping_repository.dart lib/data/rss/mikan_subject_mapping_repository.g.dart test/data/rss/mikan_subject_mapping_repository_test.dart
git commit -m "feat(mikan): cache subjectId to bangumiId mapping with 7d negative TTL"
```

---

### Task 5: `MikanSubjectLocator`

**Files:**
- Create: `lib/data/rss/mikan_subject_locator.dart`
- Create: `test/fixtures/mikan/home_search_4012.html`
- Create: `test/fixtures/mikan/home_search_empty.html`
- Create: `test/fixtures/mikan/home_bangumi_4012.html`
- Create: `test/fixtures/mikan/home_bangumi_3999.html`
- Test: `test/data/rss/mikan_subject_locator_test.dart`

**Interfaces:**
- Consumes: `double titleSimilarity(String a, String b)` (Task 1).
- Produces:
  - `class MikanSubjectCard { const MikanSubjectCard({required this.bangumiId, required this.title}); final int bangumiId; final String title; }`
  - `List<MikanSubjectCard> parseMikanSearchResults(String body)`
  - `List<String> mikanSearchCandidates({required String nameCn, String? nameJp})`
  - `class MikanSubjectLocator`:
    - `MikanSubjectLocator(Dio dio, {String searchUrlTemplate = 'https://mikanani.me/Home/Search?searchstr={keyword}', String bangumiPageUrlTemplate = 'https://mikanani.me/Home/Bangumi/{bangumiId}'})`
    - `Future<int?> resolveBangumiId({required int subjectId, required String nameCn, String? nameJp})`

- [ ] **Step 1: Write the failing test**

Create `test/fixtures/mikan/home_search_4012.html` (trimmed to the 条目-card markup documented in the design doc; the decoy card is deliberately FIRST in document order so ranking has to reorder it):

```html
<!DOCTYPE html>
<html>
<head><title>Mikan Project - 搜索结果</title></head>
<body>
<div class="central-container">
  <ul class="list-inline an-ul">
    <li>
      <a href="/Home/Bangumi/3999" target="_blank">
        <span data-src="/images/Bangumi/202604/decoy.jpg?width=400" class="b-lazy"></span>
        <div class="an-info">
          <div class="an-info-group">
            <div class="an-text" title="不完美恶女 剧场版">不完美恶女 剧场版</div>
          </div>
        </div>
      </a>
    </li>
    <li>
      <a href="/Home/Bangumi/4012" target="_blank">
        <span data-src="/images/Bangumi/202607/239c521c.jpg?width=400" class="b-lazy"></span>
        <div class="an-info">
          <div class="an-info-group">
            <div class="an-text" title="恶女不才，请多关照 ～雏宫蝶鼠换身传～">恶女不才，请多关照 ～雏宫蝶鼠换身传～</div>
          </div>
        </div>
      </a>
    </li>
  </ul>
</div>
</body>
</html>
```

Create `test/fixtures/mikan/home_search_empty.html` (a real miss still renders the chrome, but no 条目 cards — note the nav links must NOT point at `/Home/Bangumi/`):

```html
<!DOCTYPE html>
<html>
<head><title>Mikan Project - 搜索结果</title></head>
<body>
<div class="navbar-nav">
  <a href="/">首页</a>
  <a href="/Home/Classic/1">资源列表</a>
</div>
<div class="central-container">
  <ul class="list-inline an-ul"></ul>
</div>
</body>
</html>
```

Create `test/fixtures/mikan/home_bangumi_4012.html`:

```html
<!DOCTYPE html>
<html>
<head><title>Mikan Project - 恶女不才，请多关照</title></head>
<body>
<div class="pull-left leftbar-container">
  <p class="bangumi-title">恶女不才，请多关照 ～雏宫蝶鼠换身传～</p>
  <p class="bangumi-info">放送开始： 07/05/2026</p>
  <p class="bangumi-info">Bangumi番组计划链接：
    <a class="w-other-c" href="https://bgm.tv/subject/545008" target="_blank">https://bgm.tv/subject/545008</a>
  </p>
</div>
</body>
</html>
```

Create `test/fixtures/mikan/home_bangumi_3999.html`:

```html
<!DOCTYPE html>
<html>
<head><title>Mikan Project - 不完美恶女 剧场版</title></head>
<body>
<div class="pull-left leftbar-container">
  <p class="bangumi-title">不完美恶女 剧场版</p>
  <p class="bangumi-info">Bangumi番组计划链接：
    <a class="w-other-c" href="https://bgm.tv/subject/500001" target="_blank">https://bgm.tv/subject/500001</a>
  </p>
</div>
</body>
</html>
```

Create `test/data/rss/mikan_subject_locator_test.dart`:

```dart
import 'dart:io';

import 'package:animeko_flutter/data/rss/mikan_subject_locator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// The real Bangumi subject / Mikan bangumi ids for
/// 「恶女不才，请多关照 ～雏宫蝶鼠换身传～」 (see the design doc).
const _subjectId = 545008;
const _bangumiId = 4012;
const _decoyBangumiId = 3999;

const _nameCn = '恶女不才，请多关照 ～雏宫蝶鼠换身传～';
const _nameJp = 'ふつつかな悪女ではございますが ～雛宮蝶鼠伝奇～';

String searchUrl(String keyword) =>
    'https://mikanani.me/Home/Search?searchstr=${Uri.encodeQueryComponent(keyword)}';

String bangumiPageUrl(int bangumiId) =>
    'https://mikanani.me/Home/Bangumi/$bangumiId';

void main() {
  late MockDio dio;
  late MikanSubjectLocator locator;
  late String searchPage;
  late String emptySearchPage;
  late String bangumiPage4012;
  late String bangumiPage3999;

  setUpAll(() {
    searchPage = File(
      'test/fixtures/mikan/home_search_4012.html',
    ).readAsStringSync();
    emptySearchPage = File(
      'test/fixtures/mikan/home_search_empty.html',
    ).readAsStringSync();
    bangumiPage4012 = File(
      'test/fixtures/mikan/home_bangumi_4012.html',
    ).readAsStringSync();
    bangumiPage3999 = File(
      'test/fixtures/mikan/home_bangumi_3999.html',
    ).readAsStringSync();
  });

  setUp(() {
    dio = MockDio();
    locator = MikanSubjectLocator(dio);
  });

  Response<String> htmlResponse(String body) => Response(
    data: body,
    requestOptions: RequestOptions(path: '/'),
    statusCode: 200,
  );

  /// Serves [bodies] by exact URL; any other URL gets the "no results"
  /// search page, so a test only has to declare the URLs it cares about.
  void stubPages(Map<String, String> bodies) {
    when(
      () => dio.get<String>(any(), options: any(named: 'options')),
    ).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      return htmlResponse(bodies[url] ?? emptySearchPage);
    });
  }

  List<String> requestedUrls() =>
      verify(
        () => dio.get<String>(captureAny(), options: any(named: 'options')),
      ).captured.cast<String>();

  group('parseMikanSearchResults', () {
    test('parses every 条目 card in document order', () {
      final cards = parseMikanSearchResults(searchPage);

      expect(cards, hasLength(2));
      expect(cards[0].bangumiId, _decoyBangumiId);
      expect(cards[0].title, '不完美恶女 剧场版');
      expect(cards[1].bangumiId, _bangumiId);
      expect(cards[1].title, _nameCn);
    });

    test('returns an empty list for a page with no cards', () {
      expect(parseMikanSearchResults(emptySearchPage), isEmpty);
    });

    test('returns an empty list for garbage input', () {
      expect(parseMikanSearchResults('not html at all'), isEmpty);
    });
  });

  group('mikanSearchCandidates', () {
    test('truncates the Chinese name at the first ～ and keeps the raw name '
        'as the last resort', () {
      expect(mikanSearchCandidates(nameCn: _nameCn), [
        '恶女不才，请多关照',
        _nameCn,
      ]);
    });

    test('inserts the truncated Japanese name as the second candidate', () {
      expect(mikanSearchCandidates(nameCn: _nameCn, nameJp: _nameJp), [
        '恶女不才，请多关照',
        'ふつつかな悪女ではございますが',
        _nameCn,
      ]);
    });

    test('truncates at half-width and full-width parentheses too', () {
      expect(mikanSearchCandidates(nameCn: '某番剧（第二季）').first, '某番剧');
      expect(mikanSearchCandidates(nameCn: '某番剧 (2026)').first, '某番剧');
      expect(mikanSearchCandidates(nameCn: '某番剧 ~副标题~').first, '某番剧');
    });

    test('de-duplicates when no truncation happened', () {
      expect(mikanSearchCandidates(nameCn: '孤独摇滚'), ['孤独摇滚']);
    });

    test('skips a blank or duplicate Japanese name', () {
      expect(mikanSearchCandidates(nameCn: '孤独摇滚', nameJp: '   '), [
        '孤独摇滚',
      ]);
      expect(mikanSearchCandidates(nameCn: '孤独摇滚', nameJp: '孤独摇滚'), [
        '孤独摇滚',
      ]);
    });
  });

  group('resolveBangumiId', () {
    test('returns the bangumiId whose page back-links this subject, '
        'verifying the highest-similarity card first', () async {
      stubPages({
        searchUrl('恶女不才，请多关照'): searchPage,
        bangumiPageUrl(_bangumiId): bangumiPage4012,
        bangumiPageUrl(_decoyBangumiId): bangumiPage3999,
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result, _bangumiId);
      // Exactly two requests: the first keyword candidate, then the
      // best-ranked card's page. The decoy (listed first in the HTML) must
      // never be fetched.
      expect(requestedUrls(), [
        searchUrl('恶女不才，请多关照'),
        bangumiPageUrl(_bangumiId),
      ]);
    });

    test('falls back to the Japanese name when the Chinese candidate finds '
        'no cards', () async {
      stubPages({
        searchUrl('ふつつかな悪女ではございますが'): searchPage,
        bangumiPageUrl(_bangumiId): bangumiPage4012,
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
        nameJp: _nameJp,
      );

      expect(result, _bangumiId);
      expect(requestedUrls(), [
        searchUrl('恶女不才，请多关照'),
        searchUrl('ふつつかな悪女ではございますが'),
        bangumiPageUrl(_bangumiId),
      ]);
    });

    test('returns null when no card back-links the requested subject', () async {
      stubPages({
        searchUrl('恶女不才，请多关照'): searchPage,
        bangumiPageUrl(_bangumiId): bangumiPage4012,
        bangumiPageUrl(_decoyBangumiId): bangumiPage3999,
      });

      final result = await locator.resolveBangumiId(
        subjectId: 999999,
        nameCn: _nameCn,
      );

      expect(result, isNull);
      // Both cards were verified before giving up (the cap is 3).
      expect(
        requestedUrls(),
        containsAll([
          bangumiPageUrl(_bangumiId),
          bangumiPageUrl(_decoyBangumiId),
        ]),
      );
    });

    test('does not accept a back-link whose id merely starts with the '
        'subject id', () async {
      stubPages({
        searchUrl('恶女不才，请多关照'): searchPage,
        bangumiPageUrl(_bangumiId):
            '<html><body><a class="w-other-c" '
            'href="https://bgm.tv/subject/5450089">x</a></body></html>',
        bangumiPageUrl(_decoyBangumiId): bangumiPage3999,
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result, isNull);
    });

    test('returns null when every keyword candidate finds no cards', () async {
      stubPages(const {});

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
        nameJp: _nameJp,
      );

      expect(result, isNull);
      expect(requestedUrls(), hasLength(3));
    });

    test('returns null instead of throwing when a search request fails', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: RequestOptions(path: '/'),
        ),
      );

      await expectLater(
        locator.resolveBangumiId(subjectId: _subjectId, nameCn: _nameCn),
        completion(isNull),
      );
    });

    test('returns null instead of throwing when a verification request '
        'fails', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.startsWith('https://mikanani.me/Home/Bangumi/')) {
          throw DioException.badResponse(
            statusCode: 404,
            requestOptions: RequestOptions(path: url),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: url),
            ),
          );
        }
        return htmlResponse(searchPage);
      });

      await expectLater(
        locator.resolveBangumiId(subjectId: _subjectId, nameCn: _nameCn),
        completion(isNull),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/rss/mikan_subject_locator_test.dart`
Expected: FAIL with "Error: ... mikan_subject_locator.dart ... doesn't exist" / "Undefined name 'MikanSubjectLocator'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/data/rss/mikan_subject_locator.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/media/title_matcher.dart';

/// One 条目 (subject) card parsed off a Mikan `/Home/Search` result page.
/// [title] is Mikan's OWN subject title, which (unlike the torrent titles in
/// an RSS feed) carries the full name including any `～…～` suffix.
class MikanSubjectCard {
  const MikanSubjectCard({required this.bangumiId, required this.title});

  final int bangumiId;
  final String title;
}

const _defaultSubjectSearchUrl =
    'https://mikanani.me/Home/Search?searchstr={keyword}';
const _defaultBangumiPageUrl = 'https://mikanani.me/Home/Bangumi/{bangumiId}';

/// How many of the highest-ranked cards get a back-link verification
/// request. Mikan's 条目 search returns whole series families (all seasons,
/// movies, ...), so the correct one is essentially always in the top few;
/// this bounds the first-visit request cost at 1 + 3.
const _maxVerifiedCards = 3;

final _bangumiHrefPattern = RegExp(r'^/Home/Bangumi/(\d+)');

/// Parses the 条目 cards out of a Mikan `/Home/Search` page body.
///
/// Card shape (verified live 2026-09-11, see design doc): an
/// `a[href^="/Home/Bangumi/<id>"]` wrapping a `div.an-text` whose `title`
/// attribute holds Mikan's own subject title. Cards without a usable id or
/// title are skipped, and repeated ids are de-duplicated, so a markup
/// change degrades to "no cards" (→ keyword-search fallback) instead of
/// throwing.
List<MikanSubjectCard> parseMikanSearchResults(String body) {
  final document = html_parser.parse(body);
  final cards = <MikanSubjectCard>[];
  final seenIds = <int>{};

  for (final link in document.querySelectorAll('a[href^="/Home/Bangumi/"]')) {
    final href = link.attributes['href'];
    if (href == null) continue;
    final match = _bangumiHrefPattern.firstMatch(href);
    if (match == null) continue;
    final bangumiId = int.parse(match.group(1)!);
    final title = link
        .querySelector('div.an-text')
        ?.attributes['title']
        ?.trim();
    if (title == null || title.isEmpty) continue;
    if (!seenIds.add(bangumiId)) continue;
    cards.add(MikanSubjectCard(bangumiId: bangumiId, title: title));
  }

  return cards;
}

/// Where a title's "core" name ends: Mikan's search ANDs space-separated
/// substrings against *torrent* titles, so a decorated suffix such as
/// `～雏宫蝶鼠换身传～` filters out every release that omits it.
final _keywordCutPattern = RegExp(r'[～~（(]');

/// The search keywords to try, in order: the truncated Chinese name, the
/// truncated Japanese name (Mikan indexes those too), then the raw Chinese
/// name as a last resort. Blank and duplicate candidates are dropped, so a
/// name with nothing to truncate yields a single candidate and a single
/// request.
List<String> mikanSearchCandidates({required String nameCn, String? nameJp}) {
  final candidates = <String>[];

  void add(String? raw) {
    if (raw == null) return;
    final value = raw.trim();
    if (value.isEmpty || candidates.contains(value)) return;
    candidates.add(value);
  }

  add(_truncateAtDecoration(nameCn));
  if (nameJp != null) add(_truncateAtDecoration(nameJp));
  add(nameCn);

  return candidates;
}

String _truncateAtDecoration(String name) {
  final match = _keywordCutPattern.firstMatch(name);
  if (match == null) return name.trim();
  return name.substring(0, match.start).trim();
}

/// Resolves a Bangumi `subjectId` to Mikan's own `bangumiId`, so the caller
/// can fetch that subject's complete per-bangumi RSS feed instead of a
/// keyword search (which silently drops whole subtitle groups -- see design
/// doc).
///
/// Never throws and never returns a guess: the winning card must carry a
/// `bgm.tv/subject/<subjectId>` back-link on its own Mikan page. Title
/// similarity is only used to decide the *order* in which candidates get
/// verified, because the result is cached long-term and a wrong mapping
/// (e.g. a different season of the same series) would be expensive.
class MikanSubjectLocator {
  MikanSubjectLocator(
    this._dio, {
    this.searchUrlTemplate = _defaultSubjectSearchUrl,
    this.bangumiPageUrlTemplate = _defaultBangumiPageUrl,
  });

  final Dio _dio;

  /// Template with a `{keyword}` placeholder.
  final String searchUrlTemplate;

  /// Template with a `{bangumiId}` placeholder.
  final String bangumiPageUrlTemplate;

  Future<int?> resolveBangumiId({
    required int subjectId,
    required String nameCn,
    String? nameJp,
  }) async {
    for (final keyword in mikanSearchCandidates(
      nameCn: nameCn,
      nameJp: nameJp,
    )) {
      final cards = await _searchCards(keyword);
      if (cards.isEmpty) continue;

      final ranked = [...cards]..sort(
        (a, b) => titleSimilarity(
          b.title,
          nameCn,
        ).compareTo(titleSimilarity(a.title, nameCn)),
      );

      for (final card in ranked.take(_maxVerifiedCards)) {
        if (await _hasBackLink(
          bangumiId: card.bangumiId,
          subjectId: subjectId,
        )) {
          return card.bangumiId;
        }
      }

      // This keyword *did* return cards, they just were not this subject.
      // Retrying a broader keyword would only widen an already-wrong
      // result set, so stop here (design doc: 第一个返回卡片的即停).
      return null;
    }
    return null;
  }

  Future<List<MikanSubjectCard>> _searchCards(String keyword) async {
    try {
      final url = searchUrlTemplate.replaceAll(
        '{keyword}',
        Uri.encodeQueryComponent(keyword),
      );
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return parseMikanSearchResults(response.data ?? '');
    } catch (_) {
      // Timeout / non-2xx / unparseable HTML: treat as "no cards" so the
      // caller falls back to keyword search instead of failing the whole
      // media source (design doc "错误处理").
      return const [];
    }
  }

  Future<bool> _hasBackLink({
    required int bangumiId,
    required int subjectId,
  }) async {
    try {
      final url = bangumiPageUrlTemplate.replaceAll(
        '{bangumiId}',
        '$bangumiId',
      );
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      // The negative lookahead stops `.../subject/545008` from matching a
      // page that only links `.../subject/5450089`.
      final pattern = RegExp('bgm\\.tv/subject/$subjectId(?![0-9])');
      return pattern.hasMatch(response.data ?? '');
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/rss/mikan_subject_locator_test.dart`
Expected: PASS (17 tests). No codegen needed: this file declares no `@riverpod` provider (its provider lives in `rss_media_source.dart`, added in Task 7, because it needs `mikanRssSourceConfig`).

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/data/rss/mikan_subject_locator.dart test/data/rss/mikan_subject_locator_test.dart test/fixtures/mikan
git commit -m "feat(mikan): locate a subject's Mikan bangumiId via verified back-link"
```

---

### Task 6: `MediaSource.search(String title, {int? subjectId})`

**Files:**
- Modify: `lib/domain/media/media_source.dart:75-79`
- Modify: `lib/domain/media/media_registry.dart:33-35`, `:61-62`, `:85-86`, `:109-110`
- Modify: `lib/data/rss/rss_media_source.dart:123-124`
- Modify: `lib/domain/play/subject_episodes_controller.dart:46-79`
- Test: `test/domain/play/subject_episodes_controller_test.dart` (primary), plus signature updates in `test/domain/media/media_source_test.dart:33-36`, `test/ui/subject/episode_source_sheet_test.dart:27-28`, `test/ui/subject/episode_source_grid_test.dart:26-27`, `test/ui/subject/episode_playback_sheet_test.dart:61-63`, `:89`, `:115-117`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Future<List<MediaCandidate>> search(String title, {int? subjectId})` on `MediaSource` and all five implementations. `SubjectEpisodesController` now passes its own `subjectId`. Task 7 relies on `RssMediaSource.search` receiving `subjectId`.

- [ ] **Step 1: Write the failing test**

In `test/domain/play/subject_episodes_controller_test.dart`, update every `search` stub to include the named argument and add a verification test. Replace the whole `group('SubjectEpisodesController', ...)` body's tests (lines 62-148) with:

```dart
    test('merges episodes from every source that finds a match', () async {
      when(
        () => sourceA.search('目标番剧', subjectId: 1),
      ).thenAnswer((_) async => [const _FakeCandidate('a', '目标番剧')]);
      when(
        () => sourceA.listEpisodes(any()),
      ).thenAnswer((_) async => [const _FakeEpisode('a', 'A的第1集')]);
      when(
        () => sourceB.search('目标番剧', subjectId: 1),
      ).thenAnswer((_) async => [const _FakeCandidate('b', '目标番剧')]);
      when(
        () => sourceB.listEpisodes(any()),
      ).thenAnswer((_) async => [const _FakeEpisode('b', 'B的第1集')]);

      final result = await read();

      expect(result.map((e) => e.sourceId), containsAll(['a', 'b']));
      expect(
        result.map((e) => e.episode.title),
        containsAll(['A的第1集', 'B的第1集']),
      );
    });

    test('passes the subjectId through to every source', () async {
      when(
        () => sourceA.search(any(), subjectId: any(named: 'subjectId')),
      ).thenAnswer((_) async => []);
      when(
        () => sourceB.search(any(), subjectId: any(named: 'subjectId')),
      ).thenAnswer((_) async => []);

      await expectLater(read(), throwsA(isA<MediaNotFoundException>()));

      verify(() => sourceA.search('目标番剧', subjectId: 1)).called(1);
      verify(() => sourceB.search('目标番剧', subjectId: 1)).called(1);
    });

    test(
      'silently ignores a source that finds no matching candidate',
      () async {
        when(
          () => sourceA.search('目标番剧', subjectId: 1),
        ).thenAnswer((_) async => []);
        when(
          () => sourceB.search('目标番剧', subjectId: 1),
        ).thenAnswer((_) async => [const _FakeCandidate('b', '目标番剧')]);
        when(
          () => sourceB.listEpisodes(any()),
        ).thenAnswer((_) async => [const _FakeEpisode('b', 'B的第1集')]);

        final result = await read();

        expect(result, hasLength(1));
        expect(result.single.sourceId, 'b');
        verifyNever(() => sourceA.listEpisodes(any()));
      },
    );

    test('silently ignores a source whose search throws', () async {
      when(
        () => sourceA.search('目标番剧', subjectId: 1),
      ).thenThrow(Exception('network down'));
      when(
        () => sourceB.search('目标番剧', subjectId: 1),
      ).thenAnswer((_) async => [const _FakeCandidate('b', '目标番剧')]);
      when(
        () => sourceB.listEpisodes(any()),
      ).thenAnswer((_) async => [const _FakeEpisode('b', 'B的第1集')]);

      final result = await read();

      expect(result, hasLength(1));
      expect(result.single.sourceId, 'b');
    });

    test(
      'throws MediaNotFoundException when every source finds nothing',
      () async {
        when(
          () => sourceA.search(any(), subjectId: any(named: 'subjectId')),
        ).thenAnswer((_) async => []);
        when(
          () => sourceB.search(any(), subjectId: any(named: 'subjectId')),
        ).thenThrow(Exception('also down'));

        await expectLater(read(), throwsA(isA<MediaNotFoundException>()));
      },
    );

    test('queries all sources concurrently, not sequentially', () async {
      final order = <String>[];
      when(
        () => sourceA.search(any(), subjectId: any(named: 'subjectId')),
      ).thenAnswer((_) async {
        order.add('a-start');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add('a-end');
        return [];
      });
      when(
        () => sourceB.search(any(), subjectId: any(named: 'subjectId')),
      ).thenAnswer((_) async {
        order.add('b-start');
        return [];
      });

      await expectLater(read(), throwsA(isA<MediaNotFoundException>()));

      // If the sources were queried sequentially, 'b-start' could only
      // appear after 'a-end'. Concurrent querying starts both before
      // either finishes.
      expect(order.indexOf('b-start'), lessThan(order.indexOf('a-end')));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart`
Expected: FAIL with a compile error like "No named parameter with the name 'subjectId'" on `sourceA.search('目标番剧', subjectId: 1)`.

- [ ] **Step 3: Write minimal implementation**

`lib/domain/media/media_source.dart` — replace the `search` declaration and its doc comment (lines 75-79) with:

```dart
  /// Searches this source for [title], returning every plausible
  /// candidate (not just the best match -- matching is the caller's job,
  /// see `title_matcher.dart`). May throw on network/parse failure; the
  /// caller decides how to handle that (see `SubjectEpisodesController`).
  ///
  /// [subjectId] is the Bangumi subject id the search is being run for,
  /// when the caller knows it. Sources that can look up a subject directly
  /// (see `RssMediaSource`, which resolves it to a Mikan bangumiId and then
  /// fetches that subject's complete feed) use it to return far more
  /// complete results than a keyword search can; every other source
  /// ignores it. Sources MUST still work when it is null.
  Future<List<MediaCandidate>> search(String title, {int? subjectId});
```

`lib/domain/media/media_registry.dart` — the four adapters ignore `subjectId`; replace each override:

```dart
  // Anime1MediaSource (line 34)
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.searchCategories(title);
```

```dart
  // XifanMediaSource (line 62)
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.search(title);
```

```dart
  // YinghuaMediaSource (line 86)
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.search(title);
```

```dart
  // DilidiliMediaSource (line 110)
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.search(title);
```

`lib/data/rss/rss_media_source.dart` — widen the signature only (the body still ignores `subjectId`; Task 7 uses it):

```dart
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) async {
    final url = config.searchUrl.replaceAll(
      '{keyword}',
      Uri.encodeQueryComponent(title),
    );
    final response = await _dio.get<String>(url);
    final items = parseRssFeed(response.data ?? '');
    final groups = groupByEpisode(items);

    return [
      RssSeriesCandidate(sourceId: config.name, title: title, groups: groups),
    ];
  }
```

`lib/domain/play/subject_episodes_controller.dart` — pass the subjectId it already has. Replace lines 46-79 with:

```dart
    final sources = ref.watch(mediaSourcesProvider);

    // Query every source concurrently -- one source's latency/failure
    // must not block or fail the others (Decision 7: silent ignore).
    final results = await Future.wait(
      sources.map(
        (source) => _fetchFromSource(source, subjectName, subjectId),
      ),
    );

    final merged = results.expand((episodes) => episodes).toList();
    if (merged.isEmpty) {
      throw const MediaNotFoundException();
    }
    return merged;
  }

  Future<List<MergedEpisode>> _fetchFromSource(
    MediaSource source,
    String subjectName,
    int subjectId,
  ) async {
    try {
      final candidates = await source.search(subjectName, subjectId: subjectId);
      final best = matchBest(candidates, subjectName);
      if (best == null) return const [];
      final episodes = await source.listEpisodes(best);
      return episodes
          .map((e) => MergedEpisode(episode: e, sourceId: source.id))
          .toList();
    } catch (_) {
      // A single source's network/parse failure must not prevent other
      // sources' results from being shown, and must not surface as a
      // distinct error state -- see design doc "错误处理".
      return const [];
    }
  }
```

Now update the remaining test doubles so the suite compiles:

`test/domain/media/media_source_test.dart` (lines 33-36):

```dart
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) async => [
    const _FakeCandidate('Fake Anime'),
  ];
```

`test/ui/subject/episode_source_sheet_test.dart` (lines 27-28) and `test/ui/subject/episode_source_grid_test.dart` (lines 26-27) — identical change in both:

```dart
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) async =>
      const [];
```

`test/ui/subject/episode_playback_sheet_test.dart` — the three `search` stubs:

```dart
      // line 61-63
      when(
        () => source.search(any(), subjectId: any(named: 'subjectId')),
      ).thenAnswer((_) => Completer<List<MediaCandidate>>().future);
```

```dart
    // line 89
    when(
      () => source.search(any(), subjectId: any(named: 'subjectId')),
    ).thenAnswer((_) async => const []);
```

```dart
    // line 115-117
    when(
      () => source.search('目标番剧', subjectId: 1),
    ).thenAnswer((_) async => [const _FakeCandidate('anime1', '目标番剧')]);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart test/domain/media test/ui/subject test/data/rss`
Expected: PASS — including the new `'passes the subjectId through to every source'` test.

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/domain/media/media_source.dart lib/domain/media/media_registry.dart lib/data/rss/rss_media_source.dart lib/domain/play/subject_episodes_controller.dart test/domain/media/media_source_test.dart test/domain/play/subject_episodes_controller_test.dart test/ui/subject/episode_playback_sheet_test.dart test/ui/subject/episode_source_sheet_test.dart test/ui/subject/episode_source_grid_test.dart
git commit -m "feat(media): pass subjectId into MediaSource.search"
```

---

### Task 7: `RssMediaSource` fetches the per-bangumi feed

**Files:**
- Modify: `lib/data/rss/rss_media_source.dart:12-37` (config), `:104-136` (class header, fields, `search`), `:188-198` (providers)
- Modify: `lib/domain/media/media_registry.dart:1-16` (imports), `:146-155` (`mediaSources`)
- Create: `test/fixtures/mikan/rss_bangumi_4012.xml`
- Test: `test/data/rss/rss_media_source_test.dart`, `test/domain/media/media_registry_test.dart:281-288`

**Interfaces:**
- Consumes: `MikanSubjectLocator.resolveBangumiId({required int subjectId, required String nameCn, String? nameJp})` (Task 5); `MikanSubjectMappingRepository.lookup/save/readJapaneseName` + `CachedMikanMapping` (Task 4); `search(String title, {int? subjectId})` (Task 6).
- Produces:
  - `RssSourceConfig({required String name, required String searchUrl, required String iconUrl, String? subjectSearchUrl, String? bangumiFeedUrl})`
  - `RssMediaSource(RssSourceConfig config, Dio dio, RqbitEngine engine, {MikanSubjectLocator? locator, MikanSubjectMappingRepository? mappingRepository})`
  - `mikanSubjectLocatorProvider` (`@riverpod`)

- [ ] **Step 1: Write the failing test**

Create `test/fixtures/mikan/rss_bangumi_4012.xml` — a trimmed `/RSS/Bangumi?bangumiId=4012` feed. Structurally identical to `/RSS/Search` (same `<torrent>`/`<enclosure>` shape as the existing `test/fixtures/mikan_rss_search_sample.xml`), with three different subtitle groups on episode 1 (one of them using the `S01E01` format that Task 2 taught the parser) plus one episode-2 release:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
<channel>
<title>Mikan Project - 恶女不才，请多关照 ～雏宫蝶鼠换身传～</title>
<link>https://mikanani.me/RSS/Bangumi?bangumiId=4012</link>
<description>Mikan Project - 恶女不才，请多关照 ～雏宫蝶鼠换身传～</description>
<item>
<guid isPermaLink="false">[TSDM字幕组][恶女不才，请多关照][01][1080p][简中]</guid>
<link>https://mikanani.me/Home/Episode/1111111111111111111111111111111111111111</link>
<title>[TSDM字幕组][恶女不才，请多关照][01][1080p][简中]</title>
<description>[TSDM字幕组][恶女不才，请多关照][01][1080p][简中][500 MB]</description>
<torrent xmlns="https://mikanani.me/0.1/"><link>https://mikanani.me/Home/Episode/1111111111111111111111111111111111111111</link><contentLength>524288000</contentLength><pubDate>2026-07-05T22:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="524288000" url="https://mikanani.me/Download/20260705/1111111111111111111111111111111111111111.torrent" />
</item>
<item>
<guid isPermaLink="false">[LoliHouse] 虽然我是不完美恶女 ～雏宫蝶鼠替换传～ - 01 [WebRip 1920x1080 HEVC-10bit AAC][简繁内封字幕]（检索用：恶女不才，请多关照）</guid>
<link>https://mikanani.me/Home/Episode/2222222222222222222222222222222222222222</link>
<title>[LoliHouse] 虽然我是不完美恶女 ～雏宫蝶鼠替换传～ - 01 [WebRip 1920x1080 HEVC-10bit AAC][简繁内封字幕]（检索用：恶女不才，请多关照）</title>
<description>[LoliHouse] 虽然我是不完美恶女 - 01 [700 MB]</description>
<torrent xmlns="https://mikanani.me/0.1/"><link>https://mikanani.me/Home/Episode/2222222222222222222222222222222222222222</link><contentLength>734003200</contentLength><pubDate>2026-07-05T23:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="734003200" url="https://mikanani.me/Download/20260705/2222222222222222222222222222222222222222.torrent" />
</item>
<item>
<guid isPermaLink="false">[Nix-Raws] ふつつかな悪女ではございますが S01E01 (Baha 1920x1080 AVC AAC MP4)</guid>
<link>https://mikanani.me/Home/Episode/3333333333333333333333333333333333333333</link>
<title>[Nix-Raws] ふつつかな悪女ではございますが S01E01 (Baha 1920x1080 AVC AAC MP4)</title>
<description>[Nix-Raws] ふつつかな悪女ではございますが S01E01 [600 MB]</description>
<torrent xmlns="https://mikanani.me/0.1/"><link>https://mikanani.me/Home/Episode/3333333333333333333333333333333333333333</link><contentLength>629145600</contentLength><pubDate>2026-07-06T00:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="629145600" url="https://mikanani.me/Download/20260706/3333333333333333333333333333333333333333.torrent" />
</item>
<item>
<guid isPermaLink="false">[ANi] 恶女不才，请多关照 - 02 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]</guid>
<link>https://mikanani.me/Home/Episode/4444444444444444444444444444444444444444</link>
<title>[ANi] 恶女不才，请多关照 - 02 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]</title>
<description>[ANi] 恶女不才，请多关照 - 02 [620 MB]</description>
<torrent xmlns="https://mikanani.me/0.1/"><link>https://mikanani.me/Home/Episode/4444444444444444444444444444444444444444</link><contentLength>650117120</contentLength><pubDate>2026-07-12T22:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="650117120" url="https://mikanani.me/Download/20260712/4444444444444444444444444444444444444444.torrent" />
</item>
</channel>
</rss>
```

In `test/data/rss/rss_media_source_test.dart`, replace the import/mock/setup header (lines 1-36) with:

```dart
import 'dart:io';

import 'package:animeko_flutter/data/rss/mikan_subject_locator.dart';
import 'package:animeko_flutter/data/rss/mikan_subject_mapping_repository.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockRqbitEngine extends Mock implements RqbitEngine {}

class MockMikanSubjectLocator extends Mock implements MikanSubjectLocator {}

class MockMikanSubjectMappingRepository extends Mock
    implements MikanSubjectMappingRepository {}

Response<String> _xmlResponse(String body) => Response(
  data: body,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

/// The real Bangumi subject / Mikan bangumi ids for
/// 「恶女不才，请多关照 ～雏宫蝶鼠换身传～」 (see the design doc).
const _subjectId = 545008;
const _bangumiId = 4012;
const _nameCn = '恶女不才，请多关照 ～雏宫蝶鼠换身传～';

void main() {
  late MockDio dio;
  late MockRqbitEngine engine;
  late RssMediaSource source;
  late String xmlBody;
  late String bangumiFeedBody;

  setUpAll(() {
    xmlBody = File(
      'test/fixtures/mikan_rss_search_sample.xml',
    ).readAsStringSync();
    bangumiFeedBody = File(
      'test/fixtures/mikan/rss_bangumi_4012.xml',
    ).readAsStringSync();
  });

  setUp(() {
    dio = MockDio();
    engine = MockRqbitEngine();
    source = RssMediaSource(mikanRssSourceConfig, dio, engine);
  });
```

Then append this group at the end of the same file, inside `void main() { ... }`:

```dart
  group('search with a subject mapping', () {
    late MockMikanSubjectLocator locator;
    late MockMikanSubjectMappingRepository mappings;
    late RssMediaSource mappedSource;

    setUp(() {
      locator = MockMikanSubjectLocator();
      mappings = MockMikanSubjectMappingRepository();
      mappedSource = RssMediaSource(
        mikanRssSourceConfig,
        dio,
        engine,
        locator: locator,
        mappingRepository: mappings,
      );
      when(
        () => dio.get<String>(any()),
      ).thenAnswer((_) async => _xmlResponse(bangumiFeedBody));
      when(() => mappings.save(any(), any())).thenAnswer((_) async {});
      when(() => mappings.readJapaneseName(any())).thenAnswer((_) async => null);
    });

    List<String> requestedUrls() =>
        verify(() => dio.get<String>(captureAny())).captured.cast<String>();

    test('config exposes the Mikan subject-search and bangumi-feed templates', () {
      expect(
        mikanRssSourceConfig.subjectSearchUrl,
        'https://mikanani.me/Home/Search?searchstr={keyword}',
      );
      expect(
        mikanRssSourceConfig.bangumiFeedUrl,
        'https://mikanani.me/RSS/Bangumi?bangumiId={bangumiId}',
      );
    });

    test('uses the cached mapping and fetches the per-bangumi feed', () async {
      when(
        () => mappings.lookup(_subjectId),
      ).thenAnswer((_) async => const CachedMikanMapping(_bangumiId));

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls(), [
        'https://mikanani.me/RSS/Bangumi?bangumiId=4012',
      ]);
      verifyNever(
        () => locator.resolveBangumiId(
          subjectId: any(named: 'subjectId'),
          nameCn: any(named: 'nameCn'),
          nameJp: any(named: 'nameJp'),
        ),
      );
      verifyNever(() => mappings.save(any(), any()));
    });

    test('resolves and caches the mapping on a cache miss', () async {
      when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
      when(
        () => mappings.readJapaneseName(_subjectId),
      ).thenAnswer((_) async => 'ふつつかな悪女ではございますが');
      when(
        () => locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
          nameJp: 'ふつつかな悪女ではございますが',
        ),
      ).thenAnswer((_) async => _bangumiId);

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls(), [
        'https://mikanani.me/RSS/Bangumi?bangumiId=4012',
      ]);
      verify(() => mappings.save(_subjectId, _bangumiId)).called(1);
    });

    test('the per-bangumi feed yields every subtitle group for episode 1', () async {
      when(
        () => mappings.lookup(_subjectId),
      ).thenAnswer((_) async => const CachedMikanMapping(_bangumiId));

      final candidates = await mappedSource.search(
        _nameCn,
        subjectId: _subjectId,
      );

      final groups = (candidates.single as RssSeriesCandidate).groups;
      expect(groups.keys, containsAll([1, 2]));
      expect(
        groups[1]!.map((r) => r.parsed.alliance),
        containsAll(['TSDM字幕组', 'LoliHouse', 'Nix-Raws']),
      );
      expect(groups[2]!.single.parsed.alliance, 'ANi');
    });

    test('falls back to keyword search when the locator finds nothing, '
        'and caches that negative result', () async {
      when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
      when(
        () => locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
          nameJp: null,
        ),
      ).thenAnswer((_) async => null);

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls().single, startsWith(
        'https://mikanani.me/RSS/Search?searchstr=',
      ));
      verify(() => mappings.save(_subjectId, null)).called(1);
    });

    test('falls back to keyword search for a cached negative result, '
        'without asking the locator again', () async {
      when(
        () => mappings.lookup(_subjectId),
      ).thenAnswer((_) async => const CachedMikanMapping(null));

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls().single, startsWith(
        'https://mikanani.me/RSS/Search?searchstr=',
      ));
      verifyNever(
        () => locator.resolveBangumiId(
          subjectId: any(named: 'subjectId'),
          nameCn: any(named: 'nameCn'),
          nameJp: any(named: 'nameJp'),
        ),
      );
    });

    test('falls back to keyword search when no subjectId is given', () async {
      await mappedSource.search(_nameCn);

      expect(requestedUrls().single, startsWith(
        'https://mikanani.me/RSS/Search?searchstr=',
      ));
      verifyNever(() => mappings.lookup(any()));
    });

    test('falls back to keyword search when the mapping cache throws', () async {
      when(() => mappings.lookup(_subjectId)).thenThrow(Exception('db closed'));

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls().single, startsWith(
        'https://mikanani.me/RSS/Search?searchstr=',
      ));
    });

    test('a source without a locator keeps using keyword search', () async {
      await source.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls().single, startsWith(
        'https://mikanani.me/RSS/Search?searchstr=',
      ));
    });
  });
```

Also update `test/domain/media/media_registry_test.dart`'s last test (lines 281-288) — `mediaSources` now reads `appDatabaseProvider` (through `mikanSubjectMappingRepositoryProvider`), which must not open a real on-disk database in a unit test:

```dart
  test('mediaSourcesProvider returns the registered sources '
      '(yinghua and dilidili are intentionally disabled -- see '
      'mediaSources doc comment)', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final sources = container.read(mediaSourcesProvider);
    expect(sources.map((s) => s.id), ['anime1', 'xifan', 'mikan']);
  });
```

and add these imports to that file (after the existing `animeko_flutter` imports):

```dart
import 'package:animeko_flutter/data/local_database.dart';
import 'package:drift/native.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/rss/rss_media_source_test.dart`
Expected: FAIL with compile errors like "No named parameter with the name 'locator'" and "The getter 'subjectSearchUrl' isn't defined for the type 'RssSourceConfig'".

- [ ] **Step 3: Write minimal implementation**

In `lib/data/rss/rss_media_source.dart`, add the two imports at the top (after the existing `dio`/`riverpod_annotation` imports):

```dart
import 'mikan_subject_locator.dart';
import 'mikan_subject_mapping_repository.dart';
```

Replace the config class and the Mikan config constant (lines 12-37) with:

```dart
/// Configuration for one instance of the generic RSS BT media source.
///
/// Mirrors upstream Animeko's `rss` factory: [searchUrl] is a template with
/// a `{keyword}` placeholder.
class RssSourceConfig {
  const RssSourceConfig({
    required this.name,
    required this.searchUrl,
    required this.iconUrl,
    this.subjectSearchUrl,
    this.bangumiFeedUrl,
  });

  final String name;
  final String searchUrl;
  final String iconUrl;

  /// Template with a `{keyword}` placeholder for this source's *subject*
  /// (条目) search page -- an HTML page, not a feed. Only Mikan has one; it
  /// is consumed by `MikanSubjectLocator` (see [mikanSubjectLocator]) to
  /// resolve a Bangumi subjectId to this source's own subject id. Null for
  /// sources that only offer keyword search.
  final String? subjectSearchUrl;

  /// Template with a `{bangumiId}` placeholder for this source's complete
  /// per-subject feed. When non-null AND the subject mapping resolves,
  /// [RssMediaSource.search] fetches this instead of [searchUrl] -- a
  /// keyword search only returns releases whose *torrent title* contains
  /// every whitespace-separated part of the keyword, which silently drops
  /// whole subtitle groups (design doc "背景与问题"). Null for sources with
  /// no per-subject feed, whose behavior is then unchanged.
  final String? bangumiFeedUrl;
}

const mikanRssSourceConfig = RssSourceConfig(
  name: 'mikan',
  // mikanani.me is Mikan's official domain. An earlier revision pointed at
  // the `mikan.tangbai.cc` mirror, which turned out to be unreachable from
  // some networks (it never responds, unlike a clean DNS/TLS failure). The
  // official domain uses the exact same `/RSS/Search?searchstr=` endpoint
  // and RSS/torrent XML shape, so this is a drop-in swap.
  searchUrl: 'https://mikanani.me/RSS/Search?searchstr={keyword}',
  subjectSearchUrl: 'https://mikanani.me/Home/Search?searchstr={keyword}',
  bangumiFeedUrl: 'https://mikanani.me/RSS/Bangumi?bangumiId={bangumiId}',
  iconUrl: 'https://mikanani.me/favicon.ico',
);
```

Replace the class header, constructor/fields and `search` (lines 110-136) with:

```dart
class RssMediaSource implements MediaSource {
  RssMediaSource(
    this.config,
    this._dio,
    this._engine, {
    MikanSubjectLocator? locator,
    MikanSubjectMappingRepository? mappingRepository,
  }) : _locator = locator,
       _mappings = mappingRepository;

  final RssSourceConfig config;
  final Dio _dio;
  final RqbitEngine _engine;

  /// Both null for RSS sources that have no per-subject feed (see
  /// [RssSourceConfig.bangumiFeedUrl]) and in tests that only exercise the
  /// keyword-search path.
  final MikanSubjectLocator? _locator;
  final MikanSubjectMappingRepository? _mappings;

  @override
  String get id => config.name;

  @override
  String get displayName => config.name;

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) async {
    final url = await _resolveFeedUrl(title, subjectId);
    final response = await _dio.get<String>(url);
    final items = parseRssFeed(response.data ?? '');
    final groups = groupByEpisode(items);

    return [
      RssSeriesCandidate(sourceId: config.name, title: title, groups: groups),
    ];
  }

  /// The complete per-subject feed when this source has one and the subject
  /// mapping resolves, else today's keyword search. Both paths return the
  /// same RSS shape, so everything downstream is unchanged.
  Future<String> _resolveFeedUrl(String title, int? subjectId) async {
    final bangumiFeedUrl = config.bangumiFeedUrl;
    final locator = _locator;
    final mappings = _mappings;
    if (subjectId == null ||
        bangumiFeedUrl == null ||
        locator == null ||
        mappings == null) {
      return _keywordSearchUrl(title);
    }

    final bangumiId = await _resolveBangumiId(
      subjectId: subjectId,
      nameCn: title,
      locator: locator,
      mappings: mappings,
    );
    if (bangumiId == null) return _keywordSearchUrl(title);
    return bangumiFeedUrl.replaceAll('{bangumiId}', '$bangumiId');
  }

  String _keywordSearchUrl(String title) => config.searchUrl.replaceAll(
    '{keyword}',
    Uri.encodeQueryComponent(title),
  );

  /// Cache first, then the locator (whose result -- including a negative
  /// one -- is written back). Returns null on ANY problem: a mapping is an
  /// optimization, never a precondition, so a broken cache or an unlocatable
  /// subject must degrade to keyword search rather than fail the source
  /// (design doc "错误处理").
  Future<int?> _resolveBangumiId({
    required int subjectId,
    required String nameCn,
    required MikanSubjectLocator locator,
    required MikanSubjectMappingRepository mappings,
  }) async {
    try {
      final cached = await mappings.lookup(subjectId);
      if (cached != null) return cached.bangumiId;

      // Null when the subject was never cached locally, in which case the
      // locator simply skips its Japanese-name keyword candidate.
      final nameJp = await mappings.readJapaneseName(subjectId);
      final resolved = await locator.resolveBangumiId(
        subjectId: subjectId,
        nameCn: nameCn,
        nameJp: nameJp,
      );
      await mappings.save(subjectId, resolved);
      return resolved;
    } catch (_) {
      return null;
    }
  }
```

Finally add the locator provider next to `mikanRssDio` at the end of the file (after line 198):

```dart
/// Resolves Bangumi subject ids to Mikan bangumi ids for
/// [RssMediaSource.search].
///
/// Deliberately built on the same [mikanRssDio] as the feed requests: the
/// 条目 search page and bangumi pages live on the same host and need the
/// same proxy handling and timeout bounds. The `!` is safe by construction
/// -- [mikanRssSourceConfig] always declares a [RssSourceConfig.subjectSearchUrl].
@riverpod
MikanSubjectLocator mikanSubjectLocator(Ref ref) => MikanSubjectLocator(
  ref.watch(mikanRssDioProvider),
  searchUrlTemplate: mikanRssSourceConfig.subjectSearchUrl!,
);
```

In `lib/domain/media/media_registry.dart`, insert this import immediately BEFORE the existing `import '../../data/rss/rss_media_source.dart';` line (keeps the block alphabetically ordered):

```dart
import '../../data/rss/mikan_subject_mapping_repository.dart';
```

(`mikanSubjectLocatorProvider` comes from the already-imported `../../data/rss/rss_media_source.dart`.)

and wire both collaborators into the registered Mikan source (lines 150-154):

```dart
  RssMediaSource(
    mikanRssSourceConfig,
    ref.watch(mikanRssDioProvider),
    ref.watch(rqbitEngineProvider),
    locator: ref.watch(mikanSubjectLocatorProvider),
    mappingRepository: ref.watch(mikanSubjectMappingRepositoryProvider),
  ),
```

- [ ] **Step 4: Run codegen, then run tests to verify they pass**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/data/rss/rss_media_source.g.dart` with `mikanSubjectLocatorProvider`.

Run: `flutter test test/data/rss/rss_media_source_test.dart test/domain/media/media_registry_test.dart`
Expected: PASS — including the 3 pre-existing `RssMediaSource` tests (unchanged keyword path) and the 9 new mapping tests.

- [ ] **Step 5: Commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/data/rss/rss_media_source.dart lib/data/rss/rss_media_source.g.dart lib/domain/media/media_registry.dart test/data/rss/rss_media_source_test.dart test/domain/media/media_registry_test.dart test/fixtures/mikan/rss_bangumi_4012.xml
git commit -m "feat(mikan): fetch the per-bangumi RSS feed to discover all subtitle groups"
```

---

### Task 8: Full verification + manual QA

**Files:**
- Modify: none expected (formatting-only changes are possible).
- Test: the whole suite.

**Interfaces:**
- Consumes: everything from Tasks 1-7.
- Produces: nothing.

- [ ] **Step 1: Regenerate, format and analyze**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: "Succeeded after ..." with no conflict errors — proves the checked-in `*.g.dart` files match their sources.

Run: `dart format lib test`
Expected: reports the number of changed files (ideally 0 at this point).

Run: `flutter analyze`
Expected: zero errors. Pre-existing infos are acceptable; any NEW warning/error introduced by Tasks 1-7 must be fixed here.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: PASS, with the total count up by roughly 50 tests versus the pre-plan baseline (~359).

- [ ] **Step 3: Manual QA on macOS**

Run: `flutter run -d macos`

Then walk this checklist:

- [ ] Search for and open Bangumi subject **545008** 「恶女不才，请多关照 ～雏宫蝶鼠换身传～」 (URL: `https://bgm.tv/subject/545008`).
- [ ] Play **episode 1** from the Mikan (`mikan`) source.
- [ ] Open the **线路** sheet in the player's bottom bar.
- [ ] Expect roughly **6 or more** distinct 字幕组 entries — including `LoliHouse`, `黒ネズミたち` and `ANi` — instead of only `TSDM字幕组`. (`黒ネズミたち` is the display name for Kirara Fantasia releases; that naming quirk is a documented known limitation, not a bug.)
- [ ] Quit the app, relaunch it, and reopen the same subject: episode loading should be noticeably quicker and issue **no** `/Home/Search` or `/Home/Bangumi/` requests (the mapping is now cached in `MikanSubjectMappings`).
- [ ] Open a subject that is **not** on Mikan at all: the episode list must still load from the other sources with no error dialog and no hang (the locator returns null, and the Mikan source falls back to keyword search).
- [ ] Set an HTTP proxy in Settings, then repeat the first step: the 条目-search/bangumi-page requests must go through the proxy exactly like the feed requests do (they share `mikanRssDio`).

- [ ] **Step 4: Confirm the end state**

Run: `flutter analyze && flutter test`
Expected: both clean. Record any manual-QA deviation (e.g. fewer subtitle groups than expected) as a follow-up note rather than silently widening this plan's scope.

- [ ] **Step 5: Commit**

Only if `dart format` or an analyze fix changed files in Step 1:

```bash
git add -A
git commit -m "style: format Mikan subgroup-discovery sources"
```

If nothing changed, there is nothing to commit — the plan ends after Task 7's commit.

