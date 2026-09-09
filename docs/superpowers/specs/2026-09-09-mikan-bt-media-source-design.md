# Mikan BT 边下边播数据源设计

## 背景与目标

用户原始需求（逐字保留）：

> 我现在要做一个数据源是 https://mikan.tangbai.cc/, 他属于BT种子播放,就是边下边看.现在要实现这个功能,我需要你的帮助
>
> 我觉得你结合 anmeko 和 https://sub.creamycake.org/v1/bt1.json, 这个播放源,看看要怎么实现

目标：为 animeko-flutter 添加一个 BT/磁力数据源（Mikan 镜像 `https://mikan.tangbai.cc/`），实现"边下边看"，参考上游 Animeko (KMP) 的实现方式，以及 Animeko 媒体源*订阅* JSON 格式（`bt1.json` 里 nyaa.land 和 AnimeGarden 走的是 Animeko 通用 `rss` factory，searchUrl 模板驱动，非硬编码站点）。

## 已确定的技术决策

- **引擎**：rqbit sidecar 子进程（打包 rqbit 可执行文件，Dart 只通过 Dio 调用其 JSON HTTP API），POST 种子文件字节（禁止使用 magnet URI——已实测 POST magnet 会同步阻塞 DHT 解析直到超时），播放地址直接是 rqbit 的 `GET /torrents/{id}/stream/{file_idx}`（支持 Range，未下载区间会阻塞至数据到达再返回，不报错），交给 media_kit 播放。
- **功能范围（v1）**：仅在线边下边看，不做离线缓存/保留/做种。播放结束后调用 rqbit `/torrents/{id}/delete`（遗忘 + 删文件）。1→2（+ 离线缓存）留作后续增量：一张 Drift 表 + `schemaVersion` 3 迁移，非重写。
- **代理**：v1 不处理，BT 流量直连。（rqbit 支持 `RQBIT_SOCKS_PROXY_URL`，但仅 SOCKS5，与本仓库现有 `proxy_dio_config.dart` 的 HTTP 风格代理协议不兼容，此问题推后到后续迭代。）
- **数据源建模**：通用 RSS 数据源工厂（对标 Animeko 的 `rss` factory，`searchUrl` 模板驱动，`{keyword}`/`{page}` 占位符），非 Mikan 专用硬编码源。Mikan 是内置的第一个配置实例；后续可直接导入 `bt1.json` 订阅格式支持 nyaa.land、AnimeGarden。
- **架构方案**：采用"方案 1"——把 RSS/BT 数据塞进现有 `MediaSource` 抽象（search→listEpisodes→resolvePlayback 三段式），复用现有线路切换 UI（`EpisodeSourceGrid`）和播放失败自动降级重试机制（`player_screen.dart` 现有 `_player.stream.error.listen`）。"方案 3"（引入 Animeko 式带元数据的 `Media` + `MediaSelector`，支持偏好分辨率/语言/字幕组黑名单/自动选优）记为技术债，本次不做。

## 一、整体架构总览

新增三个模块，拼接进现有架构：

1. **RSS 数据源工厂** (`lib/data/rss/`)：通用 `RssMediaSource`，用 `searchUrl` 模板驱动请求，Mikan 是第一个内置配置实例。负责拉取 RSS → 解析 XML → 解析发布标题（集数/分辨率/字幕组/语言）→ 按集数分组成 `MediaEpisode`。
2. **`MediaSource` 抽象扩展** (`lib/domain/media/`)：`MediaPlaybackSource` 新增生命周期钩子 `prepare()`（返回可播放 url）/ `dispose()`（清理种子资源），`episode_source_matcher.dart` 新增按集数值匹配的分支（与现有纯位置匹配并存）。
3. **rqbit Sidecar 引擎** (`lib/data/torrent/`)：应用首次播放 BT 内容时懒启动 rqbit 子进程；播放时 Dio 下载 `.torrent` 字节 → POST 给 rqbit → 拿 stream URL → 交给现有 `player_screen.dart` 播放链路；停止播放时调用 rqbit `/delete` 清理磁盘（"不保留"范围）。

**核心设计原则**：BT 数据源对外形状伪装成普通 `MediaSource`。UI 层（`EpisodeSourceGrid`、`player_screen.dart` 的自动降级重试）不需要知道某条线路背后是 HTTP 直链还是 BT 种子，差异全部封装在 `RssMediaSource`（`MikanRssMediaSource` 配置实例）与 `MediaPlaybackSource` 新生命周期钩子内部。

