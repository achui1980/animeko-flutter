# 离线视频下载设计

日期：2026-09-17
状态：已批准（Approved）

## 背景与问题

用户在观看直链源（Xifan、Anime1）的视频时，希望能把当前正在看的这一集下载到本地，
以便离线观看，而不必每次都重新联网播放。目前应用中完全没有下载相关的基础设施：

- `lib/data/local_database.dart`（Drift，schema v3）没有任何"已下载"相关的表。
- `path_provider` 只在 `getApplicationDocumentsDirectory()` 里用来存放 sqlite 文件，
  没有专门的下载/缓存目录逻辑。
- `pubspec.yaml` 里没有任何下载管理类第三方包（`background_downloader` /
  `flutter_downloader` 均未引入），可复用的只有 `dio: ^5.11.0` 和
  `path_provider: ^2.1.6`。
- `lib/domain/media/media_source.dart` 中的 `MediaSource.resolvePlayback(episode)`
  返回 `List<MediaPlaybackSource>`，`MediaPlaybackSource` 有 `url`、`headers`、
  `label`、`Future<String> prepare()`（HTTP 源默认直接返回 `url`，BT 源覆写去访问
  rqbit）、`Future<void> dispose()`。这是 HTTP 直链源和 BT 源共用的统一接口，也是
  下载功能最自然的挂接点。
- Mikan/BT 源（`RssMediaSource` + `lib/data/torrent/rqbit_engine.dart` 的
  `RqbitEngine`）目前明确是"v1 online-stream-only"：播放完成或切换候选后
  `dispose()` 会调用 `engine.deleteTorrent()` 删除已下载的文件，不做任何留存。
  `docs/superpowers/plans/2026-09-03-playback-feature-backlog.md` 第 8 项
  "缓存/离线下载" 曾假设"应用内无 BT 源"，这一前提在 Mikan BT 源加入后已经过时，
  但本次设计明确决定 v1 **不** 把下载功能扩展到 BT 源。

两个直链源的 URL/headers 特性差异较大，直接影响下载实现：

- **Anime1**：直链 `.mp4`，但必须带 `Referer: https://anime1.me` 以及从紧邻的
  `POST https://v.anime1.me/api` 响应的 `Set-Cookie` 中提取拼装的 `Cookie` 头
  （如 `e=1; p=2; h=3`）。这些 cookie 在源码注释中被标注为**短时效**——意味着
  下载必须在 `resolvePlayback()`/`prepare()` 之后立刻发起，不能把 resolve 结果
  缓存下来供以后（比如批量下载队列里靠后的任务）复用。
- **Xifan**：`resolvePlayback()` 返回多条候选"线路"（lines），格式混合——有的是
  直链 `.mp4`（如 `https://apn.moedot.net/d/wo/2607/RE12.mp4`），有的是 HLS
  `.m3u8` manifest（如 `https://dl.playxf.top/新番/2607/12/RE12.m3u8`）。Xifan
  本身不需要任何 headers。

## 设计目标（范围）

### 范围内

- 支持对 Anime1、Xifan 两个直链 HTTP 源的单集下载。
- 支持 HLS（`.m3u8`）格式的下载，通过下载全部 `.ts` 分片 + 重写本地 manifest 实现，
  不做转码/合并（mux）成 mp4。
- 播放器页面（`PlayerScreen`）内提供下载入口，针对当前正在播放的这一集/这一源
  发起下载。
- 番剧详情页（`SubjectDetailScreen`）提供"全部下载"入口，一次性对该番剧已知的
  全部集数发起下载（使用固定的默认源）。
- 严格单任务队列：任意时刻只有一个下载任务在执行 I/O，不做并发下载。
- 下载完成后，播放该集时自动优先使用本地文件，在线源仍作为候选/回退保留。
- 提供下载管理页（新路由 `/downloads`），展示下载中/已完成/失败的条目，支持
  取消、重试、删除。
- 下载根目录默认为应用支持目录下的 `downloads/` 子目录，允许用户在设置页修改。
- Drift 新增 `DownloadedEpisodes` 表记录下载元数据（schema 升级到 v4）。

### 范围外

