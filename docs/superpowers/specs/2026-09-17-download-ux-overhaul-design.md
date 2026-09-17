# 下载功能 UX 与可靠性重做设计

日期：2026-09-17
状态：待审阅（Draft）

## 背景与问题

`docs/superpowers/specs/2026-09-17-offline-video-download-design.md`（已批准，12 任务
已全部实现完成）交付了下载功能的第一版：HTTP 直链源（Anime1/Xifan）单集下载、"全部
下载"、Drift 持久化、`/downloads` 下载管理页。功能上线后用户反馈了一系列体验和可靠性
问题，原样引用如下：

1. "现在这个下载功能有很多问题,单击了下载,不知道在那里看下载的内容,不方便.批量下载
   没办法选择下载的剧集,没有下载进度,然后也不知道是从哪个原下载的.在,好像下载也似乎
   有问题,没有办法下载"
2. "我觉得应该在详细页面的地方做个下载管理按钮,可以管理下载的内容."（配 Re:Zero S4
   详情页截图，红框标在"选集"行左侧，紧邻"连载至 06 · 预定全 8 话"）
3. "下载有问题,是我看在设立里面看到的下载只是一直在转,不知道进度,很就都不动,然后
   批量下载我需要改进能选择源来下载,或者你要自动判断那个源能下载,不是所有的剧集都
   在anime1能下载的,我现在不需要实现BT的."
4. "如果我不离开播放器页面,怎知道有没有在下载.这个是个矛盾的问题. 可以选B,批量下载
   的按钮不要放在右上角,播放器的下载也不要放在右上角,放在下面播放里的bar里面"

归纳为五类问题：(a) 找不到统一的地方查看/管理下载内容；(b) "全部下载"无法挑选剧集，
全有或全无；(c) 进度条永久转圈，观察不到真实进度；(d) 不知道某次下载来自哪个源；
(e) 部分场景下载看起来失败或完全不可用（如非 anime1/xifan 源没有下载按钮）。

本次设计**不推翻**原设计的技术选型（HTTP 直链下载、Drift 持久化、严格单任务串行
队列、不涉及 BT/断点续传/并发），而是在其之上做 UX 重构和可靠性修复。

**明确不在本次范围**：BT/种子下载（用户明确表态"我现在不需要实现BT的"）、断点续传
（除 3.4 节描述的 HLS 分段级跳过重下）、并发下载、磁盘空间预检查、底部导航新增第 5
个 tab。

## 现状代码勘查

下载是纯 HTTP 直链下载器，不涉及 rqbit/BT。rqbit 只用于 BT 在线流播放，
`lib/data/torrent/torrent_playback_source.dart:76-82` 播放结束即调用
`deleteTorrent` 删除文件，不做任何留存；`lib/data/torrent/rqbit_engine.dart:165-170`
有一个打包路径相关的 TODO，与下载功能无关。

### 触发入口现状

- `lib/ui/player/player_top_bar.dart:54-59` 右上角 `IconButton`，`tooltip: '下载'`，
  图标由 `enum DownloadButtonState { idle, queued, downloading, completed }`
  （`:4`）驱动。
- `lib/ui/player/player_screen.dart:883-895` 接线：
  `onDownload: _isDownloadableSource(sourceId) ? () => enqueue(...) : null`；
  `_isDownloadableSource`（`:986-987`）判定 `sourceId == 'anime1' || sourceId == 'xifan'`，
  Mikan/BT 播放时回调为 `null`，按钮**完全不渲染**——这是用户"没有办法下载"的直接
  原因之一。状态由 `downloadQueueControllerProvider` + `downloadedEpisodeByKeyProvider(_positionKey)`
  推导，`_positionKey`（`:134-135`）为 `'$subjectId::$sourceId::$title'`，与
  `DownloadRequest.episodeKey` 同形。
- `lib/ui/subject/subject_detail_screen.dart:81-111` 右上角 AppBar
  `IconButton(Icons.download, tooltip: '全部下载')`；`firstDownloadableSourceEpisodes()`
  （`:22-30`）用 `firstWhere(id == 'anime1' || id == 'xifan')` 挑出**第一个**可下载源，
  取该源**全部**剧集；`:94-102` 用 for 循环逐集 `enqueue`；`:103-109` 找不到可下载源时
  `on StateError` → SnackBar「没有可下载的视频源」。全有或全无，没有选集对话框。
  `mediaSourcesProvider` 注册顺序为 `[anime1, xifan, mikan]`
  （`lib/domain/media/media_registry.dart`），因此 anime1 优先。
