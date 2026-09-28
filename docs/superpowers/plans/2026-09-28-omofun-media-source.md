# OmoFun 数据源 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `omofun`（omofun.in）在线播放数据源：搜索 → 剧集列表 → `/_dyn_plays` 多线路，解析时并发探测 m3u8、只保留可用线路，直连播放。

**Architecture:** 按现有惯例手写 dio + `package:html` 抓取器，放在 `lib/data/omofun/`：纯解析函数 + 模型（`omofun_models.dart`）、与站点无关的 m3u8 线路探测器（`m3u8_line_prober.dart`）、`OmofunApi` + Riverpod providers（`omofun_api.dart`）。`lib/domain/media/media_registry.dart` 里加 `OmofunMediaSource` 适配器并注册到 `mediaSources`（Agedm 之后、Mikan 之前）。站点请求走全局代理，探测请求与 libmpv 播放强制直连。

**Tech Stack:** Dart / Flutter 3.41.6、dio 5 (`dio/io.dart` IOHttpClientAdapter)、html 0.15、Riverpod 3 codegen、flutter_test + mocktail。

Spec: `docs/superpowers/specs/2026-09-28-omofun-media-source-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| Create `lib/data/omofun/omofun_models.dart` | `OmofunCandidate` / `OmofunEpisode` / `OmofunPlaybackSource` + 纯函数 `parseOmofunSearch` / `parseOmofunEpisodes` / `parseOmofunPlays` |
| Create `lib/data/omofun/m3u8_line_prober.dart` | `probeM3u8Lines<T>()`、`looksLikeM3u8()`；不依赖 omofun |
| Create `lib/data/omofun/omofun_api.dart` | `OmofunApi`、`directHttpClientAdapter()`、providers `omofunDio` / `omofunProbeDio` / `omofunApi` |
| Generated `lib/data/omofun/omofun_api.g.dart` | build_runner 产物 |
| Modify `lib/domain/media/media_registry.dart` | `OmofunMediaSource` + 注册 |
| Create `test/data/omofun/fake_http_adapter.dart` | 测试用按 URL 路由的 `HttpClientAdapter` |
| Create `test/data/omofun/omofun_models_test.dart` | 解析测试 |
| Create `test/data/omofun/m3u8_line_prober_test.dart` | 探测器测试 |
| Create `test/data/omofun/omofun_api_test.dart` | URL/参数、探测过滤、兜底、错误、直连 adapter |
| Modify `test/domain/media/media_registry_test.dart` | `OmofunMediaSource` 组 + 注册列表断言 |

---

### Task 1: 模型与解析函数

**Files:**
- Create: `lib/data/omofun/omofun_models.dart`
- Test: `test/data/omofun/omofun_models_test.dart`

- [ ] **Step 1: 写失败测试**

`test/data/omofun/omofun_models_test.dart`:

```dart
import 'package:animeko_flutter/data/omofun/omofun_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures captured live from https://omofun.in on 2026-09-28, trimmed.
const _searchHtml = '''
<html><body>
<div class="module-card-item module-item">
  <div class="module-card-item-class">日漫</div>
  <a href="/vod/detail/2023103093.html" class="module-card-item-poster"><div class="module-item-cover"><div class="module-item-note">更新至第28集</div><div class="module-item-pic"><img class="lazy lazyload" data-original="/vodimg/small/2023103093.jpg" alt="葬送的芙莉莲" src="/loading.gif"></div></div></a>
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/2023103093.html"><strong>葬送的芙莉莲</strong></a></div></div>
</div>
<div class="module-card-item module-item">
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/2026838825.html"><strong>葬送的芙莉莲 第二季</strong></a></div></div>
</div>
<div class="module-card-item module-item">
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/abc.html"><strong>坏链接</strong></a></div></div>
</div>
<div class="module-card-item module-item">
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/1.html"><strong>  </strong></a></div></div>
</div>
</body></html>
''';