- Mikan/BT 源（`RssMediaSource`/`TorrentPlaybackSource`）下载 —— 继续保持
  "在线流式播放、播放完/切换后删除"的现状，本次不改动 `RqbitEngine`/
  `TorrentPlaybackSource` 的任何行为。
- 断点续传/跨会话持久化下载进度 —— 未完成的下载在 App 重启后需要重新开始，
  不持久化 HTTP Range 状态。
- 多任务并发下载。
- 下载前的磁盘剩余空间检查/配额管理 —— 下载失败（如磁盘写满）时只在下载管理页
  展示错误，不做预先提示。
- HLS 转码/合并成单个 mp4 文件。
- 底部导航新增第 5 个 tab —— 下载管理页通过设置页和播放器页面的入口进入，不占用
  `lib/ui/shell/main_shell.dart` 的 4-tab 导航位。

## 架构与接口变更

### 文件布局

```
lib/data/download/
  download_worker.dart          # 纯 Dart 引擎：实际 I/O（resolve→prepare→下载）
  hls_downloader.dart           # m3u8 解析 + 分片拉取 + 重写
  downloaded_episode.dart       # Drift 表 + 生成的 DAO
lib/domain/download/
  download_queue_controller.dart  # @riverpod Notifier，包装 DownloadWorker 供 UI 观察
  local_file_playback_source.dart # 已完成下载的 MediaPlaybackSource 实现
lib/ui/download/
  download_manager_screen.dart    # /downloads 路由，列表 + 操作
  download_list_item.dart
```

### `lib/data/download/downloaded_episode.dart`（Drift 表）

新增 `DownloadedEpisodes` 表，schema 版本升至 4：

```dart
// lib/data/download/downloaded_episode.dart
class DownloadedEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceId => text()();
  IntColumn get subjectId => integer()();
  // 组合键：'${subjectId}::${sourceId}::${title}'，与
  // PlaybackPositionStorage 现有的 episodeKey 命名模式保持一致
  TextColumn get episodeKey => text().unique()();
  TextColumn get episodeLabel => text()();
  TextColumn get localPath => text()();
  // 'mp4' 或 'hls'
  TextColumn get format => text()();
  IntColumn get fileSizeBytes => integer().nullable()();
  // 'downloading' | 'completed' | 'failed'（没有 'canceled'：取消时直接删行+删文件）
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
```

关键点：

- `episodeKey` 复用 `lib/data/play/playback_position_storage.dart` 中已有的
  `'${subjectId}::${sourceId}::${title}'` 组合键模式，方便与播放进度存储对照。
- `lib/data/local_database.dart` 的 `schemaVersion` 从 3 升级到 4，`migration`
  回调中新增 `from3To4` 步骤，仅创建新表，不改动现有表。
- 取消下载时直接删除该行（不写入 `failed`），同时删除已写入的本地文件/目录。

### `lib/data/download/download_worker.dart`（纯 Dart 下载引擎）

```dart
// lib/data/download/download_worker.dart
class DownloadWorker {
  DownloadWorker({required Dio dio, required Directory downloadRoot});

  /// 单任务队列；enqueue 立即返回，任务按 FIFO 顺序串行执行。
  Future<void> enqueue(DownloadRequest request);
  Future<void> cancel(String episodeKey);
  Stream<DownloadWorkerEvent> get events;
}
```

关键点：

- 不依赖 Flutter/Riverpod，可独立单元测试（fake `MediaSource`、fake `Dio`）。
- 每个任务出队时才调用 `MediaSource.resolvePlayback()` 获取候选列表并选线（见下），
  然后调用 `prepare()`，再发起实际下载——这是"严格单队列"的直接结果：由于任意
  时刻只有一个任务在执行，Anime1 的短时效 cookie 问题被自然规避，无需额外的
  "临下载前才 resolve" 的显式实现。
- Xifan 选线规则：优先选择候选列表中的 `.mp4` 直链；只有当所有候选都只有
  `.m3u8` 时才降级为下载 HLS。此规则与播放器里当前选中的线路无关，不跟随
  播放选择。