- `lib/ui/settings/settings_screen.dart:125-141`「下载目录」设置项；`:142-146`
  「下载管理」→ `context.push('/downloads')`——这是当前唯一的下载页入口。
  `lib/ui/shell/main_shell.dart:21-24` 只有首页/搜索/日历/设置四个底部 tab，本次
  不新增第五个（沿用原设计的决定）。

### 全局下载页现状

`lib/app/router.dart:97-100`：`GoRoute('/downloads') → DownloadManagerScreen`
（顶层路由，不在 `StatefulShellRoute` 内）。`lib/ui/download/download_manager_screen.dart`
（87 行）把 `downloadedEpisodesProvider`（持久化列表）与
`downloadQueueControllerProvider`（内存中的实时队列 Map）按 `episodeKey` 合并显示
（`:15-33`）；`_retry`（`:49-81`）重新拉取 `subjectEpisodesControllerProvider`，用
`sourceId` + `title == episodeLabel` 字符串匹配找回剧集对象后重新 `enqueue`，匹配
失败则 SnackBar「无法重新解析此集」；`_delete`（`:83-86`）。
`lib/ui/download/download_list_item.dart`（64 行）：下载中显示
`LinearProgressIndicator(value: queueItem?.progress)`（`:43`）；`deleteLocalPath`
（`:57-63`）删除 `Directory(localPath).parent`。

### domain 层现状

`lib/domain/download/download_queue_controller.dart`（109 行）：`DownloadQueueItem`
（`:16-30`）含 `status/received/total/errorMessage`，
`double? get progress => total <= 0 ? null : received / total`（`:29`）；
`@riverpod Dio downloadDio`（`:32-33`）是**未配置任何选项的裸 `Dio()`**，绕过 app
其余 API client 遵循的代理设置；`DownloadQueueController` 状态类型是
`Future<Map<String, DownloadQueueItem>>`（key 为 `episodeKey`）、**只存在于内存中，
从不落盘**；`build()`（`:40-55`）`watch` 了 `downloadSettingsControllerProvider` 和
`mediaSourcesProvider` 后构造 `DownloadWorker`；**没有 `retry()` 方法**（原 spec 中
有此 API，实现中缺失）。`lib/domain/settings/download_settings_controller.dart`：
默认下载目录 `<applicationSupport>/downloads`，自身是 `ref.keepAlive()`。离线优先
播放：`lib/domain/play/episode_play_controller.dart:19-29` 用 `findCompleted(key)`
命中后把本地文件候选插入播放候选列表第 0 位。

### data 层现状

`lib/data/download/download_worker.dart`（219 行）：`DownloadRequest`（`:11-27`，
`episodeKey => '$subjectId::$sourceId::${episode.title}'`）；密封事件
`DownloadQueued/DownloadProgress(received,total)/DownloadCompleted/
DownloadFailed(message)/DownloadCancelled`；`DownloadWorker`（`:60-218`）依赖
`Dio`、`downloadRoot`、`MediaSource Function(String sourceId)`、
`DownloadedEpisodeRepository`；`enqueue`（`:84-100`）对非 anime1/xifan 源**同步
`throw ArgumentError`**（`DownloadQueueController.enqueue` 未捕获）；`_drain`
（`:107-115`）严格 FIFO、单任务、单 `CancelToken`；`_download`（`:117-201`）：目录
布局 `<root>/<sourceId>/<subjectId>/<episodeLabel>/`；出队时才调用
`resolvePlayback`（为规避 Anime1 短时效 cookie）；线路选择
`candidates.firstWhere(url contains '.mp4', orElse: candidates.first)`
（`:144-147`，故意忽略播放器当前手动切换的线路）；`.m3u8` 走 `HlsDownloader`，否则
`dio.download`；成功后 upsert `completed`；取消时递归删除目录并删除 DB 行；失败时
upsert `failed` + `errorMessage`（**无自动重试、无超时判定**）。
`lib/data/download/hls_downloader.dart`（81 行）：manifest 遇到
`#EXT-X-STREAM-INF` 时只跟随**第一个** variant（`_firstMasterVariant`，`:74-80`）；
分段存为 `segment_NNNN.ts`；**`:60` `onProgress?.call(received, 0)` 导致 `total`
恒为 0**，进度永久 indeterminate。`lib/data/download/downloaded_episode_repository.dart`
（100 行）：`DownloadStatus { downloading, completed, failed }`；
`findByKey/findCompleted/getAll/watchAll/upsert/delete`。Drift：`DownloadedEpisodes`
表定义在 `lib/data/local_database.dart:105-119`（当前字段：`id / sourceId /
subjectId / episodeKey(unique) / subjectName / episodeLabel / localPath / format /
fileSizeBytes? / status / errorMessage? / createdAt / completedAt?`），
`schemaVersion => 4`（`:136`）。

