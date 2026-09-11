# Mikan 字幕组发现：改用番剧 feed 设计

日期：2026-09-11
状态：已确认，待实现

## 背景与问题

用户反馈：Mikan 网站上「恶女不才，请多关照 ～雏宫蝶鼠换身传～」的侧栏列出 4 个以上字幕组，
但 app 的线路切换里只有 `TSDM字幕组` 一个。

排查结论（已实测验证）：**app 从来不发现字幕组**。字幕组名只是解析种子标题时的副产品
（`lib/domain/media/title_parser.dart:167-174` 取首个 `]`/`】` 之前的文本），而种子来自唯一一次
关键词全文搜索（`lib/data/rss/rss_media_source.dart:124-136`）：

```
GET https://mikanani.me/RSS/Search?searchstr=<Bangumi nameCn 原文>
```

Mikan 的搜索是**按空格分词后 AND 匹配种子标题子串**，因此：

| searchstr | 条目 | 字幕组数 |
|---|---|---|
| `恶女不才，请多关照 ～雏宫蝶鼠换身传～`（app 当前实际发送） | 23 | 2 |
| `恶女不才，请多关照` | 41 | 4 |
| `GET /RSS/Bangumi?bangumiId=4012`（app 未使用） | 119 | 7 |

具体丢失原因：LoliHouse 的标题写作 `虽然我是不完美恶女 ～雏宫蝶鼠替换传～ …（检索用：恶女不才，请多关照）`，
匹配不上 `～雏宫蝶鼠换身传～` 这半截，被 Mikan **服务端**过滤；Kirara Fantasia 以 `[黒ネズミたち]`
发布，标题里根本没有该字幕组名。

按集分桶后，第 1 集的 4 条全部来自 TSDM，于是用户只看到一个字幕组。

原设计明确假定「一次关键词搜索就是全部数据」
（`docs/superpowers/specs/2026-09-09-mikan-bt-media-source-design.md:44-50`），
所以这不是回归，而是原始设计的局限。

## 目标

1. Mikan 数据源改为优先使用**按番剧的全量 feed** `/RSS/Bangumi?bangumiId=<id>`，让某一集下所有字幕组都出现在线路列表里。
2. 补齐 `title_parser` 对 `SxxExx` / `第x话` / `01v2` 的识别，避免整个字幕组因标题格式被丢弃。

非目标（明确排除）：
- 不解析 Mikan 的「字幕组列表」侧栏，也不请求按 `subgroupid` 的分组 feed。
- 不修年份抢占集数号的 bug（`… 2026 [07]` 被分到第 2026 集）。
- 不修 `resolvePlayback` 按分辨率**字符串**降序排序的 bug（`'720P'` 排在 `'1080P'` 前）。
- 不引入分辨率/语言/字幕组偏好设置，不做完整 MediaSelector。

## Mikan 端已验证的事实

`GET /Home/Search?searchstr=<q>`（条目级搜索，命中时页面 220~245 KB，未命中约 18 KB）：

| searchstr | 结果 |
|---|---|
| `恶女不才，请多关照 ～雏宫蝶鼠换身传～` | 无卡片 |
| `恶女不才，请多关照` | `/Home/Bangumi/4012` |
| `ふつつかな悪女ではございますが` | `/Home/Bangumi/4012`（日文名同样被索引） |
| `雏宫蝶鼠` | 无卡片 |

条目卡片结构：

```html
<ul class="list-inline an-ul"><li>
  <a href="/Home/Bangumi/4012" target="_blank">
    <span data-src="/images/Bangumi/202607/239c521c.jpg?..." class="b-lazy"></span>
    <div class="an-info"><div class="an-info-group">
      <div class="an-text" title="恶女不才，请多关照 ～雏宫蝶鼠换身传～">…</div>
```

- `a[href^="/Home/Bangumi/"]` → Mikan bangumiId
- 同一卡片内的 `div.an-text[title]` → Mikan 自己的条目标题（**含** `～…～` 全称，与种子标题不同）

`GET /Home/Bangumi/<id>` 页面含权威反链：

```html
<a class="w-other-c" href="https://bgm.tv/subject/545008">https://bgm.tv/subject/545008</a>
```

`/RSS/Bangumi?bangumiId=<id>` 的 RSS 结构与 `/RSS/Search` 完全一致，现有 `parseRssFeed()` 可直接复用。

## 设计

### 1. 新增组件

| 文件 | 职责 |
|---|---|
| `lib/data/rss/mikan_subject_locator.dart` | `Future<int?> resolveBangumiId({required int subjectId, required String nameCn, String? nameJp})` |
| `lib/data/rss/mikan_subject_mapping_repository.dart` | 读写 subjectId → mikanBangumiId 的持久缓存 |
| `lib/data/local_database.dart` | 新表 `MikanSubjectMappings`，`schemaVersion` 2 → 3 |

#### locator 流程

1. 生成候选关键词，按序尝试，第一个返回卡片的即停：
   1. `nameCn` 在首个 `～` / `~` / `（` / `(` 处截断并 trim
   2. `nameJp`（Bangumi `name`）同样截断
   3. `nameCn` 原文