## 二、数据模型与组件设计

### 2.1 `RssMediaSource` 如何映射到现有三段式接口

新建 `lib/data/rss/rss_media_source.dart`：

```dart
class RssMediaSource implements MediaSource {
  RssMediaSource(this.config);
  final RssSourceConfig config;   // name / searchUrl 模板 / iconUrl 等；Mikan 是内置默认实例
}
```

RSS 没有独立的"按番剧查询"和"按集查询"两个端点，一次 `GET searchUrl.replace('{keyword}', name)` 就是全部数据，因此设计为：

- `search(String name)`：**一次性**完成 RSS 拉取 + XML 解析 + 标题解析 + 按集数分组，返回单个 `RssSeriesCandidate`（实现 `MediaCandidate`，内部已内建全部分组结果 `groups: Map<int, List<RssRelease>>`）。
- `listEpisodes(MediaCandidate candidate)`：纯同步地从已缓存的 `groups` 转换为 `List<RssEpisode>`（实现 `MediaEpisode`，含 `episodeNumber` + `releases` 列表），**不再发请求**。
- `resolvePlayback(MediaEpisode episode)`：对 `episode.releases` 按 tier/分辨率/字幕组偏好做简单启发式排序（**非** Animeko 完整 `MediaSelector`，明确标记为技术债），每个 release 映射为一个 `TorrentPlaybackSource`。

过滤规则对齐上游 Animeko：**解析不出集数（`episodeRange == null`）的条目直接丢弃**，不进入任何分组。`RssSeriesCandidate`/`RssEpisode` 是新的轻量数据类，风格对齐现有 `Anime1Category`/`XifanEpisode`（同样采用 unchecked downcast 惯例）。

### 2.2 `TitleParser` 标题解析器

新建 `lib/domain/media/title_parser.dart`，与 `title_matcher.dart` 同级、同样是纯函数、无 Flutter 依赖，方便单测。对标上游 `LabelFirstRawTitleParser`，但只做本项目实际需要的 4 项子集：

```dart
class ParsedTitle {
  final EpisodeRange? episodeRange;   // null 表示解析失败，上游据此丢弃该条
  final String? resolution;           // '1080P' 等，解析不出时由调用方决定默认值
  final String alliance;              // 第一个 ] 或 】 之前的文本，与上游同一套 heuristic
  final List<String> subtitleLanguages;
}

ParsedTitle parseTitle(String rawTitle);
```

分词/集数/分辨率/语言的具体规则直接沿用调研阶段记录的上游算法：方括号 `[]`/`【】` 分词、` - 10` / `[10]` / `[07-10]` 区间记法、`resolutionNumbers = {360,480,848,1080,1440,1920,2160}` 集合防止分辨率被误判为集数、简中/繁中/粤语关键词表。这是逻辑最复杂的一块，需要最多的测试用例覆盖（见第五节）。

### 2.3 `MediaPlaybackSource` 生命周期扩展

现状（`lib/domain/media/media_source.dart:30-38`）只有 `url`/`headers` 两个 getter，`player_screen.dart:521` 直接拿去 `Media(url, httpHeaders: headers)`。改法是**新增两个有默认实现的方法**，现有 4 个 HTTP 数据源（anime1/xifan/yinghua/dilidili）**不需要改代码**：

```dart
abstract class MediaPlaybackSource {
  String get url;
  Map<String, String> get headers;

  /// 返回真正可交给播放器的 URL。HTTP 源直接返回 url（默认实现）；
  /// BT 源在这里发起"下载种子字节 → POST 给 rqbit → 拿 stream URL"整套流程。
  Future<String> prepare() async => url;

  /// 播放结束/切换线路时调用，用于清理资源。HTTP 源默认空实现。
  Future<void> dispose() async {}
}
```

`TorrentPlaybackSource`（BT 专用实现）重写这两个方法：

