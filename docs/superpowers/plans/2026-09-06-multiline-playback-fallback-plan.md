# Multi-line Playback Auto-Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a media source (Dilidili / Yinghua / Xifan) offers multiple alternate playback "lines" for the same episode, resolve all of them into an ordered candidate list and have the player automatically, silently fall through to the next candidate when native playback fails, instead of surfacing an error on the first dead mirror.

**Architecture:** `MediaSource.resolvePlayback` changes from returning a single `MediaPlaybackSource` to returning an ordered `List<MediaPlaybackSource>` (index 0 = default/primary line). Each of the three affected data sources gathers its full candidate list using a source-specific mechanism (Dilidili: multiple buttons on one watch page; Yinghua/Xifan: multiple parallel episode-list blocks merged by exact episode-title match). Faulty candidates are skipped during resolution (not fatal) unless *all* candidates fail. `EpisodePlayController`'s return type follows the interface change. `PlayerScreen` keeps a local candidate list + index, opens candidate 0, and on a native playback error silently advances to the next candidate until exhausted, at which point (and only then) it shows the existing error UI. `Anime1` is untouched (single-line site).

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4, Riverpod 3.x (`@riverpod` codegen), `package:html` for scraping, `package:dio` for HTTP, `media_kit`/`media_kit_video` for playback, `mocktail` for test mocking.

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-09-06-multiline-playback-fallback-design.md` (Chinese, approved). Implement exactly as specified there; this plan is the English/code-level realization of that spec.
- Scope is exactly 3 data sources (Dilidili, Yinghua, Xifan) + `MediaSource` interface + `EpisodePlayController` + `PlayerScreen`. `Anime1Api`/`Anime1MediaSource` internals are NOT changed (only its adapter wraps its single result in a one-element list to satisfy the new interface).
- No reachability probing, no retry-count/time cap, no distinction between "failed to open" vs "failed mid-stream", no fuzzy/normalized title matching (exact string match only), no manual line-picker UI, no change to the `MediaPlaybackSource{url, headers}` field shape.
- Because this changes a shared interface (`MediaSource.resolvePlayback`) that `lib/ui/player/player_screen.dart` also consumes, `flutter analyze` will show real errors in `player_screen.dart` from Task 1 through Task 4 (inclusive) — this is expected and resolves once Task 5 lands. Each task's own verification step only needs to run that task's own test file(s), not the whole suite. Only Task 6 requires the full `flutter analyze && flutter test` to be clean.
- After any change to a `@riverpod`-annotated method's return type, run `dart run build_runner build --delete-conflicting-outputs` before that file's tests will compile.
- Baseline before this feature: 404 tests passing, 0 failures. Conventional Commits with scope (e.g. `feat(media): ...`, `fix(player): ...`).
- `PlayerScreen` currently has **zero** automated test coverage (no `test/ui/player/player_screen_test.dart` exists — confirmed, only `player_bottom_bar_test.dart`/`player_top_bar_test.dart` exist for that directory, testing unrelated small widgets). This is a pre-existing gap, not something this feature must fix. Task 5's `PlayerScreen` changes are verified via `flutter analyze` (clean) plus manual code-reading verification of the control flow — do not attempt to build new `media_kit`-mocking test infrastructure from scratch as part of this feature.

---

### Task 1: Change `MediaSource.resolvePlayback` to return a list; update adapters and `EpisodePlayController`

**Files:**
- Modify: `lib/domain/media/media_source.dart` (interface signature, line ~67)
- Modify: `lib/domain/media/media_registry.dart` (all 4 adapter classes: `Anime1MediaSource`, `XifanMediaSource`, `YinghuaMediaSource`, `DilidiliMediaSource`)
- Modify: `lib/domain/play/episode_play_controller.dart` (return type)
- Test: `test/domain/media/media_registry_test.dart` (4 `resolvePlayback` tests, one per adapter)
- Test: `test/domain/play/episode_play_controller_test.dart`

**Interfaces:**
- Produces: `Future<List<MediaPlaybackSource>> MediaSource.resolvePlayback(MediaEpisode episode)` — non-empty ordered list, index 0 = default/primary candidate. This is the contract every later task (2, 3, 4) and consumer (`EpisodePlayController`, Task 5's `PlayerScreen`) relies on.
- Consumes: nothing new from other tasks (this task is the foundation).

- [ ] **Step 1: Change the interface signature**

In `lib/domain/media/media_source.dart`, find:

```dart
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode);
```

Replace with:

```dart
  /// Resolves every available playback candidate ("line"/"mirror") for
  /// [episode], in order. Index 0 is the default/primary line; the rest
  /// are ordered fallback candidates a player should try in sequence if
  /// an earlier one fails to play. The returned list is never empty —
  /// implementations throw instead if no candidate could be resolved.
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode);
```

- [ ] **Step 2: Update the four adapters in `lib/domain/media/media_registry.dart`**

Find each of these four methods and replace as shown. `Anime1MediaSource`:

```dart
  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as Anime1Episode).pageUrl);
```

becomes:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async =>
      [await _api.resolvePlaybackUrl((episode as Anime1Episode).pageUrl)];
```

`XifanMediaSource` (this wrapping is **temporary** — Task 4 will replace it once `XifanApi.resolvePlaybackUrl` itself returns a list):

```dart
  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as XifanEpisode).watchPageUrl);
```

becomes:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async =>
      [await _api.resolvePlaybackUrl((episode as XifanEpisode).watchPageUrl)];
```

`YinghuaMediaSource` (also **temporary**, Task 3 replaces it):

```dart
  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as YinghuaEpisode).playPageUrl);
```

becomes:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async =>
      [await _api.resolvePlaybackUrl((episode as YinghuaEpisode).playPageUrl)];
```

