# Plan 1c：在线数据源播放（anime1.me）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user tap any `SubjectCard` (Home/Search/Schedule) to reach a minimal subject detail page listing anime1.me episodes, then tap an episode to actually play it with media_kit.

**Architecture:** New `lib/data/anime1/` (HTML-scraping API client, no auth, dedicated `Dio` with a hardcoded `Referer` header), `lib/domain/play/` (two bare `@riverpod` controllers + a pure title-matching function, following the exact `HomeController`/`ScheduleController` pattern already in the repo), `lib/ui/subject/` + `lib/ui/player/` (two new screens reached via two new top-level `go_router` routes, outside the existing bottom-nav shell). No new abstraction layers (no `MediaSource` interface, no Repository/Result type, no Drift caching) — this mirrors how Plan 1b-2 built `SearchApi`/`ScheduleApi` directly.

**Tech Stack:** `dio` (already a dependency) for HTTP, new `html: ^0.15.7` dependency for HTML parsing, new `media_kit`/`media_kit_video`/`media_kit_libs_video` (`^1.2.6`/`^2.0.1`/`^1.0.7`) for video playback (libmpv-backed, matches the already-decided tech choice in `docs/superpowers/specs/2026-08-27-flutter-migration-phase1-design.md`), `flutter_riverpod`/`riverpod_annotation` codegen (already used throughout), `go_router` (already a dependency), `mocktail` for tests (already a dev dependency).