```dart
class TorrentPlaybackSource implements MediaPlaybackSource {
  TorrentPlaybackSource({required this.release, required this.engine});
  final RssRelease release;   // 含 .torrent 下载 URL、文件大小等（即 groupByEpisode 产出的同一类型）
  final RqbitEngine engine;
  int? _torrentId;

  @override
  String get url => throw StateError('必须先调用 prepare()');
  @override
  Map<String, String> get headers => const {};

  @override
  Future<String> prepare() async {
    final bytes = await _dio.get<List<int>>(release.torrentUrl, ...);
    final result = await engine.addTorrent(bytes);
    _torrentId = result.id;
    // episodeInSet 用于多文件种子（一集一文件的批量包）按集号选中对应文件；
    // 单文件种子直接回退到"最大视频文件"启发式，见 3.2 节。
    final fileIndex = result.pickVideoFile(episodeInSet: release.episodeInSet);
    return engine.streamUrl(result.id, fileIndex: fileIndex);
  }

  @override
  Future<void> dispose() async {
    if (_torrentId != null) await engine.deleteTorrent(_torrentId!);
  }
}
```

**对 `player_screen.dart` 唯一必要的改动**：`_openCandidate`（现在是 L513-526）在 `_player.open(...)` 之前插入 `final playableUrl = await source.prepare();`；播放失败/切换线路时调用旧候选的 `dispose()`。其余（降级重试、缓冲态、resume position）全部复用不变。

### 2.4 rqbit sidecar 管理类

新建 `lib/data/torrent/rqbit_engine.dart`：

```dart
class RqbitEngine {
  Future<void> ensureStarted();                                  // 懒启动子进程
  Future<AddTorrentResult> addTorrent(List<int> torrentBytes);   // POST /torrents
  String streamUrl(int torrentId, {required int fileIndex});     // http://127.0.0.1:<port>/torrents/{id}/stream/{fileIndex}
  Future<void> deleteTorrent(int torrentId);                     // POST /torrents/{id}/delete
  Future<void> shutdown();                                       // 应用退出时 kill 进程
}

@Riverpod(keepAlive: true)
RqbitEngine rqbitEngine(Ref ref) => RqbitEngine();
```

内部用 `Process.start` 拉起打包在 `macos/Runner/Resources/` 里的 rqbit 二进制，`--http-api-listen-addr 127.0.0.1:0` 让系统动态分配端口（避免硬编码端口冲突），用普通 `Dio` 调用其 JSON API。

## 三、数据流与集数分组算法

### 3.1 端到端流程

用户点击某集 → `EpisodePlaybackSheet` 请求 `SubjectEpisodesController` → 对所有 `MediaSource`（含 `RssMediaSource`）并发调用 `search(subjectName)` → `RssMediaSource.search()` 内部：用 `searchUrl` 模板拼 GET 请求（Mikan: `/RSS/Search?searchstr=<name>`）→ `XmlDocument.parse()` 解析约 100 条 `<item>` → 对每条 `item.title` 调用 `parseTitle()` 得到 `ParsedTitle` → `episodeRange == null` 的条目丢弃 → 按 `episodeRange` 分组成 `Map<int, List<RssRelease>>`（key 是集数）→ 包装成 `RssSeriesCandidate` → 结果通过 `matchBest(subjectName)` 校验（复用 `title_matcher.dart`）。

`SubjectEpisodesController` 拿到候选后调用 `listEpisodes()`——纯同步遍历分组 Map 转成 `List<RssEpisode>`，不再发请求。用户选中 Mikan 线路 + 第 N 集 → `episode_source_matcher.matchEpisodeSources()` 按集数（非位置）查找 `episodeNumber == N` 的项 → `EpisodePlayController.resolvePlayback()` 调用 `RssMediaSource.resolvePlayback(episode)`——对 releases 排序（分辨率/字幕组偏好，简单启发式），每个 release 包成 `TorrentPlaybackSource(release, engine)` → `player_screen._openCandidate(source)`：`await source.prepare()`（内部 Dio 下载 `.torrent` 字节 → POST 给 rqbit → 拿 streamUrl）→ `_player.open(Media(streamUrl))`。用户退出/切换线路时调用旧候选的 `dispose()` → `engine.deleteTorrent(id)`。

关键点：分组只做一次（在 `search()` 里），`listEpisodes()`/`resolvePlayback()` 都是同步读缓存。

### 3.2 集数分组算法

`groupByEpisode` 纯函数（位于 `title_parser.dart` 或 `rss_media_source.dart` 内部）：

```dart
Map<int, List<RssRelease>> groupByEpisode(List<RssItem> items) {
  final groups = <int, List<RssRelease>>{};
  for (final item in items) {
    try {
      final parsed = parseTitle(item.title);
      if (parsed.episodeRange == null) continue;
      for (final ep in parsed.episodeRange!.expand()) {
        groups.putIfAbsent(ep, () => []).add(RssRelease(item, parsed));
      }
    } catch (_) {
      continue; // 单条目解析异常不影响其余条目
    }
  }
  return groups;
}
```

