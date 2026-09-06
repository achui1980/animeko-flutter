# 多线路播放自动回退设计（Dilidili / Yinghua / Xifan）

日期：2026-09-06
状态：已批准（Approved）

## 背景与问题

用户在使用"嘀哩嘀哩"（Dilidili）数据源播放时遇到报错：

```
播放失败：Failed to open https://v.lzcdn31.com/20260905/10986_f90d8413/index.m3u8.
```

通过对真实站点的直接 curl 复现（非猜测）确认了根因：Dilidili 的观看页会为同一集提供多条"线路"（如 线路ML/MW/MS/MG...），每条线路各自对应一个 `play_id`，最终解析出的 CDN 域名往往完全不同。现有 `DilidiliApi.resolvePlaybackUrl()`（`lib/data/dilidili/dilidili_api.dart`）仅通过 `document.querySelector('button.play-btn')`（单选，只取第一个）读取第一条线路，没有任何回退逻辑。对某一真实剧集的 6 条线路实测：只有 1 条真正可用，其余 5 条分别以 HTTP 404、TLS 握手失败、HTTP 403 的方式失效。用户截图中的报错正是命中了一条已失效（404）的线路。

现有的"重试"按钮（`PlayerScreen._retry()`）对这一类失败是无效的：它只是 `ref.invalidate(episodePlayControllerProvider(...))`，强制 `EpisodePlayController.build()` 用**同一集/同一数据源**重新执行，会确定性地重新抓取同一个观看页并再次选中同一条（仍然失效的）第一条线路。

进一步排查发现，这不是 Dilidili 独有的问题：`Yinghua`（樱花动漫）和 `Xifan`（稀饭动漫）的抓取代码中都存在字面的 `TODO`/`NOTE` 注释，明确写着"只读取第一条线路，需要支持切换线路"（`lib/data/yinghua/yinghua_api.dart:56-60`、`lib/data/xifan/xifan_api.dart:75-78`）。`Anime1Api` 没有多线路概念，不受影响。代码库中当前没有任何"候选列表 + 失败回退"的既有模式可以复用。

## 三个数据源的"线路"结构差异（关键发现）

三者的"线路"在 HTML 结构上并不相同，因此修复方式也不同：

- **Dilidili（一对多在同一个观看页内）**：一集只有一个观看页 URL（`listEpisodes` 不变），但该观看页上有多个 `button.play-btn`，每个按钮各自带一个 `play_id`，都通过同一个 `/_get_play?id=...` 接口解析出播放地址。多线路的"展开"完全发生在 `resolvePlaybackUrl` 内部。
- **Yinghua（一对多分布在详情页的多个并列区块）**：每条线路是详情页上独立的 `div.stui-pannel.stui-pannel-bg` 区块，各自包含一份完整的 `<ul class="stui-content__playlist">`。同一集在不同线路下有**不同的 URL**（线路号编码在路径的 `sid` 段：`/index.php/vod/play/id/<bangumiId>/sid/<lineId>/nid/<episodeNumber>.html`）。目前 `listEpisodes` 用 `document.querySelector(...)`（单选）只读第一个区块。
- **Xifan（结构与 Yinghua 相同）**：每条线路是 `.anthology-list-box` 下并列的 `<ul class="anthology-list-play">`。线路号编码在路径段：`/watch/<bangumiId>/<lineId>/<episodeNumber>.html`。目前同样用 `document.querySelector(...)` 只读第一个列表。

也就是说：Dilidili 是"一集 → 多播放候选"的一对多关系，扇出完全在 `resolvePlaybackUrl` 内部；Yinghua/Xifan 是"一集在页面上对应多个不同 `MediaEpisode` URL"，扇出必须发生在 `listEpisodes` 阶段，再按标题精确匹配合并回同一个逻辑剧集。

Yinghua/Xifan 都没有 Dilidili 式的二次查询接口，均为单请求流程：请求页面 → 通过私有的 `_extractPlayerJson` 括号平衡扫描器提取内联的 `var player_aaaa = {...}` JSON → 读取 `url` 字段。Yinghua 不做解密（`encrypt` 恒为 `'0'`），并附带防御性的 `Referer: https://www.yinghua2.com/`；Xifan 按 JSON 中的 `encrypt` 字段解密（`'1'` → percent-decode，`'2'` → base64 + percent-decode，其它 → 原样使用），不附带任何 header。

## 设计目标（范围）

**范围内：**
- 一次性修复 Dilidili、Yinghua、Xifan 三个数据源（`Anime1` 无此问题，不涉及）。
- 统一 `MediaSource.resolvePlayback` 接口，使其返回一个有序的候选播放源列表，而不是单一播放源。
- 播放器在原生播放失败时自动、静默地尝试列表中的下一个候选，直到成功或全部候选耗尽。
- 全部候选耗尽后才展示错误界面；"重试"按钮语义变为"从头重新解析并重试整条候选链"。
- 为新行为补充测试覆盖（多线路抓取、部分候选解析失败的容错、播放器自动回退与耗尽后报错）。

**范围外：**
- 不引入线路可达性探测（不做候选生成阶段的网络预检）。
- 不引入候选数量或总耗时上限（依赖 media_kit/ffmpeg 自身的网络层超时）。
- 不区分"刚打开就失败"与"播放中途中断"两种失败，统一按同一逻辑自动切换下一候选。
- 不做跨线路剧集标题的模糊匹配（仅做精确字符串匹配）。
- 不新增手动选择线路的 UI（如"当前播放线路 2/6"之类的展示或手动切换控件）。
- 不改变 `MediaPlaybackSource{url, headers}` 本身的字段结构。

## 架构与接口变更