### 播放器底部条现状

`lib/ui/player/player_bottom_bar.dart`（133 行，纯 prop-driven `StatelessWidget`，
`Container(color: Colors.black45)` + `SafeArea(top: false)` + `Row`）从左到右：
播放/暂停 → 当前位置 `Text` → `Expanded(Slider)` → 总时长 `Text` → 倍速
`PopupMenuButton<double>` → `IconButton(Icons.alt_route)`（线路） →
`IconButton(Icons.playlist_play)`（选集） → 全屏切换。构造参数：
`isPlaying, position, duration, onPlayPause, onSeek, currentSpeed, speedOptions,
onSpeedSelected, onLineSwitch?, onDrawerToggle, onFullscreenToggle, isFullscreen`。

### 已确诊的现状问题清单

以下问题均由阅读源码确认（无代码内 TODO 标记），是本次重做要修复的可靠性根因：

1. `downloadQueueControllerProvider` 是 autoDispose，`build()` 从不调用
   `ref.keepAlive()`——离开播放器/下载页会销毁 notifier，丢失内存中的进度 Map，
   而数据库行仍是 `downloading` 状态，导致
   `LinearProgressIndicator(value: null)` **永久转圈**；之后再次 `enqueue` 会重新
   构造一个**全新的 `DownloadWorker`**，破坏"严格单任务"不变式，原有下载连接成为
   无人观察的孤儿。这是"一直在转"问题的主因。
2. `build()` 同时 `watch` 了 `downloadSettingsControllerProvider` 和
   `mediaSourcesProvider`——修改下载目录会重建 notifier、清空队列状态、创建第二个
   worker，丢弃第一个队列里排队的任务。
3. HLS 下载 `total` 恒为 0，导致 m3u8 来源的进度永远 indeterminate。
4. `DownloadWorker.enqueue` 对不支持的源同步抛出 `ArgumentError`，调用方未捕获
   （当前两个调用点都预先过滤过，暂不可达，但是脆弱设计）。
5. 没有 `DownloadQueueController.retry()`；UI 层的重试靠重新拉取剧集列表 +
   `title == episodeLabel` 字符串匹配重建请求对象，源的剧集标题变化或源临时不可用
   时会直接失败。
6. 崩溃/强制退出后残留的 `downloading` 行没有任何启动时 reconciliation，会永久
   显示转圈，且"取消"按钮是 no-op（找不到对应的 `CancelToken`）。
7. `deleteLocalPath`（`download_list_item.dart:59`）统一删除
   `Directory(localPath).parent`：对于 `completed` 行，`localPath` 是一个文件
   （`.parent` 正确指向该集目录）；但对于 `failed`/`downloading` 行，`localPath`
   本身就是目录，`.parent` 会指向 `<subjectId>/`，删除会**连带清除同一部番的其他
   剧集**。当前 UI 只对 `failed` 行提供"重试"未提供"删除"，因此这是潜在而非已触发
   的 bug，但本次一并修复。
8. `downloadDioProvider` 是未配置的裸 `Dio()`，绕过应用的代理设置。
9. `sourceForId: (id) => sources.firstWhere(...)` 在源列表缺少对应 id 时会
   `throw StateError`。
10. `_downloadFile` 不检查 HTTP 状态码或 `content-type`。当 Anime1 的 Referer/Cookie
    失效时，服务器可能返回 200 + HTML 错误页，该 HTML 会被原样写入
    `video.mp4` 并标记为 `completed`，播放时才会失败。**这很可能是用户反馈"好像
    下载也似乎有问题"的真实原因**。
11. 没有任何超时/停滞判定，某一集卡住会永久堵死严格串行的下载队列，是用户反馈
    "很久都不动"的另一半原因。

### 测试现状