- **区间集数展开**：`EpisodeRange` 需提供 `expand()` → `Iterable<int>`，如 `[07-10]` → `{7,8,9,10}`，该发布同时进入这 4 个分组。v1 简化假设：Mikan 多集合集大多是单文件容器（一集一个 MP4/MKV）；若种子内是多文件对应多集，则 `TorrentPlaybackSource.prepare()` 内选文件逻辑需文件名/顺序与集号对应（通过 `release.episodeInSet` 传给 `pickVideoFile()`）；若种子是单文件多集打包（罕见如季度合集），v1 不处理，写入下方"已知限制"。
- **SP/OVA/特别篇**：`EpisodeRange` 支持 `EpisodeSort.Special`（对齐上游），分组 key 用 sentinel（如负数区间）与正常集数区隔；UI 侧本期不做专门处理，SP 分组默认是"孤儿"（不强求展示，技术债）。
- **与 Bangumi sort 字段对齐**：v1 采用最简单假设 `episodeNumber == bangumiEpisode.sort` 直接数值相等匹配，不做"绝对集数→季内集数"换算（上游有 `episodeEp` vs `episodeSort` 两套字段处理，本设计不引入，已知简化）。

### 3.3 `episode_source_matcher.dart` 改动

现状（`episode_source_matcher.dart:22`）`matchEpisodeSources({ordinalIndex, allMerged})` 纯按位置 `allMerged[sourceIndex].episodes[ordinalIndex]`。**不改函数签名/调用方**，新增基于"集数值"的匹配分支，通过运行时类型判断分流：

```dart
MediaEpisode? _findBySort(List<MediaEpisode> episodes, int wantedSort) {
  for (final ep in episodes) {
    if (ep is RssEpisode && ep.episodeNumber == wantedSort) return ep;
  }
  return null; // 允许留空，不报错
}
```

`MediaEpisode` 基类不带集数字段（不改动基类，避免影响 anime1/xifan/yinghua/dilidili 四个现有实现），通过 `is RssEpisode` 向下判断走哪套匹配逻辑——两套匹配逻辑并存。

### 3.4 找不到发布的集数

不报错，留空。`SubjectEpisodesController._fetchFromSource` 现状（`subject_episodes_controller.dart:73-78`）已是每源独立 try/catch 静默吞异常。RSS 某集没人发布不是异常，是 `groups` Map 里本来就不存在该 key，`listEpisodes()` 天然没有这一项。UI 层（`EpisodeSourceGrid`）现有逻辑本就允许某源某集缺失线路，完全复用现有行为无需新增处理。

## 四、错误处理与降级策略

### 4.1 复用现有播放失败自动降级机制

`player_screen.dart:131-157` 的 `_player.stream.error.listen` 监听器在播放失败时自动切到 `_candidateIndex + 1`（下一个线路/发布）——**原样复用，无需改动**。BT 场景下"字幕组种子没人做种"和"线路链接挂了"在这一层看来是同一件事。仅需补一处：切换候选前必须调用旧候选的 `dispose()`（否则旧种子会一直占着 rqbit 下载资源不释放）。改动位置就在 `_openCandidate` 切换逻辑里：失败时先 `await oldSource.dispose()` 再 `await _openCandidate(next)`。

### 4.2 `prepare()` 超时策略——解决"种子没人做种"问题

实测发现真实 Mikan 种子可能出现长时间大部分 peer 死亡、下载速度远低于播放需求的情况。设计：`prepare()` 内部**不**死等下载完成，采用"探测式"策略——`prepare()` 拿到 stream URL 后立即返回，交给 media_kit 播放（rqbit 的 `/stream/{file_idx}` 本身会阻塞到数据可用才返回，已验证不会报错，只会延迟）。

真正需要处理超时的是**播放器长时间卡在 buffering 状态**：在 `player_screen.dart` 现有 `_isBuffering`（由 `_player.stream.buffering` 驱动）基础上新增一个计时器——若缓冲状态持续超过一个阈值（如 30 秒），判定为"这个线路太慢/没人做种"，主动触发失败降级（调用 `dispose()` + 切下一个候选），而不是让用户一直对着加载圈等。这个阈值判断放在 `player_screen.dart`（播放体验层面），而不是放进 `RqbitEngine`/`TorrentPlaybackSource` 内部——因为"多久算超时"是播放体验判断，且这样可复用到未来任何慢速线路。

