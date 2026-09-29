# OmoFun Offline Download Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the OmoFun media source downloadable for offline playback, fixing two blocking gaps discovered during design: OmoFun's HLS streams are AES-128 encrypted (the existing `HlsDownloader` never fetches the key file) and OmoFun's CDNs need to bypass the user's configured proxy exactly like online playback already does (the download pipeline never reads `MediaPlaybackSource.prefersDirectConnection`).

**Architecture:** Generically extend shared download infrastructure (per approved design, Approach A) rather than special-casing OmoFun: (1) teach `HlsDownloader` to detect and download `#EXT-X-KEY` referenced key files, rewriting the playlist to point at the local copy; (2) relocate the existing `directHttpClientAdapter()` helper from `omofun_api.dart` into the shared `proxy_dio_config.dart` module and add a `downloadDirectDioProvider`; (3) give `DownloadWorker` an optional second `Dio` used whenever the selected `MediaPlaybackSource.prefersDirectConnection` is true; (4) add a scoped mpv demuxer property toggle so locally downloaded encrypted HLS content can actually decrypt and play back (a real bug verified by hand with `mpv` during design, independent of the download pipeline itself); (5) add `'omofun'` to both places that gate which sources are downloadable. Every change here also benefits `agedm`, which has the identical latent proxy-bypass gap today.

**Tech Stack:** Flutter/Dart, Riverpod (`@riverpod` codegen), Dio (`dio`/`dio/io.dart`), Drift (unchanged), media_kit/libmpv (`NativePlayer.setProperty`), `flutter_test` + hand-rolled `HttpClientAdapter` fakes (no HTTP mocking library used anywhere in this pipeline).

---

## Before you start

Run `flutter pub get` if you haven't already this session. After any task that adds/changes a `@riverpod` provider, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

All commands below are run from the repo root (`/Users/portz/js/animeko-flutter`) unless noted.

---

### Task 1: HlsDownloader AES-128 key support

**Files:**
- Modify: `lib/data/download/hls_downloader.dart`
- Test: `test/data/download/hls_downloader_test.dart`

OmoFun's HLS media playlists contain a line like:

```
#EXT-X-KEY:METHOD=AES-128,URI="enc.key",IV=0x00000000000000000000000000000000
```

`HlsDownloader` currently copies every `#`-prefixed line verbatim into the rewritten local playlist without ever fetching what `URI="..."` points at. A player opening the local playlist will try to fetch `enc.key` from the *original remote path* (relative to nothing, since the playlist is now local) and fail, or fail differently depending on the player. This task makes `HlsDownloader` download the key file next to the segments and rewrite the `URI=` attribute to a local filename, while leaving `METHOD=`/`IV=` untouched (the IV is required for decryption and must not change).

- [ ] **Step 1: Write the failing tests**

Open `test/data/download/hls_downloader_test.dart` and add these three tests inside the existing `main()` (alongside the existing tests, using the existing `fakeDio()` helper):

