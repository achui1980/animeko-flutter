# Xifan Anime MediaSource Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 稀饭动漫 (Xifan Anime) as a second video-playback data source alongside the existing anime1.me, behind a shared `MediaSource` abstraction, with results from both sources auto-merged and displayed together on the subject detail page.

**Architecture:** A new `lib/domain/media/` layer defines `MediaSource`/`MediaCandidate`/`MediaEpisode`/`MediaPlaybackSource` abstractions. The existing anime1.me data classes (`Anime1Category`/`Anime1Episode`/`Anime1PlaybackSource`) are given a `sourceId` getter so they satisfy these abstractions with no other changes to their logic. A new `lib/data/xifan/` package (`XifanApi`, `XifanBangumi`/`XifanEpisode`/`XifanPlaybackSource`) implements the same abstractions for 稀饭动漫, using plain HTTP + HTML/regex parsing (no WebView/CEF -- confirmed via live-site investigation, see the design doc). `SubjectEpisodesController` is rewritten to query all registered sources concurrently via `Future.wait`, silently ignore any source that errors or finds no match, and merge the successful results into one list. The shared title-matching algorithm moves into `lib/domain/media/title_matcher.dart` so both sources use the exact same logic.

**Tech Stack:** Riverpod 3.3.1 codegen (`@riverpod`), `dio` + `package:html` for HTML/HTTP scraping (matching anime1.me's existing approach), go_router 17.5.0 (`extra:` for passing the resolved episode object into the play route, since `MediaEpisode` isn't a URL-serializable string), mocktail for tests.

**Design doc:** `docs/superpowers/specs/2026-09-01-xifan-media-source-design.md`

**Global constraints (apply to every task):**
- `flutter analyze` must stay at the 3 existing lint categories (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`) -- new individual issues within these categories are expected (e.g. from a new test file's direct `riverpod` import) and fine; a **new category** is not.
- `flutter test` must show 0 failures at the end of every task.
- Flutter SDK is not on the default PATH. Every command below assumes:
  ```bash
  export PATH="/Users/portz/soft/dart-sdk/flutter/bin:/Users/portz/soft/dart-sdk/flutter/bin/cache/dart-sdk/bin:$PATH"
  ```
- After any `dart run build_runner build`/`flutter test`/`flutter analyze` run, check `git status` for unrelated regenerated macOS build artifacts (`macos/Flutter/GeneratedPluginRegistrant.swift`, `macos/Podfile.lock`, `macos/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`) and `git checkout --` them before committing -- they are pre-existing, unrelated dirt, never part of any task's commit.
- **Deviation from the design doc, resolved here:** the design doc's data-flow example showed `EpisodePlayController` calling `source.resolvePlayback(episode)` but explicitly left open *how* it finds which `MediaSource` owns a given episode. This plan resolves it: the detail screen navigates to the play route via go_router's `extra:` parameter carrying the actual `MergedEpisode` object (not a URL query string), and `EpisodePlayController`'s family parameter becomes that `MergedEpisode` instead of a `String episodePageUrl`. This is a deliberate, necessary implementation choice (a `MediaEpisode` is not, in general, a plain URL string), not a contradiction of anything the design doc locked down -- and it is why `PlayerScreen`'s constructor and `lib/app/router.dart`'s play route both need small changes in Task 11, despite the design doc's data-flow section saying "PlayerScreen needs ZERO changes" (written before this specific mechanism was worked out).

---
### Task 1: `MediaSource` abstraction

**Files:**
- Create: `lib/domain/media/media_source.dart`
- Test: `test/domain/media/media_source_test.dart`

This task only defines abstract contracts with no logic of their own, so there is nothing meaningful to drive with a failing-test-first cycle. Instead, write one small compile-time-sanity test using a throwaway fake implementation, then write the abstractions to satisfy it.

- [ ] **Step 1: Write the sanity test**

```dart
// test/domain/media/media_source_test.dart
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCandidate implements MediaCandidate {
  const _FakeCandidate(this.title);
  @override
  final String title;
  @override
  String get sourceId => 'fake';
}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.title);
  @override
  final String title;
  @override
  String get sourceId => 'fake';
}

class _FakePlaybackSource implements MediaPlaybackSource {
  const _FakePlaybackSource();
  @override
  String get url => 'https://example.com/video.mp4';
  @override
  Map<String, String> get headers => const {};
}

class _FakeSource implements MediaSource {
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake Source';
  @override
  Future<List<MediaCandidate>> search(String title) async =>
      [const _FakeCandidate('Fake Anime')];
  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async =>
      [const _FakeEpisode('Episode 1')];
  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) async =>
      const _FakePlaybackSource();
}