**Design doc:** `docs/superpowers/specs/2026-08-31-plan1c-online-playback-design.md` — read this first for full rationale; this plan implements it verbatim except where a concrete engineering decision was needed that the design left open (each such decision is called out inline below, e.g. the exact route query-param shape, and using `Video`'s default `AdaptiveVideoControls` instead of hand-rolled gestures).

**Pre-requisite reading for every task in this plan:**
- `lib/domain/subject_card.dart` — the shared `SubjectCard` model tapped from Home/Search/Schedule. Has `int? id`, `String name`, `String? nameCn`, `String? imageUrl`, `String? score`, `List<String>? tags`, `String? airDate`.
- `lib/domain/schedule/schedule_controller.dart` — the exact bare-`@riverpod`-class controller pattern to follow (no `keepAlive`, `ref.watch` the API provider, return the domain-shaped result, let exceptions propagate to `AsyncError`).
- `lib/data/schedule/schedule_api.dart` — the exact `Api` class + provider pattern to follow (constructor takes `Dio`, one `@riverpod` factory function building the API from a `Dio` provider).
- `lib/app/router.dart` — current router: a single `@riverpod GoRouter appRouter(Ref ref)` with a `redirect:` gate and one `StatefulShellRoute.indexedStack` containing the three bottom-nav tabs. This plan adds two more top-level routes as *siblings* of the shell route (not branches inside it).

**Definition of Done (whole plan):**
- `flutter test` passes with zero failures.
- `flutter analyze` introduces zero new lint categories beyond the pre-existing baseline (10 `info`-level lints as of the end of Plan 1b-2 — check the current count with `flutter analyze` before Task 1 and don't let it grow in kind, only possibly in count for the same pre-existing categories).
- `flutter build macos --debug` succeeds.
- All 11 task commits are present in `git log` on `main`.
- **Explicitly NOT required for this plan to be done** (see design doc "范围之外" and "测试策略"): a human packet-capturing the real `data-apireq` JSON shape and the real `v.anime1.me/api` response shape against the live site, tuning the `0.6` match threshold against real data, and confirming a real episode actually plays. These are manual-verification follow-ups tracked in the design doc, not blocking task completion — every place in this plan's code where a real HTML/JSON shape is assumed carries a doc comment flagging it as unverified, mirroring the precedent already set by `schedule_api.dart`'s `today`/`timeZone` format comment.

---

### Task 1: Add dependencies and initialize media_kit

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/app/main.dart`

- [ ] **Step 1: Add the four new dependencies**

Add these four lines to the `dependencies:` block of `pubspec.yaml`, immediately after the existing `json_annotation: ^4.11.0` line (keep everything else in the file unchanged):

```yaml
  html: ^0.15.7
  media_kit: ^1.2.6
  media_kit_video: ^2.0.1
  media_kit_libs_video: ^1.0.7
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: exits 0, `pubspec.lock` updated with `html`, `media_kit`, `media_kit_video`, `media_kit_libs_video`, and their transitive deps (e.g. `csslib`, `source_span`, `safe_local_storage`, `synchronized`, `uri_parser`).

- [ ] **Step 3: Initialize MediaKit before `runApp`**

Open `lib/app/main.dart`. Add the import and one line, keeping the rest of the file (including the doc comment on `WidgetsFlutterBinding.ensureInitialized()`) exactly as-is:

```dart
// lib/app/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../domain/auth/auth_controller.dart';
import 'router.dart';

Future<void> main() async {
  // Must run before any platform-channel plugin use (e.g. the
  // flutter_secure_storage read inside restoreSession() below), since
  // that call happens before runApp(), which is what normally performs
  // this initialization implicitly.
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before any Player() is constructed (see
  // lib/ui/player/player_screen.dart) -- initializes media_kit's native
  // libmpv bindings for this platform.
  MediaKit.ensureInitialized();

  final container = ProviderContainer();
  await container.read(authControllerProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AnimekoFlutterApp(),
    ),
  );
}

class AnimekoFlutterApp extends ConsumerWidget {
  const AnimekoFlutterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(title: 'Animeko', routerConfig: router);
  }
}
```

- [ ] **Step 4: Verify analyze and existing tests still pass**

Run: `flutter analyze`
Expected: same pre-existing lint count/categories as before this task (record the exact count now — you'll compare against it after every later task).

Run: `flutter test`
Expected: all pre-existing tests still pass (this task touches no testable logic, only wiring).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/app/main.dart
git commit -m "chore: add html and media_kit dependencies, initialize media_kit"
```

---

### Task 2: Anime1 data models

**Files:**
- Create: `lib/data/anime1/anime1_models.dart`
- Test: `test/data/anime1/anime1_models_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/anime1/anime1_models_test.dart
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Anime1PlaybackSource.fromApiResponse', () {
    test('picks the src of the first source entry', () {
      final source = Anime1PlaybackSource.fromApiResponse({
        's': [
          {'src': 'https://example.com/720p.mp4', 'type': 'video/mp4'},
          {'src': 'https://example.com/1080p.mp4', 'type': 'video/mp4'},
        ],
      });

      expect(source.url, 'https://example.com/720p.mp4');
    });

    test('throws FormatException when "s" is missing', () {
      expect(
        () => Anime1PlaybackSource.fromApiResponse({}),
        throwsFormatException,
      );
    });

    test('throws FormatException when "s" is an empty list', () {
      expect(
        () => Anime1PlaybackSource.fromApiResponse({'s': <dynamic>[]}),
        throwsFormatException,
      );
    });

    test('throws FormatException when the first entry has no "src"', () {
      expect(
        () => Anime1PlaybackSource.fromApiResponse({
          's': [
            {'type': 'video/mp4'},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/anime1/anime1_models_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/data/anime1/anime1_models.dart'`.

- [ ] **Step 3: Write the models**

```dart
// lib/data/anime1/anime1_models.dart

/// A WordPress category page on anime1.me, corresponding to one anime
/// series. `id` is the value of the `cat` query parameter
/// (`https://anime1.me/?cat=<id>`).
class Anime1Category {
  const Anime1Category({required this.id, required this.title});

  final int id;
  final String title;
}

/// A single episode: one WordPress article inside an [Anime1Category].
class Anime1Episode {
  const Anime1Episode({required this.title, required this.pageUrl});

  /// Raw article title, e.g. `葬送的芙莉蓮 [12]`. anime1.me embeds the
  /// episode number in free-text form inside the title -- there is no
  /// separate structured episode-number field to parse it out of.
  final String title;

  /// Absolute URL of the article page. anime1.me has no separate episode
  /// ID concept, so this URL itself is the identifier passed to
  /// [Anime1Api.resolvePlaybackUrl].
  final String pageUrl;
}

/// A resolved, playable video source for one episode.
class Anime1PlaybackSource {
  const Anime1PlaybackSource({required this.url});

  /// Direct mp4/m3u8 URL.
  final String url;

  /// Parses the JSON body returned by `POST https://v.anime1.me/api`.
  ///
  /// NOTE: this shape (`{"s": [{"src": ..., "type": ...}, ...]}`) is an
  /// unverified assumption based on third-party reverse-engineering
  /// writeups, not confirmed against the live API in this repo -- see
  /// `Anime1Api.resolvePlaybackUrl`'s doc comment and the design doc's
  /// "测试策略" section. Adjust this parser if the live response disagrees.
  /// When multiple source entries are present, the *first* one is used;
  /// which entry is "highest quality" is also unconfirmed.
  factory Anime1PlaybackSource.fromApiResponse(Map<String, dynamic> json) {
    final sources = json['s'];
    if (sources is! List || sources.isEmpty) {
      throw const FormatException(
        'anime1.me API response contained no playable sources (missing or empty "s")',
      );
    }
    final first = sources.first;
    if (first is! Map || first['src'] is! String) {
      throw const FormatException(
        'anime1.me API response source entry is missing a string "src"',
      );
    }
    return Anime1PlaybackSource(url: first['src'] as String);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/anime1/anime1_models_test.dart`
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add lib/data/anime1/anime1_models.dart test/data/anime1/anime1_models_test.dart
git commit -m "feat: add Anime1Category/Anime1Episode/Anime1PlaybackSource models"
```

---

### Task 3: `Anime1Api.searchCategories` + Dio/provider wiring

**Files:**
- Create: `lib/data/anime1/anime1_api.dart`
- Test: `test/data/anime1/anime1_api_test.dart`

**Context:** anime1.me search results (`GET https://anime1.me/?s=<title>`) list matching episode articles, and each article's WordPress "posted in" category link is what identifies the show (`<a href="https://anime1.me/?cat=123" rel="category tag">番名</a>` — `rel="category tag"` is a standard WordPress theme convention for post-category links, distinguishing them from unrelated nav-menu links that might also point at `?cat=` URLs). This is an **unverified assumption about anime1.me's specific theme**, flagged in the doc comment below.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/anime1/anime1_api_test.dart
import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late Anime1Api api;

  setUp(() {
    dio = MockDio();
    api = Anime1Api(dio);
  });

  Response<String> htmlResponse(String body, {String path = '/'}) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  group('searchCategories', () {
    const searchResultsHtml = '''
<html><body>
  <article>
    <h2 class="entry-title"><a href="https://anime1.me/?p=1001">葬送的芙莉蓮 [12]</a></h2>
    <span class="cat-links">
      <a href="https://anime1.me/?cat=87" rel="category tag">葬送的芙莉蓮</a>
    </span>
  </article>
  <article>
    <h2 class="entry-title"><a href="https://anime1.me/?p=1002">葬送的芙莉蓮 [11]</a></h2>
    <span class="cat-links">
      <a href="https://anime1.me/?cat=87" rel="category tag">葬送的芙莉蓮</a>
    </span>
  </article>
  <div id="sidebar">
    <a href="https://anime1.me/?cat=999">Unrelated sidebar category widget link</a>
  </div>
</body></html>
''';

    test('sends the title as the "s" query param', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      await api.searchCategories('葬送的芙莉蓮');

      verify(
        () => dio.get<String>(
          'https://anime1.me/',
          queryParameters: {'s': '葬送的芙莉蓮'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('extracts and dedupes rel="category tag" links, ignoring other links', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      final categories = await api.searchCategories('葬送的芙莉蓮');

      expect(categories, hasLength(1));
      expect(categories.single.id, 87);
      expect(categories.single.title, '葬送的芙莉蓮');
    });

    test('returns an empty list when there are no category-tag links', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no results</body></html>'));

      final categories = await api.searchCategories('nonexistent');

      expect(categories, isEmpty);
    });
  });

  test('anime1ApiProvider builds an Anime1Api backed by anime1DioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(anime1ApiProvider);
    expect(api, isA<Anime1Api>());
  });

  test('anime1DioProvider sets the Referer header required by anime1.me', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(anime1DioProvider);
    expect(dio.options.headers['Referer'], 'https://anime1.me');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/anime1/anime1_api_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/data/anime1/anime1_api.dart'`.

- [ ] **Step 3: Write `Anime1Api` (searchCategories only) and providers**

```dart
// lib/data/anime1/anime1_api.dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'anime1_models.dart';

part 'anime1_api.g.dart';

const _baseUrl = 'https://anime1.me';
const _apiUrl = 'https://v.anime1.me/api';

/// Direct HTML-scraping client for anime1.me. There is no official API or
/// documentation -- every parsing rule here is a best-effort assumption
/// based on third-party reverse-engineering writeups, flagged individually
/// below, and needs real-site verification before this is trusted in
/// production (see the design doc's "测试策略" section).
class Anime1Api {
  Anime1Api(this._dio);
  final Dio _dio;

  /// GET https://anime1.me/?s=<title>
  ///
  /// NOTE (unverified): assumes anime1.me's WordPress theme marks each
  /// article's category link with `rel="category tag"`, which is a common
  /// WordPress convention but not confirmed for this specific site. If the
  /// real markup differs, this selector needs updating.
  Future<List<Anime1Category>> searchCategories(String title) async {
    final response = await _dio.get<String>(
      '$_baseUrl/',
      queryParameters: {'s': title},
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final seenIds = <int>{};
    final categories = <Anime1Category>[];
    for (final anchor in document.querySelectorAll('a[rel="category tag"]')) {
      final href = anchor.attributes['href'];
      final match = href == null ? null : RegExp(r'[?&]cat=(\d+)').firstMatch(href);
      if (match == null) continue;
      final id = int.parse(match.group(1)!);
      if (!seenIds.add(id)) continue;
      final title = anchor.text.trim();
      if (title.isEmpty) continue;
      categories.add(Anime1Category(id: id, title: title));
    }
    return categories;
  }
}

@riverpod
Dio anime1Dio(Ref ref) {
  // anime1.me's only anti-hotlinking check is the Referer header -- see
  // the design doc's "背景与范围" section. No auth, no other headers
  // needed.
  return Dio(BaseOptions(headers: {'Referer': 'https://anime1.me'}));
}

@riverpod
Anime1Api anime1Api(Ref ref) => Anime1Api(ref.watch(anime1DioProvider));
```

- [ ] **Step 4: Generate riverpod code and run test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/data/anime1/anime1_api.g.dart` with `anime1DioProvider`/`anime1ApiProvider`.

Run: `flutter test test/data/anime1/anime1_api_test.dart`
Expected: PASS (5/5).

- [ ] **Step 5: Commit**

```bash
git add lib/data/anime1/anime1_api.dart lib/data/anime1/anime1_api.g.dart test/data/anime1/anime1_api_test.dart
git commit -m "feat: add Anime1Api.searchCategories with dedicated Referer-header Dio"
```

---

### Task 4: `Anime1Api.fetchCategoryEpisodes` (with pagination)

**Files:**
- Modify: `lib/data/anime1/anime1_api.dart`
- Modify: `test/data/anime1/anime1_api_test.dart`

**Context:** WordPress paginates category archive pages with `<a class="next page-numbers" href="...">` linking to the next page; the plan caps how many pages are followed (`_maxPages`) as a defensive bound against an infinite/malformed pagination chain, not because 20 is a meaningful real limit.

- [ ] **Step 1: Write the failing test**

Add this `group` to `test/data/anime1/anime1_api_test.dart`, right after the `group('searchCategories', ...)` block (before the two standalone `anime1ApiProvider`/`anime1DioProvider` tests):

```dart
  group('fetchCategoryEpisodes', () {
    const page1Html = '''
<html><body>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1002">葬送的芙莉蓮 [12]</a></h2></article>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1001">葬送的芙莉蓮 [11]</a></h2></article>
  <nav class="pagination">
    <a class="next page-numbers" href="https://anime1.me/page/2/?cat=87">Next</a>
  </nav>
</body></html>
''';
    const page2Html = '''
<html><body>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1000">葬送的芙莉蓮 [10]</a></h2></article>
</body></html>
''';

    test('fetches https://anime1.me/?cat=<id>', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body></body></html>'));

      await api.fetchCategoryEpisodes(87);

      verify(
        () => dio.get<String>('https://anime1.me/?cat=87', options: any(named: 'options')),
      ).called(1);
    });

    test('parses episode title and page URL from each article', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('''
<html><body>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1001">葬送的芙莉蓮 [12]</a></h2></article>
</body></html>
'''));

      final episodes = await api.fetchCategoryEpisodes(87);

      expect(episodes, hasLength(1));
      expect(episodes.single.title, '葬送的芙莉蓮 [12]');
      expect(episodes.single.pageUrl, 'https://anime1.me/?p=1001');
    });

    test('follows pagination via "next page-numbers" links', () async {
      when(() => dio.get<String>('https://anime1.me/?cat=87', options: any(named: 'options')))
          .thenAnswer((_) async => htmlResponse(page1Html));
      when(() => dio.get<String>('https://anime1.me/page/2/?cat=87', options: any(named: 'options')))
          .thenAnswer((_) async => htmlResponse(page2Html));

      final episodes = await api.fetchCategoryEpisodes(87);

      expect(episodes.map((e) => e.title), [
        '葬送的芙莉蓮 [12]',
        '葬送的芙莉蓮 [11]',
        '葬送的芙莉蓮 [10]',
      ]);
    });

    test('stops when there is no next-page link', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(page2Html));

      await api.fetchCategoryEpisodes(87);

      verify(() => dio.get<String>(any(), options: any(named: 'options'))).called(1);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/anime1/anime1_api_test.dart`
Expected: FAIL — `NoSuchMethodError: The method 'fetchCategoryEpisodes' isn't defined for the type 'Anime1Api'`.

- [ ] **Step 3: Implement `fetchCategoryEpisodes`**

Add this method inside the `Anime1Api` class in `lib/data/anime1/anime1_api.dart`, right after `searchCategories`, and add the constant right after the top-level `_apiUrl` constant:

```dart
// Add near the top, alongside `const _apiUrl = ...;`:
const _maxPaginationPages = 20;
```

```dart
  /// GET https://anime1.me/?cat=<categoryId>, following pagination.
  ///
  /// NOTE (unverified): assumes each episode article has its title+link
  /// inside `<h2 class="entry-title"><a>`, and that pagination uses a
  /// `<a class="next page-numbers">` link -- both are common WordPress
  /// theme defaults, not confirmed for this specific site. `_maxPaginationPages`
  /// is a defensive bound against a malformed/infinite pagination chain,
  /// not a meaningful real limit.
  Future<List<Anime1Episode>> fetchCategoryEpisodes(int categoryId) async {
    final episodes = <Anime1Episode>[];
    String? nextPageUrl = '$_baseUrl/?cat=$categoryId';
    var pagesFetched = 0;

    while (nextPageUrl != null && pagesFetched < _maxPaginationPages) {
      final response = await _dio.get<String>(
        nextPageUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final document = html_parser.parse(response.data ?? '');

      for (final titleLink in document.querySelectorAll('h2.entry-title a')) {
        final href = titleLink.attributes['href'];
        final title = titleLink.text.trim();
        if (href == null || title.isEmpty) continue;
        episodes.add(Anime1Episode(title: title, pageUrl: href));
      }

      nextPageUrl = document.querySelector('a.next.page-numbers')?.attributes['href'];
      pagesFetched++;
    }

    return episodes;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/anime1/anime1_api_test.dart`
Expected: PASS (9/9).

- [ ] **Step 5: Commit**

```bash
git add lib/data/anime1/anime1_api.dart test/data/anime1/anime1_api_test.dart
git commit -m "feat: add Anime1Api.fetchCategoryEpisodes with pagination"
```

---

### Task 5: `Anime1Api.resolvePlaybackUrl`

**Files:**
- Modify: `lib/data/anime1/anime1_api.dart`
- Modify: `test/data/anime1/anime1_api_test.dart`

**Context:** Per the design doc, the episode article page embeds a `data-apireq="<base64>"` attribute; the **raw attribute string is forwarded as-is** (not decoded by this client) as form field `d` in a `POST https://v.anime1.me/api` request, and the JSON response is parsed by `Anime1PlaybackSource.fromApiResponse` (Task 2). Both the `data-apireq` element shape and the response shape are unverified — see the doc comments below and in `anime1_models.dart`.

- [ ] **Step 1: Write the failing test**

Add this `group` to `test/data/anime1/anime1_api_test.dart`, right after the `group('fetchCategoryEpisodes', ...)` block:

```dart
  group('resolvePlaybackUrl', () {
    const episodePageHtml = '''
<html><body>
  <div class="video-js" data-apireq="eyJmb28iOiJiYXIifQ=="></div>
</body></html>
''';

    Response<Map<String, dynamic>> apiJsonResponse(Map<String, dynamic> data) {
      return Response(
        data: data,
        requestOptions: RequestOptions(path: 'https://v.anime1.me/api'),
        statusCode: 200,
      );
    }

    test('extracts data-apireq and POSTs it as form field "d"', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(episodePageHtml));
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => apiJsonResponse({
            's': [
              {'src': 'https://video.example.com/720p.mp4', 'type': 'video/mp4'},
            ],
          }));

      await api.resolvePlaybackUrl('https://anime1.me/?p=1001');

      verify(
        () => dio.post<Map<String, dynamic>>(
          'https://v.anime1.me/api',
          data: {'d': 'eyJmb28iOiJiYXIifQ=='},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('returns the parsed Anime1PlaybackSource from the API response', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(episodePageHtml));
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => apiJsonResponse({
            's': [
              {'src': 'https://video.example.com/720p.mp4', 'type': 'video/mp4'},
            ],
          }));

      final source = await api.resolvePlaybackUrl('https://anime1.me/?p=1001');

      expect(source.url, 'https://video.example.com/720p.mp4');
    });

    test('throws FormatException when the page has no data-apireq attribute', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no video here</body></html>'));

      expect(
        () => api.resolvePlaybackUrl('https://anime1.me/?p=1001'),
        throwsFormatException,
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/anime1/anime1_api_test.dart`
Expected: FAIL — `NoSuchMethodError: The method 'resolvePlaybackUrl' isn't defined for the type 'Anime1Api'`.

- [ ] **Step 3: Implement `resolvePlaybackUrl`**

Add this method inside the `Anime1Api` class, right after `fetchCategoryEpisodes`:

```dart
  /// GET the episode page, extract `data-apireq`, then POST it to
  /// https://v.anime1.me/api and parse the response.
  ///
  /// NOTE (unverified): assumes the raw `data-apireq` attribute string is
  /// forwarded as-is (not base64-decoded by this client) as
  /// `application/x-www-form-urlencoded` field `d`. Both this request
  /// shape and the response shape parsed by
  /// [Anime1PlaybackSource.fromApiResponse] are third-party
  /// reverse-engineering assumptions, not confirmed against the live API.
  Future<Anime1PlaybackSource> resolvePlaybackUrl(String episodePageUrl) async {
    final pageResponse = await _dio.get<String>(
      episodePageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(pageResponse.data ?? '');
    final apireq = document.querySelector('[data-apireq]')?.attributes['data-apireq'];
    if (apireq == null || apireq.isEmpty) {
      throw const FormatException(
        'anime1.me episode page has no data-apireq attribute',
      );
    }

    final apiResponse = await _dio.post<Map<String, dynamic>>(
      _apiUrl,
      data: {'d': apireq},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return Anime1PlaybackSource.fromApiResponse(apiResponse.data ?? {});
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/anime1/anime1_api_test.dart`
Expected: PASS (12/12).

- [ ] **Step 5: Run the full suite and analyze**

Run: `flutter test`
Expected: all pass, no regressions in other files.

Run: `flutter analyze`
Expected: same pre-existing categories as recorded in Task 1 (no new categories; `Anime1Api`'s new code should not introduce any).

- [ ] **Step 6: Commit**

```bash
git add lib/data/anime1/anime1_api.dart test/data/anime1/anime1_api_test.dart
git commit -m "feat: add Anime1Api.resolvePlaybackUrl"
```

---

### Task 6: Title-matching algorithm + not-found exception

**Files:**
- Create: `lib/domain/play/subject_episodes_controller.dart` (this task writes only the pure-function/exception part; Task 7 adds the controller class to the same file)
- Test: `test/domain/play/subject_episodes_controller_test.dart` (this task writes only the `matchBestCategory` group; Task 7 adds the controller group to the same file)

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/play/subject_episodes_controller_test.dart
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchBestCategory', () {
    test('returns null for an empty candidate list', () {
      expect(matchBestCategory([], '葬送的芙莉蓮'), isNull);
    });

    test('returns the exact title match', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const other = Anime1Category(id: 2, title: '無關的番劇');
      final result = matchBestCategory([other, target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('matches case-insensitively and ignores whitespace', () {
      const target = Anime1Category(id: 1, title: 'Attack On Titan');
      final result = matchBestCategory([target], 'attack  on titan');
      expect(result, target);
    });

    test('normalizes full-width Latin characters to half-width', () {
      const target = Anime1Category(id: 1, title: 'ＦＲＩＥＲＥＮ');
      final result = matchBestCategory([target], 'FRIEREN');
      expect(result, target);
    });

    test('matches when one title contains the other', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮 第二季');
      final result = matchBestCategory([target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('returns null when no candidate is similar enough', () {
      const unrelated = Anime1Category(id: 1, title: '完全無關的標題');
      final result = matchBestCategory([unrelated], '葬送的芙莉蓮');
      expect(result, isNull);
    });

    test('picks the highest-scoring candidate among several', () {
      const exact = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const partial = Anime1Category(id: 2, title: '葬送的芙莉蓮 特別篇');
      final result = matchBestCategory([partial, exact], '葬送的芙莉蓮');
      expect(result, exact);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/domain/play/subject_episodes_controller.dart'`.

- [ ] **Step 3: Implement the pure matching function and exception**

```dart
// lib/domain/play/subject_episodes_controller.dart
import '../../data/anime1/anime1_models.dart';

/// Thrown when no anime1.me category matches the requested subject title
/// with sufficient confidence (see [matchBestCategory]). Not a
/// network/parsing failure -- retrying without changing the title
/// produces the same result, so the UI shows an empty "not found" state
/// instead of a retry button (see `SubjectDetailScreen`).
class Anime1NotFoundException implements Exception {
  const Anime1NotFoundException();

  @override
  String toString() =>
      'Anime1NotFoundException: no matching anime1.me category found';
}

/// Minimum similarity score (see [_similarity]) for a category to be
/// considered a match. This is an initial guess, not tuned against real
/// anime1.me data -- adjust during manual verification if it produces too
/// many false positives/negatives (see design doc "测试策略").
const matchThreshold = 0.6;

/// Picks the best-matching [Anime1Category] for [subjectName] out of
/// [candidates], or `null` if none scores at or above [matchThreshold].
/// Pure function, directly testable with no mocking. Deliberately uses
/// title-string similarity only, with no year/season filtering (see
/// design doc "标题匹配策略").
Anime1Category? matchBestCategory(
  List<Anime1Category> candidates,
  String subjectName,
) {
  final normalizedTarget = _normalize(subjectName);
  Anime1Category? best;
  var bestScore = 0.0;
  for (final candidate in candidates) {
    final score = _similarity(_normalize(candidate.title), normalizedTarget);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return bestScore >= matchThreshold ? best : null;
}

/// Lowercases, strips whitespace, and converts full-width Latin
/// letters/digits/punctuation (U+FF01-FF5E) to their half-width
/// equivalents, so e.g. "ＡＴＴＡＣＫ" and "Attack" compare equal.
String _normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAllMapped(
        RegExp(r'[\uFF01-\uFF5E]'),
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0),
      );
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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart`
Expected: PASS (7/7).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/play/subject_episodes_controller.dart test/domain/play/subject_episodes_controller_test.dart
git commit -m "feat: add anime1.me title-matching algorithm"
```

---

### Task 7: `SubjectEpisodesController`

**Files:**
- Modify: `lib/domain/play/subject_episodes_controller.dart`
- Modify: `test/domain/play/subject_episodes_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Add this `group` to `test/domain/play/subject_episodes_controller_test.dart`, right after the `group('matchBestCategory', ...)` block, and add the two new imports at the top of the file (`package:animeko_flutter/data/anime1/anime1_api.dart`, `package:mocktail/mocktail.dart`, `package:riverpod/riverpod.dart`):

```dart
// Add to the top of the file, alongside the existing imports:
import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
```

```dart
  group('SubjectEpisodesController', () {
    late _MockAnime1Api api;
    late ProviderContainer container;

    setUp(() {
      api = _MockAnime1Api();
      container = ProviderContainer(
        overrides: [anime1ApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
    });

    test('matches a category then returns its episodes', () async {
      when(() => api.searchCategories('葬送的芙莉蓮')).thenAnswer(
        (_) async => [const Anime1Category(id: 87, title: '葬送的芙莉蓮')],
      );
      when(() => api.fetchCategoryEpisodes(87)).thenAnswer(
        (_) async => [
          const Anime1Episode(title: '葬送的芙莉蓮 [1]', pageUrl: 'https://anime1.me/?p=1'),
        ],
      );

      final result = await container.read(
        subjectEpisodesControllerProvider(subjectId: 1, subjectName: '葬送的芙莉蓮').future,
      );

      expect(result, hasLength(1));
      expect(result.single.title, '葬送的芙莉蓮 [1]');
    });

    test('throws Anime1NotFoundException when no category matches', () async {
      when(() => api.searchCategories(any())).thenAnswer((_) async => []);

      await expectLater(
        container.read(
          subjectEpisodesControllerProvider(subjectId: 1, subjectName: 'unmatched').future,
        ),
        throwsA(isA<Anime1NotFoundException>()),
      );
      verifyNever(() => api.fetchCategoryEpisodes(any()));
    });

    test('propagates a searchCategories API exception', () async {
      when(() => api.searchCategories(any())).thenThrow(Exception('network down'));

      await expectLater(
        container.read(
          subjectEpisodesControllerProvider(subjectId: 1, subjectName: 'x').future,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _MockAnime1Api extends Mock implements Anime1Api {}
```

**Note:** the closing `}` and `class _MockAnime1Api extends Mock implements Anime1Api {}` above replace the file's existing final `}` that closes `void main() { ... }` — the mock class must live outside `main()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart`
Expected: FAIL — `Undefined name 'subjectEpisodesControllerProvider'`.

- [ ] **Step 3: Implement `SubjectEpisodesController`**

Add these lines to the top of `lib/domain/play/subject_episodes_controller.dart` (replacing the current single import line) and the class at the bottom of the file:

```dart
// lib/domain/play/subject_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';

part 'subject_episodes_controller.g.dart';
```

(Keep everything else already in the file -- `Anime1NotFoundException`, `matchThreshold`, `matchBestCategory`, `_normalize`, `_similarity` -- unchanged, then append:)

```dart
@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<Anime1Episode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final api = ref.watch(anime1ApiProvider);
    final categories = await api.searchCategories(subjectName);
    final best = matchBestCategory(categories, subjectName);
    if (best == null) {
      throw const Anime1NotFoundException();
    }
    return api.fetchCategoryEpisodes(best.id);
  }
}
```

- [ ] **Step 4: Generate riverpod code and run test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/domain/play/subject_episodes_controller.g.dart`.

Run: `flutter test test/domain/play/subject_episodes_controller_test.dart`
Expected: PASS (10/10).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/play/subject_episodes_controller.dart lib/domain/play/subject_episodes_controller.g.dart test/domain/play/subject_episodes_controller_test.dart
git commit -m "feat: add SubjectEpisodesController"
```

---

### Task 8: `EpisodePlayController`

**Files:**
- Create: `lib/domain/play/episode_play_controller.dart`
- Test: `test/domain/play/episode_play_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/play/episode_play_controller_test.dart
import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/play/episode_play_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockAnime1Api extends Mock implements Anime1Api {}

void main() {
  group('EpisodePlayController', () {
    late _MockAnime1Api api;
    late ProviderContainer container;

    setUp(() {
      api = _MockAnime1Api();
      container = ProviderContainer(
        overrides: [anime1ApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
    });

    test('resolves the playback source via Anime1Api', () async {
      when(() => api.resolvePlaybackUrl('https://anime1.me/?p=1')).thenAnswer(
        (_) async => const Anime1PlaybackSource(url: 'https://video.example.com/1.mp4'),
      );

      final result = await container.read(
        episodePlayControllerProvider(episodePageUrl: 'https://anime1.me/?p=1').future,
      );

      expect(result.url, 'https://video.example.com/1.mp4');
    });

    test('propagates a resolvePlaybackUrl exception', () async {
      when(() => api.resolvePlaybackUrl(any())).thenThrow(const FormatException('bad'));

      await expectLater(
        container.read(
          episodePlayControllerProvider(episodePageUrl: 'https://anime1.me/?p=1').future,
        ),
        throwsFormatException,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/play/episode_play_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/domain/play/episode_play_controller.dart'`.

- [ ] **Step 3: Implement `EpisodePlayController`**

```dart
// lib/domain/play/episode_play_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';

part 'episode_play_controller.g.dart';

@riverpod
class EpisodePlayController extends _$EpisodePlayController {
  @override
  Future<Anime1PlaybackSource> build({required String episodePageUrl}) {
    final api = ref.watch(anime1ApiProvider);
    return api.resolvePlaybackUrl(episodePageUrl);
  }
}
```

- [ ] **Step 4: Generate riverpod code and run test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/domain/play/episode_play_controller.g.dart`.

Run: `flutter test test/domain/play/episode_play_controller_test.dart`
Expected: PASS (2/2).

- [ ] **Step 5: Run the full suite and analyze**

Run: `flutter test`
Expected: all pass.

Run: `flutter analyze`
Expected: same pre-existing categories as Task 1's baseline.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/play/episode_play_controller.dart lib/domain/play/episode_play_controller.g.dart test/domain/play/episode_play_controller_test.dart
git commit -m "feat: add EpisodePlayController"
```

---

### Task 9: `ErrorRetryView` shared widget

**Files:**
- Create: `lib/ui/common/error_retry_view.dart`

**Context:** No dedicated widget test for this file, matching the design doc's "测试策略" decision to skip widget tests for the new UI layer (relying on manual verification instead, same as `HomeScreen`/`SearchScreen`/`ScheduleScreen` today).

- [ ] **Step 1: Write the widget**

```dart
// lib/ui/common/error_retry_view.dart
import 'package:flutter/material.dart';

/// Shared "failed to load, tap to retry" placeholder. Used by
/// `SubjectDetailScreen` and `PlayerScreen` for any error that is *not*
/// `Anime1NotFoundException` -- see the design doc's "错误处理" table.
/// `Anime1NotFoundException` gets its own non-retryable empty state
/// instead, rendered inline by the screen that catches it.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze is clean**

Run: `flutter analyze`
Expected: same pre-existing categories as Task 1's baseline.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/common/error_retry_view.dart
git commit -m "feat: add shared ErrorRetryView widget"
```

---

### Task 10: `SubjectDetailScreen` + `PlayerScreen` + navigation helper

**Files:**
- Create: `lib/ui/subject/subject_navigation.dart`
- Create: `lib/ui/subject/subject_detail_screen.dart`
- Create: `lib/ui/player/player_screen.dart`

**Context — engineering decisions made to fill in what the design doc left open:**
1. **Cover image but no synopsis.** The design doc says "封面+简介+剧集列表", but there is no subject-detail API yet (that's Plan 1b-3's job) to fetch a synopsis from — only `SubjectCard.imageUrl` is available from the tap origin. `SubjectDetailScreen` therefore accepts an optional `imageUrl` and shows it as a cover when present; it does not show a synopsis. This keeps the page genuinely minimal rather than inventing placeholder text.
2. **Gesture controls come from `Video`'s default `AdaptiveVideoControls`, not hand-rolled `GestureDetector` code.** The design doc's decision #4 ("只做基本控制—拖动进度条、单击显隐控制栏、双击暂停/播放、基本全屏按钮") describes *exactly* what media_kit's `Video` widget already provides out of the box when no custom `controls:` builder is passed. Writing custom gesture code here would duplicate the library's own default behavior for no benefit — so `PlayerScreen` uses the default.
3. **Navigation is centralized in one helper function** (`openSubjectDetail`) instead of duplicating the push-URL logic in Home/Search/Schedule (Task 11) — DRY.

- [ ] **Step 1: Write the navigation helper**

```dart
// lib/ui/subject/subject_navigation.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/subject_card.dart';

/// Pushes to the subject detail route for [card]. Does nothing if the
/// card has no [SubjectCard.id] -- all four `SubjectCard.from*` factories
/// set this from a required wire field, so in practice this should not
/// happen for cards rendered by Home/Search/Schedule; guarded defensively
/// so a malformed API response can't crash navigation.
void openSubjectDetail(BuildContext context, SubjectCard card) {
  final id = card.id;
  if (id == null) return;
  final name = Uri.encodeComponent(card.nameCn ?? card.name);
  final imageUrl = card.imageUrl;
  final query = imageUrl == null
      ? 'name=$name'
      : 'name=$name&imageUrl=${Uri.encodeComponent(imageUrl)}';
  context.push('/subject/$id?$query');
}
```

- [ ] **Step 2: Write `SubjectDetailScreen`**

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
                if (error is Anime1NotFoundException) {
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
                    onTap: () => context.push(
                      '/subject/$subjectId/play?url=${Uri.encodeComponent(episode.pageUrl)}',
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
```

- [ ] **Step 3: Write `PlayerScreen`**

```dart
// lib/ui/player/player_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../domain/play/episode_play_controller.dart';
import '../common/error_retry_view.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.episodePageUrl});

  final String episodePageUrl;

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
    ref.invalidate(
      episodePlayControllerProvider(episodePageUrl: widget.episodePageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = episodePlayControllerProvider(
      episodePageUrl: widget.episodePageUrl,
    );
    // `player.open` is a command, not a declarative value -- it must run
    // as a side effect exactly once per successful resolution, not on
    // every `build()` (see design doc "数据流" step 3).
    ref.listen(provider, (previous, next) {
      next.whenData((source) => _player.open(Media(source.url)));
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

- [ ] **Step 4: Verify analyze and full test suite**

Run: `flutter analyze`
Expected: same pre-existing categories as Task 1's baseline (no widget tests were added for this task per the design doc, so this step is the only verification here).

Run: `flutter test`
Expected: all pass (no new test files in this task, but confirms nothing else broke).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/subject/subject_navigation.dart lib/ui/subject/subject_detail_screen.dart lib/ui/player/player_screen.dart
git commit -m "feat: add SubjectDetailScreen, PlayerScreen, and subject navigation helper"
```

---

### Task 11: Router wiring + tap-to-navigate in Home/Search/Schedule

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/ui/home/home_screen.dart`
- Modify: `lib/ui/search/search_screen.dart`
- Modify: `lib/ui/schedule/schedule_screen.dart`

- [ ] **Step 1: Add the two new top-level routes to the router**

In `lib/app/router.dart`, add two imports and two new `GoRoute`s as *siblings* of the `StatefulShellRoute.indexedStack` inside the `routes:` list (not inside any `StatefulShellBranch`):

```dart
// Add to the existing import block, alphabetically among the other `ui/` imports:
import '../ui/player/player_screen.dart';
import '../ui/subject/subject_detail_screen.dart';
```

```dart
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/subject/:subjectId',
        builder: (context, state) {
          final subjectId = int.parse(state.pathParameters['subjectId']!);
          final name = state.uri.queryParameters['name'] ?? '';
          final imageUrl = state.uri.queryParameters['imageUrl'];
          return SubjectDetailScreen(
            subjectId: subjectId,
            subjectName: name,
            imageUrl: imageUrl,
          );
        },
      ),
      GoRoute(
        path: '/subject/:subjectId/play',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          return PlayerScreen(episodePageUrl: url);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/search', builder: (context, state) => const SearchScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/schedule', builder: (context, state) => const ScheduleScreen())],
          ),
        ],
      ),
    ],
```

(Everything else in the file -- `_RouterRefreshNotifier`, the `redirect:` callback, `initialLocation`, `refreshListenable`, both `ref.onDispose` calls -- is unchanged.)

- [ ] **Step 2: Wire the tap handler in `HomeScreen`**

In `lib/ui/home/home_screen.dart`, add one import and wrap the tappable card content in `_SubjectCardSection`'s `itemBuilder`:

```dart
// Add to the top of the file:
import '../../ui/subject/subject_navigation.dart';
```

Replace the `itemBuilder`'s returned `SizedBox` with a version wrapped in `GestureDetector`:

```dart
            itemBuilder: (context, index) {
              final card = cards[index];
              return GestureDetector(
                onTap: () => openSubjectDetail(context, card),
                child: SizedBox(
                  width: 120,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Expanded(
                          child: card.imageUrl != null
                              ? Image.network(card.imageUrl!, fit: BoxFit.cover)
                              : Container(color: Colors.grey.shade300),
                        ),
                        Text(
                          card.nameCn ?? card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
```

- [ ] **Step 3: Wire the tap handler in `SearchScreen`**

In `lib/ui/search/search_screen.dart`, add the same import and an `onTap` to the existing `ListTile`:

```dart
// Add to the top of the file:
import '../../ui/subject/subject_navigation.dart';
```

```dart
            return ListTile(
              leading: card.imageUrl != null
                  ? Image.network(card.imageUrl!, width: 48, fit: BoxFit.cover)
                  : const SizedBox(width: 48),
              title: Text(card.nameCn ?? card.name),
              subtitle: card.tags != null && card.tags!.isNotEmpty
                  ? Text(card.tags!.join(', '))
                  : null,
              onTap: () => openSubjectDetail(context, card),
            );
```

- [ ] **Step 4: Wire the tap handler in `ScheduleScreen`**

In `lib/ui/schedule/schedule_screen.dart`, add the same import and an `onTap` to the existing `ListTile`:

```dart
// Add to the top of the file:
import '../../ui/subject/subject_navigation.dart';
```

```dart
                  .map(
                    (card) => ListTile(
                      leading: card.imageUrl != null
                          ? Image.network(card.imageUrl!, width: 40, fit: BoxFit.cover)
                          : const SizedBox(width: 40),
                      title: Text(card.nameCn ?? card.name),
                      onTap: () => openSubjectDetail(context, card),
                    ),
                  )
```

- [ ] **Step 5: Generate riverpod code, run the full suite, analyze, and build**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: no new `.g.dart` diffs (router.dart's provider signature didn't change), exits 0.

Run: `flutter test`
Expected: all pass, including the existing `test/app/router_test.dart` (login-gating behavior is unaffected by adding sibling routes).

Run: `flutter analyze`
Expected: same pre-existing categories as Task 1's baseline.

Run: `flutter build macos --debug`
Expected: succeeds (this is the first task that pulls in the native `media_kit_libs_video` macOS bundle — if this step fails, check `macos/Podfile.lock`/CocoaPods integration before assuming the Dart code is wrong).

- [ ] **Step 6: Commit**

```bash
git add lib/app/router.dart lib/ui/home/home_screen.dart lib/ui/search/search_screen.dart lib/ui/schedule/schedule_screen.dart
git commit -m "feat: wire subject detail/play routes and SubjectCard tap navigation"
```

---

## Manual verification (after all 11 tasks, not blocking task completion)

These require a human with a browser/network access and cannot be automated by an agentic worker — track them as a follow-up, per the design doc's "测试策略" section:

1. Open anime1.me's search page and a category page in a real browser, compare the actual HTML against the `rel="category tag"` / `h2.entry-title a` / `a.next.page-numbers` selectors assumed in Task 3/4. Adjust the selectors in `lib/data/anime1/anime1_api.dart` if they don't match.
2. Open an episode article page, inspect the real `data-apireq` attribute and confirm it's forwarded as-is (Task 5's assumption).
3. Capture the real response of `POST https://v.anime1.me/api` and confirm/fix `Anime1PlaybackSource.fromApiResponse`'s `{"s": [{"src": ...}]}` shape assumption (Task 2/5).
4. Run the app (`flutter run -d macos`), search for a real anime, tap through to an episode, and confirm it actually plays. Tune `matchThreshold` (currently `0.6`, in `lib/domain/play/subject_episodes_controller.dart`) if real titles don't match as expected.