```dart
  test('downloads an AES-128 key referenced by #EXT-X-KEY and rewrites its '
      'URI to the local file', () async {
    final dio = fakeDio({
      'https://cdn.example/episode/playlist.m3u8':
          '#EXTM3U\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="enc.key",'
          'IV=0x00000000000000000000000000000000\n'
          '#EXTINF:4.0,\n'
          'segment0.ts\n',
      'https://cdn.example/episode/enc.key': <int>[1, 2, 3, 4, 5, 6, 7, 8, 9,
          10, 11, 12, 13, 14, 15, 16],
      'https://cdn.example/episode/segment0.ts': <int>[9, 9, 9],
    });
    final targetDirectory = await Directory.systemTemp.createTemp(
      'hls_downloader_test_',
    );
    addTearDown(() => targetDirectory.delete(recursive: true));

    await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/playlist.m3u8'),
      targetDirectory: targetDirectory,
    );

    final keyFile = File('${targetDirectory.path}/key_0000.key');
    expect(await keyFile.exists(), isTrue);
    expect(
      await keyFile.readAsBytes(),
      <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    );

    final playlist = File('${targetDirectory.path}/playlist.m3u8');
    final rewritten = await playlist.readAsString();
    expect(rewritten, contains('URI="key_0000.key"'));
    expect(rewritten, contains('METHOD=AES-128'));
    expect(
      rewritten,
      contains('IV=0x00000000000000000000000000000000'),
    );
    expect(rewritten, isNot(contains('URI="enc.key"')));
  });

  test('does not re-download the key file if it already exists locally',
      () async {
    final dio = fakeDio({
      'https://cdn.example/episode/playlist.m3u8':
          '#EXTM3U\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="enc.key",'
          'IV=0x00000000000000000000000000000000\n'
          '#EXTINF:4.0,\n'
          'segment0.ts\n',
      // No entry for enc.key -- if the downloader tries to fetch it,
      // the fake adapter returns a 404 and the test fails.
      'https://cdn.example/episode/segment0.ts': <int>[9, 9, 9],
    });
    final targetDirectory = await Directory.systemTemp.createTemp(
      'hls_downloader_test_',
    );
    addTearDown(() => targetDirectory.delete(recursive: true));
    await File(
      '${targetDirectory.path}/key_0000.key',
    ).writeAsBytes(<int>[42, 42]);

    await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/playlist.m3u8'),
      targetDirectory: targetDirectory,
    );

    expect(
      await File('${targetDirectory.path}/key_0000.key').readAsBytes(),
      <int>[42, 42],
    );
  });

  test('propagates an error when the key file fails to download', () async {
    final dio = fakeDio({
      'https://cdn.example/episode/playlist.m3u8':
          '#EXTM3U\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="enc.key",'
          'IV=0x00000000000000000000000000000000\n'
          '#EXTINF:4.0,\n'
          'segment0.ts\n',
      // enc.key deliberately omitted -> fake adapter 404s.
      'https://cdn.example/episode/segment0.ts': <int>[9, 9, 9],
    });
    final targetDirectory = await Directory.systemTemp.createTemp(
      'hls_downloader_test_',
    );
    addTearDown(() => targetDirectory.delete(recursive: true));

    await expectLater(
      HlsDownloader(dio).download(
        manifestUrl: Uri.parse('https://cdn.example/episode/playlist.m3u8'),
        targetDirectory: targetDirectory,
      ),
      throwsA(isA<DioException>()),
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/download/hls_downloader_test.dart`
Expected: the 3 new tests FAIL (key file never created / `enc.key` never fetched / no exception thrown), the pre-existing tests still PASS.

- [ ] **Step 3: Implement key handling**

Open `lib/data/download/hls_downloader.dart` and read it in full first (92 lines) to see the exact current structure of `download()`. Add a top-level regex and a helper function, then wire the key-download step into `download()` right after the `output` list is built (i.e. after master-variant resolution, before the segment-download loop) so that a key-download failure surfaces before any segment work starts:

```dart
final _keyUriPattern = RegExp(r'URI="([^"]*)"');

/// Downloads the AES-128 key referenced by a `#EXT-X-KEY` line (if any)
/// and returns the rewritten line pointing at the local key file, or
/// `null` if [line] isn't a `#EXT-X-KEY` line or has no `URI=` attribute.
///
/// OmoFun's HLS streams are AES-128 encrypted with a fixed all-zero IV
/// (confirmed by hand against a live stream during design -- the key
/// never rotates, so a downloaded key stays valid for the episode's
/// full runtime). `METHOD=`/`IV=` attributes are preserved verbatim;
/// only `URI=` is rewritten, so decryption still works against the
/// locally saved key file.
Future<String?> _rewriteKeyLine(
  String line,
  Uri playlistUrl,
  Map<String, String> headers,
  Directory targetDirectory,
  Dio dio,
) async {
  if (!line.startsWith('#EXT-X-KEY')) return null;
  final match = _keyUriPattern.firstMatch(line);
  if (match == null) return null;
  final keyUri = playlistUrl.resolve(match.group(1)!);
  final keyFile = File('${targetDirectory.path}/key_0000.key');
  final alreadyDownloaded =
      await keyFile.exists() && await keyFile.length() > 0;
  if (!alreadyDownloaded) {
    await dio.downloadUri(
      keyUri,
      keyFile.path,
      options: Options(headers: headers),
    );
  }
  return line.replaceFirst(_keyUriPattern, 'URI="key_0000.key"');
}
```

Then, inside `download()`, right after the `output` list (mutable copy of `lines`) is created and before the segment-download loop, add:

```dart
    for (var index = 0; index < output.length; index++) {
      final rewritten = await _rewriteKeyLine(
        output[index],
        playlistUrl,
        headers,
        targetDirectory,
        _dio,
      );
      if (rewritten != null) output[index] = rewritten;
    }