`test/data/download/download_worker_test.dart`（262 行）、
`downloaded_episode_repository_test.dart`（121）、`hls_downloader_test.dart`（96）、
`test/domain/download/download_queue_controller_test.dart`（118）、
`local_file_playback_source_test.dart`（12）、
`test/domain/settings/download_settings_controller_test.dart`（59）、
`test/ui/download/download_manager_screen_test.dart`（192）、
`test/ui/settings/settings_screen_download_test.dart`（152）、
`test/ui/subject/subject_detail_screen_download_test.dart`（135，其 `:73` 测试
"queues every episode from first HTTP source" 覆盖的正是本次要淘汰的全有全无
行为）、`test/ui/player/player_top_bar_test.dart`（参数化图标测试，本次要整块移除
迁移到新的 badge button 测试）、`test/domain/play/episode_play_controller_test.dart:101`、
`test/data/local_database_test.dart:104-105`（`schemaVersion == 4`，本次改为 5）。

### 关键 API 事实

`MediaEpisode`（`lib/domain/media/media_source.dart:21-27`）是抽象类，只有
`String get sourceId` 和 `String get title` 两个 getter，源特定数据在各源自己的
子类里，**不可通用序列化**——因此 `retry()` 必须重新拉取一次剧集列表，无法绕过
（反正 retry 本身也要重新联网 `resolvePlayback`）。`MediaPlaybackSource`（`:30-58`）
提供 `url`、`headers`、`String? get label`、`Future<String> prepare()`、
`Future<void> dispose()`。

## 设计

### 1. 组件架构

核心思路：**一个下载面板组件，三处复用；一个常驻队列，进度落盘。**

三处入口向同一个 `DownloadPanel` 组件传入不同参数：

| 入口 | 参数 | tab1 选集下载 | tab2 下载列表 |
|---|---|---|---|
| 首页右上角（带角标） | 无 `subjectId` | 隐藏 | 全部番剧的下载记录 |
| 详情页选集行（带角标） | `subjectId` | 显示这部番的剧集 | 只显示这部番 |
| 播放器底部条（带角标） | `subjectId` | 显示这部番的剧集 | 只显示这部番 |

面板是**浮层 sheet 形式，不是新路由**，这样在播放器全屏状态下也能查看而不必退出
全屏（直接解答了用户"如果我不离开播放器页面,怎知道有没有在下载"的疑问，见第 3.3
节的按钮反馈设计配合使用）。`/downloads` 路由**保留但退化为薄壳**，只包一个
`DownloadPanel(subjectId: null)`；设置页的"下载管理"入口继续指向它；首页图标点击
直接打开浮层（不经过路由跳转）。

数据流：三处 UI → `downloadQueueControllerProvider`（改为 `keepAlive`） →
`DownloadWorker` → Drift `DownloadedEpisodes` 表（新增进度字段，跨页面可观察）。

**新增文件**：

- `lib/ui/download/download_panel.dart` —— 面板骨架 + 两个 tab
- `lib/ui/download/episode_selection_tab.dart` —— 逐集勾选（全选/清空/已选 N 集）
- `lib/ui/download/download_badge_button.dart` —— 带角标的下载按钮（三处复用；
  `DownloadButtonState` enum 从 `player_top_bar.dart` 移到这里）
- `lib/domain/download/download_source_resolver.dart` —— 第 4 节的择源纯函数

**改动文件**：

- `lib/ui/download/download_manager_screen.dart` —— 瘦身为
  `DownloadPanel(subjectId: null)` 的薄壳
- `lib/ui/download/download_list_item.dart` —— 新增状态显示（已中断/已停滞）+
  来源标签 + 失败原因文案
- `lib/ui/subject/subject_detail_screen.dart` —— 移除 AppBar「全部下载」，
  「选集」行加入带角标下载按钮
- `lib/ui/player/player_bottom_bar.dart` —— 在倍速右侧、线路左侧插入下载按钮
- `lib/ui/player/player_top_bar.dart` —— 移除下载按钮
- `lib/ui/home/*` —— 首页 AppBar 右上角新增下载图标（带角标）
- `lib/domain/download/download_queue_controller.dart` —— keepAlive、`retry()`、
  择源集成、停滞检测
- `lib/data/download/download_worker.dart` —— 可注入时间源/定时器、停滞逻辑、
  目录快照、HTTP 响应校验
- `lib/data/download/hls_downloader.dart` —— 真实分段进度、重试跳过已下分段
- `lib/data/download/downloaded_episode_repository.dart` —— `reconcileInterrupted()`、
  `findCompletedForEpisode()`、进度写盘节流
- `lib/data/local_database.dart` —— schema v4 → v5

### 2. 数据层改动

**2.1 Drift schema v4 → v5，新增 6 个可空/带默认值字段**（原因见 5.1）：