const _detailHtml = '''
<html><body>
<div class="module-list sort-list tab-list his-tab-list" id="panel1"><div class="module-play-list"><div class="module-play-list-content module-play-list-base">
<a class="module-play-list-link" href="/vod/play/2023103093/ep1.html" title="播放葬送的芙莉莲第01集"><span>第01集</span></a>
<a class="module-play-list-link" href="/vod/play/2023103093/ep2.html" title="播放葬送的芙莉莲第02集"><span>第02集</span></a>
<a class="module-play-list-link" href="/vod/play/2023103093/ep2.html" title="播放葬送的芙莉莲第02集"><span>第02集</span></a>
<a class="module-play-list-link" href="/vod/play/2023103093/ep3.html"></a>
<a class="module-play-list-link" href="/vod/play/999/ep1.html"><span>别的番</span></a>
</div></div></div>
<div class="module-play-list-content"><a href="/vod/play/2023103093/ep99.html"><span>列表外</span></a></div>
</body></html>
''';

const _playsJson = '''
{"video_plays":[
 {"play_data":"https://v.gsuus.com/play/7axxj2Ba/index.m3u8","src_site":"gszy"},
 {"play_data":"https://hn.bfvvs.com/play/DdwwgK8d/index.m3u8","src_site":"hnzy"},
 {"play_data":"https://v.gsuus.com/play/7axxj2Ba/index.m3u8","src_site":"gszy"},
 {"play_data":"","src_site":"empty"},
 {"play_data":"/_player_x_/relative.m3u8","src_site":"rel"},
 {"play_data":"https://bfikuncdn.com/20230929/f0a53bgA/index.m3u8"}
],"html_content":"<li></li>"}
''';