```

This loop is a no-op for anime1/xifan/agedm playlists (no `#EXT-X-KEY` line matches `line.startsWith('#EXT-X-KEY')`, so `_rewriteKeyLine` returns `null` for every line and `output` is unchanged) -- fully backward-compatible.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/download/hls_downloader_test.dart`
Expected: all tests PASS (3 new + all pre-existing).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/data/download/hls_downloader.dart test/data/download/hls_downloader_test.dart
flutter analyze lib/data/download/hls_downloader.dart test/data/download/hls_downloader_test.dart
git add lib/data/download/hls_downloader.dart test/data/download/hls_downloader_test.dart
git commit -m "feat(download): fetch and rewrite AES-128 HLS keys locally"
```

Confirm via `git status` that only these two files are staged before committing.

---

### Task 2: Relocate directHttpClientAdapter and add a download-side direct Dio

**Files:**
- Modify: `lib/data/settings/proxy_dio_config.dart`
- Modify: `lib/data/omofun/omofun_api.dart`
- Modify: `test/data/settings/proxy_dio_config_test.dart`
- Modify: `test/data/omofun/omofun_api_test.dart`

`directHttpClientAdapter()` (an `IOHttpClientAdapter` whose `HttpClient` always has `findProxy` forced to `'DIRECT'`, bypassing whatever `HttpOverrides.global` set) currently lives only in `omofun_api.dart`, private to that one file's probe Dio. The download pipeline needs the exact same capability for any `prefersDirectConnection == true` source (currently `agedm` and `omofun`). This task moves the helper to the shared `lib/data/settings/proxy_dio_config.dart` module (which already owns `decideProxy()`/`ProxyHttpOverrides`) and adds a new `downloadDirectDioProvider` there for the download pipeline to use in Task 3.

- [ ] **Step 1: Write the failing test for the relocated function and the new provider**

Open `test/data/settings/proxy_dio_config_test.dart` and read it in full first (179 lines) to see existing groups/imports/helpers. Add this new group at the end of `main()`, after the existing groups. It needs `dart:io`, `package:dio/dio.dart`, and `package:riverpod/riverpod.dart` imports added at the top if not already present (check first -- `dart:io` almost certainly already is; add `package:dio/dio.dart` and `package:riverpod/riverpod.dart` if missing):

```dart
  group('directHttpClientAdapter', () {
    test('bypasses a global proxy override', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      unawaited(
        server.forEach((request) {
          request.response.write('#EXTM3U\n#EXTINF:1,\nseg.ts');
          request.response.close();
        }),
      );
      final loopbackUrl = 'http://127.0.0.1:${server.port}/playlist.m3u8';

      await HttpOverrides.runWithHttpOverrides(() async {
        final direct = Dio()..httpClientAdapter = directHttpClientAdapter();
        final response = await direct.get<String>(loopbackUrl);
        expect(response.data, contains('#EXTM3U'));

        final plain = Dio();
        await expectLater(
          plain.get<String>(loopbackUrl),
          throwsA(isA<DioException>()),
        );
      }, _ProxyEverything());
    });
  });

  group('downloadDirectDioProvider', () {
    test('is configured with the direct-connection adapter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final dio = container.read(downloadDirectDioProvider);
      expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
    });
  });
```

Also add this class near the bottom of the test file (or wherever other top-level test helper classes live in the file):

```dart
class _ProxyEverything extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'PROXY 127.0.0.1:1';
}
```

Add `import 'package:dio/io.dart';` if `IOHttpClientAdapter` isn't already referenced/imported in this test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/settings/proxy_dio_config_test.dart`
Expected: FAIL with "Undefined name 'directHttpClientAdapter'" / "Undefined name 'downloadDirectDioProvider'" (compile error).

- [ ] **Step 3: Implement the relocation and the new provider**

Open `lib/data/settings/proxy_dio_config.dart` and read it in full first (106 lines). Add these imports at the top (alongside the existing `dart:io` and `package:riverpod_annotation/riverpod_annotation.dart`):

```dart
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
```

Add this function anywhere after the existing `decideProxy`/`ProxyHttpOverrides` definitions (e.g. right before `installProxyHttpOverrides`):