- `receivedBytes`（int，默认 0）—— mp4 已下载字节数
- `totalBytes`（int?）—— 来自 `Content-Length`，HLS 为 `null`
- `downloadedSegments`（int?）—— HLS 已下载分段数
- `totalSegments`（int?）—— HLS 总分段数，下载前先探测写入
- `lastProgressAt`（DateTime?）—— 最后一次字节数增长的时间，用于停滞判定
- `episodeDir`（String）—— worker 创建下载目录时写入，专用于删除操作（见 5.1）

进度百分比由**一个共用函数**计算，三处 UI 都调用它：mp4 用
`receivedBytes / totalBytes`，HLS 用 `downloadedSegments / totalSegments`，两者都
拿不到时才回退为 indeterminate——HLS 从此有真实百分比，不再永久转圈。

迁移：`if (from < 5) { await m.addColumn(...) × 6 }`，`schemaVersion => 5`。
`test/data/local_database_test.dart:104-105` 断言随之改为 5，并新增一个用例验证
v4→v5 迁移后旧数据保留、新列存在。

**2.2 `DownloadStatus` 新增一个值**：`downloading / completed / failed` +
`interrupted`。"已停滞"（stalled）是**瞬态**，不落盘——队列已改为 keepAlive 常驻，
内存判定足够，`DownloadQueueItem` 新增 `bool isStalled` 字段。

启动时 reconciliation：`DownloadedEpisodeRepository` 新增 `reconcileInterrupted()`，
把所有仍是 `downloading` 状态的行统一改为 `interrupted`；由常驻队列 controller 的
`build()` 调用一次（`keepAlive` 保证整个 app 生命周期内只执行一次）。

**2.3 进度写盘节流**：每 1 秒或进度变化 ≥ 1% 才写一次数据库；完成/失败/取消时无
条件写一次。内存中的进度状态仍实时更新（当前打开的面板体验不受影响），仅"离开
页面再回来"时的持久化进度最多滞后 1 秒。

**2.4 "是否已下载"改为跨源判定**：`episodeKey`（`'$subjectId::$sourceId::$title'`）
本身携带 `sourceId`。自动择源（第 4 节）之后会出现"当前正在看 mikan 源第 6 集，
实际下载文件来自 anime1"的情况，此时按原逻辑查询会返回"未下载"，尽管文件已经在
磁盘上。修法：**保留 `episodeKey` 作为下载任务的唯一键不变**（不迁移历史数据），
新增一个忽略 `sourceId` 的查询方法 `findCompletedForEpisode(subjectId, episodeTitle)`；
播放器下载按钮的状态计算、选集面板"✓ 已下载"判定、离线优先播放候选查找三处，
全部改用这个新查询。

### 3. 队列与 worker 改动

**3.1 队列常驻，改目录不再清空队列**：`DownloadQueueController` 标注
`@Riverpod(keepAlive: true)`。`build()` 不再 `watch` 下载目录设置和
`mediaSourcesProvider`（这正是"改下载目录会清空队列"的根因）。下载目录改为**在
`enqueue()` 时快照进 `DownloadRequest`**：已经排队的任务仍写入旧目录，新任务使用
新目录。

**3.2 `retry(episodeKey)` 迁移到 domain 层，且重新执行择源**：从 UI 层的字符串
匹配重建，迁移为 `DownloadQueueController.retry(episodeKey)`，三处面板共用同一
实现。重试时不再锁定原来的 `sourceId`，而是重新运行第 4 节的择源函数——如果原
来的源已经没有这一集了，会自动换成另一个可用源。彻底匹配不到剧集时给出可操作的
错误提示："源的剧集列表已变化，请在详情页重新选择这一集"，而不是笼统的"无法重新
解析此集"。

**3.3 停滞判定语义**（解答用户"批量下载卡住/很久都不动"的问题）：

| 情况 | 处理 |
|---|---|
| 30 秒内无新字节到达 | 标记该行"已停滞，正在重试"，取消当前连接，自动重试一次（每集只自动重试一次） |
| 重试后再次 30 秒无新字节 | 判定失败，记录失败原因，跳过并开始下载队列中的下一集；失败行留在面板中，可手动重试 |
| 从入队起 2 分钟内累计字节数一直为 0（根本没能建立连接） | 直接判失败并跳过，不必等到 30 秒规则触发多次 |
| 正在下载但速度很慢（字节数持续增长） | 永不因为"慢"而超时 |