- HTTP/MP4 下载直接用 `Dio().download(url, savePath, onReceiveProgress:, options: Options(headers:))`，无需新依赖。
- 下载目录结构：`<downloadRoot>/<sourceId>/<subjectId>/<episodeLabel>/`，内含
  `video.mp4`（mp4 格式）或 `playlist.m3u8` + `segment_*.ts`（hls 格式）。
- 下载失败（网络错误、HTTP 错误、磁盘写满等）统一捕获为 `failed` 状态 +
  `errorMessage`，不做自动重试。Anime1 的 403（cookie/referer 问题）按普通失败
  处理，不需要特殊分支。

### `lib/data/download/hls_downloader.dart`（HLS 分片下载）

手写最小 m3u8 解析器（约 50-80 行），不引入新 pub 包：

```dart
// lib/data/download/hls_downloader.dart
class HlsDownloader {
  Future<void> download({
    required Uri manifestUrl,
    required Directory targetDir,
    required Dio dio,
    void Function(int downloaded, int total)? onProgress,
  });
}
```

解析逻辑：

1. 拉取 manifest 文本，逐行解析。
2. 若包含 `#EXT-X-STREAM-INF`，视为 master playlist：取第一个 variant URL，
   相对 `manifestUrl` 解析成绝对地址，重新拉取该 URL 作为真正的 media playlist。
3. 否则视为 media playlist：收集所有非注释行（即 `#EXTINF` 后紧跟的分片 URI，
   相对 `manifestUrl` 解析为绝对地址），逐个下载为 `segment_0000.ts`、
   `segment_0001.ts`……
4. 写出本地 `playlist.m3u8`：保留除分片 URI 行外的所有原始 tag 行，仅将 URI 行
   替换为本地文件名（`segment_0000.ts` 等）。
5. 本地播放时复用现有 `media_kit` `Player`，直接打开本地 `playlist.m3u8` 文件，
   与远程 HLS 流播放走同一套播放机制，无需转码/合并。

### `lib/domain/download/download_queue_controller.dart`（Riverpod 包装层）

```dart
// lib/domain/download/download_queue_controller.dart
@riverpod
class DownloadQueueController extends _$DownloadQueueController {
  @override
  DownloadQueueState build() { ... }

  Future<void> enqueue(MergedEpisode episode, String sourceId);
  Future<void> cancel(String episodeKey);
  Future<void> retry(String episodeKey);
}
```

关键点：

- 薄封装层，只负责把 `DownloadWorker` 的事件流转换成 Riverpod 状态供 UI 观察，
  实际 I/O 逻辑全部在 `DownloadWorker` 里，保证可脱离 Flutter/Riverpod 单测。
- "全部下载"没有单独的批量代码路径：`SubjectDetailScreen` 遍历所有集数逐个调用
  `enqueue()`，它们只是被依次塞进同一个单任务队列，由队列自然串行消化。

### `lib/domain/download/local_file_playback_source.dart`（离线优先播放）

```dart
// lib/domain/download/local_file_playback_source.dart
class LocalFilePlaybackSource implements MediaPlaybackSource {
  LocalFilePlaybackSource({required this.localPath});

  @override
  String get url => localPath;
  @override
  Map<String, String> get headers => const {};
  @override
  String? get label => '本地下载';
  @override
  Future<String> prepare() async => localPath;
  @override
  Future<void> dispose() async {}
}
```

集成点：`lib/domain/play/episode_play_controller.dart` 的
`EpisodePlayController.build()` 在调用现有 `resolvePlayback()` 之后，根据
`episodeKey` 查询 `DownloadedEpisodes` 表，若存在 `completed` 行，则把
`LocalFilePlaybackSource` 插入到候选列表最前面。`PlayerScreen._openCandidate()`
无需任何改动——它已经统一处理任意 `MediaPlaybackSource` 候选，本地文件候选和
在线候选走完全相同的打开/回退逻辑。

### UI 变更

- **`PlayerScreen`**：顶部栏新增下载图标按钮，图标状态反映
  `downloadQueueControllerProvider` 中当前集的状态（空闲/排队中/下载中/已完成）。
  点击后调用 `enqueue(episode, sourceId)`；若已有活动任务，新任务排队等待。