```dart
/// Builds a Dio [IOHttpClientAdapter] whose underlying [HttpClient] always
/// forces `findProxy` to `'DIRECT'`, unconditionally bypassing whatever
/// [HttpOverrides.global] set (e.g. [ProxyHttpOverrides]). Used for CDNs
/// that only work when accessed directly -- see
/// [MediaPlaybackSource.prefersDirectConnection] on [AgedmPlaybackSource]
/// and [OmofunPlaybackSource].
IOHttpClientAdapter directHttpClientAdapter() =>
    IOHttpClientAdapter(createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT');
```

Add a desktop user-agent constant and the new provider (mirroring `downloadDio` in `download_queue_controller.dart`, but with the direct adapter and a UA, since download requests go straight to the CDN without a browser session in front of them):

```dart
const _directDownloadUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

/// A [Dio] instance for the download pipeline that bypasses the user's
/// configured proxy, for use with [MediaPlaybackSource] candidates whose
/// [MediaPlaybackSource.prefersDirectConnection] is `true`.
@riverpod
Dio downloadDirectDio(Ref ref) =>
    Dio(BaseOptions(headers: {'User-Agent': _directDownloadUserAgent}))
      ..httpClientAdapter = directHttpClientAdapter();
```

Add `part 'proxy_dio_config.g.dart';` near the top of the file (after the imports, before the first class/function) if it isn't already present -- check first, since this file may not have had any `@riverpod` members before this change.