`DilidiliMediaSource` (also **temporary**, Task 2 replaces it):

```dart
  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as DilidiliEpisode).watchPageUrl);
```

becomes:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async =>
      [await _api.resolvePlaybackUrl((episode as DilidiliEpisode).watchPageUrl)];
```

- [ ] **Step 3: Update `EpisodePlayController`'s return type**

In `lib/domain/play/episode_play_controller.dart`, find:

```dart
  @override
  Future<MediaPlaybackSource> build({required MergedEpisode episode}) {
```

Replace with:

```dart
  @override
  Future<List<MediaPlaybackSource>> build({required MergedEpisode episode}) {
```

The body (`ref.watch(mediaSourcesProvider)`, `firstWhere`, `return source.resolvePlayback(episode.episode);`) stays exactly as-is.

- [ ] **Step 4: Regenerate codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: exits 0, regenerates `lib/domain/play/episode_play_controller.g.dart` (its generated provider type now matches `List<MediaPlaybackSource>`). No `[SEVERE]` lines.

- [ ] **Step 5: Update `test/domain/media/media_registry_test.dart`'s four `resolvePlayback` tests**

Each of the four existing tests currently mocks the API's `resolvePlaybackUrl` to return a single object and asserts the adapter returns that same object. Update each so the mock still returns a single object (Tasks 2–4 haven't changed the underlying APIs yet) but the assertion checks the adapter's one-element list. For example, the Dilidili group's test should read:

```dart
    test(
      "resolvePlayback delegates to resolvePlaybackUrl using the episode's watchPageUrl",
      () async {
        const episode = DilidiliEpisode(
          title: 'Ep 1',
          watchPageUrl: 'https://dilidili.io/play/1',
        );
        const expected = DilidiliPlaybackSource(
          url: 'https://cdn.example/1.m3u8',
          headers: {'Referer': 'https://dilidili.io/'},
        );
        when(() => mockApi.resolvePlaybackUrl(episode.watchPageUrl))
            .thenAnswer((_) async => expected);

        final result = await source.resolvePlayback(episode);

        expect(result, [expected]);
      },
    );
```

Apply the same pattern (mock returns a single object; assertion is `expect(result, [expected])`) to the Anime1, Xifan, and Yinghua groups' equivalent tests, using each group's own existing episode/playback-source construction and mock variable names already present in the file — only the final assertion line and its surrounding `expected`/`result` naming need to change to the list form.

- [ ] **Step 6: Update `test/domain/play/episode_play_controller_test.dart`**

The existing test `'resolves via the MediaSource matching the episode\'s sourceId'` currently does:

```dart
    when(() => sourceB.resolvePlayback(episode.episode))
        .thenAnswer((_) async => const _FakePlaybackSource(url: 'b-url'));

    final result = await container.read(
      episodePlayControllerProvider(episode: episode).future,
    );

    expect(result.url, 'b-url');
```

Change the mock to return a list and the assertion to index into it:

```dart
    when(() => sourceB.resolvePlayback(episode.episode)).thenAnswer(
      (_) async => const [_FakePlaybackSource(url: 'b-url')],
    );

    final result = await container.read(
      episodePlayControllerProvider(episode: episode).future,
    );

    expect(result, hasLength(1));
    expect(result.first.url, 'b-url');
```

The second test, `'propagates a resolvePlayback exception'`, is unaffected by this type change (it only asserts that an exception thrown by `resolvePlayback` propagates) — leave it as-is.

- [ ] **Step 7: Run the scoped tests**

Run: `flutter test test/domain/media/media_registry_test.dart test/domain/play/episode_play_controller_test.dart`

Expected: all tests in both files pass. (Do NOT run the full suite or `flutter analyze` yet — `player_screen.dart` will show real analyzer errors until Task 5; this is expected per Global Constraints.)

- [ ] **Step 8: Commit**

```bash
git add lib/domain/media/media_source.dart lib/domain/media/media_registry.dart lib/domain/play/episode_play_controller.dart lib/domain/play/episode_play_controller.g.dart test/domain/media/media_registry_test.dart test/domain/play/episode_play_controller_test.dart
git commit -m "feat(media): change resolvePlayback to return ordered candidate list"
```

---

### Task 2: Dilidili — resolve all lines from one watch page

**Files:**
- Modify: `lib/data/dilidili/dilidili_api.dart` (`resolvePlaybackUrl`)
- Modify: `lib/domain/media/media_registry.dart` (`DilidiliMediaSource.resolvePlayback` — drop Task 1's temporary wrapping)
- Test: `test/data/dilidili/dilidili_api_test.dart`

**Interfaces:**
- Consumes: Task 1's `MediaPlaybackSource`/`MediaSource` interface (unchanged from Task 1).
- Produces: `Future<List<DilidiliPlaybackSource>> DilidiliApi.resolvePlaybackUrl(String watchPageUrl)` — the new signature Task 1's temporary adapter wrapping will be replaced with.

- [ ] **Step 1: Rewrite `resolvePlaybackUrl` in `lib/data/dilidili/dilidili_api.dart`**

Find:

```dart
  Future<DilidiliPlaybackSource> resolvePlaybackUrl(String watchPageUrl) async {
    final watchResponse = await _dio.get<String>(
      watchPageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(watchResponse.data ?? '');

    final playButton = document.querySelector('button.play-btn');
    final playId = playButton?.attributes['play_id'];
    if (playId == null || playId.isEmpty) {
      throw const FormatException(
        '嘀哩嘀哩 watch page has no button.play-btn with a play_id',
      );
    }

    final playResponse = await _dio.get<String>(
      '$_baseUrl/_get_play',
      queryParameters: {'id': playId},
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Referer': watchPageUrl},
      ),
    );
    final playData = jsonDecode(playResponse.data ?? '{}') as Map<String, dynamic>;
    final result = playData['result'] as Map<String, dynamic>?;
    final url = result?['play_data'] as String?;
    if (url == null || url.isEmpty) {
      throw const FormatException('嘀哩嘀哩 /_get_play has no "play_data" field');
    }

    return DilidiliPlaybackSource(
      url: url,
      headers: const {'Referer': 'https://dilidili.io/'},
    );
  }
```

Replace with:

```dart
  /// Resolves ALL playable "线路" (line) candidates for the given watch
  /// page, in the order they appear on the page. The watch page can list
  /// multiple `button.play-btn` elements (one per line), each with its
  /// own `play_id`; every line is independently resolved via
  /// `/_get_play`. Lines that fail to resolve (network error, malformed
  /// JSON, missing `play_data`) are skipped rather than aborting the
  /// whole call — an exception is only thrown if EVERY line fails.
  Future<List<DilidiliPlaybackSource>> resolvePlaybackUrl(
    String watchPageUrl,
  ) async {
    final watchResponse = await _dio.get<String>(
      watchPageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(watchResponse.data ?? '');

    final playIds = document
        .querySelectorAll('button.play-btn')
        .map((button) => button.attributes['play_id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (playIds.isEmpty) {
      throw const FormatException(
        '嘀哩嘀哩 watch page has no button.play-btn with a play_id',
      );
    }

    final sources = <DilidiliPlaybackSource>[];
    for (final playId in playIds) {
      try {
        final playResponse = await _dio.get<String>(
          '$_baseUrl/_get_play',
          queryParameters: {'id': playId},
          options: Options(
            responseType: ResponseType.plain,
            headers: {'Referer': watchPageUrl},
          ),
        );
        final playData =
            jsonDecode(playResponse.data ?? '{}') as Map<String, dynamic>;
        final result = playData['result'] as Map<String, dynamic>?;
        final url = result?['play_data'] as String?;
        if (url == null || url.isEmpty) continue;
        sources.add(
          DilidiliPlaybackSource(
            url: url,
            headers: const {'Referer': 'https://dilidili.io/'},
          ),
        );
      } catch (_) {
        continue;
      }
    }

    if (sources.isEmpty) {
      throw const FormatException('嘀哩嘀哩 /_get_play has no "play_data" field');
    }
    return sources;
  }
```

- [ ] **Step 2: Drop the temporary wrapping in `DilidiliMediaSource`**

In `lib/domain/media/media_registry.dart`, find:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async =>
      [await _api.resolvePlaybackUrl((episode as DilidiliEpisode).watchPageUrl)];
```

Replace with (no more wrapping needed — the API itself now returns the list, and `List<DilidiliPlaybackSource>` is a valid covariant return for `List<MediaPlaybackSource>` just as the pre-existing singular case already relied on the same covariance):

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as DilidiliEpisode).watchPageUrl);
```

- [ ] **Step 3: Update the existing "first play-btn" test**

In `test/data/dilidili/dilidili_api_test.dart`, the `resolvePlaybackUrl` group's existing `watchPageHtml` fixture already has 3 `button.play-btn` elements (`play_id="346921"`/`"346926"`/`"346928"`, labeled 线路ML/MW/MS). Find the existing test named `'uses the first play-btn\'s play_id and returns play_data as-is'` and replace its body so it mocks all three `/_get_play` calls and asserts the full ordered list, for example:

```dart
    test(
      'collects every play-btn\'s play_id and resolves each into a candidate, in page order',
      () async {
        when(() => mockDio.get<String>(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => htmlResponse(watchPageHtml));
        when(() => mockDio.get<String>(
              '$baseUrl/_get_play',
              queryParameters: {'id': '346921'},
              options: any(named: 'options'),
            )).thenAnswer(
          (_) async => htmlResponse(
            '{"result":{"play_data":"https://cdn1.example/a.m3u8"}}',
          ),
        );
        when(() => mockDio.get<String>(
              '$baseUrl/_get_play',
              queryParameters: {'id': '346926'},
              options: any(named: 'options'),
            )).thenAnswer(
          (_) async => htmlResponse(
            '{"result":{"play_data":"https://cdn2.example/b.m3u8"}}',
          ),
        );
        when(() => mockDio.get<String>(
              '$baseUrl/_get_play',
              queryParameters: {'id': '346928'},
              options: any(named: 'options'),
            )).thenAnswer(
          (_) async => htmlResponse(
            '{"result":{"play_data":"https://cdn3.example/c.m3u8"}}',
          ),
        );

        final result = await api.resolvePlaybackUrl(watchPageUrl);

        expect(result.map((s) => s.url), [
          'https://cdn1.example/a.m3u8',
          'https://cdn2.example/b.m3u8',
          'https://cdn3.example/c.m3u8',
        ]);
        expect(result.every((s) => s.headers['Referer'] == 'https://dilidili.io/'), isTrue);
      },
    );
```

Adjust the mock setup's exact `mockDio`/helper/variable names (e.g. `baseUrl`, `htmlResponse`, `watchPageUrl`) to whatever is already used elsewhere in this same file — the file already establishes these conventions in its existing tests; keep them consistent rather than introducing new names.

- [ ] **Step 4: Add a partial-failure test**

Add a new test asserting that if one of the three `/_get_play` calls throws or returns no `play_data`, the other two candidates are still returned:

```dart
    test(
      'skips a candidate whose /_get_play call fails, keeps the rest',
      () async {
        when(() => mockDio.get<String>(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => htmlResponse(watchPageHtml));
        when(() => mockDio.get<String>(
              '$baseUrl/_get_play',
              queryParameters: {'id': '346921'},
              options: any(named: 'options'),
            )).thenThrow(Exception('network error'));
        when(() => mockDio.get<String>(
              '$baseUrl/_get_play',
              queryParameters: {'id': '346926'},
              options: any(named: 'options'),
            )).thenAnswer(
          (_) async => htmlResponse('{"result":{"play_data":"https://cdn2.example/b.m3u8"}}'),
        );
        when(() => mockDio.get<String>(
              '$baseUrl/_get_play',
              queryParameters: {'id': '346928'},
              options: any(named: 'options'),
            )).thenAnswer(
          (_) async => htmlResponse('{"result":{}}'),
        );

        final result = await api.resolvePlaybackUrl(watchPageUrl);

        expect(result.map((s) => s.url), ['https://cdn2.example/b.m3u8']);
      },
    );
```

- [ ] **Step 5: Add an all-fail test**

Add a new test asserting a `FormatException` is thrown only when every candidate fails to resolve:

```dart
    test('throws FormatException when every line fails to resolve', () async {
      when(() => mockDio.get<String>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => htmlResponse(watchPageHtml));
      when(() => mockDio.get<String>(
            '$baseUrl/_get_play',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => htmlResponse('{"result":{}}'));

      expect(
        () => api.resolvePlaybackUrl(watchPageUrl),
        throwsA(isA<FormatException>()),
      );
    });
```

The existing test `'throws FormatException when there is no play-btn'` needs no changes (an empty-buttons watch page still throws before any `/_get_play` call is attempted). The existing test previously named `'throws FormatException when /_get_play has no play_data'` (single-candidate case) should be kept but adapted to use a reduced, single-button HTML fixture inline (rather than the file-level 3-button `watchPageHtml`) so it remains a clean single-candidate example — or simply delete it if Step 5's all-fail test already covers the same assertion path; prefer keeping both for clarity of intent (single-candidate failure vs. multi-candidate exhaustion).

- [ ] **Step 6: Run the scoped test**

Run: `flutter test test/data/dilidili/dilidili_api_test.dart`

Expected: all tests pass, including the 3 new/updated ones.

- [ ] **Step 7: Commit**

```bash
git add lib/data/dilidili/dilidili_api.dart lib/domain/media/media_registry.dart test/data/dilidili/dilidili_api_test.dart
git commit -m "feat(media): resolve all Dilidili play-btn lines as fallback candidates"
```

---

### Task 3: Yinghua — merge episodes across line blocks, resolve all lines

**Files:**
- Modify: `lib/data/yinghua/yinghua_models.dart` (`YinghuaEpisode`)
- Modify: `lib/data/yinghua/yinghua_api.dart` (`listEpisodes`, `resolvePlaybackUrl`)
- Modify: `lib/domain/media/media_registry.dart` (`YinghuaMediaSource.resolvePlayback` — drop Task 1's temporary wrapping)
- Test: `test/data/yinghua/yinghua_api_test.dart`

**Interfaces:**
- Consumes: Task 1's `MediaEpisode`/`MediaPlaybackSource` interfaces.
- Produces: `YinghuaEpisode.playPageUrls: List<String>` (replaces the old single `playPageUrl: String` field — this is a breaking rename any other code referencing `.playPageUrl` must follow); `Future<List<YinghuaPlaybackSource>> YinghuaApi.resolvePlaybackUrl(List<String> playPageUrls)` (signature changes from accepting a single `String` to a `List<String>`).

- [ ] **Step 1: Change the `YinghuaEpisode` model**

In `lib/data/yinghua/yinghua_models.dart`, find:

```dart
/// One entry in a bangumi's episode list (only the *first* line/route --
/// see [YinghuaApi.listEpisodes]'s doc comment).
class YinghuaEpisode implements MediaEpisode {
  const YinghuaEpisode({required this.title, required this.playPageUrl});
  @override
  final String title;
  final String playPageUrl;
  @override
  String get sourceId => 'yinghua';
}
```

Replace with:

```dart
/// One logical episode, merged across all "线路" (line) blocks that
/// expose it under the same title. [playPageUrls] is ordered by line
/// appearance on the detail page; index 0 is the default/primary line,
/// the rest are fallback candidates.
class YinghuaEpisode implements MediaEpisode {
  const YinghuaEpisode({required this.title, required this.playPageUrls});
  @override
  final String title;
  final List<String> playPageUrls;
  @override
  String get sourceId => 'yinghua';
}
```

- [ ] **Step 2: Rewrite `listEpisodes` in `lib/data/yinghua/yinghua_api.dart`**

Find:

```dart
  Future<List<YinghuaEpisode>> listEpisodes(int id) async {
    final response = await _dio.get<String>(
      '$_baseUrl/index.php/vod/detail/id/$id.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final firstLine = document.querySelector('div.stui-pannel.stui-pannel-bg');
    if (firstLine == null) return const [];

    final episodes = <YinghuaEpisode>[];
    for (final link in firstLine.querySelectorAll('.stui-content__playlist > li > a')) {
      final href = link.attributes['href'];
      final title = link.text.trim();
      if (href == null || title.isEmpty) continue;
      final url = href.startsWith('http') ? href : '$_baseUrl$href';
      episodes.add(YinghuaEpisode(title: title, playPageUrl: url));
    }
    return episodes;
  }
```

Replace with:

```dart
  /// Lists episodes merged across ALL "线路" (line) blocks on the detail
  /// page. Each line block is a `div.stui-pannel.stui-pannel-bg` with its
  /// own full `<ul class="stui-content__playlist">`; the same logical
  /// episode appears in multiple blocks under a different URL (the line
  /// is encoded in the URL's `sid` path segment). Episodes are merged
  /// across blocks by EXACT title match, in the order blocks appear on
  /// the page — so [YinghuaEpisode.playPageUrls] is ordered with the
  /// first-encountered line first (the default/primary line).
  Future<List<YinghuaEpisode>> listEpisodes(int id) async {
    final response = await _dio.get<String>(
      '$_baseUrl/index.php/vod/detail/id/$id.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final lineBlocks = document.querySelectorAll(
      'div.stui-pannel.stui-pannel-bg',
    );

    // Title -> ordered list of URLs (first-seen line first).
    final urlsByTitle = <String, List<String>>{};
    final titleOrder = <String>[];
    for (final block in lineBlocks) {
      for (final link
          in block.querySelectorAll('.stui-content__playlist > li > a')) {
        final href = link.attributes['href'];
        final title = link.text.trim();
        if (href == null || title.isEmpty) continue;
        final url = href.startsWith('http') ? href : '$_baseUrl$href';
        final urls = urlsByTitle.putIfAbsent(title, () {
          titleOrder.add(title);
          return <String>[];
        });
        urls.add(url);
      }
    }

    return titleOrder
        .map(
          (title) => YinghuaEpisode(
            title: title,
            playPageUrls: urlsByTitle[title]!,
          ),
        )
        .toList();
  }
```

- [ ] **Step 3: Rewrite `resolvePlaybackUrl` in `lib/data/yinghua/yinghua_api.dart`**

Find:

```dart
  Future<YinghuaPlaybackSource> resolvePlaybackUrl(String playPageUrl) async {
    final response = await _dio.get<String>(
      playPageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';

    final json = _extractPlayerJson(body);
    if (json == null) {
      throw const FormatException(
        '樱花动漫 play page has no player_aaaa script variable',
      );
    }

    final playerData = jsonDecode(json) as Map<String, dynamic>;
    final url = playerData['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const FormatException('樱花动漫 player_aaaa has no "url" field');
    }

    return YinghuaPlaybackSource(
      url: url,
      headers: const {'Referer': 'https://www.yinghua2.com/'},
    );
  }
```

Replace with:

```dart
  /// Resolves ALL playable line candidates for a logical episode, in the
  /// order given by [playPageUrls] (see [YinghuaEpisode]). Each URL is
  /// requested and parsed independently; a URL that fails (network
  /// error, missing `player_aaaa`, missing `url` field) is skipped
  /// rather than aborting the whole call — an exception is only thrown
  /// if EVERY URL fails.
  Future<List<YinghuaPlaybackSource>> resolvePlaybackUrl(
    List<String> playPageUrls,
  ) async {
    final sources = <YinghuaPlaybackSource>[];
    for (final playPageUrl in playPageUrls) {
      try {
        final response = await _dio.get<String>(
          playPageUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final body = response.data ?? '';

        final json = _extractPlayerJson(body);
        if (json == null) continue;

        final playerData = jsonDecode(json) as Map<String, dynamic>;
        final url = playerData['url'] as String?;
        if (url == null || url.isEmpty) continue;

        sources.add(
          YinghuaPlaybackSource(
            url: url,
            headers: const {'Referer': 'https://www.yinghua2.com/'},
          ),
        );
      } catch (_) {
        continue;
      }
    }

    if (sources.isEmpty) {
      throw const FormatException(
        '樱花动漫: none of the candidate lines resolved to a playable url',
      );
    }
    return sources;
  }
```

Leave the private `_extractPlayerJson` helper (the brace-balancing scanner) completely untouched — it is reused per-candidate as-is.

- [ ] **Step 4: Drop the temporary wrapping in `YinghuaMediaSource`**

In `lib/domain/media/media_registry.dart`, find:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async =>
      [await _api.resolvePlaybackUrl((episode as YinghuaEpisode).playPageUrl)];
```

Replace with:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as YinghuaEpisode).playPageUrls);
```

- [ ] **Step 5: Update `test/data/yinghua/yinghua_api_test.dart`'s `listEpisodes` fixture/tests**

The existing HTML fixture already contains multiple `div.stui-pannel.stui-pannel-bg` line blocks (used previously only to prove the "only reads the first block" behavior). Update the `listEpisodes` test(s) so they now assert the merged, multi-line result. Any existing test named along the lines of `'reads only the first line block'` should be renamed and rewritten, e.g.:

```dart
    test(
      'merges episodes across all line blocks by exact title match, preserving line order',
      () async {
        when(() => mockDio.get<String>(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => htmlResponse(detailPageHtml));

        final episodes = await api.listEpisodes(76362);

        expect(episodes, hasLength(2));
        expect(episodes[0].title, '第01集');
        expect(episodes[0].playPageUrls, [
          'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/5/nid/1.html',
          'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/2/nid/1.html',
        ]);
        expect(episodes[1].title, '第02集');
        expect(episodes[1].playPageUrls, [
          'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/5/nid/2.html',
        ]);
      },
    );
```

(The exact expected URLs must match whatever `detailPageHtml`/equivalent fixture variable is already defined in the file — reuse the existing fixture's real `sid`/`nid` values rather than inventing new ones; the example above mirrors the two-line, two-episode fixture already described when this feature was researched. If the file's existing fixture only has one episode per line, add a second line block with an overlapping-and-a-non-overlapping episode title to exercise both the "same title merges" and "unique title stays a separate episode" cases.)

- [ ] **Step 6: Update `resolvePlaybackUrl` tests to accept/exercise a list**

Update the existing single-URL `resolvePlaybackUrl` test to pass a one-element list and assert a one-element result list, and add two new tests: partial-candidate-failure-still-returns-remainder, and all-candidates-fail-throws. Follow the same shape as Task 2 Step 4/5's Dilidili tests, adapted to Yinghua's single-request-per-URL flow (mock `_dio.get` per distinct `playPageUrl` value rather than per `play_id` query parameter):

```dart
    test('resolves multiple lines, skipping ones that fail', () async {
      when(() => mockDio.get<String>(
            'https://www.yinghua2.com/line-a.html',
            options: any(named: 'options'),
          )).thenThrow(Exception('network error'));
      when(() => mockDio.get<String>(
            'https://www.yinghua2.com/line-b.html',
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => htmlResponse(
          'var player_aaaa = {"url":"https://cdn.example/b.m3u8","encrypt":"0"}',
        ),
      );

      final result = await api.resolvePlaybackUrl([
        'https://www.yinghua2.com/line-a.html',
        'https://www.yinghua2.com/line-b.html',
      ]);

      expect(result.map((s) => s.url), ['https://cdn.example/b.m3u8']);
    });

    test('throws when every line fails to resolve', () async {
      when(() => mockDio.get<String>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => htmlResponse('no player_aaaa here'));

      expect(
        () => api.resolvePlaybackUrl([
          'https://www.yinghua2.com/line-a.html',
          'https://www.yinghua2.com/line-b.html',
        ]),
        throwsA(isA<FormatException>()),
      );
    });
```

- [ ] **Step 7: Run the scoped test**

Run: `flutter test test/data/yinghua/yinghua_api_test.dart`

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/data/yinghua/yinghua_models.dart lib/data/yinghua/yinghua_api.dart lib/domain/media/media_registry.dart test/data/yinghua/yinghua_api_test.dart
git commit -m "feat(media): merge Yinghua episodes across lines, resolve all as fallback candidates"
```

---

### Task 4: Xifan — merge episodes across line lists, resolve all lines

**Files:**
- Modify: `lib/data/xifan/xifan_models.dart` (`XifanEpisode`)
- Modify: `lib/data/xifan/xifan_api.dart` (`listEpisodes`, `resolvePlaybackUrl`)
- Modify: `lib/domain/media/media_registry.dart` (`XifanMediaSource.resolvePlayback` — drop Task 1's temporary wrapping)
- Test: `test/data/xifan/xifan_api_test.dart`

**Interfaces:**
- Consumes: Task 1's `MediaEpisode`/`MediaPlaybackSource` interfaces.
- Produces: `XifanEpisode.watchPageUrls: List<String>` (replaces old single `watchPageUrl: String`); `Future<List<XifanPlaybackSource>> XifanApi.resolvePlaybackUrl(List<String> watchPageUrls)`.

This task is structurally identical to Task 3, applied to Xifan's HTML structure and decrypt logic.

- [ ] **Step 1: Change the `XifanEpisode` model**

In `lib/data/xifan/xifan_models.dart`, find:

```dart
class XifanEpisode implements MediaEpisode {
  const XifanEpisode({required this.title, required this.watchPageUrl});
  @override
  final String title;
  final String watchPageUrl;
  @override
  String get sourceId => 'xifan';
}
```

Replace with:

```dart
/// One logical episode, merged across all "线路" (line) lists that
/// expose it under the same title. [watchPageUrls] is ordered by line
/// appearance on the bangumi page; index 0 is the default/primary line,
/// the rest are fallback candidates.
class XifanEpisode implements MediaEpisode {
  const XifanEpisode({required this.title, required this.watchPageUrls});
  @override
  final String title;
  final List<String> watchPageUrls;
  @override
  String get sourceId => 'xifan';
}
```

- [ ] **Step 2: Rewrite `listEpisodes` in `lib/data/xifan/xifan_api.dart`**

Find:

```dart
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

Replace with:

```dart
  /// Lists episodes merged across ALL "线路" (line) lists on the bangumi
  /// page. Each line is its own `<ul class="anthology-list-play">`
  /// sibling under `.anthology-list-box`; the same logical episode
  /// appears in multiple lists under a different URL (the line is
  /// encoded in the URL's middle path segment). Episodes are merged
  /// across lists by EXACT title match, in the order lists appear on the
  /// page — so [XifanEpisode.watchPageUrls] is ordered with the
  /// first-encountered line first (the default/primary line).
  Future<List<XifanEpisode>> listEpisodes(int bangumiId) async {
    final response = await _dio.get<String>(
      '$_watchBaseUrl/bangumi/$bangumiId.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final lists = document.querySelectorAll('.anthology-list-play');

    final urlsByTitle = <String, List<String>>{};
    final titleOrder = <String>[];
    for (final list in lists) {
      for (final link in list.querySelectorAll('a')) {
        final href = link.attributes['href'];
        final title = link.text.trim();
        if (href == null || title.isEmpty) continue;
        final url = href.startsWith('http') ? href : '$_watchBaseUrl$href';
        final urls = urlsByTitle.putIfAbsent(title, () {
          titleOrder.add(title);
          return <String>[];
        });
        urls.add(url);
      }
    }

    return titleOrder
        .map(
          (title) => XifanEpisode(
            title: title,
            watchPageUrls: urlsByTitle[title]!,
          ),
        )
        .toList();
  }
```

- [ ] **Step 3: Rewrite `resolvePlaybackUrl` in `lib/data/xifan/xifan_api.dart`**

Find:

```dart
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

Replace with:

```dart
  /// Resolves ALL playable line candidates for a logical episode, in the
  /// order given by [watchPageUrls] (see [XifanEpisode]). Each URL is
  /// requested, decrypted per its own `encrypt` field, and parsed
  /// independently; a URL that fails is skipped rather than aborting the
  /// whole call — an exception is only thrown if EVERY URL fails.
  Future<List<XifanPlaybackSource>> resolvePlaybackUrl(
    List<String> watchPageUrls,
  ) async {
    final sources = <XifanPlaybackSource>[];
    for (final watchPageUrl in watchPageUrls) {
      try {
        final response = await _dio.get<String>(
          watchPageUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final body = response.data ?? '';

        final json = _extractPlayerJson(body);
        if (json == null) continue;

        final playerData = jsonDecode(json) as Map<String, dynamic>;
        final rawUrl = playerData['url'] as String?;
        if (rawUrl == null || rawUrl.isEmpty) continue;

        final encrypt = playerData['encrypt']?.toString() ?? '0';
        sources.add(XifanPlaybackSource(url: _decryptUrl(rawUrl, encrypt)));
      } catch (_) {
        continue;
      }
    }

    if (sources.isEmpty) {
      throw const FormatException(
        '稀饭动漫: none of the candidate lines resolved to a playable url',
      );
    }
    return sources;
  }
```

Leave the private `_extractPlayerJson` and `_decryptUrl` helpers completely untouched — both are reused per-candidate as-is.

- [ ] **Step 4: Drop the temporary wrapping in `XifanMediaSource`**

In `lib/domain/media/media_registry.dart`, find:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async =>
      [await _api.resolvePlaybackUrl((episode as XifanEpisode).watchPageUrl)];
```

Replace with:

```dart
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as XifanEpisode).watchPageUrls);
```

- [ ] **Step 5: Update `test/data/xifan/xifan_api_test.dart`'s `listEpisodes` fixture/tests**

Apply the same transformation as Task 3 Step 5: the existing fixture already has multiple `<ul class="anthology-list-play">` lists (previously used to prove the "only reads the first list" behavior). Rewrite the relevant test to assert the merged, multi-line result, mirroring the pattern:

```dart
    test(
      'merges episodes across all anthology-list-play lists by exact title match, preserving line order',
      () async {
        when(() => mockDio.get<String>(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => htmlResponse(bangumiPageHtml));

        final episodes = await api.listEpisodes(1001);

        expect(episodes, hasLength(2));
        expect(episodes[0].title, '第01集');
        expect(episodes[0].watchPageUrls, [
          'https://watch.example/watch/1001/1/1.html',
          'https://watch.example/watch/1001/2/1.html',
        ]);
      },
    );
```

(Substitute the file's real base URL / fixture variable names and real captured `watchPageUrls` values — reuse whatever line/episode URLs are already present in the existing `bangumiPageHtml`-equivalent fixture rather than inventing new ones.)

- [ ] **Step 6: Update `resolvePlaybackUrl` tests to accept/exercise a list, including the `encrypt` decrypt paths**

Update the existing single-URL test(s) to pass a list and assert a list result, preserving coverage of all three `encrypt` branches (`'0'`/`'1'`/`'2'`) that already exist in the file, and add partial-failure and all-fail tests following the same shape as Task 3 Step 6:

```dart
    test('resolves multiple lines, skipping ones that fail, decrypting per encrypt field', () async {
      when(() => mockDio.get<String>(
            'https://watch.example/watch/1001/1/1.html',
            options: any(named: 'options'),
          )).thenThrow(Exception('network error'));
      when(() => mockDio.get<String>(
            'https://watch.example/watch/1001/2/1.html',
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => htmlResponse(
          'var player_aaaa = {"url":"https://cdn.example/b.m3u8","encrypt":"0"}',
        ),
      );

      final result = await api.resolvePlaybackUrl([
        'https://watch.example/watch/1001/1/1.html',
        'https://watch.example/watch/1001/2/1.html',
      ]);

      expect(result.map((s) => s.url), ['https://cdn.example/b.m3u8']);
    });

    test('throws when every line fails to resolve', () async {
      when(() => mockDio.get<String>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => htmlResponse('no player_aaaa here'));

      expect(
        () => api.resolvePlaybackUrl([
          'https://watch.example/watch/1001/1/1.html',
          'https://watch.example/watch/1001/2/1.html',
        ]),
        throwsA(isA<FormatException>()),
      );
    });
```

- [ ] **Step 7: Run the scoped test**

Run: `flutter test test/data/xifan/xifan_api_test.dart`

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/data/xifan/xifan_models.dart lib/data/xifan/xifan_api.dart lib/domain/media/media_registry.dart test/data/xifan/xifan_api_test.dart
git commit -m "feat(media): merge Xifan episodes across lines, resolve all as fallback candidates"
```

---

### Task 5: `PlayerScreen` — silent auto-advance through candidates on native playback failure

**Files:**
- Modify: `lib/ui/player/player_screen.dart`

**Interfaces:**
- Consumes: `episodePlayControllerProvider`'s new `AsyncValue<List<MediaPlaybackSource>>` type (from Task 1); `MediaPlaybackSource{url, headers}` (unchanged shape).
- Produces: no new public interface — this is the final consumer of the candidate list.

- [ ] **Step 1: Add the import**

Near the top of `lib/ui/player/player_screen.dart`, alongside the existing imports, add:

```dart
import '../../domain/media/media_source.dart';
```

- [ ] **Step 2: Add candidate-tracking fields**

In `_PlayerScreenState`, alongside the existing `String? _playbackError;` field, add:

```dart
  List<MediaPlaybackSource>? _candidates;
  int _candidateIndex = 0;
```

- [ ] **Step 3: Extract the `_openCandidate` helper**

The current `ref.listen` callback in `build()` contains this body (opening the player, setting playback rate, resuming position, resetting the "advanced to next episode" flag):

```dart
        await _player.open(
          Media(
            source.url,
            httpHeaders: source.headers,
          ),
        );
        final speed = await ref.read(playbackSpeedControllerProvider.future);
        await _player.setRate(speed);
        await _maybeResumePosition();
        if (mounted) _hasAdvancedToNextEpisode = false;
```

Extract this into a new private method on `_PlayerScreenState` (place it near `_retry()`):

```dart
  Future<void> _openCandidate(MediaPlaybackSource source) async {
    await _player.open(Media(source.url, httpHeaders: source.headers));
    final speed = await ref.read(playbackSpeedControllerProvider.future);
    await _player.setRate(speed);
    await _maybeResumePosition();
    if (mounted) _hasAdvancedToNextEpisode = false;
  }
```

- [ ] **Step 4: Update the `ref.listen` callback in `build()` to store the candidate list and open candidate 0**

Find:

```dart
    ref.listen(provider, (previous, next) {
      next.whenData((source) async {
        await _player.open(
          Media(
            source.url,
            httpHeaders: source.headers,
          ),
        );
        final speed = await ref.read(playbackSpeedControllerProvider.future);
        await _player.setRate(speed);
        await _maybeResumePosition();
        if (mounted) _hasAdvancedToNextEpisode = false;
      });
    });
```

Replace with:

```dart
    ref.listen(provider, (previous, next) {
      next.whenData((candidates) async {
        _candidates = candidates;
        _candidateIndex = 0;
        if (mounted) setState(() => _playbackError = null);
        await _openCandidate(candidates[_candidateIndex]);
      });
    });
```

- [ ] **Step 5: Update the native-error listener in `initState()` to silently advance instead of always surfacing an error**

Find:

```dart
    _player.stream.error.listen((message) {
      if (mounted) setState(() => _playbackError = message);
    });
```

Replace with:

```dart
    _player.stream.error.listen((message) {
      if (!mounted) return;
      final candidates = _candidates;
      if (candidates != null && _candidateIndex + 1 < candidates.length) {
        // Another line is available -- silently advance and retry
        // without surfacing an error to the user. Does not distinguish
        // "failed to open" from "failed mid-stream"; both are handled
        // identically per the design spec.
        _candidateIndex++;
        _openCandidate(candidates[_candidateIndex]);
        return;
      }
      setState(() => _playbackError = message);
    });
```

- [ ] **Step 6: Update `_retry()` to reset the candidate index**

Find:

```dart
  void _retry() {
    setState(() => _playbackError = null);
    ref.invalidate(episodePlayControllerProvider(episode: _currentEpisode));
  }
```

Replace with:

```dart
  void _retry() {
    setState(() => _playbackError = null);
    _candidateIndex = 0;
    ref.invalidate(episodePlayControllerProvider(episode: _currentEpisode));
  }
```

(`ref.invalidate` triggers a full re-resolution — `_candidates`/`_candidateIndex` are then reset again by Step 4's `ref.listen` callback once the new data arrives, but resetting `_candidateIndex` here too is cheap and avoids any brief window where a stale index could be read.)

- [ ] **Step 7: Verify the rest of `build()` needs no changes**

Confirm that `final playback = ref.watch(provider);` and the `playback.when(loading: ..., error: (error, stack) => ErrorRetryView(message: '播放失败：$error', onRetry: _retry), data: (_) => _playbackError != null ? ErrorRetryView(message: '播放失败：$_playbackError', onRetry: _retry) : Video(...))` block require NO changes — the `data: (_)` callback already ignores its value, and the error-text format is unchanged by design. `_playbackError`'s meaning has changed (now "all candidates exhausted") but its usage site is unchanged.

- [ ] **Step 8: Run static analysis**

Run: `flutter analyze`

Expected: no errors anywhere in the project (this is the first point where the whole project — including `player_screen.dart` — compiles cleanly again after Task 1's interface change). Only pre-existing info-level issues are acceptable, per AGENTS.md.

- [ ] **Step 9: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "fix(player): silently auto-advance through playback candidates on native failure"
```

---

### Task 6: Final regression pass

**Files:** none — verification only.

**Interfaces:** Consumes everything from Tasks 1–5. Produces final go/no-go confirmation that the feature is complete and non-regressive.

- [ ] **Step 1: Regenerate codegen once more as a safety net**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: exits 0, no `[SEVERE]` lines (should mostly report builders as up-to-date/skipped since Task 1 already regenerated the one affected file).

- [ ] **Step 2: Run full static analysis**

Run: `flutter analyze`

Expected: no errors. Only pre-existing info-level issues (the same ~27 infos noted in prior features of this codebase) are acceptable.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`

Expected: all tests pass, 0 failures. The total count should be the pre-feature baseline (404) plus every new test added across Tasks 1–4 (at minimum: 3 new/updated Dilidili tests, ~4 new/updated Yinghua tests, ~4 new/updated Xifan tests, 1 updated controller test, 4 updated adapter tests) — some tests were rewritten in place rather than purely added, so the exact delta may be smaller than the raw count of new `test(...)` blocks; the important assertion is 0 failures, not an exact target count.

- [ ] **Step 4: Verify git state**

Run: `git status --short && git log --oneline -8`

Expected: clean working tree; the log shows (newest first) Task 5's commit, Task 4's commit, Task 3's commit, Task 2's commit, Task 1's commit, then the pre-existing design-spec commit `3a71dbb` and whatever preceded it.

- [ ] **Step 5: Report to the user**

Report (in Chinese, per this session's standing instruction) that the feature is complete: Dilidili/Yinghua/Xifan now each resolve every available line into an ordered candidate list, and `PlayerScreen` silently falls through to the next candidate on native playback failure, only showing an error once every candidate has been exhausted. Note the one accepted gap: `PlayerScreen` itself still has no automated test coverage (pre-existing condition, not introduced by this feature) — verification for Task 5 was `flutter analyze` plus manual control-flow review, consistent with the rest of the codebase's existing testing conventions for this file.
