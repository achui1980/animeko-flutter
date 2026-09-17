# 离线视频下载 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Anime1 和稀饭（Xifan）的 HTTP 视频源提供可排队、可管理、可离线优先播放的本地下载功能。

**Architecture:** 使用一个纯 Dart 的 `DownloadWorker` 严格按 FIFO 顺序执行任务，并由薄 Riverpod `DownloadQueueController` 将任务状态公开给界面。Drift 持久化下载元数据；MP4 通过 Dio 写入单文件，HLS 通过本地清单和分片目录保存。`EpisodePlayController` 在正常解析在线候选后，将已完成文件作为第一个 `MediaPlaybackSource` 候选插入。

**Tech Stack:** Flutter、Dart、Riverpod 3 code generation、Drift/SQLite、Dio、path_provider、file_selector、media_kit、mocktail。

---

## 文件职责图

| 文件 | 职责 |
| --- | --- |
| `lib/data/local_database.dart` | 声明 `DownloadedEpisodes` 表并把数据库升级至 schema v4。 |
| `lib/data/download/downloaded_episode_repository.dart` | 对下载记录的单一 Drift 读写接口。 |
| `lib/data/download/hls_downloader.dart` | 拉取并本地化单层 HLS media playlist。 |
| `lib/data/download/download_worker.dart` | 单任务 FIFO、出队后即时 resolve、文件下载、取消和事件发射。 |
| `lib/domain/download/download_queue_controller.dart` | 把 worker 事件映射为可供 UI 观察的 Riverpod 状态。 |
| `lib/domain/download/local_file_playback_source.dart` | 将完成的本地文件适配为既有播放候选。 |
| `lib/domain/settings/download_settings_controller.dart` | 解析默认下载根目录及持久化的自定义路径。 |
| `lib/ui/download/` | 下载管理列表及行内取消、重试、删除操作。 |

所有新建 `@riverpod` 文件均须在对应任务末尾运行 `dart run build_runner build --delete-conflicting-outputs`，并提交生成的 `*.g.dart` 文件。

### Task 1: 添加目录选择依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 在 dependencies 中添加目录选择器**

在 `saver_gallery` 附近添加：

```yaml
  file_selector: ^1.0.3
```

- [ ] **Step 2: 获取依赖并确认解析成功**

Run: `flutter pub get`