- **`SubjectDetailScreen`**：`AppBar()`（当前为空，只有默认返回按钮）新增"全部
  下载"动作，遍历 `subjectMainEpisodesControllerProvider` 返回的全部集数，对
  固定的默认源逐个调用 `enqueue()`。
- **`SettingsScreen`**：在现有"通用"分组（`SettingsSplitGroup`）中新增"下载目录"
  列项，点击弹出文件夹选择器修改下载根目录（macOS 需考虑沙盒权限）。
- **新路由 `/downloads`（`DownloadManagerScreen`）**：普通 `GoRoute`，不占用
  底部导航位。单个 `ListView`，每行展示封面/标题/集数/来源 + 状态标签：
  - 下载中：进度条 + 取消按钮。
  - 失败：错误信息文本 + 重试按钮（重新 `enqueue`）。
  - 已完成：删除按钮（同时删除 Drift 行和本地文件/目录）。
  入口：`SettingsScreen`新增"下载管理"列项，以及 `PlayerScreen` 顶部栏的下载
  图标按钮旁可跳转。

## 测试要求

- `test/data/download/hls_downloader_test.dart`：参考
  `test/data/xifan/xifan_api_test.dart` 的 fixture 风格，覆盖 media playlist
  解析、master playlist 解析（含 variant 选择）、相对 URI 解析为绝对地址、
  本地 manifest 重写正确性。
- `test/data/download/download_worker_test.dart`：使用 fake `MediaSource`/fake
  `Dio` 覆盖：入队顺序（FIFO）、出队时才调用 `resolvePlayback()`（验证 Anime1
  场景下每次任务执行前才 resolve，而不是预先批量 resolve）、Xifan mp4 优先于
  m3u8 的选线规则、cancel 语义（删除部分文件+删除 Drift 行）、retry 语义
  （失败后重新入队）。不涉及真实网络/文件系统。
- `test/domain/download/local_file_playback_source_test.dart` +
  `episode_play_controller_test.dart` 补充用例：使用内存 Drift DB 预先插入
  `completed` 行，验证 `EpisodePlayController.build()` 正确把
  `LocalFilePlaybackSource` 插入候选列表最前面，且未下载的集数行为不变。
- `test/ui/download/download_manager_screen_test.dart`：widget 测试覆盖空列表、
  下载中、失败三种状态的渲染与按钮可交互性。

## 风险与已知限制

- **不支持断点续传**：App 重启或进程中断会导致未完成的下载丢失进度，需要用户
  手动重新开始。这是 v1 的既定简化，不是缺陷。
- **严格单队列意味着批量下载耗时较长**：一部 24 集的番剧"全部下载"会按顺序
  逐集下载，用户需要等待较长时间才能看到全部下载完成，v1 接受此限制以避免
  并发写文件和 Anime1 cookie 竞态问题。
- **Anime1 cookie 短时效**：如果单集下载耗时过长（例如非常慢的网络），
  cookie 可能在下载中途失效导致 403。这种情况会被当作普通下载失败处理
  （标记 `failed`，用户可重试），不做特殊的"续期"逻辑。
- **HLS 下载不做转码**：保留原始 `.ts` 分片和重写后的本地 `.m3u8`，不合并成
  单一 mp4 文件。这意味着本地下载目录会包含多个小文件而非一个视频文件，用户
  如果想在文件系统层面把下载内容分享给其他播放器，需要自己处理这一堆文件；
  应用内播放没有影响（`media_kit` 可直接打开本地 m3u8）。
- **不做磁盘空间预检查**：如果下载过程中磁盘写满，会在下载管理页显示为
  `failed` + 错误信息，不会提前阻止用户发起下载。
- **BT/Mikan 源完全不支持下载**：用户在 Mikan 源下想要离线保存视频时没有任何
  入口，需要引导用户改用 Anime1/Xifan（如果该番剧同时存在于这些源）。这是
  范围内明确排除的功能，非缺陷。
- **删除已下载文件失败时的行为未特殊处理**：如果本地文件在应用外被移动/删除，
  用户在下载管理页点击删除时对已不存在的文件调用删除操作，会静默忽略
  文件系统层的 `FileSystemException`（"not found"）并仍然删除 Drift 行，
  确保管理页列表与实际状态保持一致。