void main() {
  test('a MediaSource implementation can search, list episodes, and resolve playback', () async {
    final source = _FakeSource();

    final candidates = await source.search('Fake Anime');
    expect(candidates.single.title, 'Fake Anime');
    expect(candidates.single.sourceId, 'fake');

    final episodes = await source.listEpisodes(candidates.single);
    expect(episodes.single.title, 'Episode 1');

    final playback = await source.resolvePlayback(episodes.single);
    expect(playback.url, 'https://example.com/video.mp4');
    expect(playback.headers, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/media/media_source_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/domain/media/media_source.dart'." (or a similar "not found" compile error -- the file doesn't exist yet)

- [ ] **Step 3: Write the abstractions**

```dart
// lib/domain/media/media_source.dart

/// A single search result from one [MediaSource] -- one candidate anime
/// series/subject that may or may not be the one the caller is looking
/// for. [MediaSource.search] returns these; the caller (see
/// `lib/domain/media/title_matcher.dart`) picks the best match by
/// [title], then passes it to [MediaSource.listEpisodes].
abstract class MediaCandidate {
  /// Which [MediaSource.id] this candidate came from.
  String get sourceId;

  /// Display title, in whatever language/form the source itself uses.
  /// Used for title-matching (see `title_matcher.dart`) -- deliberately
  /// not required to be normalized/translated by the source itself.
  String get title;
}

/// A single playable episode belonging to one [MediaCandidate].
/// [MediaSource.listEpisodes] returns these; the caller passes one to
/// [MediaSource.resolvePlayback] to get an actual playback URL.
abstract class MediaEpisode {
  /// Which [MediaSource.id] this episode came from.
  String get sourceId;

  /// Display title, e.g. an episode number/name.
  String get title;
}

/// A resolved, playable video source for one [MediaEpisode].
abstract class MediaPlaybackSource {
  /// Direct video URL (mp4/m3u8/etc).
  String get url;

  /// HTTP headers that must be sent when actually requesting [url] (e.g.
  /// via media_kit's `Media(url, httpHeaders: ...)`). Empty when the
  /// source's CDN needs none.
  Map<String, String> get headers;
}

/// A single video-playback data source (e.g. anime1.me, 稀饭动漫). Each
/// concrete source implements this with its own [MediaCandidate]/
/// [MediaEpisode]/[MediaPlaybackSource] subtypes and internally downcasts
/// the abstract parameters it receives back to its own concrete types --
/// see `lib/domain/media/media_registry.dart`'s adapter classes.
abstract class MediaSource {
  /// Stable identifier, e.g. `'anime1'`/`'xifan'`. Used to route a
  /// [MediaEpisode] back to the [MediaSource] that produced it (see
  /// `EpisodePlayController`) and as the merged-episode-list source badge
  /// (see `SubjectDetailScreen`).
  String get id;

  /// Human-readable name shown in the UI, e.g. `'anime1.me'`/`'稀饭动漫'`.
  String get displayName;

  /// Searches this source for [title], returning every plausible
  /// candidate (not just the best match -- matching is the caller's job,
  /// see `title_matcher.dart`). May throw on network/parse failure; the
  /// caller decides how to handle that (see `SubjectEpisodesController`).
  Future<List<MediaCandidate>> search(String title);

  /// Lists every episode under [candidate] (which must have come from
  /// this same source's [search]).
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate);

  /// Resolves [episode] (which must have come from this same source's
  /// [listEpisodes]) to an actual playable URL.
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/media/media_source_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; `flutter analyze` shows the same 3 pre-existing categories, no new category.

```bash
git add lib/domain/media/media_source.dart test/domain/media/media_source_test.dart
git commit -m "feat: add MediaSource/MediaCandidate/MediaEpisode/MediaPlaybackSource abstractions"
```

---
### Task 2: Anime1 data classes implement the `MediaSource` abstractions

**Files:**
- Modify: `lib/data/anime1/anime1_models.dart`
- Test: `test/data/anime1/anime1_models_test.dart`

Minimal-change adapter approach per the design doc: no other anime1.me logic changes, just add `implements`/`sourceId`.

- [ ] **Step 1: Write the failing test**

Add this new `group` to the end of `test/data/anime1/anime1_models_test.dart` (inside `main()`, after the existing `group('Anime1PlaybackSource.fromApiResponse', ...)` block, before the closing `}`), and add the import at the top:

```dart
import 'package:animeko_flutter/domain/media/media_source.dart';
```

```dart
  group('MediaSource abstractions', () {
    test('Anime1Category implements MediaCandidate with sourceId "anime1"', () {
      const category = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      expect(category, isA<MediaCandidate>());
      expect(category.sourceId, 'anime1');
    });

    test('Anime1Episode implements MediaEpisode with sourceId "anime1"', () {
      const episode = Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1');
      expect(episode, isA<MediaEpisode>());
      expect(episode.sourceId, 'anime1');
    });

    test('Anime1PlaybackSource implements MediaPlaybackSource', () {
      const source = Anime1PlaybackSource(url: 'https://example.com/v.mp4');
      expect(source, isA<MediaPlaybackSource>());
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/anime1/anime1_models_test.dart`
Expected: FAIL -- `Anime1Category`/`Anime1Episode`/`Anime1PlaybackSource` don't have a `sourceId` getter and aren't declared to implement anything yet.

- [ ] **Step 3: Add the `implements` clauses and `sourceId` getters**

In `lib/data/anime1/anime1_models.dart`, add this import at the top:

```dart
import '../../domain/media/media_source.dart';
```

Then change the three class declarations (keep every other line, including all existing doc comments, fields, and the `fromApiResponse` factory, exactly as they are):

```dart
class Anime1Category implements MediaCandidate {
  const Anime1Category({required this.id, required this.title});

  final int id;
  @override
  final String title;

  @override
  String get sourceId => 'anime1';
}
```

```dart
class Anime1Episode implements MediaEpisode {
  const Anime1Episode({required this.title, required this.pageUrl});

  /// Raw article title, e.g. `葬送的芙莉蓮 [12]`. anime1.me embeds the
  /// episode number in free-text form inside the title -- there is no
  /// separate structured episode-number field to parse it out of.
  @override
  final String title;

  /// Absolute URL of the article page. anime1.me has no separate episode
  /// ID concept, so this URL itself is the identifier passed to
  /// [Anime1Api.resolvePlaybackUrl].
  final String pageUrl;

  @override
  String get sourceId => 'anime1';
}
```

```dart
class Anime1PlaybackSource implements MediaPlaybackSource {
  const Anime1PlaybackSource({required this.url, this.headers = const {}});

  /// Direct mp4/m3u8 URL.
  @override
  final String url;

  /// HTTP headers that must be sent when actually requesting [url] (e.g.
  /// via media_kit's `Media(url, httpHeaders: ...)`).
  ///
  /// Verified against the live site (2026-09-01): the CDN host serving
  /// [url] rejects the request with `403 Forbidden` unless the exact
  /// `Set-Cookie` values returned by the `POST https://v.anime1.me/api`
  /// call (three short-lived, path-scoped access-token cookies named
  /// `e`/`p`/`h`) are echoed back as a `Cookie` header on the video
  /// request -- the `Referer` header alone is not sufficient. See
  /// `Anime1Api.resolvePlaybackUrl`, which builds this map from that
  /// response's headers.
  @override
  final Map<String, String> headers;

  // ... factory Anime1PlaybackSource.fromApiResponse(...) is unchanged ...
}
```

(Only the class signature lines and the three field declarations above gain `@override`/the `sourceId` getter and `implements` clause -- the doc comments on `id`/`headers`, and the entire `fromApiResponse` factory body, stay exactly as they already are in the file.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/anime1/anime1_models_test.dart`
Expected: PASS (all tests, including the 3 new ones)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged (3 categories, no new).

```bash
git add lib/data/anime1/anime1_models.dart test/data/anime1/anime1_models_test.dart
git commit -m "feat: make Anime1Category/Episode/PlaybackSource implement the MediaSource abstractions"
```

---
### Task 3: Extract the shared title-matching module

**Files:**
- Create: `lib/domain/media/title_matcher.dart`
- Modify: `lib/domain/play/subject_episodes_controller.dart` (remove the matching logic, call the extracted version instead)
- Create: `test/domain/media/title_matcher_test.dart` (migrated matching tests)
- Modify: `test/domain/play/subject_episodes_controller_test.dart` (remove the migrated `matchBestCategory` group)

This is a pure move-and-rename refactor (`matchBestCategory` -> generic `matchBest<T extends MediaCandidate>`), not new logic -- every test case's *behavior* is identical, only the types change (`Anime1Category` candidates now flow through the generic function via its `MediaCandidate` interface from Task 2). `SubjectEpisodesController` itself is only touched minimally here (its full rewrite to multi-source is Task 10) -- it still returns `Future<List<Anime1Episode>>` and still throws `Anime1NotFoundException` after this task; only the *matching call* changes from `matchBestCategory` to `matchBest`.

- [ ] **Step 1: Write the new test file**

Create `test/domain/media/title_matcher_test.dart` with the exact same 9 test cases currently in `test/domain/play/subject_episodes_controller_test.dart`'s `matchBestCategory` group, renamed to call `matchBest` and importing `Anime1Category` (which now implements `MediaCandidate` per Task 2) as the concrete candidate type:

```dart
// test/domain/media/title_matcher_test.dart
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/media/title_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchBest', () {
    test('returns null for an empty candidate list', () {
      expect(matchBest(<Anime1Category>[], '葬送的芙莉蓮'), isNull);
    });

    test('returns the exact title match', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const other = Anime1Category(id: 2, title: '無關的番劇');
      final result = matchBest([other, target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('matches case-insensitively and ignores whitespace', () {
      const target = Anime1Category(id: 1, title: 'Attack On Titan');
      final result = matchBest([target], 'attack  on titan');
      expect(result, target);
    });

    test('normalizes full-width Latin characters to half-width', () {
      const target = Anime1Category(id: 1, title: 'ＦＲＩＥＲＥＮ');
      final result = matchBest([target], 'FRIEREN');
      expect(result, target);
    });

    test('matches when one title contains the other', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮 第二季');
      final result = matchBest([target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('returns null when no candidate is similar enough', () {
      const unrelated = Anime1Category(id: 1, title: '完全無關的標題');
      final result = matchBest([unrelated], '葬送的芙莉蓮');
      expect(result, isNull);
    });

    test('picks the highest-scoring candidate among several', () {
      const exact = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const partial = Anime1Category(id: 2, title: '葬送的芙莉蓮 特別篇');
      final result = matchBest([partial, exact], '葬送的芙莉蓮');
      expect(result, exact);
    });

    test(
      'matches a Simplified-Chinese subject name against anime1.me\'s '
      'Traditional-Chinese title even when word order differs and the '
      'subject name carries extra subtitle text',
      () {
        const target = Anime1Category(id: 1948, title: '我是不才惡女');
        final result = matchBest(
          [target],
          '恶女不才，请多关照 〇雏宫蝶鼠换身传〇',
        );
        expect(result, target);
      },
    );

    test(
      'matches a reordered core title separated from an unrelated, '
      'much longer subtitle by a delimiter',
      () {
        const target = Anime1Category(id: 1, title: '太喜泼');
        final result = matchBest(
          [target],
          '泼喜太，某个不相关的很长副标题内容',
        );
        expect(result, target);
      },
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/media/title_matcher_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/domain/media/title_matcher.dart'."

- [ ] **Step 3: Create `title_matcher.dart` by moving the matching logic out of `subject_episodes_controller.dart`**

```dart
// lib/domain/media/title_matcher.dart
import 'media_source.dart';

/// Minimum similarity score (see [_similarity]) for a candidate to be
/// considered a match. This is an initial guess, not tuned against real
/// site data -- adjust during manual verification if it produces too
/// many false positives/negatives (see design doc "测试策略").
const matchThreshold = 0.6;

/// Picks the best-matching candidate for [subjectName] out of
/// [candidates], or `null` if none scores at or above [matchThreshold].
/// Pure function, directly testable with no mocking. Deliberately uses
/// title-string similarity only, with no year/season filtering (see
/// design doc "标题匹配策略"). Generic over any concrete [MediaCandidate]
/// subtype so both anime1.me and 稀饭动漫 (and any future source) share
/// this exact same logic.
T? matchBest<T extends MediaCandidate>(
  List<T> candidates,
  String subjectName,
) {
  final normalizedTarget = _normalize(subjectName);
  T? best;
  var bestScore = 0.0;
  for (final candidate in candidates) {
    final score = _bestSimilarity(
      _normalize(candidate.title),
      normalizedTarget,
    );
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return bestScore >= matchThreshold ? best : null;
}

/// A small, deliberately non-exhaustive map of common Simplified Chinese
/// characters to their Traditional Chinese counterpart. Bangumi titles
/// are often Simplified while some sources' titles (e.g. anime1.me) are
/// Traditional (see e.g. "恶女不才..." vs. "我是不才惡女"); without this,
/// such pairs never share any characters and always score 0.
///
/// This is *not* a full canonical Simplified/Traditional conversion
/// table (those run into the thousands of entries and hand-transcribing
/// one from memory risks silent inaccuracies) -- it only covers a
/// modest set of very common characters likely to appear in anime
/// titles. Characters not in this map (in either direction) pass
/// through unchanged, so this can only ever help a match, never hurt
/// one that already worked.
const _simplifiedToTraditional = <String, String>{
  '国': '國', '这': '這', '时': '時', '后': '後', '会': '會', '经': '經',
  '还': '還', '没': '沒', '么': '麼', '着': '著', '许': '許', '义': '義',
  '动': '動', '汉': '漢', '机': '機', '开': '開', '关': '關', '门': '門',
  '习': '習', '书': '書', '学': '學', '觉': '覺', '爱': '愛', '亲': '親',
  '见': '見', '闻': '聞', '语': '語', '话': '話', '气': '氣', '风': '風',
  '飞': '飛', '坏': '壞', '怀': '懷', '恶': '惡', '说': '說', '读': '讀',
  '写': '寫', '让': '讓', '应': '應', '该': '該', '战': '戰', '师': '師',
  '问': '問', '乐': '樂', '过': '過', '连': '連', '选': '選', '择': '擇',
  '现': '現', '实': '實', '处': '處', '备': '備', '决': '決', '剧': '劇',
  '观': '觀', '欢': '歡', '声': '聲', '对': '對', '导': '導', '带': '帶',
  '张': '張', '强': '強', '无': '無', '来': '來', '样': '樣', '点': '點',
  '满': '滿', '灭': '滅', '灵': '靈', '产': '產', '电': '電', '种': '種',
  '类': '類', '纪': '紀', '纯': '純', '组': '組', '织': '織', '终': '終',
  '统': '統', '维': '維', '综': '綜', '绿': '綠', '网': '網', '职': '職',
  '联': '聯', '胜': '勝', '舰': '艦', '苏': '蘇', '获': '獲', '营': '營',
  '蓝': '藍', '虽': '雖', '虚': '虛', '补': '補', '装': '裝', '计': '計',
  '认': '認', '议': '議', '记': '記', '讲': '講', '论': '論', '设': '設',
  '证': '證', '评': '評', '识': '識', '诉': '訴', '词': '詞', '诚': '誠',
  '误': '誤', '请': '請', '课': '課', '谁': '誰', '调': '調', '谈': '談',
  '谋': '謀', '谎': '謊', '谢': '謝', '谣': '謠', '购': '購', '贵': '貴',
  '贸': '貿', '费': '費', '资': '資', '质': '質', '财': '財', '败': '敗',
  '车': '車', '轻': '輕', '转': '轉', '输': '輸', '达': '達', '运': '運',
  '远': '遠', '进': '進', '适': '適', '边': '邊', '钢': '鋼', '铁': '鐵',
  '银': '銀', '键': '鍵', '锁': '鎖', '长': '長', '间': '間', '闷': '悶',
  '阳': '陽', '阴': '陰', '际': '際', '险': '險', '陆': '陸', '飘': '飄',
};

/// Lowercases, strips whitespace, converts full-width Latin
/// letters/digits/punctuation (U+FF01-FF5E) to their half-width
/// equivalents (so e.g. "ＡＴＴＡＣＫ" and "Attack" compare equal), and
/// maps known Simplified Chinese characters to Traditional Chinese via
/// [_simplifiedToTraditional].
String _normalize(String input) {
  final withoutWhitespace = input
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAllMapped(
        RegExp(r'[\uFF01-\uFF5E]'),
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0),
      );
  final buffer = StringBuffer();
  for (final char in withoutWhitespace.split('')) {
    buffer.write(_simplifiedToTraditional[char] ?? char);
  }
  return buffer.toString();
}

/// Punctuation/decoration commonly used to separate a title's "core" name
/// from extra subtitle/season text (e.g. "OOO：Alt Title", "OOO 〇Sub〇").
/// Splitting on these lets a short core title match against a much
/// longer one even when word order differs and plain containment fails
/// (see [_bestSimilarity]).
final RegExp _segmentDelimiters = RegExp(
  '[，,、:：\\-\u2014~\uFF5E\u301C()\uFF08\uFF09\u3010\u3011\u300C\u300D'
  '\u3008\u3009\u3014\u3015\u3007\u25CB\u30FB]+',
);

/// The full [normalized] string plus each non-empty piece produced by
/// splitting on [_segmentDelimiters] -- always includes the whole string
/// so callers never lose the plain whole-title comparison.
Set<String> _segments(String normalized) {
  final parts = normalized
      .split(_segmentDelimiters)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  return {normalized, ...parts};
}

/// The highest [_similarity] score across every combination of [a]'s and
/// [b]'s [_segments]. This lets a title's short "core" name match a
/// candidate even when one side carries extra subtitle text that would
/// otherwise dilute a whole-string character-overlap score below
/// [matchThreshold] (see design doc's follow-up note on word-order and
/// subtitle mismatches).
double _bestSimilarity(String a, String b) {
  var best = 0.0;
  for (final segmentA in _segments(a)) {
    for (final segmentB in _segments(b)) {
      final score = _similarity(segmentA, segmentB);
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
double _similarity(String a, String b) {
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

- [ ] **Step 4: Update `subject_episodes_controller.dart` to remove the moved logic and call the extracted `matchBest`**

Replace the entire contents of `lib/domain/play/subject_episodes_controller.dart` with:

```dart
// lib/domain/play/subject_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';
import '../media/title_matcher.dart';

part 'subject_episodes_controller.g.dart';

/// Thrown when no anime1.me category matches the requested subject title
/// with sufficient confidence (see [matchBest]). Not a network/parsing
/// failure -- retrying without changing the title produces the same
/// result, so the UI shows an empty "not found" state instead of a retry
/// button (see `SubjectDetailScreen`).
///
/// NOTE: this is replaced by the source-agnostic `MediaNotFoundException`
/// in Task 10, once this controller queries multiple sources.
class Anime1NotFoundException implements Exception {
  const Anime1NotFoundException();

  @override
  String toString() =>
      'Anime1NotFoundException: no matching anime1.me category found';
}

@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<Anime1Episode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final api = ref.watch(anime1ApiProvider);
    final categories = await api.searchCategories(subjectName);
    final best = matchBest(categories, subjectName);
    if (best == null) {
      throw const Anime1NotFoundException();
    }
    return api.fetchCategoryEpisodes(best.id);
  }
}
```

- [ ] **Step 5: Remove the migrated `matchBestCategory` group from the old test file**

In `test/domain/play/subject_episodes_controller_test.dart`, delete the entire `group('matchBestCategory', () { ... });` block (all 9 tests), leaving only the `group('SubjectEpisodesController', ...)` block and the `_MockAnime1Api` class. The file's imports stay the same (it still needs `Anime1Category`/`Anime1Episode`/`Anime1Api`/`Anime1NotFoundException`/`subjectEpisodesControllerProvider`).

- [ ] **Step 6: Run both affected test files and the full suite, then analyze**

Run: `flutter test test/domain/media/title_matcher_test.dart test/domain/play/subject_episodes_controller_test.dart`
Expected: PASS (9 tests in `title_matcher_test.dart`, 3 tests in `subject_episodes_controller_test.dart`)

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged (3 categories, no new).

- [ ] **Step 7: Commit**

```bash
git add lib/domain/media/title_matcher.dart lib/domain/play/subject_episodes_controller.dart test/domain/media/title_matcher_test.dart test/domain/play/subject_episodes_controller_test.dart
git commit -m "refactor: extract title-matching into a shared, source-agnostic module"
```

---
### Task 4: 稀饭动漫 (Xifan) data models

**Files:**
- Create: `lib/data/xifan/xifan_models.dart`
- Test: `test/data/xifan/xifan_models_test.dart`

Mirrors `lib/data/anime1/anime1_models.dart`'s shape exactly (see Task 2), implementing the same abstractions from Task 1.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/xifan/xifan_models_test.dart
import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XifanBangumi', () {
    test('implements MediaCandidate with sourceId "xifan"', () {
      const bangumi = XifanBangumi(id: 1001, title: '鬼灭之刃');
      expect(bangumi, isA<MediaCandidate>());
      expect(bangumi.sourceId, 'xifan');
      expect(bangumi.title, '鬼灭之刃');
    });
  });

  group('XifanEpisode', () {
    test('implements MediaEpisode with sourceId "xifan"', () {
      const episode = XifanEpisode(
        title: '第01集',
        watchPageUrl: 'https://dm1.xfdm.pro/watch/1001/1/1.html',
      );
      expect(episode, isA<MediaEpisode>());
      expect(episode.sourceId, 'xifan');
      expect(episode.watchPageUrl, 'https://dm1.xfdm.pro/watch/1001/1/1.html');
    });
  });

  group('XifanPlaybackSource', () {
    test('implements MediaPlaybackSource, defaulting headers to empty', () {
      const source = XifanPlaybackSource(url: 'https://apn.moedot.net/d/wo/1/a.mp4');
      expect(source, isA<MediaPlaybackSource>());
      expect(source.url, 'https://apn.moedot.net/d/wo/1/a.mp4');
      expect(source.headers, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/xifan/xifan_models_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/data/xifan/xifan_models.dart'."

- [ ] **Step 3: Write the models**

```dart
// lib/data/xifan/xifan_models.dart
import '../../domain/media/media_source.dart';

/// A search-result "bangumi" (anime series) page on 稀饭动漫.
/// `id` is the numeric ID used in `/bangumi/<id>.html`.
class XifanBangumi implements MediaCandidate {
  const XifanBangumi({required this.id, required this.title});

  final int id;
  @override
  final String title;

  @override
  String get sourceId => 'xifan';
}

/// A single episode: one entry in a bangumi's episode list.
class XifanEpisode implements MediaEpisode {
  const XifanEpisode({required this.title, required this.watchPageUrl});

  /// Episode label, e.g. `第01集`.
  @override
  final String title;

  /// Absolute URL of the watch page
  /// (`/watch/<bangumiId>/<line>/<episode>.html`), passed to
  /// [XifanApi.resolvePlaybackUrl].
  final String watchPageUrl;

  @override
  String get sourceId => 'xifan';
}

/// A resolved, playable video source for one episode. 稀饭动漫's video CDN
/// (`apn.moedot.net` -> `hydownload.pan.wo.cn`) is fully unauthenticated
/// and needs zero headers -- verified live (2026-09-01) via a plain,
/// header-less range request that returned `206 Partial Content` with
/// real MP4 bytes.
class XifanPlaybackSource implements MediaPlaybackSource {
  const XifanPlaybackSource({required this.url, this.headers = const {}});

  @override
  final String url;
  @override
  final Map<String, String> headers;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/xifan/xifan_models_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged.

```bash
git add lib/data/xifan/xifan_models.dart test/data/xifan/xifan_models_test.dart
git commit -m "feat: add XifanBangumi/XifanEpisode/XifanPlaybackSource models"
```

---
### Task 5: `XifanApi.search`

**Files:**
- Create: `lib/data/xifan/xifan_api.dart`
- Test: `test/data/xifan/xifan_api_test.dart`

Search goes through `dm1.xfdm.pro/search.html?wd=<title>` (static HTML, zero CAPTCHA -- **not** `anime.xifanacg.com/search/wd/<title>.html`, which IS CAPTCHA-gated and must never be used; `dm1.xfdm.pro` is a confirmed mirror domain sharing the same numeric bangumi IDs, verified live 2026-09-01).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/xifan/xifan_api_test.dart
import 'package:animeko_flutter/data/xifan/xifan_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late XifanApi api;

  setUp(() {
    dio = MockDio();
    api = XifanApi(dio);
  });

  Response<String> htmlResponse(String body) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );
  }

  group('search', () {
    // Real dm1.xfdm.pro/anime.xifanacg.com search-result markup (captured
    // live, 2026-09-01): each result's title lives in a `.thumb-txt`
    // element and its detail-page link lives in a separate `.thumb-menu
    // > a` element, in matching order -- NOT nested inside one common
    // container (unverified assumption: index-pairing is used here
    // because no single enclosing element was confirmed live; adjust if
    // this proves wrong once manually re-verified against the real
    // site).
    const searchResultsHtml = '''
<html><body>
  <div class="thumb-content"><div class="thumb-txt cor4 hide">鬼灭之刃</div></div>
  <div class="thumb-menu"><a target="_self" href="/bangumi/1001.html" class="button cr3">播放正片</a></div>
  <div class="thumb-content"><div class="thumb-txt cor4 hide">鬼灭之刃 无限城篇</div></div>
  <div class="thumb-menu"><a target="_self" href="/bangumi/1050.html" class="button cr3">播放正片</a></div>
</body></html>
''';

    test('sends the title as the "wd" query param to dm1.xfdm.pro', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      await api.search('鬼灭之刃');

      verify(
        () => dio.get<String>(
          'https://dm1.xfdm.pro/search.html',
          queryParameters: {'wd': '鬼灭之刃'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('pairs each .thumb-txt title with its matching .thumb-menu > a link', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      final results = await api.search('鬼灭之刃');

      expect(results, hasLength(2));
      expect(results[0].id, 1001);
      expect(results[0].title, '鬼灭之刃');
      expect(results[1].id, 1050);
      expect(results[1].title, '鬼灭之刃 无限城篇');
    });

    test('returns an empty list when there are no results', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no results</body></html>'));

      final results = await api.search('nonexistent');

      expect(results, isEmpty);
    });

    test('skips a link whose href has no numeric bangumi ID', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('''
<html><body>
  <div class="thumb-content"><div class="thumb-txt cor4 hide">无效结果</div></div>
  <div class="thumb-menu"><a href="/some-other-page.html">无效</a></div>
</body></html>
'''));

      final results = await api.search('anything');

      expect(results, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/data/xifan/xifan_api.dart'."

- [ ] **Step 3: Write `XifanApi.search`**

```dart
// lib/data/xifan/xifan_api.dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'xifan_models.dart';

/// Direct HTML-scraping client for 稀饭动漫. There is no official API or
/// documentation -- every parsing rule here is a best-effort assumption
/// based on live-site investigation (2026-09-01) and needs re-verification
/// before this is trusted in production (see design doc's "测试策略"
/// section).
class XifanApi {
  XifanApi(this._dio);
  final Dio _dio;

  static const _searchBaseUrl = 'https://dm1.xfdm.pro';

  /// GET https://dm1.xfdm.pro/search.html?wd=`<title>`
  ///
  /// **Do not** use `anime.xifanacg.com/search/wd/<title>.html` -- that
  /// path is CAPTCHA-gated (verified live 2026-09-01, via a real browser
  /// render: it shows a "请输入验证码" modal with no underlying search-data
  /// API call at all). `dm1.xfdm.pro` is a confirmed mirror domain that
  /// serves the same numeric bangumi IDs via a different, un-gated
  /// search path.
  ///
  /// NOTE (unverified): assumes each result's title (`.thumb-txt`) and
  /// its detail-page link (`.thumb-menu > a`) appear in matching order
  /// across the whole page, rather than nested inside one shared
  /// container -- no single enclosing element for one result was
  /// confirmed live. If this proves wrong, re-scope both selectors to a
  /// shared parent instead of pairing by index.
  Future<List<XifanBangumi>> search(String title) async {
    final response = await _dio.get<String>(
      '$_searchBaseUrl/search.html',
      queryParameters: {'wd': title},
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final titles = document
        .querySelectorAll('.thumb-txt')
        .map((e) => e.text.trim())
        .toList();
    final links = document
        .querySelectorAll('.thumb-menu > a')
        .map((e) => e.attributes['href'])
        .toList();

    final idPattern = RegExp(r'/bangumi/(\d+)\.html');
    final seenIds = <int>{};
    final results = <XifanBangumi>[];
    for (var i = 0; i < titles.length && i < links.length; i++) {
      final href = links[i];
      if (href == null) continue;
      final match = idPattern.firstMatch(href);
      if (match == null) continue;
      final id = int.parse(match.group(1)!);
      if (!seenIds.add(id)) continue;
      if (titles[i].isEmpty) continue;
      results.add(XifanBangumi(id: id, title: titles[i]));
    }
    return results;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged.

```bash
git add lib/data/xifan/xifan_api.dart test/data/xifan/xifan_api_test.dart
git commit -m "feat: add XifanApi.search via dm1.xfdm.pro's un-gated search endpoint"
```

---
### Task 6: `XifanApi.listEpisodes`

**Files:**
- Modify: `lib/data/xifan/xifan_api.dart`
- Modify: `test/data/xifan/xifan_api_test.dart`

- [ ] **Step 1: Write the failing test**

Add this `group` to `test/data/xifan/xifan_api_test.dart` (after the `search` group, before the closing `}` of `main()`):

```dart
  group('listEpisodes', () {
    // Real bangumi detail-page markup (captured live, 2026-09-01): the
    // episode list for one "line"/source lives in a
    // `.anthology-list-play > li > a` list. A bangumi page can offer
    // several lines (e.g. "稀饭新番主线-1"/"-2", "稀饭备用-1"), each with
    // its own separate episode list -- this implementation deliberately
    // only reads the *first* `.anthology-list-play` on the page (v1
    // simplification: no line-switching/merging within one source, which
    // is a different axis from the cross-source merge in
    // `SubjectEpisodesController`).
    const detailPageHtml = '''
<html><body>
  <div class="anthology">
    <div class="anthology-tab"><a>稀饭新番主线-1</a><a>稀饭新番主线-2</a></div>
    <div class="anthology-list-box">
      <ul class="anthology-list-play">
        <li><a class="hide this-link" href="/watch/1001/1/1.html">第01集</a></li>
        <li><a class="hide this-link" href="/watch/1001/1/2.html">第02集</a></li>
      </ul>
      <ul class="anthology-list-play">
        <li><a class="hide this-link" href="/watch/1001/2/1.html">第01集</a></li>
        <li><a class="hide this-link" href="/watch/1001/2/2.html">第02集</a></li>
      </ul>
    </div>
  </div>
</body></html>
''';

    test('fetches https://dm1.xfdm.pro/bangumi/<id>.html', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body></body></html>'));

      await api.listEpisodes(1001);

      verify(
        () => dio.get<String>('https://dm1.xfdm.pro/bangumi/1001.html', options: any(named: 'options')),
      ).called(1);
    });

    test('parses episodes from only the first anthology-list-play', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(detailPageHtml));

      final episodes = await api.listEpisodes(1001);

      expect(episodes, hasLength(2));
      expect(episodes[0].title, '第01集');
      expect(episodes[0].watchPageUrl, 'https://dm1.xfdm.pro/watch/1001/1/1.html');
      expect(episodes[1].title, '第02集');
      expect(episodes[1].watchPageUrl, 'https://dm1.xfdm.pro/watch/1001/1/2.html');
    });

    test('returns an empty list when the page has no anthology-list-play', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no episodes</body></html>'));

      final episodes = await api.listEpisodes(9999);

      expect(episodes, isEmpty);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: FAIL -- `listEpisodes` is not a method on `XifanApi` yet.

- [ ] **Step 3: Add `listEpisodes` to `XifanApi`**

Add this method inside the `XifanApi` class (after `search`, before the closing `}`), and add `watchPageUrl`-building constant + import:

```dart
  static const _watchBaseUrl = 'https://dm1.xfdm.pro';

  /// GET https://dm1.xfdm.pro/bangumi/`<bangumiId>`.html
  ///
  /// NOTE (unverified, v1 simplification): only the *first*
  /// `.anthology-list-play` list on the page is read, even when the
  /// bangumi offers multiple lines. See this method's test-file doc
  /// comment for why.
  Future<List<XifanEpisode>> listEpisodes(int bangumiId) async {
    final response = await _dio.get<String>(
      '$_watchBaseUrl/bangumi/$bangumiId.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final list = document.querySelector('.anthology-list-play');
    if (list == null) return const [];

    final episodes = <XifanEpisode>[];
    for (final link in list.querySelectorAll('a')) {
      final href = link.attributes['href'];
      final title = link.text.trim();
      if (href == null || title.isEmpty) continue;
      final url = href.startsWith('http') ? href : '$_watchBaseUrl$href';
      episodes.add(XifanEpisode(title: title, watchPageUrl: url));
    }
    return episodes;
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged.

```bash
git add lib/data/xifan/xifan_api.dart test/data/xifan/xifan_api_test.dart
git commit -m "feat: add XifanApi.listEpisodes"
```

---
### Task 7: `XifanApi.resolvePlaybackUrl` (all 3 `encrypt` cases)

**Files:**
- Modify: `lib/data/xifan/xifan_api.dart`
- Modify: `test/data/xifan/xifan_api_test.dart`

The watch page embeds the video URL as an inline JS variable `var player_aaaa = {...};`, with an `encrypt` field controlling how `url` is encoded (confirmed live 2026-09-01 by reading the real `/static/js/player.js?t=a20260901` source): `'0'`/missing -> use as-is; `'1'` -> percent-decode; `'2'` -> base64-decode then percent-decode. The object contains a *nested* `vod_data` object, so extracting it needs a brace-balance scan, not a naive non-greedy regex (which would stop at `vod_data`'s closing brace instead of the outer one).

- [ ] **Step 1: Write the failing test**

Add this `group` to `test/data/xifan/xifan_api_test.dart` (after `listEpisodes`, before the closing `}` of `main()`):

```dart
  group('resolvePlaybackUrl', () {
    // Real watch-page script content (captured live, 2026-09-01),
    // simplified: `player_aaaa` is a JSON-like object containing a
    // *nested* `vod_data` object -- extraction must brace-balance, not
    // stop at the first `}`.
    String watchPageHtml(String encrypt, String url) => '''
<html><body>
<script>
var player_aaaa={"flag":"play","encrypt":$encrypt,"trysee":0,"points":0,
"link":"/watch/1001/1/1.html","link_next":"/watch/1001/1/2.html","link_pre":"",
"vod_data":{"vod_name":"鬼灭之刃","vod_actor":"","vod_director":"","vod_class":""},
"url":"$url","url_next":"","from":"xfxf1","server":"no","note":"","id":"1001","sid":1,"nid":1}
</script>
</body></html>
''';

    test('encrypt=0 (or "0"): uses the url as-is', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(
        watchPageHtml('0', 'https://apn.moedot.net/d/wo/1/a.mp4'),
      ));

      final source = await api.resolvePlaybackUrl('https://dm1.xfdm.pro/watch/1001/1/1.html');

      expect(source.url, 'https://apn.moedot.net/d/wo/1/a.mp4');
      expect(source.headers, isEmpty);
    });

    test('encrypt=1: percent-decodes the url', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(
        watchPageHtml('1', 'https%3A%2F%2Fexample.com%2Fvideo.mp4'),
      ));

      final source = await api.resolvePlaybackUrl('https://dm1.xfdm.pro/watch/1001/1/1.html');

      expect(source.url, 'https://example.com/video.mp4');
    });

    test('encrypt=2: base64-decodes then percent-decodes the url', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(
        watchPageHtml('2', 'aHR0cHM6Ly9leGFtcGxlLmNvbS92aWRlby5tcDQ='),
      ));

      final source = await api.resolvePlaybackUrl('https://dm1.xfdm.pro/watch/1001/1/1.html');

      expect(source.url, 'https://example.com/video.mp4');
    });

    test('throws FormatException when there is no player_aaaa variable', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no player here</body></html>'));

      expect(
        () => api.resolvePlaybackUrl('https://dm1.xfdm.pro/watch/1001/1/1.html'),
        throwsFormatException,
      );
    });

    test('throws FormatException when player_aaaa has no "url" field', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('''
<html><body><script>
var player_aaaa={"flag":"play","encrypt":0,"vod_data":{"vod_name":"x"}}
</script></body></html>
'''));

      expect(
        () => api.resolvePlaybackUrl('https://dm1.xfdm.pro/watch/1001/1/1.html'),
        throwsFormatException,
      );
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: FAIL -- `resolvePlaybackUrl` is not a method on `XifanApi` yet.

- [ ] **Step 3: Add `resolvePlaybackUrl`, its brace-balancing extractor, and the decrypt helper**

Add `import 'dart:convert';` to the top of `lib/data/xifan/xifan_api.dart`. Add this method inside the `XifanApi` class (after `listEpisodes`), plus the two private top-level helper functions below the class:

```dart
  /// GET the watch page, extract the inline `var player_aaaa = {...};`
  /// object, and decrypt its `url` field per the `encrypt` field's rule
  /// (see this task's description above).
  Future<XifanPlaybackSource> resolvePlaybackUrl(String watchPageUrl) async {
    final response = await _dio.get<String>(
      watchPageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';

    final json = _extractPlayerJson(body);
    if (json == null) {
      throw const FormatException(
        '稀饭动漫 watch page has no player_aaaa script variable',
      );
    }

    final playerData = jsonDecode(json) as Map<String, dynamic>;
    final rawUrl = playerData['url'] as String?;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw const FormatException('稀饭动漫 player_aaaa has no "url" field');
    }

    final encrypt = playerData['encrypt']?.toString() ?? '0';
    return XifanPlaybackSource(url: _decryptUrl(rawUrl, encrypt));
  }
```

```dart
/// Scans forward from `var player_aaaa` for its `{...}` object literal,
/// tracking brace depth so a nested object (e.g. `vod_data`) doesn't
/// cause extraction to stop early. Returns `null` if the marker isn't
/// found or its braces never balance.
String? _extractPlayerJson(String html) {
  const marker = 'var player_aaaa';
  final markerIndex = html.indexOf(marker);
  if (markerIndex == -1) return null;

  final braceStart = html.indexOf('{', markerIndex);
  if (braceStart == -1) return null;

  var depth = 0;
  for (var i = braceStart; i < html.length; i++) {
    final char = html[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return html.substring(braceStart, i + 1);
    }
  }
  return null;
}

/// Mirrors the real `MacPlayer.Init()` decrypt rule read from the live
/// `player.js` source (2026-09-01): `'1'` -> percent-decode (JS
/// `unescape()`); `'2'` -> base64-decode then percent-decode; anything
/// else (including `'0'`/missing) -> use [url] as-is.
String _decryptUrl(String url, String encrypt) {
  switch (encrypt) {
    case '1':
      return Uri.decodeComponent(url);
    case '2':
      return Uri.decodeComponent(latin1.decode(base64Decode(url)));
    default:
      return url;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: PASS (12 tests)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged.

```bash
git add lib/data/xifan/xifan_api.dart test/data/xifan/xifan_api_test.dart
git commit -m "feat: add XifanApi.resolvePlaybackUrl with encrypt=0/1/2 decoding"
```

---
### Task 8: `xifanDio`/`xifanApi` Riverpod providers

**Files:**
- Modify: `lib/data/xifan/xifan_api.dart`
- Modify: `test/data/xifan/xifan_api_test.dart`

Mirrors `anime1Dio`/`anime1Api` in `lib/data/anime1/anime1_api.dart` exactly, including routing through the shared proxy setting via `configureProxy` -- but sets only a `User-Agent` header, not `Referer`/`Cookie` (稀饭动漫's search/detail/watch pages and its video CDN need no special headers at all, unlike anime1.me -- verified live 2026-09-01).

- [ ] **Step 1: Write the failing test**

Add this to the bottom of `test/data/xifan/xifan_api_test.dart` (top-level, after the closing `}` of `group('resolvePlaybackUrl', ...)`, still inside `main()`):

```dart
  test('xifanApiProvider builds a XifanApi backed by xifanDioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(xifanApiProvider);
    expect(api, isA<XifanApi>());
  });

  test('xifanDioProvider sets a non-empty User-Agent header', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(xifanDioProvider);
    expect(dio.options.headers['User-Agent'], isNotEmpty);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: FAIL -- `xifanApiProvider`/`xifanDioProvider` don't exist yet.

- [ ] **Step 3: Add the providers**

Add these imports to the top of `lib/data/xifan/xifan_api.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../settings/proxy_dio_config.dart';
```

Add `part 'xifan_api.g.dart';` right after the imports (before the `class XifanApi` declaration), and add these two provider functions at the bottom of the file (after the `XifanApi` class, before the two private top-level helper functions from Task 7):

```dart
@riverpod
Dio xifanDio(Ref ref) {
  final dio = Dio(BaseOptions(headers: {'User-Agent': 'Mozilla/5.0'}));
  configureProxy(dio, ref);
  return dio;
}

@riverpod
XifanApi xifanApi(Ref ref) => XifanApi(ref.watch(xifanDioProvider));
```

- [ ] **Step 4: Generate the provider code and run the test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/data/xifan/xifan_api.g.dart` with no errors.

Run: `flutter test test/data/xifan/xifan_api_test.dart`
Expected: PASS (14 tests)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged.

```bash
git add lib/data/xifan/xifan_api.dart lib/data/xifan/xifan_api.g.dart test/data/xifan/xifan_api_test.dart
git commit -m "feat: add xifanDio/xifanApi providers, routed through the configured proxy"
```

---
### Task 9: `media_registry.dart` -- adapters + the `mediaSources` provider

**Files:**
- Create: `lib/domain/media/media_registry.dart`
- Test: `test/domain/media/media_registry_test.dart`

Thin adapter classes bridge each concrete API (`Anime1Api`, `XifanApi`) to the shared `MediaSource` interface, downcasting the abstract `MediaCandidate`/`MediaEpisode` parameters they receive back to their own concrete types (per the design doc's minimal-change approach) -- neither `Anime1Api` nor `XifanApi` themselves need to change.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/media/media_registry_test.dart
import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/data/xifan/xifan_api.dart';
import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockAnime1Api extends Mock implements Anime1Api {}

class MockXifanApi extends Mock implements XifanApi {}

void main() {
  group('Anime1MediaSource', () {
    late MockAnime1Api api;
    late Anime1MediaSource source;

    setUp(() {
      api = MockAnime1Api();
      source = Anime1MediaSource(api);
    });

    test('id and displayName', () {
      expect(source.id, 'anime1');
      expect(source.displayName, 'anime1.me');
    });

    test('search delegates to Anime1Api.searchCategories', () async {
      when(() => api.searchCategories('鬼灭之刃')).thenAnswer(
        (_) async => [const Anime1Category(id: 1, title: '鬼灭之刃')],
      );
      final result = await source.search('鬼灭之刃');
      expect(result, hasLength(1));
      expect(result.single.title, '鬼灭之刃');
    });

    test("listEpisodes delegates to fetchCategoryEpisodes using the candidate's id", () async {
      when(() => api.fetchCategoryEpisodes(87)).thenAnswer(
        (_) async => [const Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1')],
      );
      final result = await source.listEpisodes(const Anime1Category(id: 87, title: 'x'));
      expect(result, hasLength(1));
    });

    test("resolvePlayback delegates to resolvePlaybackUrl using the episode's pageUrl", () async {
      when(() => api.resolvePlaybackUrl('https://anime1.me/1')).thenAnswer(
        (_) async => const Anime1PlaybackSource(url: 'https://video.example.com/a.mp4'),
      );
      final result = await source.resolvePlayback(
        const Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1'),
      );
      expect(result.url, 'https://video.example.com/a.mp4');
    });
  });

  group('XifanMediaSource', () {
    late MockXifanApi api;
    late XifanMediaSource source;

    setUp(() {
      api = MockXifanApi();
      source = XifanMediaSource(api);
    });

    test('id and displayName', () {
      expect(source.id, 'xifan');
      expect(source.displayName, '稀饭动漫');
    });

    test('search delegates to XifanApi.search', () async {
      when(() => api.search('鬼灭之刃')).thenAnswer(
        (_) async => [const XifanBangumi(id: 1001, title: '鬼灭之刃')],
      );
      final result = await source.search('鬼灭之刃');
      expect(result, hasLength(1));
    });

    test("listEpisodes delegates to listEpisodes using the candidate's id", () async {
      when(() => api.listEpisodes(1001)).thenAnswer(
        (_) async => [
          const XifanEpisode(
            title: '第01集',
            watchPageUrl: 'https://dm1.xfdm.pro/watch/1001/1/1.html',
          ),
        ],
      );
      final result = await source.listEpisodes(const XifanBangumi(id: 1001, title: 'x'));
      expect(result, hasLength(1));
    });

    test("resolvePlayback delegates to resolvePlaybackUrl using the episode's watchPageUrl", () async {
      when(() => api.resolvePlaybackUrl('https://dm1.xfdm.pro/watch/1001/1/1.html')).thenAnswer(
        (_) async => const XifanPlaybackSource(url: 'https://apn.moedot.net/d/wo/1/a.mp4'),
      );
      final result = await source.resolvePlayback(
        const XifanEpisode(
          title: '第01集',
          watchPageUrl: 'https://dm1.xfdm.pro/watch/1001/1/1.html',
        ),
      );
      expect(result.url, 'https://apn.moedot.net/d/wo/1/a.mp4');
    });
  });

  test('mediaSourcesProvider returns both the anime1 and xifan sources', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sources = container.read(mediaSourcesProvider);
    expect(sources.map((s) => s.id), ['anime1', 'xifan']);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/media/media_registry_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/domain/media/media_registry.dart'."

- [ ] **Step 3: Write `media_registry.dart`**

```dart
// lib/domain/media/media_registry.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';
import '../../data/xifan/xifan_api.dart';
import '../../data/xifan/xifan_models.dart';
import 'media_source.dart';

part 'media_registry.g.dart';

/// Adapts the existing, unchanged [Anime1Api] to the shared [MediaSource]
/// interface. Downcasts the abstract [MediaCandidate]/[MediaEpisode]
/// parameters it receives back to [Anime1Category]/[Anime1Episode] --
/// safe because [SubjectEpisodesController] only ever passes this source
/// candidates/episodes that this same source itself produced.
class Anime1MediaSource implements MediaSource {
  Anime1MediaSource(this._api);
  final Anime1Api _api;

  @override
  String get id => 'anime1';

  @override
  String get displayName => 'anime1.me';

  @override
  Future<List<MediaCandidate>> search(String title) =>
      _api.searchCategories(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.fetchCategoryEpisodes((candidate as Anime1Category).id);

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as Anime1Episode).pageUrl);
}

/// Adapts [XifanApi] to the shared [MediaSource] interface. See
/// [Anime1MediaSource]'s doc comment for the downcast-safety rationale.
class XifanMediaSource implements MediaSource {
  XifanMediaSource(this._api);
  final XifanApi _api;

  @override
  String get id => 'xifan';

  @override
  String get displayName => '稀饭动漫';

  @override
  Future<List<MediaCandidate>> search(String title) => _api.search(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.listEpisodes((candidate as XifanBangumi).id);

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as XifanEpisode).watchPageUrl);
}

/// Every registered [MediaSource], queried concurrently by
/// `SubjectEpisodesController`. Add a new source here (and nowhere else)
/// to make it participate in the merged search/episode-list flow.
@riverpod
List<MediaSource> mediaSources(Ref ref) => [
      Anime1MediaSource(ref.watch(anime1ApiProvider)),
      XifanMediaSource(ref.watch(xifanApiProvider)),
    ];
```

- [ ] **Step 4: Generate the provider code and run the test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/domain/media/media_registry.g.dart` with no errors.

Run: `flutter test test/domain/media/media_registry_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged.

```bash
git add lib/domain/media/media_registry.dart lib/domain/media/media_registry.g.dart test/domain/media/media_registry_test.dart
git commit -m "feat: add Anime1MediaSource/XifanMediaSource adapters and the mediaSources registry"
```

---
### Task 10: Rewrite `SubjectEpisodesController` to query all sources and merge results (+ update `SubjectDetailScreen`)

**Files:**
- Modify: `lib/domain/play/subject_episodes_controller.dart`
- Modify: `test/domain/play/subject_episodes_controller_test.dart`
- Modify: `lib/ui/subject/subject_detail_screen.dart`

Replaces the anime1.me-only `Anime1NotFoundException`/single-source `build()` with the source-agnostic `MediaNotFoundException`/`MergedEpisode` design from the design doc's "数据流" section: every registered source is queried concurrently via `Future.wait`; a source that errors (network/parse failure) or finds no title match is silently skipped (Decision 7); only when *every* source contributes nothing does the controller throw.

`SubjectDetailScreen` is updated in this **same** task, not a later one -- it's the only other file that references `Anime1NotFoundException` (which this task deletes) and `Anime1Episode`'s bare `.title` field (replaced by `MergedEpisode.title`), so leaving it unchanged here would break `flutter analyze`/`flutter test` for the rest of the plan until whatever later task got around to fixing it.

- [ ] **Step 1: Write the failing test**

Replace the entire contents of `test/domain/play/subject_episodes_controller_test.dart` with:

```dart
// test/domain/play/subject_episodes_controller_test.dart
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _FakeCandidate implements MediaCandidate {
  const _FakeCandidate(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class MockMediaSource extends Mock implements MediaSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(const _FakeCandidate('fallback', 'fallback'));
  });

  group('SubjectEpisodesController', () {
    late MockMediaSource sourceA;
    late MockMediaSource sourceB;
    late ProviderContainer container;

    setUp(() {
      sourceA = MockMediaSource();
      sourceB = MockMediaSource();
      when(() => sourceA.id).thenReturn('a');
      when(() => sourceB.id).thenReturn('b');
      container = ProviderContainer(
        overrides: [mediaSourcesProvider.overrideWithValue([sourceA, sourceB])],
        // See Task 7's precedent (Plan 1c) for why riverpod 3.x's default
        // retry must be disabled for tests that expect a thrown
        // exception to propagate immediately from a bare
        // `container.read(provider.future)`.
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    Future<List<MergedEpisode>> read() => container.read(
          subjectEpisodesControllerProvider(subjectId: 1, subjectName: '目标番剧').future,
        );

    test('merges episodes from every source that finds a match', () async {
      when(() => sourceA.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('a', '目标番剧')],
      );
      when(() => sourceA.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('a', 'A的第1集')],
      );
      when(() => sourceB.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('b', '目标番剧')],
      );
      when(() => sourceB.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('b', 'B的第1集')],
      );

      final result = await read();

      expect(result.map((e) => e.sourceId), containsAll(['a', 'b']));
      expect(result.map((e) => e.episode.title), containsAll(['A的第1集', 'B的第1集']));
    });

    test('silently ignores a source that finds no matching candidate', () async {
      when(() => sourceA.search('目标番剧')).thenAnswer((_) async => []);
      when(() => sourceB.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('b', '目标番剧')],
      );
      when(() => sourceB.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('b', 'B的第1集')],
      );

      final result = await read();

      expect(result, hasLength(1));
      expect(result.single.sourceId, 'b');
      verifyNever(() => sourceA.listEpisodes(any()));
    });

    test('silently ignores a source whose search throws', () async {
      when(() => sourceA.search('目标番剧')).thenThrow(Exception('network down'));
      when(() => sourceB.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('b', '目标番剧')],
      );
      when(() => sourceB.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('b', 'B的第1集')],
      );

      final result = await read();

      expect(result, hasLength(1));
      expect(result.single.sourceId, 'b');
    });

    test('throws MediaNotFoundException when every source finds nothing', () async {
      when(() => sourceA.search(any())).thenAnswer((_) async => []);
      when(() => sourceB.search(any())).thenThrow(Exception('also down'));

      await expectLater(read(), throwsA(isA<MediaNotFoundException>()));
    });

    test('queries all sources concurrently, not sequentially', () async {
      final order = <String>[];
      when(() => sourceA.search(any())).thenAnswer((_) async {
        order.add('a-start');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add('a-end');
        return [];
      });
      when(() => sourceB.search(any())).thenAnswer((_) async {
        order.add('b-start');
        return [];
      });

      await expectLater(read(), throwsA(isA<MediaNotFoundException>()));

      // If the sources were queried sequentially, 'b-start' could only
      // appear after 'a-end'. Concurrent querying starts both before
      // either finishes.
      expect(order.indexOf('b-start'), lessThan(order.indexOf('a-end')));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart`
Expected: FAIL -- `MediaNotFoundException`/`MergedEpisode` don't exist yet, and `SubjectEpisodesController.build()` still takes only `subjectName`+`subjectId` against the hardcoded `anime1ApiProvider`, not `mediaSourcesProvider`.

- [ ] **Step 3: Rewrite `subject_episodes_controller.dart`**

Replace the entire file with:

```dart
// lib/domain/play/subject_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../media/media_registry.dart';
import '../media/media_source.dart';
import '../media/title_matcher.dart';

part 'subject_episodes_controller.g.dart';

/// Thrown when *no* registered [MediaSource] has a matching candidate
/// (or every source that had one also failed to list its episodes) for
/// the requested subject title -- see [matchBest]. Not a
/// network/parsing failure by itself (a single source's own failure is
/// swallowed silently, see `_fetchFromSource`); retrying without
/// changing the title produces the same result, so the UI shows an
/// empty "not found" state instead of a retry button (see
/// `SubjectDetailScreen`).
class MediaNotFoundException implements Exception {
  const MediaNotFoundException();

  @override
  String toString() =>
      'MediaNotFoundException: no source has a matching subject';
}

/// One [MediaEpisode] together with which [MediaSource.id] it came from
/// -- used by `SubjectDetailScreen` to show a per-episode source badge,
/// and by `EpisodePlayController` to find the right [MediaSource] to
/// resolve playback with.
class MergedEpisode {
  const MergedEpisode({required this.episode, required this.sourceId});

  final MediaEpisode episode;
  final String sourceId;

  String get title => episode.title;
}

@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final sources = ref.watch(mediaSourcesProvider);

    // Query every source concurrently -- one source's latency/failure
    // must not block or fail the others (Decision 7: silent ignore).
    final results = await Future.wait(
      sources.map((source) => _fetchFromSource(source, subjectName)),
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
  ) async {
    try {
      final candidates = await source.search(subjectName);
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
}
```

- [ ] **Step 4: Update `SubjectDetailScreen`**

`Anime1NotFoundException` no longer exists after Step 3, and `episodeList[index]` is now a `MergedEpisode` (not `Anime1Episode`) -- this step keeps the app compiling and adds the per-episode source badge (Decision 6). Replace the entire contents of `lib/ui/subject/subject_detail_screen.dart` with:

```dart
// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/play/subject_episodes_controller.dart';
import '../common/error_retry_view.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.imageUrl,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectEpisodesControllerProvider(
      subjectId: subjectId,
      subjectName: subjectName,
    );
    final episodes = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: Column(
        children: [
          if (imageUrl != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(imageUrl!, fit: BoxFit.cover),
            ),
          Expanded(
            child: episodes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                if (error is MediaNotFoundException) {
                  return const Center(child: Text('未找到该番剧的播放资源'));
                }
                return ErrorRetryView(
                  message: '加载失败：$error',
                  onRetry: () => ref.invalidate(provider),
                );
              },
              data: (episodeList) => ListView.builder(
                itemCount: episodeList.length,
                itemBuilder: (context, index) {
                  final episode = episodeList[index];
                  return ListTile(
                    title: Text(episode.title),
                    trailing: Chip(label: Text(_sourceLabel(episode.sourceId))),
                    onTap: () => context.push(
                      '/subject/$subjectId/play',
                      extra: episode,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Human-readable label for the merged-episode-list source badge
/// (Decision 6). Falls back to the raw `sourceId` for any future source
/// that forgets to add a case here -- never crashes, just looks slightly
/// less polished.
String _sourceLabel(String sourceId) {
  switch (sourceId) {
    case 'anime1':
      return 'anime1.me';
    case 'xifan':
      return '稀饭动漫';
    default:
      return sourceId;
  }
}
```

Note: `context.push('/subject/$subjectId/play', extra: episode)` passes the `MergedEpisode` object directly rather than a URL query string, matching the router change in Task 11 (they must land in the same task-pair for the app to compile in between -- see Task 11's own note on this).

Actually wait -- since `router.dart`'s play route still reads `state.uri.queryParameters['url']` until Task 11 changes it, and `PlayerScreen` still expects `episodePageUrl: String` until Task 11 changes it, `context.push('/subject/$subjectId/play', extra: episode)` in this step does **not** yet connect to anything -- the route builder simply ignores the `extra` value and keeps reading the (now always-empty) `url` query parameter, and `PlayerScreen` doesn't accept an `episode` parameter yet. This is intentionally a temporarily-inert call, not a compile error: `context.push`'s `extra:` parameter accepts any `Object?` regardless of what the target route does with it, so nothing here fails to compile or fails a test -- it just means "tapping an episode won't actually open the right video yet" until Task 11 finishes wiring the other end. No test in this plan exercises that end-to-end tap-to-play flow (matches the established "no widget tests for these screens" precedent), so this doesn't cause any test regression.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: Run the full suite and analyze, then commit**

Run: `flutter test && flutter analyze`
Expected: all tests pass; analyze unchanged (3 categories, no new).

```bash
git add lib/domain/play/subject_episodes_controller.dart test/domain/play/subject_episodes_controller_test.dart lib/ui/subject/subject_detail_screen.dart
git commit -m "feat: query all MediaSources concurrently, merge episodes, and show a source badge"
```

---
### Task 11: Rewrite `EpisodePlayController` to resolve via the owning `MediaSource` (+ update `PlayerScreen` and the play route)

**Files:**
- Modify: `lib/domain/play/episode_play_controller.dart`
- Modify: `test/domain/play/episode_play_controller_test.dart`
- Modify: `lib/ui/player/player_screen.dart`
- Modify: `lib/app/router.dart`

Instead of hardcoding `Anime1Api.resolvePlaybackUrl`, the controller now takes a whole `MergedEpisode` (produced by `SubjectEpisodesController` in Task 10, carrying its `sourceId`) and looks up the matching `MediaSource` from `mediaSourcesProvider` to resolve it -- this is how the plan resolves the design doc's explicitly-deferred "how does EpisodePlayController know which source an episode came from" question (see this plan's header note).

`PlayerScreen` and `router.dart`'s play route are updated in this **same** task, not a later one -- both are the only other places coupled to `EpisodePlayController`'s family-parameter shape (`episodePageUrl: String` -> `episode: MergedEpisode`), so leaving them unchanged here would break `flutter analyze`/`flutter test` until a later task fixed them. This is also where the design doc's "PlayerScreen needs ZERO changes" note gets superseded: a `MediaEpisode` is a general Dart object, not a URL string, so `PlayerScreen` must be handed the actual `MergedEpisode` object -- via go_router's `extra:` mechanism (in-memory object passing, no serialization) rather than a `url` query parameter -- which Task 10 already started wiring on the `SubjectDetailScreen` side.

- [ ] **Step 1: Write the failing test**

Replace the entire contents of `test/domain/play/episode_play_controller_test.dart` with:

```dart
// test/domain/play/episode_play_controller_test.dart
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/episode_play_controller.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _FakePlaybackSource implements MediaPlaybackSource {
  const _FakePlaybackSource(this.url);
  @override
  final String url;
  @override
  Map<String, String> get headers => const {};
}

class MockMediaSource extends Mock implements MediaSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(const _FakeEpisode('fallback', 'fallback'));
  });

  group('EpisodePlayController', () {
    late MockMediaSource sourceA;
    late MockMediaSource sourceB;
    late ProviderContainer container;

    setUp(() {
      sourceA = MockMediaSource();
      sourceB = MockMediaSource();
      when(() => sourceA.id).thenReturn('a');
      when(() => sourceB.id).thenReturn('b');
      container = ProviderContainer(
        overrides: [mediaSourcesProvider.overrideWithValue([sourceA, sourceB])],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    test('resolves via the MediaSource matching the episode\'s sourceId', () async {
      final episode = MergedEpisode(episode: const _FakeEpisode('b', 'ep1'), sourceId: 'b');
      when(() => sourceB.resolvePlayback(episode.episode)).thenAnswer(
        (_) async => const _FakePlaybackSource('https://example.com/v.mp4'),
      );

      final source = await container.read(
        episodePlayControllerProvider(episode: episode).future,
      );

      expect(source.url, 'https://example.com/v.mp4');
      verifyNever(() => sourceA.resolvePlayback(any()));
    });

    test('propagates a resolvePlayback exception', () async {
      final episode = MergedEpisode(episode: const _FakeEpisode('a', 'ep1'), sourceId: 'a');
      when(() => sourceA.resolvePlayback(episode.episode)).thenThrow(Exception('resolve failed'));

      await expectLater(
        container.read(episodePlayControllerProvider(episode: episode).future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/play/episode_play_controller_test.dart`
Expected: FAIL -- `EpisodePlayController.build()` still takes `episodePageUrl` and hardcodes `anime1ApiProvider`.

- [ ] **Step 3: Rewrite `episode_play_controller.dart`**

```dart
// lib/domain/play/episode_play_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../media/media_registry.dart';
import '../media/media_source.dart';
import 'subject_episodes_controller.dart';

part 'episode_play_controller.g.dart';

@riverpod
class EpisodePlayController extends _$EpisodePlayController {
  @override
  Future<MediaPlaybackSource> build({required MergedEpisode episode}) {
    final sources = ref.watch(mediaSourcesProvider);
    final source = sources.firstWhere((s) => s.id == episode.sourceId);
    return source.resolvePlayback(episode.episode);
  }
}
```

- [ ] **Step 4: Update `PlayerScreen` to take a `MergedEpisode` instead of a URL string**

Replace the entire contents of `lib/ui/player/player_screen.dart` with:

```dart
// lib/ui/player/player_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../domain/play/episode_play_controller.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../common/error_retry_view.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.episode});

  final MergedEpisode episode;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _player = Player();
  late final _controller = VideoController(_player);

  /// Set when media_kit reports a playback error *after* a source was
  /// already opened successfully (i.e. after `AsyncData` -- see the
  /// design doc's "播放页 - 播放本身失败" row). Address-resolution
  /// failures are handled by `episodePlayControllerProvider`'s own
  /// `AsyncError` instead; this field is strictly for the second kind of
  /// failure.
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _player.stream.error.listen((message) {
      if (mounted) setState(() => _playbackError = message);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _playbackError = null);
    ref.invalidate(episodePlayControllerProvider(episode: widget.episode));
  }

  @override
  Widget build(BuildContext context) {
    final provider = episodePlayControllerProvider(episode: widget.episode);
    // `player.open` is a command, not a declarative value -- it must run
    // as a side effect exactly once per successful resolution, not on
    // every `build()` (see design doc "数据流" step 3).
    ref.listen(provider, (previous, next) {
      next.whenData(
        (source) => _player.open(
          Media(
            source.url,
            // Some sources' video CDNs (e.g. anime1.me) reject direct
            // requests without specific headers -- see each concrete
            // MediaPlaybackSource's own `headers` doc comment. Others
            // (e.g. 稀饭动漫) need none, in which case this is empty.
            httpHeaders: source.headers,
          ),
        ),
      );
    });
    final playback = ref.watch(provider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: playback.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorRetryView(
            message: '播放失败：$error',
            onRetry: _retry,
          ),
          data: (_) => _playbackError != null
              ? ErrorRetryView(
                  message: '播放失败：$_playbackError',
                  onRetry: _retry,
                )
              // Uses Video's default AdaptiveVideoControls (seek-bar drag,
              // tap to show/hide controls, fullscreen button) -- see this
              // task's "Context" note above for why no custom
              // GestureDetector code is written here.
              : Video(controller: _controller),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Update the play route in `router.dart` to pass the episode via `extra`**

In `lib/app/router.dart`, add this import (alongside the existing `../ui/subject/subject_detail_screen.dart` import):

```dart
import '../domain/play/subject_episodes_controller.dart';
```

Replace the existing `/subject/:subjectId/play` route:

```dart
      GoRoute(
        path: '/subject/:subjectId/play',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          return PlayerScreen(episodePageUrl: url);
        },
      ),
```

with:

```dart
      GoRoute(
        path: '/subject/:subjectId/play',
        builder: (context, state) {
          final episode = state.extra as MergedEpisode;
          return PlayerScreen(episode: episode);
        },
      ),
```

(Every other route, and the `redirect:`/`refreshListenable`/`_RouterRefreshNotifier` logic above them, stays exactly as it is.)

- [ ] **Step 6: Regenerate provider code and run the test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `episode_play_controller.g.dart` and `router.g.dart` regenerate (hash/shape changes only, matching the new family-parameter type); no unrelated `.g.dart` files change.

Run: `flutter test test/domain/play/episode_play_controller_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 7: Run the full suite and analyze, then commit**

Run: `flutter test`
Expected: 0 failures.

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

```bash
git add lib/domain/play/episode_play_controller.dart lib/domain/play/episode_play_controller.g.dart test/domain/play/episode_play_controller_test.dart lib/ui/player/player_screen.dart lib/app/router.dart lib/app/router.g.dart
git commit -m "feat: resolve playback via the owning MediaSource; pass episodes to PlayerScreen via router extra"
```

---
### Task 12: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: 0 failures.

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: same 3 pre-existing categories (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`), no new category.

- [ ] **Step 3: Run a real macOS debug build**

Run: `flutter build macos --debug`
Expected: `✓ Built build/macos/Build/Products/Debug/animeko_flutter.app`

- [ ] **Step 4: Confirm the working tree is clean of unrelated artifacts**

Run: `git status`
Expected: no changes outside what earlier tasks already committed, except possibly the known pre-existing unrelated macOS build-artifact files (`macos/Flutter/GeneratedPluginRegistrant.swift`, `macos/Podfile.lock`, etc.) -- if any of those are dirty, `git checkout --` them; they are never part of this feature's commits.

- [ ] **Step 5: Confirm all 12 feature commits are present on `main`**

Run: `git log --oneline` and confirm, from oldest to newest, the 11 commits from Tasks 1-11 of this plan are all present (this final verification task produces no commit of its own).

## Definition of Done

- `flutter test`: all tests pass.
- `flutter analyze`: same 3 categories as the pre-existing baseline, zero new categories (individual-count growth within an existing category, e.g. from a new test file's direct `riverpod` import, is expected and fine).
- `flutter build macos --debug`: succeeds.
- All 11 task commits from Tasks 1-11 are present in `git log` on `main`.

## 手工验证 (does not block Definition of Done)

- Search a real anime title in the running app's Search tab (or open a subject's detail page from Home/Search/Schedule) whose title exists on **both** anime1.me and 稀饭动漫, and confirm the merged episode list shows entries from both sources with the correct badge label on each.
- Confirm a 稀饭动漫 episode with `encrypt=0` (the majority case observed live) plays; if a real `encrypt=1`/`encrypt=2` episode can be found, confirm those play too (neither was observed live during this plan's design phase -- the decrypt logic itself is verified against the real `player.js` source, but not yet exercised end-to-end against a real `encrypt!=0` payload).
- Confirm that a title present on only one of the two sources still shows that source's episodes with no error/warning about the other source (Decision 7).
- Confirm the `.thumb-txt`/`.thumb-menu > a` index-pairing assumption in `XifanApi.search` (flagged as unverified in Task 5) holds for a search that returns 3+ results, not just 1-2.
- Confirm `XifanApi.listEpisodes`'s "only the first `.anthology-list-play` on the page" simplification (Task 6) doesn't silently miss episodes for a bangumi where the *first* line has fewer episodes than a later one.