2. `GET /Home/Search?searchstr=<候选>`，用 `package:html` 解析出 `(mikanBangumiId, mikanTitle)` 列表。
3. 按 `titleSimilarity(mikanTitle, nameCn)`（复用 `lib/domain/media/title_matcher.dart`）降序排序。
4. 对前 3 名依次 `GET /Home/Bangumi/<id>`，校验页面内是否存在 `bgm.tv/subject/<subjectId>` 反链。
   第一个通过的即为结果。
5. 全部落空 → 返回 `null`。

反链校验是权威匹配，杜绝同系列不同季互相认错（结果要长期缓存，误判代价高）。

#### 缓存表

```dart
class MikanSubjectMappings extends Table {
  IntColumn get subjectId => integer()();            // Bangumi subject id, 主键
  IntColumn get mikanBangumiId => integer().nullable()(); // null = 已确认查不到
  DateTimeColumn get resolvedAt => dateTime()();
  @override Set<Column> get primaryKey => {subjectId};
}
```

- 正结果永久有效。
- 负结果（`mikanBangumiId == null`）7 天 TTL，到期后重新解析——新番上架 Mikan 有延迟。
- `onUpgrade` 中 `from < 3` 时 `m.createTable(mikanSubjectMappings)`。

### 2. 接入点改动

`MediaSource.search(String title)` 拿不到 subjectId，签名改为：

```dart
Future<List<MediaCandidate>> search(String title, {int? subjectId});
```

Anime1 / Xifan 实现忽略 `subjectId`。`lib/domain/play/subject_episodes_controller.dart` 已持有 subjectId，直接透传。

`mikanRssSourceConfig` 增加两个模板字段，保留现有 `searchUrl` 作回退：

- `subjectSearchUrl: 'https://mikanani.me/Home/Search?searchstr={keyword}'`
- `bangumiFeedUrl: 'https://mikanani.me/RSS/Bangumi?bangumiId={bangumiId}'`

`RssMediaSource.search`：

```
subjectId != null 且映射解析成功 → GET bangumiFeedUrl
否则                             → GET searchUrl（今天的行为）
```

两条路径之后都走同一套 `parseRssFeed()` → `groupByEpisode()`，因此
`listEpisodes` / `resolvePlayback` / `LineSwitchSheet` / `PlayerScreen` **零改动**，
字幕组数量自然从 2 变成 6~7。

只有 Mikan 具备按番剧 feed，`bangumiFeedUrl` 为空的 RSS 源行为不变。

### 3. 标题解析补充

`lib/domain/media/title_parser.dart` 新增识别（保持现有裸数字路径不变）：

| 格式 | 解析为 | 现状 |
|---|---|---|
| `S01E09` / `E09` | 第 9 集 | 整条丢弃 |
| `第09话` / `第9集` / `第09話` | 第 9 集 | 整条丢弃 |
| `09v2` | 第 9 集 | 整条丢弃 |

实测在 `bangumiId=4012` 的 119 条里，当前有 12 条被丢弃：Nix-Raws 全部 10 条（`S01E0x`）
与 TSDM 的 3 条 `v2` 重发——前者导致整个字幕组消失。

### 4. 错误处理

- locator 的任何失败（超时、404、无卡片、反链不匹配、HTML 结构变更）统一返回 `null`，
  由 `RssMediaSource` 回退到关键词搜索。Mikan 绝不会因为映射失败而变成空结果。
- locator 不向 `subject_episodes_controller` 的 `Future.wait` 抛异常
  （该处的 `catch (_) => []` 仍是最后防线，但不应被触发）。
- 复用 `mikanRssDio`（沿用进程级代理 `HttpOverrides`、`User-Agent`、10s 连接/接收超时）。
  注意 `docs/superpowers/specs/2026-09-01-proxy-settings-design.md:214`：`findProxy` 不得捕获 `Ref`。
- 映射成功后写库；后续进入同一条目零额外请求。

### 5. 测试

全部离线，fixture 置于 `test/fixtures/mikan/`（裁剪后的搜索页、番剧页、番剧 feed）：

- `mikan_subject_locator_test.dart`
  - 从搜索页 fixture 解析出 `(id, title)` 列表
  - 候选关键词生成：`～` 截断、日文名回退、原文兜底
  - 反链校验：`bgm.tv/subject/545008` 通过；其他 subjectId 拒绝
  - 无卡片 / 请求抛错 → 返回 `null`
- `mikan_subject_mapping_repository_test.dart`：命中、未命中、负缓存 7 天 TTL 过期重试
- `rss_media_source_test.dart` 扩充：mock dio 断言「有映射请求 `/RSS/Bangumi?bangumiId=`」
  与「无映射请求 `/RSS/Search?searchstr=`」
- `title_parser_test.dart` 扩充：`S01E09`、`第09话`、`01v2` 三种新格式

测试不访问网络。

## 已知局限

- 字幕组名仍取自标题首个方括号，Kirara Fantasia 依旧显示为 `黒ネズミたち`。
- 番剧 feed 是全季全量，条目更多，解析开销略增（119 条 vs 23 条），仍在毫秒级。
- 首次进入一个条目最多多 4 个请求（1 次搜索 + 最多 3 次番剧页校验），仅首次。
- Mikan 未收录的条目永远走关键词搜索，行为与今天一致。
- Mikan 改版 HTML 结构会使映射失效并静默回退——不会崩，但会退回今天的字幕组数量。