Now update `lib/data/omofun/omofun_api.dart`: remove the local `directHttpClientAdapter()` function (currently at lines 88-90) and its now-unused imports (`dart:io` and `package:dio/io.dart` -- check whether either is still referenced elsewhere in the file before removing; if `HttpClient`/`IOHttpClientAdapter` types aren't used anywhere else in this file, remove both imports). Add:

```dart
import '../settings/proxy_dio_config.dart';
```

in the correct alphabetical import position. The existing call site (`omofunProbeDio` provider) does not need to change at all -- `directHttpClientAdapter()` is called the same way, just imported from a different module now.

- [ ] **Step 4: Regenerate codegen and run tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/data/settings/proxy_dio_config_test.dart
```
Expected: PASS.

- [ ] **Step 5: Move the now-redundant test out of omofun_api_test.dart**

Open `test/data/omofun/omofun_api_test.dart` and read it in full (149 lines). Delete the entire `'directHttpClientAdapter bypasses a global proxy override'` test (currently around lines 127-142) and the `_ProxyEverything` class it uses (now duplicated in `proxy_dio_config_test.dart` from Step 1 -- it's fine for both test files to have their own private copy of this tiny helper class; do not try to share it across test files). If `dart:io` (for `HttpServer`/`HttpOverrides`) is no longer used anywhere else in this test file after removing that test, remove the now-unused import.

Run: `flutter test test/data/omofun/omofun_api_test.dart`
Expected: remaining tests still PASS (search/listEpisodes/resolvePlayback/provider-wiring tests untouched).

- [ ] **Step 6: Full verification and commit**

```bash
flutter test test/data/omofun/ test/data/settings/proxy_dio_config_test.dart
flutter analyze lib/data/settings/proxy_dio_config.dart lib/data/omofun/omofun_api.dart test/data/settings/proxy_dio_config_test.dart test/data/omofun/omofun_api_test.dart
dart format lib/data/settings/proxy_dio_config.dart lib/data/omofun/omofun_api.dart test/data/settings/proxy_dio_config_test.dart test/data/omofun/omofun_api_test.dart
git add lib/data/settings/proxy_dio_config.dart lib/data/settings/proxy_dio_config.g.dart lib/data/omofun/omofun_api.dart lib/data/omofun/omofun_api.g.dart test/data/settings/proxy_dio_config_test.dart test/data/omofun/omofun_api_test.dart
git commit -m "refactor(media): share the direct-connection Dio adapter with downloads"
```

Confirm via `git status` that only the intended files are touched (note `omofun_api.g.dart` will change hash-only if anything, and `proxy_dio_config.g.dart` is newly generated).

---

### Task 3: Wire a direct-connection Dio through the download pipeline

**Files:**
- Modify: `lib/data/download/download_worker.dart`
- Modify: `lib/domain/download/download_queue_controller.dart`
- Test: `test/data/download/download_worker_test.dart`

`DownloadWorker` currently always uses the single `Dio` it was constructed with, for both `HlsDownloader` and the plain-file `_downloadFile` path. This task adds an optional second `Dio` (`directDio`) that's used instead whenever the resolved `MediaPlaybackSource.prefersDirectConnection` is `true`, and wires `DownloadQueueController` to supply `downloadDirectDioProvider` (from Task 2) as that second Dio in production.

`directDio` must be **optional** (nullable, defaulting to the primary `dio` when not supplied) -- `download_worker_test.dart` has dozens of existing `DownloadWorker(...)` construction call sites that don't pass it, and making it required would force a large, purely-mechanical edit across that entire 609-line file for no benefit.

- [ ] **Step 1: Write the failing test**

Open `test/data/download/download_worker_test.dart` and read it in full first (609 lines) to confirm the exact current helper signatures (`_PlaybackSource`, `_Source`, `_Adapter`, `_dio()`, `_request()`) before adding to them. Add a new playback-source helper class near the existing `_PlaybackSource` (it doesn't override `prefersDirectConnection`, so a dedicated subclass is needed for this test):

```dart
class _DirectPlaybackSource extends MediaPlaybackSource {
  const _DirectPlaybackSource(this.url);
  @override
  final String url;
  @override
  Map<String, String> get headers => const {};
  @override
  bool get prefersDirectConnection => true;
}
```

Then add this test in the same `group`/section as the existing 'accepts an AGE download request' test. It deliberately uses `sourceId: 'agedm'` (already allow-listed today) rather than `'omofun'` (not allow-listed until Task 4) -- this test is about the Dio-selection *mechanism* being wired correctly, which is independent of which source IDs are allow-listed, and using an already-allowed source keeps this task fully self-contained and green on its own, without a forward dependency on Task 4:

```dart
  test('uses directDio for candidates that prefer a direct connection',
      () async {
    final directDio = _dio({
      'https://cdn.example/direct.mp4': const _HttpResponse(
        statusCode: 200,
        body: [1, 2, 3],
        headers: {'content-length': '3'},
      ),
    });
    final regularDio = _dio({});
    final worker = DownloadWorker(
      dio: regularDio,
      directDio: directDio,
      sourceForId: (_) => _Source(
        'agedm',
        const [_DirectPlaybackSource('https://cdn.example/direct.mp4')],
      ),
      repository: repository,
    );
    final request = _request('agedm', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    expect(await repository.findCompleted(request.episodeKey), isNotNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: FAIL with a compile error ("no named parameter 'directDio'") since `directDio` doesn't exist on `DownloadWorker` yet.

- [ ] **Step 3: Implement directDio in DownloadWorker**

Open `lib/data/download/download_worker.dart` and read it in full (456 lines) to confirm exact current line numbers before editing (they may have shifted slightly from Task 1/2, though those tasks didn't touch this file). Modify the constructor:

```dart
class DownloadWorker {
  DownloadWorker({
    required Dio dio,
    Dio? directDio,
    required MediaSource Function(String sourceId) sourceForId,
    required DownloadedEpisodeRepository repository,
    this.stallTimeout = const Duration(seconds: 30),
    this.noProgressTimeout = const Duration(minutes: 2),
    this.stallCheckInterval = const Duration(seconds: 1),
    DateTime Function() now = DateTime.now,
  })  : _dio = dio,
        _directDio = directDio ?? dio,
        _sourceForId = sourceForId,
        _repository = repository,
        _now = now;
  final Dio _dio;
  final Dio _directDio;
  ...
```

(Keep every other existing field/parameter exactly as-is -- only add the `directDio` parameter and the `_directDio` field, initialized to `directDio ?? dio` so every pre-existing call site that omits it keeps working unchanged.)

In `_attempt()`, find the line that picks `selected` from `candidates` (`candidates.firstWhere((c) => c.url.toLowerCase().contains('.mp4'), orElse: () => candidates.first)`) and, further down where `isHls`/the HLS-vs-mp4 branch calls `HlsDownloader(_dio)` and `_downloadFile(url, localPath, selected.headers, onProgress)`, change both call sites to pick the right Dio based on `selected.prefersDirectConnection`:

```dart
      final activeDio = selected.prefersDirectConnection ? _directDio : _dio;
      final size = isHls
          ? (await HlsDownloader(activeDio).download(
              manifestUrl: Uri.parse(url),
              targetDirectory: directory,
              headers: selected.headers,
              cancelToken: _cancelToken,
              onProgress: onProgress,
            )).fileSizeBytes
          : await _downloadFile(
              url,
              localPath,
              selected.headers,
              onProgress,
              dio: activeDio,
            );
```

Update `_downloadFile`'s signature to accept the dio to use instead of always closing over `_dio`:

```dart
  Future<int> _downloadFile(
    String url,
    String path,
    Map<String, String> headers,
    void Function(int received, int total) onProgress, {
    required Dio dio,
  }) async {
    final response = await dio.download(
      url,
      path,
      cancelToken: _cancelToken,
      options: Options(headers: headers, validateStatus: (_) => true),
      onReceiveProgress: onProgress,
    );
    ...
```

(Keep the rest of `_downloadFile`'s body -- the validation logic after the download call -- exactly as it is today; only the Dio source and the added named parameter change.)

- [ ] **Step 4: Wire DownloadQueueController to supply directDio**

Open `lib/domain/download/download_queue_controller.dart` and find the `DownloadWorker(...)` construction inside `build()` (currently `DownloadWorker(dio: ref.read(downloadDioProvider), sourceForId: ..., repository: _repository)`). Add the import:

```dart
import '../../data/settings/proxy_dio_config.dart';
```

in the correct alphabetical position, and update the constructor call:

```dart
    _worker = DownloadWorker(
      dio: ref.read(downloadDioProvider),
      directDio: ref.read(downloadDirectDioProvider),
      sourceForId: (id) => sources.firstWhere((source) => source.id == id),
      repository: _repository,
    );
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/download/download_worker_test.dart test/domain/download/download_queue_controller_test.dart`
Expected: ALL tests PASS, including the new `'uses directDio for candidates that prefer a direct connection'` test from Step 1.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/data/download/download_worker.dart lib/domain/download/download_queue_controller.dart test/data/download/download_worker_test.dart
flutter analyze lib/data/download/download_worker.dart lib/domain/download/download_queue_controller.dart test/data/download/download_worker_test.dart
git add lib/data/download/download_worker.dart lib/domain/download/download_queue_controller.dart test/data/download/download_worker_test.dart
git commit -m "feat(download): use a direct-connection Dio for direct-preferring sources"
```

---

### Task 4: Allow OmoFun downloads in DownloadWorker's allow-list

**Files:**
- Modify: `lib/data/download/download_worker.dart`
- Test: `test/data/download/download_worker_test.dart`

- [ ] **Step 1: Write the failing test**

Add this test to `test/data/download/download_worker_test.dart`, right next to the existing `'accepts an AGE download request'` test, mirroring it exactly:

```dart
  test('accepts an OmoFun download request', () async {
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/omofun.mp4': const _HttpResponse(
          statusCode: 200,
          body: [1, 2, 3],
          headers: {'content-length': '3'},
        ),
      }),
      sourceForId: (_) => _Source(
        'omofun',
        const [_PlaybackSource('https://cdn.example/omofun.mp4')],
      ),
      repository: repository,
    );
    final request = _request('omofun', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    expect(await repository.findCompleted(request.episodeKey), isNotNull);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: this new test FAILS (episode ends up `failed` with `'此来源不支持下载'`, not `completed`) because `'omofun'` isn't yet in the allow-list. All other tests in the file, including Task 3's `'uses directDio for candidates that prefer a direct connection'` test, continue to PASS.

- [ ] **Step 3: Update the allow-list**

Open `lib/data/download/download_worker.dart`, find `enqueue()`'s allow-list check (`if (request.sourceId != 'anime1' && request.sourceId != 'xifan' && request.sourceId != 'agedm') {`) and add the fourth condition:

```dart
  void enqueue(DownloadRequest request) {
    if (request.sourceId != 'anime1' &&
        request.sourceId != 'xifan' &&
        request.sourceId != 'agedm' &&
        request.sourceId != 'omofun') {
      unawaited(_failUnsupportedSource(request));
      return;
    }
    ...
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: ALL tests PASS, including both the new `'accepts an OmoFun download request'` test and Task 3's `'uses directDio for candidates that prefer a direct connection'` test.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/data/download/download_worker.dart test/data/download/download_worker_test.dart
flutter analyze lib/data/download/download_worker.dart test/data/download/download_worker_test.dart
git add lib/data/download/download_worker.dart test/data/download/download_worker_test.dart
git commit -m "feat(download): allow OmoFun source downloads"
```

---

### Task 5: Add OmoFun to the downloadable-source priority list

**Files:**
- Modify: `lib/domain/download/download_source_resolver.dart`
- Test: `test/domain/download/download_source_resolver_test.dart`

- [ ] **Step 1: Write the failing tests**

Open `test/domain/download/download_source_resolver_test.dart` and read it in full (101 lines). Add these three tests, mirroring the existing `'an episode with only agedm is downloadable'` test (lines 57-62) and the priority test:

```dart
  test('an episode with only omofun is downloadable', () {
    final options = resolveDownloadOptions([_e('omofun', '第1集')]);
    expect(options.single.isDownloadable, isTrue);
    expect(options.single.preferred!.sourceId, 'omofun');
  });

  test('prefers agedm over omofun when both are available', () {
    final options = resolveDownloadOptions([
      _e('omofun', '第1集'),
      _e('agedm', '第1集'),
    ]);
    expect(options.single.preferred!.sourceId, 'agedm');
  });

  test('prefers omofun over a non-downloadable source like mikan', () {
    final options = resolveDownloadOptions([
      _e('mikan', '第1集'),
      _e('omofun', '第1集'),
    ]);
    expect(options.single.isDownloadable, isTrue);
    expect(options.single.preferred!.sourceId, 'omofun');
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/domain/download/download_source_resolver_test.dart`
Expected: FAIL -- `'an episode with only omofun is downloadable'` fails because `omofun`-only episodes currently have `isDownloadable == false`; `'prefers omofun over a non-downloadable source like mikan'` fails similarly.

- [ ] **Step 3: Update the priority list**

Open `lib/domain/download/download_source_resolver.dart` and change line 9:

```dart
const downloadableSourcePriority = ['anime1', 'xifan', 'agedm', 'omofun'];
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/domain/download/download_source_resolver_test.dart`
Expected: ALL tests PASS (3 new + all pre-existing).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/domain/download/download_source_resolver.dart test/domain/download/download_source_resolver_test.dart
flutter analyze lib/domain/download/download_source_resolver.dart test/domain/download/download_source_resolver_test.dart
git add lib/domain/download/download_source_resolver.dart test/domain/download/download_source_resolver_test.dart
git commit -m "feat(download): add OmoFun to the downloadable source priority list"
```

---

### Task 6: Scoped mpv demuxer toggle for encrypted local HLS playback

**Files:**
- Modify: `lib/ui/player/player_screen.dart`

Even once a downloaded OmoFun episode has its key and segments saved locally (Task 1), stock mpv fails to play it back: mpv's native "extended-M3U playlist of separate files" parser takes precedence over ffmpeg's HLS demuxer for *local* `.m3u8` files, so it tries to open each still-encrypted `segment_NNNN.ts` file directly and fails ("unrecognized file format"). Forcing the lavf/HLS demuxer surfaces a second, distinct failure: ffmpeg's `allowed_extensions` protocol whitelist blocks opening the local `.key` file for security reasons (a `.key` extension isn't in ffmpeg's default multimedia whitelist).

This was verified by hand during design with a real local `mpv` invocation: setting the property `demuxer-lavf-o=allowed_extensions=ALL` *alone* (without needing to also force `--demuxer=lavf`) makes mpv's own auto-probe correctly pick the lavf/HLS demuxer for the local file AND allows it to open the local key file -- `mpv --no-config --vo=null --ao=null --length=3 --demuxer-lavf-o=allowed_extensions=ALL playlist.m3u8` produced clean `AV: ...` progress and a clean EOF exit against a synthetic encrypted local playlist.

This toggle relaxes ffmpeg's local-file-read protection, so it must be scoped to *only* fire when opening a locally downloaded file (never for network URLs, where the app is trusting a third-party-hosted m3u8 it doesn't control) -- exactly mirroring how `_configureProxy` already scopes the proxy bypass per-candidate rather than globally.

There is no existing automated test for `_configureProxy` itself (this file has no `player_screen_test.dart` -- it's a heavily media_kit-dependent `StatefulWidget` exercised only via the sibling widget tests for its sub-components, e.g. `player_bottom_bar_test.dart`, `player_top_bar_test.dart`, `line_switch_sheet_test.dart`, none of which touch `_openCandidate`/`_configureProxy`). This task therefore has no new automated test; correctness is confirmed by code review plus the manual verification in Task 7.

- [ ] **Step 1: Add the import**

Open `lib/ui/player/player_screen.dart` and add this import in alphabetical position (between the existing `import '../../domain/download/download_source_resolver.dart';` and `import '../../domain/media/media_registry.dart';`):

```dart
import '../../domain/download/local_file_playback_source.dart';
```

- [ ] **Step 2: Add the toggle method, mirroring `_configureProxy`**

Right after the existing `_configureProxy` method (ends at line 285) and before `_isLoopbackUrl` (line 291), add:

```dart
  /// Relaxes ffmpeg's local-file-read whitelist so mpv's HLS demuxer can
  /// open a key file saved alongside a downloaded playlist (see
  /// `HlsDownloader`'s `#EXT-X-KEY` handling). Scoped to only apply when
  /// opening a [LocalFilePlaybackSource] -- never for network playback of
  /// a third-party-hosted m3u8, since this option weakens a security
  /// boundary and downloaded files are the only ones this app writes
  /// (and therefore fully trusts) itself.
  Future<void> _configureDemuxerOptions(MediaPlaybackSource source) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    await platform.setProperty(
      'demuxer-lavf-o',
      source is LocalFilePlaybackSource ? 'allowed_extensions=ALL' : '',
    );
  }
```

- [ ] **Step 3: Call it from `_openCandidate`**

Find `_openCandidate` (around line 601) and add the call right after the existing `_configureProxy` call:

```dart
    final playableUrl = await source.prepare();
    await _configureProxy(source, playableUrl);
    await _configureDemuxerOptions(source);
    await _player.open(Media(playableUrl, httpHeaders: source.headers));
```

- [ ] **Step 4: Analyze and commit**

```bash
dart format lib/ui/player/player_screen.dart
flutter analyze lib/ui/player/player_screen.dart
flutter test test/ui/player/
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): allow mpv to open locally saved HLS decryption keys"
```

(`flutter test test/ui/player/` reruns the existing sub-component widget tests as a smoke check -- none of them exercise `_openCandidate` directly, so this is a compile/regression check, not new coverage for this change.)

---

### Task 7: Final verification

No new files. Automated steps first, then one manual step that can't be scripted.

- [ ] **Step 1: Format everything touched by this feature**

```bash
dart format lib test
```
Expected: no changes, or only changes inside files touched by Tasks 1-6 above. If any unrelated file changes (pre-existing formatter-version drift, seen before in this repo), revert those specific files with `git checkout -- <file>` and do not include them in this feature's commits.

- [ ] **Step 2: Analyze**

```bash
flutter analyze
```
Expected: no new errors or warnings compared to before this feature (existing pre-existing `info`-level lints, e.g. `depend_on_referenced_packages` on test-only `riverpod` imports, are fine and predate this work).

- [ ] **Step 3: Full test suite**

```bash
flutter test
```
Expected: the full suite passes. If 1-2 unrelated tests fail (e.g. timing-sensitive auth tests), re-run just those files in isolation and then the full suite again to confirm it's flakiness, not a regression, before concluding this step.

- [ ] **Step 4: Manual verification (cannot be automated)**

```bash
flutter run -d macos
```

In the running app:
1. Search for 葬送的芙莉莲 (Frieren), open episode 1.
2. Switch to the OmoFun source (via the line/source picker) to confirm it's still playable online (regression check for Tasks 2/3's Dio changes).
3. Trigger a download of that episode from the OmoFun source (episode list checkbox or the player's download button).
4. Confirm the download completes successfully (check the download management screen for a `completed` state, not `failed`).
5. Fully close and reopen the app (or otherwise force offline-first playback, e.g. via airplane mode / disabling network) and open the same episode again -- confirm it plays from the local download with working video AND audio (this specifically exercises Task 1's key-download + Task 6's demuxer toggle together; a "video plays but audio is garbled" or "fails to open" result means one of those two didn't work).
6. If a system proxy is configured on the test machine, confirm playback (both online via OmoFun and the local download) works regardless -- exercises Task 2/3's direct-connection wiring.

- [ ] **Step 5: Fix-up commits if needed**

If manual verification in Step 4 surfaces any issue, fix it and commit following Conventional Commits (e.g. `fix(download): ...` or `fix(player): ...`), then re-run Step 4 from the top.