**3.4 HLS 真实进度 + 重试跳过已下载分段**：下载前先抓取 manifest 数出总分段数，
写入 `totalSegments`；每下载完一个分段 `downloadedSegments` 自增一次，据此计算
真实百分比。重试同一任务时，检查 `segment_NNNN.ts` 是否已存在且非空，存在则跳过
不重新下载。mp4 类型的重试仍从头下载（不依赖源是否支持 HTTP Range）。主播放列表
（master playlist）的处理仍只跟随第一个 variant，画质不可选，属于第 5.4 节的已知
限制。

**3.5 `enqueue` 不再同步抛异常**：`DownloadWorker.enqueue` 遇到不支持的源时，
不再 `throw ArgumentError`，而是写入一条 `failed` 状态的记录，`errorMessage` 为
"此来源不支持下载"，行为与其他失败路径一致。

**3.6 并发**：本次仍不支持，保持严格单任务串行队列（YAGNI，与原设计一致）。

**3.7 可测试性约束**：`DownloadWorker` 必须接受可注入的时间源和定时器
（`DateTime Function() now` + 可控的 ticker 抽象），生产环境注入真实实现，测试
注入可手动推进的假实现，使停滞/超时相关测试不必真实等待 30 秒或 2 分钟。

### 4. 自动逐集择源策略

**4.1 一个纯函数**：新建 `lib/domain/download/download_source_resolver.dart`，纯
Dart 实现（不 import `package:flutter`，不发起网络请求）。输入：合并后的剧集列表
（`MergedEpisode`，沿用 `lib/domain/play/subject_episodes_controller.dart:30-37`
现有的合并逻辑，不新造分组规则）。输出：每一集对应一条 `EpisodeDownloadOption`，
包含集标题、该集所有可下载的 HTTP 候选源（按 `mediaSourcesProvider` 的注册顺序
排优先级——anime1 优先、xifan 次之）、`isDownloadable`、来源标签列表、
`preferred`（首选候选源）。

**4.2 四处调用点共用同一个函数**：

| 调用方 | 用法 |
|---|---|
| 选集面板 tab1 | 对整个列表运行一遍：展示来源标签；`isDownloadable == false` 的行置灰不可勾选 |
| 批量下载（勾选后的"下载选中 N 集"） | 对每个勾选的集取其 `preferred`，逐集 `enqueue` |
| 播放器底部条单集下载按钮 | 查询当前播放的集：命中则使用 `preferred`（可能与当前播放源不同）并显示"将从 anime1 下载"；查不到任何候选才置灰 |
| `retry()` | 重新运行一遍择源——原来的源已不可用时自动切换到另一个 |

四处调用统一到一个函数的好处：择源规则只维护一处，四处行为自动保持一致；纯函数
可以直接喂假数据做单元测试，不需要 mock 网络。

**4.3 换源后的旧记录清理策略**：由于 `episodeKey` 携带 `sourceId` 不变，同一集若
先后从 anime1 和 xifan 下载过，会产生两条独立的数据库记录和两份文件。正常流程下
不会出现这种重复（自动择源每次只挑一个源；相关 UI 用 `findCompletedForEpisode`
做跨源判定，不会重复触发下载）。但"anime1 下载一半失败 → 用户点击重试 → 此时
anime1 已经没有这一集了 → 自动换成 xifan 并成功"这条路径会在磁盘上留下 anime1
半成品目录的垃圾。**处理方式：重试成功后，自动删除同一集在其他源上的旧记录及
对应文件**，保证磁盘上每一集永远只保留一份成功的下载。

### 5. 错误处理与已知限制

**5.1 对第 2 节的修正——`localPath` 语义不统一的问题**：`completed` 状态的行，
`localPath` 存的是文件路径；`failed`/`downloading` 状态的行，`localPath` 存的是
目录路径。而 `download_list_item.dart:59` 的删除逻辑统一执行
`Directory(localPath).parent`，对于目录类型的行，这会指向 `<subjectId>/`，删除
时会连带清除同一部番的其他剧集文件。修法：Drift 新增专用列 `episodeDir`（worker
创建下载目录时写入），删除操作统一改为删除 `Directory(episodeDir)`，`localPath`
之后只用于确定播放文件路径，不再用于删除。因此 v5 迁移共新增 6 列（详见 2.1），
而非最初讨论的 5 列。