### 1. 统一接口变更

```dart
// lib/domain/media/media_source.dart
abstract class MediaSource {
  ...
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode);
  // 变更前：Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode);
}
```

返回值约定：非空有序列表，下标 0 为默认/首选线路，其余按线路在页面中出现的顺序排列，作为失败回退的尝试顺序。`MediaPlaybackSource{url, headers}` 结构本身不变——每个候选携带自己的 headers，天然支持"不同线路可能需要不同 header"的情况，无需额外设计。

### 2. 三个数据源各自的改法

- **Dilidili**（`lib/data/dilidili/dilidili_api.dart`）：`resolvePlaybackUrl` 中的 `document.querySelector('button.play-btn')` 改为 `querySelectorAll(...)`，遍历所有按钮取得全部 `play_id`，对每个 `play_id` 分别调用 `/_get_play`，逐个尝试解析出 `MediaPlaybackSource`。`listEpisodes` 不变。

- **Yinghua**（`lib/data/yinghua/yinghua_api.dart`）：`listEpisodes` 改为 `document.querySelectorAll('div.stui-pannel.stui-pannel-bg')` 遍历全部线路区块；跨区块按**剧集标题精确字符串匹配**合并为同一个逻辑剧集，`YinghuaEpisode` 从持有单个 `playPageUrl: String` 改为持有一个有序的 URL 列表（如 `List<String> playPageUrls`）。`resolvePlaybackUrl` 相应地改为遍历该 URL 列表，对每个 URL 请求页面并提取 `player_aaaa` JSON，逐个尝试构造 `YinghuaPlaybackSource`。

- **Xifan**（`lib/data/xifan/xifan_api.dart`）：结构与 Yinghua 完全对应——`listEpisodes` 改为 `document.querySelectorAll('.anthology-list-play')` 遍历全部线路列表，按标题精确匹配合并；`XifanEpisode` 从单个 `watchPageUrl: String` 改为有序 URL 列表；`resolvePlaybackUrl` 遍历该列表，对每个 URL 请求并按原有 `encrypt` 字段逻辑解密，逐个尝试构造 `XifanPlaybackSource`。

- **容错原则（三者一致）**：解析某一个候选时若失败（网络错误、JSON 解析失败、字段缺失等），跳过该候选而不是立即抛出异常；仅当**全部**候选都解析失败时才抛出异常（沿用现有的 `FormatException` 风格与错误文案）。若列表中至少有一个候选成功解析，`resolvePlayback`/各 API 的 `resolvePlaybackUrl` 就应返回这些成功解析出的候选（顺序保持与原始线路顺序一致）。

### 3. `EpisodePlayController` 改法

```dart
// lib/domain/play/episode_play_controller.dart
@riverpod
class EpisodePlayController extends _$EpisodePlayController {
  @override
  Future<List<MediaPlaybackSource>> build({required MergedEpisode episode}) {
    final sources = ref.watch(mediaSourcesProvider);
    final source = sources.firstWhere((s) => s.id == episode.sourceId);
    return source.resolvePlayback(episode.episode);
  }
}
```

仅返回类型从 `Future<MediaPlaybackSource>` 变为 `Future<List<MediaPlaybackSource>>`，其余查找 `MediaSource`、调用 `resolvePlayback` 的逻辑不变。

### 4. `PlayerScreen` 改法

新增本地状态：`List<MediaPlaybackSource>? _candidates`、`int _candidateIndex`。

- 收到新的候选列表时：重置 `_candidateIndex = 0`，用 `_candidates![0]` 通过 `Media(url, httpHeaders: headers)` 打开播放。
- 原生播放报错（`_player.stream.error` 事件）时：若 `_candidateIndex + 1 < _candidates!.length`，静默地将 `_candidateIndex` 递增并打开下一个候选（**不展示任何错误提示，继续保持原有的加载中状态**；不区分是"刚打开就失败"还是"播放中途中断"，统一按此逻辑处理）。
- 仅当最后一个候选也失败时，才展示 `ErrorRetryView`（错误文案格式不变，仍为 `'播放失败：$_playbackError'`）。
- "重试"（`_retry()`）按钮语义变为"从头重新走完整条候选链"：重置 `_candidateIndex = 0` 并 `ref.invalidate(episodePlayControllerProvider(...))`，触发完整的重新解析（因为源页面内容可能已发生变化，不只是简单地重放本地候选列表）。

### 5. 测试要求

- 三个数据源现有的 HTML 测试夹具（fixtures）目前只覆盖单线路场景，需要补充多线路场景的夹具与断言，验证能收集到完整的、按线路顺序排列的候选列表。
- 各数据源的 `resolvePlaybackUrl`（或等价方法）需要补充测试：（a）部分候选解析失败时，仍能返回其余成功解析的候选；（b）全部候选解析失败时抛出异常。
- `EpisodePlayController`/`PlayerScreen` 需要补充测试覆盖：失败时自动切换下一候选、候选耗尽后展示错误、"重试"会重置到候选链起点并触发完整重新解析。

## 风险与已知限制

- 依赖 media_kit/ffmpeg 自身的网络层超时来判定"当前候选已失败"，若某条线路的失败方式是长时间挂起而非快速报错，自动切换会因此延迟——设计上认为当前观察到的真实失败模式（404/TLS失败/403）都是快速失败，此风险接受但不主动处理（范围外）。
- Yinghua/Xifan 的跨线路剧集合并采用标题精确匹配；若未来某个站点在不同线路下出现标题不一致（如"第01集" vs "第1集"），该线路会被视为独立剧集而不会被合并为同一候选链的一部分——现有测试夹具未观察到此类不一致，暂不处理（范围外）。