void main() {
  group('parseOmofunSearch', () {
    test('parses cards and skips ones without title or numeric vodId', () {
      final results = parseOmofunSearch(_searchHtml);
      expect(results.map((c) => c.vodId), ['2023103093', '2026838825']);
      expect(results.map((c) => c.title), ['葬送的芙莉莲', '葬送的芙莉莲 第二季']);
      expect(results.first.sourceId, 'omofun');
    });

    test('returns empty list when there are no cards', () {
      expect(parseOmofunSearch('<html><body>无结果</body></html>'), isEmpty);
    });
  });

  group('parseOmofunEpisodes', () {
    test('uses first list, keeps order, dedupes, filters other vodIds', () {
      final eps = parseOmofunEpisodes(_detailHtml, '2023103093');
      expect(eps.map((e) => e.ep), [1, 2, 3]);
      expect(eps.map((e) => e.title), ['第01集', '第02集', '第3集']);
      expect(eps.every((e) => e.vodId == '2023103093'), isTrue);
      expect(eps.first.sourceId, 'omofun');
    });

    test('returns empty list when there is no play list', () {
      expect(parseOmofunEpisodes('<html></html>', '1'), isEmpty);
    });
  });

  group('parseOmofunPlays', () {
    test('dedupes by url keeping first, drops empty and non-http lines', () {
      final lines = parseOmofunPlays(_playsJson);
      expect(lines.map((l) => l.url), [
        'https://v.gsuus.com/play/7axxj2Ba/index.m3u8',
        'https://hn.bfvvs.com/play/DdwwgK8d/index.m3u8',
        'https://bfikuncdn.com/20230929/f0a53bgA/index.m3u8',
      ]);
      expect(lines.map((l) => l.label), ['gszy', 'hnzy', '线路3']);
      expect(lines.every((l) => l.prefersDirectConnection), isTrue);
      expect(lines.every((l) => l.headers.isEmpty), isTrue);
    });

    test('returns empty list on malformed payloads', () {
      expect(parseOmofunPlays('not json'), isEmpty);
      expect(parseOmofunPlays('[]'), isEmpty);
      expect(parseOmofunPlays('{"video_plays":"x"}'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/data/omofun/omofun_models_test.dart`
Expected: FAIL（`omofun_models.dart` 不存在，编译错误）

- [ ] **Step 3: 实现**

`lib/data/omofun/omofun_models.dart`:

```dart
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../domain/media/media_source.dart';

const omofunSourceId = 'omofun';

/// A search hit on omofun.in (`/vod/detail/<vodId>.html`).
class OmofunCandidate implements MediaCandidate {
  const OmofunCandidate({required this.vodId, required this.title});

  final String vodId;

  @override
  final String title;

  @override
  String get sourceId => omofunSourceId;
}

/// One episode, played via `/_dyn_plays/<vodId>/ep<ep>`.
class OmofunEpisode implements MediaEpisode {
  const OmofunEpisode({
    required this.vodId,
    required this.ep,
    required this.title,
  });

  final String vodId;
  final int ep;

  @override
  final String title;

  @override
  String get sourceId => omofunSourceId;
}

/// One m3u8 line from `video_plays`. CDN hosts are mainland resource
/// sites, so libmpv should bypass the user's proxy.
class OmofunPlaybackSource extends MediaPlaybackSource {
  const OmofunPlaybackSource({required this.url, required this.label});

  @override
  final String url;

  @override
  final String? label;

  @override
  Map<String, String> get headers => const {};

  @override
  bool get prefersDirectConnection => true;
}

final _detailHref = RegExp(r'/vod/detail/(\d+)\.html');

/// Parses `/vod/search.html?wd=` result cards. Cards without a title or a
/// numeric vodId are skipped.
List<OmofunCandidate> parseOmofunSearch(String html) {
  final doc = html_parser.parse(html);
  final results = <OmofunCandidate>[];
  for (final card in doc.querySelectorAll('div.module-card-item')) {
    final link = card.querySelector('.module-card-item-title a');
    if (link == null) continue;
    final title = (link.querySelector('strong')?.text ?? link.text).trim();
    final match = _detailHref.firstMatch(link.attributes['href'] ?? '');
    if (title.isEmpty || match == null) continue;
    results.add(OmofunCandidate(vodId: match.group(1)!, title: title));
  }
  return results;
}

/// Parses the first `.module-play-list-content` of a detail page. Links
/// outside that list (recommendations etc.) are ignored.
List<OmofunEpisode> parseOmofunEpisodes(String html, String vodId) {
  final list = html_parser.parse(html).querySelector('.module-play-list-content');
  if (list == null) return const [];
  final hrefPattern = RegExp(
    '^/vod/play/${RegExp.escape(vodId)}/ep(\\d+)\\.html\$',
  );
  final seen = <String>{};
  final episodes = <OmofunEpisode>[];
  for (final a in list.querySelectorAll('a')) {
    final href = a.attributes['href'] ?? '';
    final match = hrefPattern.firstMatch(href);
    if (match == null || !seen.add(href)) continue;
    final ep = int.parse(match.group(1)!);
    final span = a.querySelector('span')?.text.trim() ?? '';
    episodes.add(
      OmofunEpisode(vodId: vodId, ep: ep, title: span.isEmpty ? '第$ep集' : span),
    );
  }
  return episodes;
}

/// Parses the `/_dyn_plays` JSON. Dedupes by url (first wins), drops empty
/// and non-http(s) entries, labels each line with its `src_site`.
List<OmofunPlaybackSource> parseOmofunPlays(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map) return const [];
  final plays = decoded['video_plays'];
  if (plays is! List) return const [];

  final seen = <String>{};
  final lines = <OmofunPlaybackSource>[];
  for (final play in plays) {
    if (play is! Map) continue;
    final raw = play['play_data'];
    if (raw is! String) continue;
    final url = raw.trim();
    final scheme = Uri.tryParse(url)?.scheme;
    if (scheme != 'http' && scheme != 'https') continue;
    if (!seen.add(url)) continue;
    final site = play['src_site'];
    final label = site is String && site.trim().isNotEmpty
        ? site.trim()
        : '线路${lines.length + 1}';
    lines.add(OmofunPlaybackSource(url: url, label: label));
  }
  return lines;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/data/omofun/omofun_models_test.dart`
Expected: PASS（6 tests）

- [ ] **Step 5: Commit**

```bash
dart format lib/data/omofun test/data/omofun
git add lib/data/omofun/omofun_models.dart test/data/omofun/omofun_models_test.dart
git commit -m "feat(media): parse OmoFun search, episodes and play lines"
```

---

### Task 2: m3u8 线路探测器

**Files:**
- Create: `lib/data/omofun/m3u8_line_prober.dart`
- Create: `test/data/omofun/fake_http_adapter.dart`
- Test: `test/data/omofun/m3u8_line_prober_test.dart`

- [ ] **Step 1: 写测试辅助 adapter**

`test/data/omofun/fake_http_adapter.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Routes requests by full URL. Unknown URLs fail like an unreachable host.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  final Map<String, Future<ResponseBody> Function()> routes;
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    final route = routes[url];
    if (route == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'unreachable in test',
      );
    }
    return route();
  }

  @override
  void close({bool force = false}) {}
}

Future<ResponseBody> Function() respond(String body, [int status = 200]) =>
    () async => ResponseBody.fromString(body, status);
```

- [ ] **Step 2: 写失败测试**

`test/data/omofun/m3u8_line_prober_test.dart`:

```dart
import 'package:animeko_flutter/data/omofun/m3u8_line_prober.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http_adapter.dart';

const _m3u8 = '#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:10,\nseg0.ts\n';

void main() {
  Dio dioWith(Map<String, Future<ResponseBody> Function()> routes) =>
      Dio()..httpClientAdapter = FakeHttpAdapter(routes);

  test('keeps only 2xx #EXTM3U lines, preserving original order', () async {
    final dio = dioWith({
      'https://a.test/1.m3u8': respond(_m3u8),
      'https://b.test/2.m3u8': respond('forbidden', 403),
      'https://c.test/3.m3u8': respond('nope', 404),
      'https://d.test/4.m3u8': respond('<html>blocked</html>'),
      'https://f.test/6.m3u8': respond(_m3u8),
    });
    final lines = [
      'https://a.test/1.m3u8',
      'https://b.test/2.m3u8',
      'https://c.test/3.m3u8',
      'https://d.test/4.m3u8',
      'https://e.test/unreachable.m3u8',
      'https://f.test/6.m3u8',
    ];
    final live = await probeM3u8Lines(lines, urlOf: (l) => l, dio: dio);
    expect(live, ['https://a.test/1.m3u8', 'https://f.test/6.m3u8']);
  });

  test('drops lines slower than the timeout', () async {
    final dio = dioWith({
      'https://slow.test/x.m3u8': () => Future.delayed(
        const Duration(seconds: 1),
        () => ResponseBody.fromString(_m3u8, 200),
      ),
      'https://fast.test/x.m3u8': respond(_m3u8),
    });
    final live = await probeM3u8Lines(
      ['https://slow.test/x.m3u8', 'https://fast.test/x.m3u8'],
      urlOf: (l) => l,
      dio: dio,
      timeout: const Duration(milliseconds: 50),
    );
    expect(live, ['https://fast.test/x.m3u8']);
  });

  test('empty input returns empty output', () async {
    expect(await probeM3u8Lines(<String>[], urlOf: (l) => l, dio: Dio()), isEmpty);
  });

  group('looksLikeM3u8', () {
    test('accepts BOM and leading whitespace', () {
      // UTF-8 BOM bytes followed by whitespace and the tag.
      expect(
        looksLikeM3u8([0xEF, 0xBB, 0xBF, ...'\n  #EXTM3U\n'.codeUnits]),
        isTrue,
      );
      expect(looksLikeM3u8(' \n#EXTM3U'.codeUnits), isTrue);
    });

    test('rejects html and empty bodies', () {
      expect(looksLikeM3u8('<html>'.codeUnits), isFalse);
      expect(looksLikeM3u8(const []), isFalse);
    });
  });
}
```

- [ ] **Step 3: 运行确认失败**

Run: `flutter test test/data/omofun/m3u8_line_prober_test.dart`
Expected: FAIL（`m3u8_line_prober.dart` 不存在）

- [ ] **Step 4: 实现**

`lib/data/omofun/m3u8_line_prober.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const defaultProbeTimeout = Duration(seconds: 4);
const _maxProbeBytes = 1024;

/// Concurrently fetches the head of each line's top-level m3u8 and returns
/// only the lines that answered 2xx with a body starting with `#EXTM3U`
/// within [timeout]. Original order is preserved; failures are dropped
/// silently. Does not follow variant playlists or fetch segments.
Future<List<T>> probeM3u8Lines<T>(
  List<T> lines, {
  required String Function(T line) urlOf,
  required Dio dio,
  Duration timeout = defaultProbeTimeout,
}) async {
  final alive = await Future.wait(
    lines.map((line) => _isLive(dio, urlOf(line), timeout)),
  );
  return [
    for (var i = 0; i < lines.length; i++)
      if (alive[i]) lines[i],
  ];
}

/// True when [head] (first bytes of a response) is an HLS playlist.
bool looksLikeM3u8(List<int> head) {
  var text = utf8.decode(head, allowMalformed: true);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return text.trimLeft().startsWith('#EXTM3U');
}

Future<bool> _isLive(Dio dio, String url, Duration timeout) async {
  final cancel = CancelToken();
  try {
    return await _readHead(dio, url, cancel).timeout(timeout);
  } catch (_) {
    return false;
  } finally {
    if (!cancel.isCancelled) cancel.cancel();
  }
}

Future<bool> _readHead(Dio dio, String url, CancelToken cancel) async {
  final response = await dio.get<ResponseBody>(
    url,
    cancelToken: cancel,
    options: Options(
      responseType: ResponseType.stream,
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  );
  final body = response.data;
  if (body == null) return false;
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in body.stream) {
    bytes.add(chunk);
    if (bytes.length >= _maxProbeBytes) break;
  }
  return looksLikeM3u8(bytes.takeBytes());
}
```

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/data/omofun/m3u8_line_prober_test.dart`
Expected: PASS（5 tests）

- [ ] **Step 6: Commit**

```bash
dart format lib/data/omofun test/data/omofun
git add lib/data/omofun/m3u8_line_prober.dart test/data/omofun/fake_http_adapter.dart test/data/omofun/m3u8_line_prober_test.dart
git commit -m "feat(media): probe m3u8 lines and keep only live ones"
```

---

### Task 3: OmofunApi 与 providers

**Files:**
- Create: `lib/data/omofun/omofun_api.dart`
- Generated: `lib/data/omofun/omofun_api.g.dart`
- Test: `test/data/omofun/omofun_api_test.dart`

- [ ] **Step 1: 写失败测试**

`test/data/omofun/omofun_api_test.dart`:

```dart
import 'dart:io';

import 'package:animeko_flutter/data/omofun/omofun_api.dart';
import 'package:animeko_flutter/data/omofun/omofun_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import 'fake_http_adapter.dart';

class MockDio extends Mock implements Dio {}

Response<String> plainResponse(String body) => Response(
  data: body,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

// Captured live from https://omofun.in on 2026-09-28, trimmed.
const _searchHtml = '''
<div class="module-card-item module-item"><div class="module-card-item-title"><a href="/vod/detail/2023103093.html"><strong>葬送的芙莉莲</strong></a></div></div>
''';
const _detailHtml = '''
<div class="module-play-list-content"><a href="/vod/play/2023103093/ep1.html"><span>第01集</span></a></div>
''';
const _playsJson = '''
{"video_plays":[
 {"play_data":"https://dead.test/a/index.m3u8","src_site":"jszy"},
 {"play_data":"https://live.test/b/index.m3u8","src_site":"gszy"},
 {"play_data":"https://live2.test/c/index.m3u8","src_site":"hnzy"}
]}
''';

const _episode = OmofunEpisode(vodId: '2023103093', ep: 1, title: '第01集');
const _playsUrl = 'https://omofun.in/_dyn_plays/2023103093/ep1';

class _ProxyEverything extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'PROXY 127.0.0.1:1';
}

void main() {
  late MockDio siteDio;
  late FakeHttpAdapter probeAdapter;
  late OmofunApi api;

  setUp(() {
    siteDio = MockDio();
    probeAdapter = FakeHttpAdapter({
      'https://live.test/b/index.m3u8': respond('#EXTM3U\n'),
      'https://live2.test/c/index.m3u8': respond('#EXTM3U\n'),
    });
    api = OmofunApi(
      siteDio,
      probeDio: Dio()..httpClientAdapter = probeAdapter,
      probeTimeout: const Duration(milliseconds: 200),
    );
  });

  void stubPlays(String body) {
    when(
      () => siteDio.get<String>(_playsUrl, options: any(named: 'options')),
    ).thenAnswer((_) async => plainResponse(body));
  }

  test('search hits /vod/search.html with wd param', () async {
    when(
      () => siteDio.get<String>(
        'https://omofun.in/vod/search.html',
        queryParameters: {'wd': '葬送的芙莉莲'},
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => plainResponse(_searchHtml));

    final results = await api.search('葬送的芙莉莲');
    expect(results.single.vodId, '2023103093');
  });

  test('listEpisodes hits the detail page', () async {
    when(
      () => siteDio.get<String>(
        'https://omofun.in/vod/detail/2023103093.html',
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => plainResponse(_detailHtml));

    final eps = await api.listEpisodes('2023103093');
    expect(eps.single.ep, 1);
  });

  test('resolvePlayback returns only live lines in original order', () async {
    stubPlays(_playsJson);
    final lines = await api.resolvePlayback(_episode);
    expect(lines.map((l) => l.label), ['gszy', 'hnzy']);
    expect(lines.every((l) => l.prefersDirectConnection), isTrue);
  });

  test('resolvePlayback falls back to all lines when every probe fails', () async {
    probeAdapter.routes.clear();
    stubPlays(_playsJson);
    final lines = await api.resolvePlayback(_episode);
    expect(lines.map((l) => l.label), ['jszy', 'gszy', 'hnzy']);
  });

  test('resolvePlayback throws StateError when there are no lines', () async {
    stubPlays('{"video_plays":[]}');
    expect(api.resolvePlayback(_episode), throwsStateError);
  });

  test('resolvePlayback throws StateError when /_dyn_plays fails', () async {
    when(
      () => siteDio.get<String>(_playsUrl, options: any(named: 'options')),
    ).thenThrow(
      DioException.connectionError(
        requestOptions: RequestOptions(path: _playsUrl),
        reason: 'down',
      ),
    );
    expect(api.resolvePlayback(_episode), throwsStateError);
  });

  test('directHttpClientAdapter bypasses a global proxy override', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((req) {
      req.response.write('#EXTM3U');
      req.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/index.m3u8';

    await HttpOverrides.runWithHttpOverrides(() async {
      final direct = Dio()..httpClientAdapter = directHttpClientAdapter();
      expect((await direct.get<String>(url)).data, '#EXTM3U');

      await expectLater(Dio().get<String>(url), throwsA(isA<DioException>()));
    }, _ProxyEverything());
  });

  test('omofunApiProvider wires up', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(omofunApiProvider), isA<OmofunApi>());
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/data/omofun/omofun_api_test.dart`
Expected: FAIL（`omofun_api.dart` 不存在）

- [ ] **Step 3: 实现**

`lib/data/omofun/omofun_api.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'm3u8_line_prober.dart';
import 'omofun_models.dart';

part 'omofun_api.g.dart';

/// omofun.in announces omofun.tv as its newest domain; switch here if the
/// current one dies. No multi-domain fallback in v1.
const omofunBaseUrl = 'https://omofun.in';

const _desktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
const _siteTimeout = Duration(seconds: 15);

/// Scraper for omofun.in (MacCMS, mxpro theme). Site requests use [_dio]
/// (global proxy applies); line probes use [_probeDio] (forced direct, to
/// match how libmpv will fetch the stream).
class OmofunApi {
  OmofunApi(
    this._dio, {
    required Dio probeDio,
    this.probeTimeout = defaultProbeTimeout,
  }) : _probeDio = probeDio;

  final Dio _dio;
  final Dio _probeDio;
  final Duration probeTimeout;

  Future<List<OmofunCandidate>> search(String keyword) async {
    final res = await _dio.get<String>(
      '$omofunBaseUrl/vod/search.html',
      queryParameters: {'wd': keyword},
      options: Options(responseType: ResponseType.plain),
    );
    return parseOmofunSearch(res.data ?? '');
  }

  Future<List<OmofunEpisode>> listEpisodes(String vodId) async {
    final res = await _dio.get<String>(
      '$omofunBaseUrl/vod/detail/$vodId.html',
      options: Options(responseType: ResponseType.plain),
    );
    return parseOmofunEpisodes(res.data ?? '', vodId);
  }

  /// Returns the live lines, or every line if none probe as live (let the
  /// player's auto-fallback have a go). Throws [StateError] when the site
  /// returns no lines at all.
  Future<List<OmofunPlaybackSource>> resolvePlayback(
    OmofunEpisode episode,
  ) async {
    final String body;
    try {
      final res = await _dio.get<String>(
        '$omofunBaseUrl/_dyn_plays/${episode.vodId}/ep${episode.ep}',
        options: Options(responseType: ResponseType.plain),
      );
      body = res.data ?? '';
    } on DioException {
      throw StateError('omofun: no playable lines');
    }

    final lines = parseOmofunPlays(body);
    if (lines.isEmpty) throw StateError('omofun: no playable lines');

    try {
      final live = await probeM3u8Lines(
        lines,
        urlOf: (l) => l.url,
        dio: _probeDio,
        timeout: probeTimeout,
      );
      return live.isEmpty ? lines : live;
    } catch (_) {
      return lines;
    }
  }
}

/// An adapter whose clients never use a proxy, overriding whatever
/// `HttpOverrides.global` (the app proxy setting) configured.
IOHttpClientAdapter directHttpClientAdapter() => IOHttpClientAdapter(
  createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
);

@riverpod
Dio omofunDio(Ref ref) => Dio(
  BaseOptions(
    headers: {'User-Agent': _desktopUserAgent},
    connectTimeout: _siteTimeout,
    receiveTimeout: _siteTimeout,
  ),
);

@riverpod
Dio omofunProbeDio(Ref ref) =>
    Dio(BaseOptions(headers: {'User-Agent': _desktopUserAgent}))
      ..httpClientAdapter = directHttpClientAdapter();

@riverpod
OmofunApi omofunApi(Ref ref) => OmofunApi(
  ref.watch(omofunDioProvider),
  probeDio: ref.watch(omofunProbeDioProvider),
);
```

- [ ] **Step 4: 生成代码**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 生成 `lib/data/omofun/omofun_api.g.dart`，无错误。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/data/omofun/`
Expected: PASS（全部 omofun 测试）

- [ ] **Step 6: Commit**

```bash
dart format lib/data/omofun test/data/omofun
git add lib/data/omofun/omofun_api.dart lib/data/omofun/omofun_api.g.dart test/data/omofun/omofun_api_test.dart
git commit -m "feat(media): add OmoFun API with direct line probing"
```

---

### Task 4: 注册 OmofunMediaSource

**Files:**
- Modify: `lib/domain/media/media_registry.dart`（imports、AgedmMediaSource 之后加适配器、`mediaSources` 列表）
- Test: `test/domain/media/media_registry_test.dart`（mocks、新 group、注册断言 ~line 376）

- [ ] **Step 1: 写失败测试**

在 `test/domain/media/media_registry_test.dart`：

imports 中按字母序加入：

```dart
import 'package:animeko_flutter/data/omofun/omofun_api.dart';
import 'package:animeko_flutter/data/omofun/omofun_models.dart';
```

mocks 区（`class MockAgedmApi ...` 旁）加入：

```dart
class MockOmofunApi extends Mock implements OmofunApi {}
```

在 AgedmMediaSource group 之后加入：

```dart
  group('OmofunMediaSource', () {
    late MockOmofunApi api;
    late OmofunMediaSource source;

    setUp(() {
      api = MockOmofunApi();
      source = OmofunMediaSource(api);
    });

    test('id and displayName', () {
      expect(source.id, 'omofun');
      expect(source.displayName, 'OmoFun');
    });

    test('search delegates to the api', () async {
      const hit = OmofunCandidate(vodId: '1', title: '葬送的芙莉莲');
      when(() => api.search('葬送的芙莉莲')).thenAnswer((_) async => [hit]);
      expect(await source.search('葬送的芙莉莲', subjectId: 1), [hit]);
    });

    test('listEpisodes passes the vodId', () async {
      const ep = OmofunEpisode(vodId: '1', ep: 1, title: '第01集');
      when(() => api.listEpisodes('1')).thenAnswer((_) async => [ep]);
      expect(
        await source.listEpisodes(
          const OmofunCandidate(vodId: '1', title: 'x'),
        ),
        [ep],
      );
    });

    test('resolvePlayback delegates the episode', () async {
      const ep = OmofunEpisode(vodId: '1', ep: 1, title: '第01集');
      const line = OmofunPlaybackSource(url: 'https://a/i.m3u8', label: 'gszy');
      when(() => api.resolvePlayback(ep)).thenAnswer((_) async => [line]);
      expect(await source.resolvePlayback(ep), [line]);
    });
  });
```

把注册断言改为：

```dart
    expect(sources.map((s) => s.id), [
      'anime1',
      'xifan',
      'agedm',
      'omofun',
      'mikan',
    ]);
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/domain/media/media_registry_test.dart`
Expected: FAIL（`OmofunMediaSource` 未定义）

- [ ] **Step 3: 实现**

`lib/domain/media/media_registry.dart` imports 按字母序加入（`dilidili_models.dart` 之后）：

```dart
import '../../data/omofun/omofun_api.dart';
import '../../data/omofun/omofun_models.dart';
```

在 `AgedmMediaSource` 类之后加入：

```dart
/// Adapts [OmofunApi] to the shared [MediaSource] interface. See
/// [Anime1MediaSource]'s doc comment for the downcast-safety rationale.
class OmofunMediaSource implements MediaSource {
  OmofunMediaSource(this._api);
  final OmofunApi _api;

  @override
  String get id => omofunSourceId;

  @override
  String get displayName => 'OmoFun';

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.search(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.listEpisodes((candidate as OmofunCandidate).vodId);

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlayback(episode as OmofunEpisode);
}
```

`mediaSources` 列表中 `AgedmMediaSource(...)` 之后加入：

```dart
  OmofunMediaSource(ref.watch(omofunApiProvider)),
```

- [ ] **Step 4: 生成代码并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/domain/media/media_registry_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/domain/media/media_registry.dart lib/domain/media/media_registry.g.dart test/domain/media/media_registry_test.dart
git commit -m "feat(media): register OmoFun media source"
```

（若 `media_registry.g.dart` 无变化，`git add` 会忽略它。）

---

### Task 5: 全量验证

- [ ] **Step 1:** `dart format lib test` — 无改动或仅格式化改动（有则提交 `style: format`）。
- [ ] **Step 2:** `flutter analyze` — 无新的 error / warning。
- [ ] **Step 3:** `flutter test` — 全部通过。
- [ ] **Step 4（手动）:** `flutter run -d macos`，打开「葬送的芙莉莲」第 1 集：选源面板中出现 OmoFun；能播放；换线列表只含探测存活的线路（标签如 gszy / hnzy / ikzy）。
- [ ] **Step 5:** 如有修复，按 Conventional Commits 提交（如 `fix(media): ...`）。