### 4.3 rqbit 进程本身的异常

`RqbitEngine.ensureStarted()` 需处理：

- **启动失败**（二进制缺失/损坏、端口被占用、权限问题）：异常直接向上抛给调用方（`prepare()` 的调用者），最终表现为"这个候选打不开"，走 4.1 的降级路径——rqbit 启动失败等价于"BT 这条线路整体不可用"，所有 BT 候选一起失败，非 BT 候选（如果同时存在）仍可正常播放。
- **运行中异常退出**：`RqbitEngine` 内部监听子进程的 `exitCode`（`Process.exitCode` future），一旦检测到意外退出，标记内部状态为"未启动"，下次 `ensureStarted()` 调用时重新拉起进程。已在播放的流会因连接断开触发 `_player.stream.error`，走 4.1 现有降级路径自然处理，不需要专门的"崩溃恢复"UI。
- **端口选择**：使用 `--http-api-listen-addr 127.0.0.1:0`（系统随机分配空闲端口）避免端口冲突。

### 4.4 rqbit HTTP API 请求超时/失败

- `POST /torrents`（添加种子）：设定一个保守超时（如 10 秒）防止极端情况卡死，超时按失败处理。
- `GET /torrents/{id}/stream/{file_idx}`：未下载区间会阻塞直到数据到达（不报错），rqbit 内部有约 180 秒/片超时，超时后连接会被服务端中断。这类"连接意外中断"会被 media_kit 感知为播放错误，自然走现有 `_player.stream.error.listen` 降级路径，无需额外处理——这是"直接把 rqbit 的 stream URL 交给播放器"而非"自己包一层 Dio 请求"的设计优势，媒体层的错误处理机制原生复用。
- 常规管理类请求（`/torrents/{id}/delete` 清理等）：失败仅记录日志，不阻塞用户操作（清理失败最坏情况是磁盘多占用一些空间，属于可接受的降级）。

### 4.5 标题解析失败/RSS XML 格式异常

- 单条 `<item>` 解析异常：在 `groupByEpisode` 的循环体内 `try { ... } catch { continue; }`，跳过该条目，不影响其余条目的处理——对齐现有 xifan/anime1 数据层"逐候选 try/catch continue"的既有代码惯例。
- 整个 `search()` 请求失败（网络错误、RSS 服务端 5xx、响应体不是合法 XML）：异常向上抛出，被 `SubjectEpisodesController._fetchFromSource` 的 try/catch 吞掉，等价于"这个 RSS 源这次没搜到东西"，不影响 anime1/xifan 等其他源正常显示结果。

## 五、测试策略

### 5.1 整体原则

延续本仓库现有测试风格（`mocktail` mock API 类而非 HTTP 层、`ProviderContainer` + `addTearDown`、真实 fixture 驱动解析测试），不引入新的测试框架。新增测试全部放在 `test/` 下对应 `lib/` 路径（如 `test/data/rss/`、`test/data/torrent/`、`test/domain/media/title_parser_test.dart`）。

### 5.2 RSS/标题解析——用真实 fixture

将实测抓取到的几份真实 Mikan RSS 响应（含 MP4/MKV 混合、区间集数 `[07-10]`、`【】` 分隔符、`★07月新番` 季度标记等真实样本）存为测试 fixture 文件，如 `test/fixtures/mikan_rss_search_sample.xml`。

- `test/data/rss/rss_parser_test.dart`：喂入 fixture，断言解析出的 `<item>` 数量、`torrent>pubDate` 正确读取（不是 `item>pubDate`）、`enclosure@url` 正确提取。
- `test/domain/media/title_parser_test.dart`：逐条覆盖真实标题样本（如 `[黒ネズミたち]...- 10`、`【澄空学园&动漫国字幕组】★07月新番[...][07-10]`、`[ANi]  ... - 09 [1080P][Baha]` 等），断言 `episodeRange`/`resolution`/`alliance`/`subtitleLanguages` 符合预期。这是逻辑最复杂的一块，预计 10-20 个用例，覆盖单集/区间集/无法解析集数应返回 null 等边界。

### 5.3 集数分组算法