Expected: 命令成功，`pubspec.lock` 包含 `file_selector` 与 macOS 平台实现包。

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat(download): add directory selector dependency"
```

### Task 2: 持久化下载记录并升级 Drift schema

**Files:**
- Modify: `lib/data/local_database.dart`
- Create: `lib/data/download/downloaded_episode_repository.dart`
- Modify: `lib/data/local_database.g.dart`
- Create: `test/data/download/downloaded_episode_repository_test.dart`

- [ ] **Step 1: 写失败的 repository 测试**

创建内存数据库测试，覆盖按键写入/更新、按键查询、状态筛选和删除：

```dart
import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(db);
  });
  tearDown(() => db.close());

  test('upsert replaces the record with the same episode key', () async {
    await repository.upsert(const DownloadedEpisodeWrite(
      sourceId: 'xifan', subjectId: 1, episodeKey: '1::xifan::1',
      subjectName: '测试番剧', episodeLabel: '1', localPath: '/tmp/one.mp4', format: 'mp4',
      status: DownloadStatus.downloading,
    ));
    await repository.upsert(const DownloadedEpisodeWrite(
      sourceId: 'xifan', subjectId: 1, episodeKey: '1::xifan::1',
      subjectName: '测试番剧', episodeLabel: '1', localPath: '/tmp/one.mp4', format: 'mp4',
      status: DownloadStatus.completed, fileSizeBytes: 100,
    ));

    final rows = await repository.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.status, DownloadStatus.completed.name);
    expect(rows.single.fileSizeBytes, 100);
  });

  test('findCompleted returns only a completed local file', () async {
    await repository.upsert(const DownloadedEpisodeWrite(
      sourceId: 'anime1', subjectId: 2, episodeKey: '2::anime1::2',
      subjectName: '测试番剧', episodeLabel: '2', localPath: '/tmp/two.mp4', format: 'mp4',
      status: DownloadStatus.failed, errorMessage: '403',
    ));
    expect(await repository.findCompleted('2::anime1::2'), isNull);
  });

  test('delete removes the matching record', () async {
    await repository.upsert(const DownloadedEpisodeWrite(
      sourceId: 'xifan', subjectId: 3, episodeKey: '3::xifan::3',
      subjectName: '测试番剧', episodeLabel: '3', localPath: '/tmp/three.mp4', format: 'mp4',
      status: DownloadStatus.completed,
    ));
    await repository.delete('3::xifan::3');
    expect(await repository.findByKey('3::xifan::3'), isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart`

Expected: FAIL，因为 repository、状态类型和表尚不存在。

- [ ] **Step 3: 定义表、迁移和 repository**

在 `MikanSubjectMappings` 后声明表，并加入 `@DriftDatabase.tables`：

```dart
class DownloadedEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceId => text()();
  IntColumn get subjectId => integer()();
  TextColumn get episodeKey => text().unique()();
  TextColumn get subjectName => text()();
  TextColumn get episodeLabel => text()();
  TextColumn get localPath => text()();
  TextColumn get format => text()();
  IntColumn get fileSizeBytes => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
```

将 schema version 改为 `4`，并在 `onUpgrade` 的最后添加：

```dart
if (from < 4) {
  await m.createTable(downloadedEpisodes);
}
```

创建 repository；状态以 `DownloadStatus.name` 字符串写入 Drift，领域和 UI 通过该枚举名称比较：

```dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../local_database.dart';

part 'downloaded_episode_repository.g.dart';

enum DownloadStatus { downloading, completed, failed }

class DownloadedEpisodeWrite {
  const DownloadedEpisodeWrite({
    required this.sourceId, required this.subjectId, required this.episodeKey,
    required this.subjectName, required this.episodeLabel, required this.localPath,
    required this.format,
    required this.status, this.fileSizeBytes, this.errorMessage,
  });
  final String sourceId;
  final int subjectId;
  final String episodeKey;
  final String subjectName;
  final String episodeLabel;
  final String localPath;
  final String format;
  final DownloadStatus status;
  final int? fileSizeBytes;
  final String? errorMessage;
}

class DownloadedEpisodeRepository {
  DownloadedEpisodeRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  Future<DownloadedEpisode?> findByKey(String episodeKey) =>
      (_db.select(_db.downloadedEpisodes)
            ..where((row) => row.episodeKey.equals(episodeKey)))
          .getSingleOrNull();

  Future<DownloadedEpisode?> findCompleted(String episodeKey) =>
      (_db.select(_db.downloadedEpisodes)
            ..where((row) => row.episodeKey.equals(episodeKey))
            ..where((row) => row.status.equals(DownloadStatus.completed.name)))
          .getSingleOrNull();

  Future<List<DownloadedEpisode>> getAll() =>
      (_db.select(_db.downloadedEpisodes)
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .get();

  Future<void> upsert(DownloadedEpisodeWrite value) async {
    final existing = await findByKey(value.episodeKey);
    await _db.into(_db.downloadedEpisodes).insertOnConflictUpdate(
      DownloadedEpisodesCompanion.insert(
        id: Value(existing?.id), sourceId: value.sourceId,
        subjectId: value.subjectId, episodeKey: value.episodeKey,
        subjectName: value.subjectName, episodeLabel: value.episodeLabel,
        localPath: value.localPath,
        format: value.format, fileSizeBytes: Value(value.fileSizeBytes),
        status: value.status.name, errorMessage: Value(value.errorMessage),
        createdAt: existing?.createdAt ?? _now(),
        completedAt: Value(value.status == DownloadStatus.completed ? _now() : null),
      ),
    );
  }

  Future<void> delete(String episodeKey) => (_db.delete(_db.downloadedEpisodes)
        ..where((row) => row.episodeKey.equals(episodeKey))).go();
}

@riverpod
DownloadedEpisodeRepository downloadedEpisodeRepository(Ref ref) =>
    DownloadedEpisodeRepository(ref.watch(appDatabaseProvider));
```

- [ ] **Step 4: 生成代码并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/data/download/downloaded_episode_repository_test.dart`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/data/local_database.dart lib/data/local_database.g.dart lib/data/download/downloaded_episode_repository.dart lib/data/download/downloaded_episode_repository.g.dart test/data/download/downloaded_episode_repository_test.dart
git commit -m "feat(download): persist downloaded episode metadata"
```

### Task 3: 保存并解析下载目录设置

**Files:**
- Modify: `lib/data/settings/settings_storage.dart`
- Create: `lib/domain/settings/download_settings_controller.dart`
- Modify: `lib/data/settings/settings_storage.g.dart`
- Create: `lib/domain/settings/download_settings_controller.g.dart`
- Modify: `test/data/settings/settings_storage_test.dart`
- Create: `test/domain/settings/download_settings_controller_test.dart`

- [ ] **Step 1: 先写失败测试**

在 storage 测试中添加：

```dart
test('stores and clears a custom download directory', () async {
  final prefs = await SharedPreferences.getInstance();
  final storage = SettingsStorage(prefs);
  expect(storage.getDownloadDirectory(), isNull);
  await storage.setDownloadDirectory('/Volumes/Media/Anime');
  expect(storage.getDownloadDirectory(), '/Volumes/Media/Anime');
  await storage.setDownloadDirectory(null);
  expect(storage.getDownloadDirectory(), isNull);
});
```

为 controller 创建 mock `SettingsStorage` 测试，验证无自定义值时返回传入的默认目录，设置后更新 state 且写入 storage：

```dart
test('uses the application-support downloads directory by default', () async {
  when(() => storage.getDownloadDirectory()).thenReturn(null);
  final container = ProviderContainer(overrides: [
    settingsStorageProvider.overrideWith((ref) async => storage),
    defaultDownloadDirectoryProvider.overrideWith((ref) async => '/support/downloads'),
  ]);
  addTearDown(container.dispose);
  expect(await container.read(downloadSettingsControllerProvider.future), '/support/downloads');
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/settings/settings_storage_test.dart test/domain/settings/download_settings_controller_test.dart`

Expected: FAIL，因为新增 API 与 provider 尚不存在。

- [ ] **Step 3: 实现存储和默认目录 controller**

在 `settings_storage.dart` 添加键和方法：

```dart
const _downloadDirectoryKey = 'download_directory';

String? getDownloadDirectory() => _prefs.getString(_downloadDirectoryKey);

Future<void> setDownloadDirectory(String? path) async {
  if (path == null) {
    await _prefs.remove(_downloadDirectoryKey);
  } else {
    await _prefs.setString(_downloadDirectoryKey, path);
  }
}
```

创建 controller。该 provider 返回已创建的绝对目录，所有下载均只读这一处路径：

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/settings/settings_storage.dart';

part 'download_settings_controller.g.dart';

@riverpod
Future<String> defaultDownloadDirectory(Ref ref) async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(p.join(support.path, 'downloads'));
  await directory.create(recursive: true);
  return directory.path;
}

@riverpod
class DownloadSettingsController extends _$DownloadSettingsController {
  @override
  Future<String> build() async {
    ref.keepAlive();
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getDownloadDirectory() ??
        await ref.watch(defaultDownloadDirectoryProvider.future);
  }

  Future<void> setDownloadDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw ArgumentError.value(path, 'path', '目录不存在');
    }
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setDownloadDirectory(path);
    state = AsyncData(path);
  }
}
```

- [ ] **Step 4: 生成代码并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/data/settings/settings_storage_test.dart test/domain/settings/download_settings_controller_test.dart`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/data/settings/settings_storage.dart lib/data/settings/settings_storage.g.dart lib/domain/settings/download_settings_controller.dart lib/domain/settings/download_settings_controller.g.dart test/data/settings/settings_storage_test.dart test/domain/settings/download_settings_controller_test.dart
git commit -m "feat(download): add configurable download directory"
```

### Task 4: 下载并本地化 HLS 清单

**Files:**
- Create: `lib/data/download/hls_downloader.dart`
- Create: `test/data/download/hls_downloader_test.dart`

- [ ] **Step 1: 写失败的清单转换测试**

使用 `DioAdapter` 或测试用的 `Dio` mock adapter，验证 media playlist 中相对 URI 被下载、改写为本地文件名，及 master playlist 只选择第一个 variant：

```dart
test('downloads media segments and rewrites their URI lines', () async {
  final target = await Directory.systemTemp.createTemp('hls_test_');
  addTearDown(() => target.delete(recursive: true));
  final dio = fakeDio({
    'https://cdn.example/episode/index.m3u8': '#EXTM3U\n#EXTINF:1,\npart-a.ts\n#EXTINF:1,\npart-b.ts\n#EXT-X-ENDLIST\n',
    'https://cdn.example/episode/part-a.ts': [1, 2],
    'https://cdn.example/episode/part-b.ts': [3, 4],
  });
  final result = await HlsDownloader(dio).download(
    manifestUrl: Uri.parse('https://cdn.example/episode/index.m3u8'),
    targetDirectory: target,
  );
  expect(await result.playlist.readAsString(), contains('segment_0000.ts'));
  expect(await File('${target.path}/segment_0001.ts').readAsBytes(), [3, 4]);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/download/hls_downloader_test.dart`

Expected: FAIL，因为 `HlsDownloader` 不存在。

- [ ] **Step 3: 实现最小 HLS downloader**

实现只支持单层 master/media playlist 的类。非 `#` 行是 URI；master 的第一个 `#EXT-X-STREAM-INF` 后 URI 指向 variant；media playlist 的 URI 顺序下载为 `segment_%04d.ts`：

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

class HlsDownloadResult {
  const HlsDownloadResult(this.playlist, this.fileSizeBytes);
  final File playlist;
  final int fileSizeBytes;
}

class HlsDownloader {
  HlsDownloader(this._dio);
  final Dio _dio;

  Future<HlsDownloadResult> download({
    required Uri manifestUrl,
    required Directory targetDirectory,
    Map<String, String> headers = const {},
    void Function(int received, int total)? onProgress,
  }) async {
    await targetDirectory.create(recursive: true);
    var url = manifestUrl;
    var text = await _getText(url, headers);
    final masterVariant = _firstMasterVariant(text);
    if (masterVariant != null) {
      url = url.resolve(masterVariant);
      text = await _getText(url, headers);
    }
    final lines = text.split(RegExp(r'\r?\n'));
    final output = <String>[];
    final uriIndices = <int>[];
    for (var index = 0; index < lines.length; index++) {
      output.add(lines[index]);
      if (lines[index].isNotEmpty && !lines[index].startsWith('#')) uriIndices.add(index);
    }
    var received = 0;
    for (var index = 0; index < uriIndices.length; index++) {
      final segment = File(p.join(targetDirectory.path, 'segment_${index.toString().padLeft(4, '0')}.ts'));
      await _dio.downloadUri(url.resolve(lines[uriIndices[index]]), segment.path,
          options: Options(headers: headers));
      received += await segment.length();
      output[uriIndices[index]] = segment.uri.pathSegments.last;
      onProgress?.call(received, 0);
    }
    final playlist = File(p.join(targetDirectory.path, 'playlist.m3u8'));
    await playlist.writeAsString(output.join('\n'));
    return HlsDownloadResult(playlist, received + await playlist.length());
  }

  Future<String> _getText(Uri url, Map<String, String> headers) async =>
      (await _dio.getUri<String>(url, options: Options(headers: headers))).data!;

  String? _firstMasterVariant(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    for (var index = 0; index + 1 < lines.length; index++) {
      if (lines[index].startsWith('#EXT-X-STREAM-INF')) return lines[index + 1];
    }
    return null;
  }
}
```

- [ ] **Step 4: 运行 HLS 测试**

Run: `flutter test test/data/download/hls_downloader_test.dart`

Expected: PASS，且测试覆盖相对 URI、media playlist、master playlist 和本地清单改写。

- [ ] **Step 5: Commit**

```bash
git add lib/data/download/hls_downloader.dart test/data/download/hls_downloader_test.dart
git commit -m "feat(download): download HLS playlists locally"
```

### Task 5: 实现严格单任务下载 worker

**Files:**
- Create: `lib/data/download/download_worker.dart`
- Create: `test/data/download/download_worker_test.dart`

- [ ] **Step 1: 编写失败的 worker 测试**

用 fake `MediaSource`、临时目录和可控 Dio 验证：(1) FIFO；(2) 任务开始时才调用 `resolvePlayback`；(3) Xifan 优先 MP4；(4) 取消删除部分文件和记录；(5) 失败记录错误：

```dart
test('resolves the second request only after the first finishes', () async {
  final events = <DownloadEvent>[];
  final worker = DownloadWorker(
    dio: fakeDio({...}), downloadRoot: directory.path,
    sourceForId: (id) => sources[id]!, repository: repository,
  )..events.listen(events.add);
  worker.enqueue(firstRequest);
  worker.enqueue(secondRequest);
  await worker.whenIdle;
  verifyInOrder([
    () => firstSource.resolvePlayback(firstRequest.episode),
    () => secondSource.resolvePlayback(secondRequest.episode),
  ]);
  expect(events.whereType<DownloadCompleted>(), hasLength(2));
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/download/download_worker_test.dart`

Expected: FAIL，因为 worker 与事件类型不存在。

- [ ] **Step 3: 实现 worker 和稳定的请求/事件类型**

实现以下公共 API。worker 只接受 `anime1`、`xifan`；每个任务开始时才解析候选，Anime1 因而始终获得新 cookie；所有下载完成、失败、取消后再开始下一个任务：

```dart
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../domain/media/media_source.dart';
import 'downloaded_episode_repository.dart';
import 'hls_downloader.dart';

class DownloadRequest {
  const DownloadRequest({required this.subjectId, required this.subjectName,
    required this.sourceId, required this.episode, required this.episodeLabel});
  final int subjectId;
  final String subjectName;
  final String sourceId;
  final MediaEpisode episode;
  final String episodeLabel;
  String get episodeKey => '$subjectId::$sourceId::${episode.title}';
}

sealed class DownloadEvent { const DownloadEvent(this.request); final DownloadRequest request; }
class DownloadQueued extends DownloadEvent { const DownloadQueued(super.request); }
class DownloadProgress extends DownloadEvent { const DownloadProgress(super.request, this.received, this.total); final int received; final int total; }
class DownloadCompleted extends DownloadEvent { const DownloadCompleted(super.request); }
class DownloadFailed extends DownloadEvent { const DownloadFailed(super.request, this.message); final String message; }
class DownloadCancelled extends DownloadEvent { const DownloadCancelled(super.request); }

class DownloadWorker {
  DownloadWorker({required Dio dio, required String downloadRoot,
    required MediaSource Function(String sourceId) sourceForId,
    required DownloadedEpisodeRepository repository})
      : _dio = dio, _downloadRoot = downloadRoot, _sourceForId = sourceForId,
        _repository = repository;
  final Dio _dio;
  final String _downloadRoot;
  final MediaSource Function(String) _sourceForId;
  final DownloadedEpisodeRepository _repository;
  final _queue = <DownloadRequest>[];
  final _events = StreamController<DownloadEvent>.broadcast();
  CancelToken? _cancelToken;
  DownloadRequest? _active;
  Completer<void>? _idle;
  Stream<DownloadEvent> get events => _events.stream;
  Future<void> get whenIdle => _idle?.future ?? Future.value();

  void enqueue(DownloadRequest request) {
    if (_active?.episodeKey == request.episodeKey || _queue.any((item) => item.episodeKey == request.episodeKey)) return;
    _queue.add(request); _events.add(DownloadQueued(request));
    _idle ??= Completer<void>();
    if (_active == null) unawaited(_drain());
  }

  void cancel(String episodeKey) {
    _queue.removeWhere((item) => item.episodeKey == episodeKey);
    if (_active?.episodeKey == episodeKey) _cancelToken?.cancel();
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      _active = _queue.removeAt(0);
      await _download(_active!);
      _active = null;
    }
    _idle?.complete(); _idle = null;
  }

  Future<void> _download(DownloadRequest request) async {
    final directory = Directory(p.join(_downloadRoot, request.sourceId,
        request.subjectId.toString(), request.episodeLabel));
    _cancelToken = CancelToken();
    try {
      await directory.create(recursive: true);
      await _repository.upsert(DownloadedEpisodeWrite(sourceId: request.sourceId,
        subjectId: request.subjectId, episodeKey: request.episodeKey,
        subjectName: request.subjectName,
        episodeLabel: request.episodeLabel, localPath: directory.path,
        format: 'mp4', status: DownloadStatus.downloading));
      final candidates = await _sourceForId(request.sourceId).resolvePlayback(request.episode);
      final selected = candidates.firstWhere((item) => item.url.toLowerCase().contains('.mp4'),
          orElse: () => candidates.first);
      final url = await selected.prepare();
      final isHls = Uri.parse(url).path.toLowerCase().endsWith('.m3u8');
      final localPath = isHls ? p.join(directory.path, 'playlist.m3u8') : p.join(directory.path, 'video.mp4');
      final size = isHls
          ? (await HlsDownloader(_dio).download(manifestUrl: Uri.parse(url), targetDirectory: directory,
              headers: selected.headers, onProgress: (r, t) => _events.add(DownloadProgress(request, r, t)))).fileSizeBytes
          : await _downloadFile(url, localPath, selected.headers, request);
      await _repository.upsert(DownloadedEpisodeWrite(sourceId: request.sourceId,
        subjectId: request.subjectId, episodeKey: request.episodeKey,
        subjectName: request.subjectName,
        episodeLabel: request.episodeLabel, localPath: localPath, format: isHls ? 'hls' : 'mp4',
        status: DownloadStatus.completed, fileSizeBytes: size));
      _events.add(DownloadCompleted(request));
    } on DioException catch (error) when (CancelToken.isCancel(error)) {
      await directory.delete(recursive: true); await _repository.delete(request.episodeKey);
      _events.add(DownloadCancelled(request));
    } catch (error) {
      await _repository.upsert(DownloadedEpisodeWrite(sourceId: request.sourceId,
        subjectId: request.subjectId, episodeKey: request.episodeKey,
        subjectName: request.subjectName,
        episodeLabel: request.episodeLabel, localPath: directory.path, format: 'mp4',
        status: DownloadStatus.failed, errorMessage: error.toString()));
      _events.add(DownloadFailed(request, error.toString()));
    } finally { _cancelToken = null; }
  }

  Future<int> _downloadFile(String url, String path, Map<String, String> headers, DownloadRequest request) async {
    await _dio.download(url, path, cancelToken: _cancelToken, options: Options(headers: headers),
      onReceiveProgress: (received, total) => _events.add(DownloadProgress(request, received, total)));
    return File(path).length();
  }
}
```

- [ ] **Step 4: 修正 HlsDownloader 以接收取消 token**

为 `HlsDownloader.download` 添加可选 `CancelToken? cancelToken`，并将其传给每个 `downloadUri`；worker 调用时传入 `_cancelToken`。这样取消 HLS 也遵循与 MP4 相同的删除语义。

- [ ] **Step 5: 运行 worker 与 HLS 测试**

Run: `flutter test test/data/download/download_worker_test.dart test/data/download/hls_downloader_test.dart`

Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/data/download/download_worker.dart lib/data/download/hls_downloader.dart test/data/download/download_worker_test.dart test/data/download/hls_downloader_test.dart
git commit -m "feat(download): add sequential download worker"
```

### Task 6: 本地播放候选和离线优先解析

**Files:**
- Create: `lib/domain/download/local_file_playback_source.dart`
- Modify: `lib/domain/play/episode_play_controller.dart`
- Modify: `lib/domain/play/episode_play_controller.g.dart`
- Modify: `lib/ui/player/player_screen.dart`
- Modify: `test/domain/play/episode_play_controller_test.dart`
- Create: `test/domain/download/local_file_playback_source_test.dart`

- [ ] **Step 1: 写失败的本地候选和 controller 测试**

测试 `LocalFilePlaybackSource` 不携带 HTTP headers，并在 completed row 存在时验证其排在在线候选前：

```dart
test('inserts a completed local download before resolved candidates', () async {
  await repository.upsert(const DownloadedEpisodeWrite(
    sourceId: 'xifan', subjectId: 42, episodeKey: '42::xifan::1',
    subjectName: '测试番剧', episodeLabel: '1', localPath: '/offline/video.mp4', format: 'mp4',
    status: DownloadStatus.completed,
  ));
  when(() => source.resolvePlayback(episode.episode))
      .thenAnswer((_) async => const [_FakePlaybackSource('https://cdn/video.mp4')]);
  final candidates = await container.read(episodePlayControllerProvider(
    episode: episode, subjectId: 42,
  ).future);
  expect(candidates.first, isA<LocalFilePlaybackSource>());
  expect(candidates.first.url, '/offline/video.mp4');
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/play/episode_play_controller_test.dart test/domain/download/local_file_playback_source_test.dart`

Expected: FAIL，因为 controller 尚未接收 `subjectId` 且本地候选不存在。

- [ ] **Step 3: 添加本地候选并更新 controller**

```dart
import '../media/media_source.dart';

class LocalFilePlaybackSource extends MediaPlaybackSource {
  const LocalFilePlaybackSource(this.localPath);
  final String localPath;
  @override String get url => localPath;
  @override Map<String, String> get headers => const {};
  @override String get label => '本地下载';
}
```

将 `EpisodePlayController.build` 改为如下异步签名和实现：

```dart
Future<List<MediaPlaybackSource>> build({
  required MergedEpisode episode,
  required int subjectId,
}) async {
  final source = ref.watch(mediaSourcesProvider)
      .firstWhere((item) => item.id == episode.sourceId);
  final candidates = await source.resolvePlayback(episode.episode);
  final key = '$subjectId::${episode.sourceId}::${episode.title}';
  final local = await ref.read(downloadedEpisodeRepositoryProvider)
      .findCompleted(key);
  if (local == null) return candidates;
  return [LocalFilePlaybackSource(local.localPath), ...candidates];
}
```

同步将 `player_screen.dart` 的两个 provider 调用改为：

```dart
episodePlayControllerProvider(
  episode: _currentEpisode,
  subjectId: widget.subjectId,
)
```

测试中所有现有 provider 调用同样传入 `subjectId`，并用 `downloadedEpisodeRepositoryProvider.overrideWithValue(repository)` 注入内存 repository。

- [ ] **Step 4: 生成代码并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/domain/play/episode_play_controller_test.dart test/domain/download/local_file_playback_source_test.dart`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/download/local_file_playback_source.dart lib/domain/play/episode_play_controller.dart lib/domain/play/episode_play_controller.g.dart lib/ui/player/player_screen.dart test/domain/play/episode_play_controller_test.dart test/domain/download/local_file_playback_source_test.dart
git commit -m "feat(download): prefer completed local episodes for playback"
```

### Task 7: Riverpod 队列控制器

**Files:**
- Create: `lib/domain/download/download_queue_controller.dart`
- Create: `lib/domain/download/download_queue_controller.g.dart`
- Create: `test/domain/download/download_queue_controller_test.dart`

- [ ] **Step 1: 写失败的 controller 状态映射测试**

测试 worker 的 `Queued`、`Progress`、`Completed`、`Failed` 事件能按 `episodeKey` 映射为 UI 状态，且 `retry` 只接受失败记录：

```dart
test('maps worker progress into state indexed by episode key', () async {
  controller.emit(const DownloadProgress(request, 50, 100));
  await container.pump();
  expect(container.read(downloadQueueControllerProvider)['1::xifan::1']!.progress, .5);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/download/download_queue_controller_test.dart`

Expected: FAIL，因为 provider 不存在。

- [ ] **Step 3: 实现 UI 状态和 controller**

`DownloadQueueController` 在 `build` 中创建一次 worker、监听事件、并在 dispose 时关闭 subscription。状态仅保存瞬时队列/进度；完成、失败记录的长期来源仍是 Drift：

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/download/download_worker.dart';
import '../../data/download/downloaded_episode_repository.dart';
import '../media/media_registry.dart';
import '../play/subject_episodes_controller.dart';
import '../settings/download_settings_controller.dart';

part 'download_queue_controller.g.dart';

enum DownloadQueueStatus { queued, downloading, completed, failed }
class DownloadQueueItem {
  const DownloadQueueItem({required this.status, this.received = 0, this.total = 0, this.errorMessage});
  final DownloadQueueStatus status; final int received; final int total; final String? errorMessage;
  double? get progress => total <= 0 ? null : received / total;
}

@riverpod
class DownloadQueueController extends _$DownloadQueueController {
  StreamSubscription<DownloadEvent>? _subscription;
  late DownloadWorker _worker;
  @override
  Future<Map<String, DownloadQueueItem>> build() async {
    final root = await ref.watch(downloadSettingsControllerProvider.future);
    final sources = ref.watch(mediaSourcesProvider);
    _worker = DownloadWorker(dio: ref.read(downloadDioProvider), downloadRoot: root,
      sourceForId: (id) => sources.firstWhere((source) => source.id == id),
      repository: ref.read(downloadedEpisodeRepositoryProvider));
    _subscription = _worker.events.listen(_onEvent);
    ref.onDispose(() { _subscription?.cancel(); });
    return const {};
  }
  void enqueue({required int subjectId, required String subjectName, required MergedEpisode episode}) => _worker.enqueue(
    DownloadRequest(subjectId: subjectId, subjectName: subjectName, sourceId: episode.sourceId,
      episode: episode.episode, episodeLabel: episode.title));
  void cancel(String episodeKey) => _worker.cancel(episodeKey);
  void _onEvent(DownloadEvent event) {
    final key = event.request.episodeKey;
    final current = state.value ?? const <String, DownloadQueueItem>{};
    if (event is DownloadCancelled) {
      state = AsyncData({...current}..remove(key));
    } else if (event is DownloadQueued) {
      state = AsyncData({...current, key: const DownloadQueueItem(status: DownloadQueueStatus.queued)});
    } else if (event is DownloadProgress) {
      state = AsyncData({...current, key: DownloadQueueItem(status: DownloadQueueStatus.downloading, received: event.received, total: event.total)});
    } else if (event is DownloadCompleted) {
      state = AsyncData({...current, key: const DownloadQueueItem(status: DownloadQueueStatus.completed)});
    } else if (event is DownloadFailed) {
      state = AsyncData({...current, key: DownloadQueueItem(status: DownloadQueueStatus.failed, errorMessage: event.message)});
    }
  }
}
```

在同一文件定义 `@riverpod Dio downloadDio(Ref ref) => Dio();`。由于 `build` 是异步的，provider state 类型为 `AsyncValue<Map<String, DownloadQueueItem>>`；UI 使用 `.valueOrNull ?? const {}` 读取。管理页重试时通过 `subjectEpisodesControllerProvider(subjectId: row.subjectId, subjectName: row.subjectName)` 找回 `sourceId` 与标题均匹配的 `MergedEpisode`，再调用 `enqueue`；绝不从持久化行伪造 `MediaEpisode`。

- [ ] **Step 4: 完成 `_onEvent` 的确定性映射**

`_onEvent` 已在上一步完整给出：按 `event.request.episodeKey` 使用不可变 map 更新 `AsyncData`，并将 `DownloadCancelled` 移除。controller 中不做文件 I/O 或 Drift 写入。

- [ ] **Step 5: 生成代码并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/domain/download/download_queue_controller_test.dart`

Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/domain/download/download_queue_controller.dart lib/domain/download/download_queue_controller.g.dart test/domain/download/download_queue_controller_test.dart
```

### Task 8: Player 顶栏下载动作

**Files:**
- Modify: `lib/ui/player/player_top_bar.dart`
- Modify: `lib/ui/player/player_screen.dart`
- Modify: `test/ui/player/player_top_bar_test.dart`

- [ ] **Step 1: 写失败的顶栏交互测试**

扩展现有 pump 所需参数并验证下载回调：

```dart
var downloadTapped = false;
// PlayerTopBar(..., onDownload: () => downloadTapped = true,
//   downloadState: DownloadButtonState.idle)
await tester.tap(find.byIcon(Icons.download_outlined));
expect(downloadTapped, isTrue);
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/player/player_top_bar_test.dart`

Expected: FAIL，因为新参数和图标不存在。

- [ ] **Step 3: 实现按钮状态和 PlayerScreen 调用**

在顶栏文件定义 `DownloadButtonState { idle, queued, downloading, completed }`，用下列映射渲染：idle=`Icons.download_outlined`，queued=`Icons.schedule`，downloading=`Icons.downloading`，completed=`Icons.download_done`。新增必填 `onDownload`、`downloadState` 参数，在截图按钮后添加 tooltip 为“下载”的 `IconButton`。

在 `PlayerScreen.build` 中观察 `downloadQueueControllerProvider`，以 `_positionKey` 查询状态；点击时调用：

```dart
ref.read(downloadQueueControllerProvider.notifier).enqueue(
  subjectId: widget.subjectId,
  subjectName: widget.subjectName,
  episode: _currentEpisode,
);
```

已完成但重启后不在瞬时 queue state 的情况，需同时观察 `downloadedEpisodeRepositoryProvider.findCompleted(_positionKey)` 的 Riverpod Future provider，按钮显示 completed。为此在 `downloaded_episode_repository.dart` 添加：

```dart
@riverpod
Future<DownloadedEpisode?> downloadedEpisodeByKey(Ref ref, String episodeKey) =>
    ref.watch(downloadedEpisodeRepositoryProvider).findByKey(episodeKey);
```

- [ ] **Step 4: 生成代码并运行顶栏测试**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/ui/player/player_top_bar_test.dart`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/player_top_bar.dart lib/ui/player/player_screen.dart lib/data/download/downloaded_episode_repository.dart lib/data/download/downloaded_episode_repository.g.dart test/ui/player/player_top_bar_test.dart
git commit -m "feat(player): add current episode download action"
```

### Task 9: 详情页全部下载

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart`
- Create: `test/ui/subject/subject_detail_screen_download_test.dart`

- [ ] **Step 1: 写失败的全部下载测试**

覆盖点击 action 后只选择第一个可下载源（`anime1` 或 `xifan`）的所有集，并把它们交给 queue notifier：

```dart
testWidgets('queues every episode from the first HTTP source', (tester) async {
  // Override subjectEpisodesControllerProvider with anime1 ep1/ep2 and xifan ep1.
  // Tap the AppBar download icon and verify notifier receives only anime1 ep1/ep2.
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_detail_screen_download_test.dart`

Expected: FAIL，因为 AppBar 尚无动作。

- [ ] **Step 3: 添加 AppBar action**

将空 `AppBar()` 改为包含 `Icons.download`、tooltip“全部下载”的 action。点击时获取：

```dart
final allMerged = await ref.read(subjectEpisodesControllerProvider(
  subjectId: subjectId,
  subjectName: subjectName,
).future);
final sourceId = allMerged.map((item) => item.sourceId)
    .firstWhere((id) => id == 'anime1' || id == 'xifan');
for (final episode in allMerged.where((item) => item.sourceId == sourceId)) {
  ref.read(downloadQueueControllerProvider.notifier).enqueue(
    subjectId: subjectId, subjectName: subjectName, episode: episode,
  );
}
```

若没有 HTTP 源，捕获 `StateError` 并显示“没有可下载的视频源”的 `SnackBar`。不要使用 `EpisodeSourceIndex` 或预先解析播放 URL。

- [ ] **Step 4: 运行测试**

Run: `flutter test test/ui/subject/subject_detail_screen_download_test.dart`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ui/subject/subject_detail_screen.dart test/ui/subject/subject_detail_screen_download_test.dart
git commit -m "feat(subject): queue all episodes for download"
```

### Task 10: 设置页的目录和管理页入口

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart`
- Create: `test/ui/settings/settings_screen_download_test.dart`

- [ ] **Step 1: 写失败 widget 测试**

验证“下载目录”显示 provider 当前值，“下载管理”会导航至 `/downloads`；对 `getDirectoryPath` 注入包装函数，不在 widget test 中打开原生选择器。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/settings/settings_screen_download_test.dart`

Expected: FAIL，因为两个设置项不存在。

- [ ] **Step 3: 在 SettingsScreen 添加存储分组**

新增 `SettingsSplitGroup(title: '存储', children: [...])`，含：

```dart
ListTile(
  title: const Text('下载目录'),
  subtitle: Text(downloadDirectory.value ?? '加载中'),
  trailing: const Icon(Icons.folder_open),
  onTap: downloadDirectory.hasValue ? () async {
    final path = await getDirectoryPath(initialDirectory: downloadDirectory.value);
    if (path != null) {
      await ref.read(downloadSettingsControllerProvider.notifier)
          .setDownloadDirectory(path);
    }
  } : null,
),
ListTile(
  title: const Text('下载管理'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/downloads'),
),
```

导入 `package:file_selector/file_selector.dart` 和 `download_settings_controller.dart`。macOS sandbox 当前关闭；仍只接受用户通过原生 picker 选取的现有目录。

- [ ] **Step 4: 运行测试**

Run: `flutter test test/ui/settings/settings_screen_download_test.dart`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/settings_screen.dart test/ui/settings/settings_screen_download_test.dart
git commit -m "feat(settings): configure video download directory"
```

### Task 11: 下载管理页面与路由

**Files:**
- Create: `lib/ui/download/download_manager_screen.dart`
- Create: `lib/ui/download/download_list_item.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/app/router.g.dart`
- Create: `test/ui/download/download_manager_screen_test.dart`

- [ ] **Step 1: 写失败的管理页状态测试**

分别预置空、downloading、failed、completed Drift 行，验证空态、进度+取消、错误+重试、删除按钮可见：

```dart
testWidgets('shows retry details for a failed download', (tester) async {
  await repository.upsert(const DownloadedEpisodeWrite(
    sourceId: 'xifan', subjectId: 1, episodeKey: '1::xifan::1',
    subjectName: '测试番剧', episodeLabel: '1', localPath: '/tmp/one.mp4',
    format: 'mp4', status: DownloadStatus.failed, errorMessage: '网络错误',
  ));
  await tester.pumpWidget(testApp(const DownloadManagerScreen()));
  expect(find.text('网络错误'), findsOneWidget);
  expect(find.text('重试'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/download/download_manager_screen_test.dart`

Expected: FAIL，因为页面和路由不存在。

- [ ] **Step 3: 实现 repository 列表监听**

在 repository 增加供界面刷新的流：

```dart
Stream<List<DownloadedEpisode>> watchAll() =>
    (_db.select(_db.downloadedEpisodes)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();

@riverpod
Stream<List<DownloadedEpisode>> downloadedEpisodes(Ref ref) =>
    ref.watch(downloadedEpisodeRepositoryProvider).watchAll();
```

- [ ] **Step 4: 实现列表项和管理页**

`DownloadListItem` 接收 Drift 行及当前 `DownloadQueueItem?`。下载中显示 `LinearProgressIndicator(value: progress)` 与“取消”；失败显示 `errorMessage ?? '下载失败'` 与“重试”；完成显示“删除”。删除先执行 `Directory(row.localPath).parent.delete(recursive: true)`，对 `FileSystemException` 忽略，然后 `repository.delete(row.episodeKey)`。

`DownloadManagerScreen` watch `downloadedEpisodesProvider`，无记录显示“暂无下载”；有记录用 `ListView.builder`。重试时读取 `subjectEpisodesControllerProvider(subjectId: row.subjectId, subjectName: row.subjectName)`，选择 `sourceId == row.sourceId && title == row.episodeLabel` 的 `MergedEpisode`，随后调用 `enqueue(subjectId: row.subjectId, subjectName: row.subjectName, episode: match)`。如果来源暂时不能解析或已无匹配集数，保留 failed 行，并显示“无法重新解析此集”。

页面 AppBar 标题为“下载管理”。每行显示 `sourceId`、`episodeLabel` 和 `subjectName`；首版不展示封面，因为下载元数据不保存远程图片 URL，也不为管理页重复请求封面。

- [ ] **Step 5: 注册顶层路由**

在 `router.dart` 导入页面，在 `/collection` 后、`StatefulShellRoute` 前添加：

```dart
GoRoute(
  path: '/downloads',
  builder: (context, state) => const DownloadManagerScreen(),
),
```

不在 `MainShell` 的四个底部 tab 中增加第五项。

- [ ] **Step 6: 生成代码并运行 widget 测试**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/ui/download/download_manager_screen_test.dart`

Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add lib/data/download/downloaded_episode_repository.dart lib/data/download/downloaded_episode_repository.g.dart lib/data/local_database.dart lib/data/local_database.g.dart lib/domain/download/download_queue_controller.dart lib/ui/download lib/app/router.dart lib/app/router.g.dart test/data/download/downloaded_episode_repository_test.dart test/ui/download/download_manager_screen_test.dart
git commit -m "feat(download): add download management screen"
```

### Task 12: 完整回归与手动 macOS 验证

**Files:**
- Modify: 仅修复本任务前面测试或静态分析发现的问题

- [ ] **Step 1: 格式化所有修改的 Dart 文件**

Run: `dart format lib test`

Expected: 命令成功，无格式化错误。

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`

Expected: 无 error；既有 info 可保留。

- [ ] **Step 3: 运行完整测试集**

Run: `flutter test`

Expected: 全部测试 PASS。

- [ ] **Step 4: 手动验证 macOS 行为**

Run: `flutter run -d macos`

Expected: 验证 Xifan MP4 单集下载、Xifan HLS 单集下载、Anime1 单集下载、详情页全部下载、取消、失败重试、删除、自定义目录和离线优先播放。确认 Mikan 播放仍是在线临时 BT，管理页不会提供其下载任务。

- [ ] **Step 5: Commit 格式化或修复**

```bash
git add lib test
```

仅当本任务产生格式化或验证修复时提交；若工作树无变化，不创建空提交。