**5.2 "下载失败/下载不了"的根本修复——校验响应内容**：`_downloadFile` 目前既不
检查 HTTP 状态码也不检查 `content-type`。当 Anime1 的 Referer/Cookie 失效时，
服务器可能返回 200 状态码 + 一段 HTML 错误页；该 HTML 内容会被原样写入
`video.mp4` 并标记为 `completed`，只有真正播放时才会暴露问题——这很可能是用户
反馈"好像下载也似乎有问题"的真实原因。修复为：非 2xx 状态码 → 失败，
`errorMessage` 写入具体状态码；`content-type` 为 `text/html` → 失败，
`errorMessage` 为"源返回了网页而非视频（可能是防盗链或登录失效）"；响应体明显
过小且 `Content-Length` 缺失（< 100KB）→ 失败，`errorMessage` 为"返回内容过小，
可能不是视频"。失败原因逐字显示在下载列表行中。

**5.3 其余防御性修复**：`downloadDioProvider` 目前是未配置的裸 `Dio()`，改为复用
app 内其他 API client 配置代理设置的方式（实现阶段对齐现有写法，不重新发明）；
`sourceForId` 在源列表缺少对应 id 时不再 `throw StateError`，改为写入一条 `failed`
记录，`errorMessage` 为"来源已不可用"；磁盘写满/权限不足触发的 `FileSystemException`
统一写入 `failed` 记录并携带系统异常信息，本次不做预先的磁盘空间检查（YAGNI）。

**5.4 已知限制**（原样保留，供用户和后续开发者知悉）：

- mp4 类型下载不支持断点续传，重试从头开始下载。
- 不支持并发下载，同一时刻只有一个任务在下载。
- HLS 主播放列表只跟随第一个 variant，画质不可选。
- 不支持 BT/种子下载（Mikan 源的剧集在下载面板中显示为不可下载）。
- 自动择源可能导致"正在观看的画面"与"实际下载到本地的文件"来自不同源，画质/
  字幕组可能存在差异——因此下载面板和播放器按钮旁必须显示来源标签，让用户能够
  察觉这一点。
- 修改下载目录设置后，已经在队列中排队/下载中的任务仍会写入旧目录，只有新加入
  的任务使用新目录。

## 播放器交互细节

**用户明确要求**（原始诉求第 5 条）：批量下载按钮不放在详情页右上角 AppBar；
播放器下载按钮不放在顶部 top bar，移到底部播放控制条。

- 播放器底部条 `player_bottom_bar.dart` 在"倍速"右侧、"线路"左侧插入下载按钮，
  使用 `DownloadBadgeButton`。
- 按钮自身根据当前播放集的下载状态变化图标（未下载/排队中/下载中百分比/已完成），
  同时叠加一个全局角标数字，表示当前"正在下载中的集数"（不限于本番剧）。点击或
  长按打开与详情页共用的 `DownloadPanel(subjectId: 当前番剧)`，浮层显示在播放器
  之上，可以看到进度、可以取消，且**不需要离开播放器页面**——直接回答了用户提出
  的"如果我不离开播放器页面,怎知道有没有在下载"这一矛盾。
- 当前播放集所在的源不可下载（如 Mikan/BT）时，按钮**不再直接消失**：调用第 4
  节的择源函数查询该集是否存在于任意可下载源，命中则按钮可用并显示"将从 anime1
  下载"提示；所有源都无法下载才置灰。
- 入队成功和下载完成时，额外弹出一次性提示条（不遮挡画面，几秒后自动消失），
  提示条不作为唯一的进度反馈渠道。

## 详情页交互细节

详情页"选集"标题行（原截图中红框标注的位置，紧邻"连载至 06 · 预定全 8 话"）新增
**一个**带角标的下载按钮，角标显示当前这部番剧正在下载中的集数；原 AppBar 右上角
的"全部下载"图标移除。点击打开 `DownloadPanel(subjectId: 该番剧)`，包含两个 tab：

- **「选集下载」tab**：使用 `EpisodeSelectionTab`，列出合并后的剧集列表，逐集
  一行：`Checkbox` + 集标题 + 来源标签（如 `anime1`、`xifan`、`anime1 / xifan`）。
  三种不可勾选状态：`✓ 已下载`（置灰）、`◌ 下载中 42%`（置灰，显示实时进度）、
  `☐ 无可下载来源`（更淡的置灰，不可勾选）。勾选辅助仅提供「全选」/「清空」两个
  按钮（不做"仅选未下载"快捷键或 Shift 范围选择，YAGNI）。底部固定显示"已选 N 集"
  和主按钮"下载选中 N 集"，点击后对每个勾选集取其 `preferred` 源逐集 `enqueue`。
- **「下载中 · 已下载(N)」tab**：复用 `DownloadListItem`，只显示该番剧的记录，
  按状态展示下载中/已中断/已停滞/已完成/失败，提供取消/重试/删除操作。