`test/data/rss/episode_grouping_test.dart`：`groupByEpisode()` 用构造好的 `RssItem` 列表（不需要真实网络）测试：区间集数展开后同时出现在多个分组、`episodeRange == null` 的条目被丢弃且不影响其余条目分组、单条目解析异常被 `try/catch continue` 跳过不中断整体。

### 5.4 `MediaPlaybackSource` 生命周期钩子回归测试

- `test/domain/media/media_source_test.dart`（现有文件）补充测试：确认 `prepare()`/`dispose()` 默认实现对 HTTP 源（anime1/xifan/yinghua/dilidili）是透明的——即不覆写这两个方法的现有实现，`prepare()` 直接返回 `url`，`dispose()` 是空操作。这是保证现有测试套件不回归的关键验证点。
- `test/data/torrent/torrent_playback_source_test.dart`（新建）：mock `RqbitEngine`，验证 `prepare()` 正确调用 `engine.addTorrent(bytes)` 并返回 `engine.streamUrl(...)` 的结果；`dispose()` 正确调用 `engine.deleteTorrent(id)`；`prepare()` 抛异常时正确向上传播。

### 5.5 `episode_source_matcher.dart` 新匹配分支

`test/domain/play/episode_source_matcher_test.dart`（现有文件）新增用例：验证 `RssEpisode` 按 `episodeNumber` 匹配（而非位置），包括"某集缺失发布"时返回 null 不报错的情况；同时保留并确保现有纯位置匹配的用例（anime1/xifan 等）继续通过，验证两套逻辑并存不冲突。

### 5.6 `RqbitEngine` 测试范围划分

- 纯单元测试（默认 CI 跑）：mock Dio 层，验证 `RqbitEngine` 对 rqbit HTTP API 的请求构造正确（如 `POST /torrents` 的 body 是原始字节、`streamUrl()` 拼接的 URL 格式正确、`deleteTorrent()` 调的是 `/torrents/{id}/delete` 而非 `/forget`）。
- 真实拉起 rqbit 二进制的集成测试：标记为可选/慢测试，不在默认 `flutter test` 里跑，避免 CI 环境缺 rqbit 二进制导致失败。此类测试留作实施阶段按需补充。

### 5.7 现有测试的回归保证

本设计对现有 4 个数据源（anime1/xifan/yinghua/dilidili）、`media_registry.dart` 注册列表、`player_screen.dart` 播放主链路均无破坏性改动（新增方法有默认实现、新增 provider 是独立文件），预期现有测试套件应 100% 保持通过，仅 `media_registry_test.dart` 需要追加对新 RSS 源 ID 的断言。

## 六、已知限制 / 技术债

- **无代理支持**：v1 BT 流量直连，不接入现有代理设置。rqbit 支持 SOCKS5（`RQBIT_SOCKS_PROXY_URL`），但与本仓库现有 HTTP 风格代理配置协议不兼容，需要后续单独设计（如扩展代理设置支持双协议，或新增独立的 BT 专用代理输入框）。
- **无离线缓存/保留/做种**：v1 仅在线边下边看，播放结束即删除种子和已下载数据。后续增量（1→2）需要新增一张 Drift 表记录保留的下载项 + `schemaVersion` 3 迁移，属于纯增量非重写。
- **多集合集单文件场景不支持**：若同一个种子内单文件对应多集打包（罕见，如季度合集压缩包），v1 不处理，可能导致点击第 N 集实际打开的是合集起始内容。
- **SP/特别篇孤儿分组**：特别篇/OVA 等非常规集数目前只是分组隔离，UI 不做专门展示，用户在正常集数网格里看不到这些内容。
- **`episodeNumber == bangumiEpisode.sort` 简化假设**：不做"绝对集数→季内集数"换算，与上游 Animeko 的 `episodeEp`/`episodeSort` 双字段机制相比是简化。对于跨季连续编号的番剧可能匹配错位。
- **`resolvePlayback` 排序是简单启发式**：按 tier/分辨率/字幕组做基础排序，非 Animeko 完整 `MediaSelector`（无用户可配置的分辨率偏好、语言偏好、字幕组黑名单、自动选优记忆）。
- **无 fastresume 跨重启恢复**：应用重启后进行中的下载/播放状态不会恢复，符合"仅在线边下边看"范围。
- **"方案 3"（Animeko 式完整 MediaSelector 升级）记为技术债**：本次不做架构级重写，仅在现有 `MediaSource` 抽象上做最小必要扩展。