## 首页与设置页

首页 AppBar 右上角新增下载图标（带全局角标：所有番剧正在下载中的总集数），点击
直接打开 `DownloadPanel(subjectId: null)` 浮层，两个 tab 中"选集下载"被隐藏（没有
明确的 subject 上下文）。设置页原有的"下载管理"入口保留，指向已退化为薄壳的
`/downloads` 路由，效果与首页图标一致。

## 测试计划

**6.1 时间源可注入约束**：见第 3.7 节。

**新增测试文件**：

| 文件 | 覆盖 |
|---|---|
| `test/domain/download/download_source_resolver_test.dart` | 纯函数喂假合并列表：只 anime1 可下、只 xifan 可下、两者都可下（验证 anime1 优先）、只有 mikan（全不可下）、混合列表逐集不同源 |
| `test/ui/download/download_panel_test.dart` | 两个 tab 切换；`subjectId == null` 时隐藏选集 tab；按 `subjectId` 过滤下载列表 |
| `test/ui/download/episode_selection_tab_test.dart` | 勾选/全选/清空；已下载与下载中的行置灰不可勾选；无可下载来源的行置灰；"已选 N 集"文案与主按钮文案；点击主按钮只 `enqueue` 勾选的那几集 |
| `test/ui/download/download_badge_button_test.dart` | 四种状态对应的图标；角标数字显示；角标为 0 时不显示 |
| `test/ui/download/download_list_item_test.dart`（新用例） | `interrupted` 显示"已中断"+ 重试/删除；`isStalled` 显示"已停滞，正在重试"；真实百分比显示；来源标签行；失败原因逐字显示 |

**改动现有测试文件**：

| 文件 | 改动 |
|---|---|
| `test/data/download/download_worker_test.dart` | 新增停滞四例（30s 无字节→自动重试一次；重试后再 30s→failed 且继续下一集；2 分钟零字节→直接 failed；慢但持续增长→永不超时）；HTTP 非 2xx 与 `text/html` content-type 判定失败；下载目录快照进 `DownloadRequest` |
| `test/data/download/hls_downloader_test.dart` | 下载前数出总分段数写入 `totalSegments`；逐段递增 `downloadedSegments`；重试时跳过已存在的非空分段文件 |
| `test/data/download/downloaded_episode_repository_test.dart` | `reconcileInterrupted()`；`findCompletedForEpisode(subjectId, title)` 跨源命中；进度字段按 1 秒/1% 节流写入 |
| `test/domain/download/download_queue_controller_test.dart` | keepAlive 后跨 `ref.invalidate` 场景不被销毁；改下载目录不清空队列；`retry()` 重新执行择源；换源成功后自动删除其他源的旧记录和文件；`enqueue` 对不支持的源写 `failed` 而非抛异常 |
| `test/data/local_database_test.dart` | `schemaVersion == 5`；v4→v5 迁移后 6 个新列存在，且旧数据保留 |
| `test/ui/subject/subject_detail_screen_download_test.dart` | 重写——现有 `:73` "queues every episode from first HTTP source" 覆盖的正是被淘汰的全有全无行为；改测"AppBar 不再有全部下载按钮"、"选集行有带角标的下载按钮"、"点击打开面板" |
| `test/ui/player/player_top_bar_test.dart` | 下载按钮已移除，现有参数化图标测试整块删除（迁移到 `download_badge_button_test.dart`） |
| `test/ui/player/player_bottom_bar_test.dart` | 下载按钮位于倍速右侧、线路左侧；状态图标；点击回调；当前源不可下载时显示"将从 anime1 下载"提示 |
| `test/ui/home/*` | 首页 AppBar 下载图标 + 全局角标 |
| `test/domain/play/episode_play_controller_test.dart` | 离线优先播放改用跨源查询后，从 mikan 播放该集也能命中 anime1 下载的那份文件 |

**明确不写的测试**：不写真实联网的端到端下载测试；`DownloadWorker` 的测试用假
`Dio` adapter，HLS 测试用假 manifest 内容。

## 与原设计文档的关系

本文档假定读者已经了解
`docs/superpowers/specs/2026-09-17-offline-video-download-design.md` 中描述的
基础技术选型（HTTP 直链、Drift 持久化、严格单任务队列、HLS 分段下载不做 mux、
不支持 BT/并发/断点续传的范围边界），仅在其基础上做本文档描述的 UX 重构和可靠性
修复，不重复解释未变化的部分。
