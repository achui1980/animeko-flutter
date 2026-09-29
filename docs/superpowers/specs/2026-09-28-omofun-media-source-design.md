# OmoFun 媒体源集成设计

日期：2026-09-28
状态：已批准（待实现）

## 目标

把 omofun.in 接入为一个新的在线播放媒体源（id `omofun`，显示名 `OmoFun`）。

**范围**
- 只做在线播放。不接入离线下载，所以 `downloadableSourcePriority` 和 `download_worker.dart` 的允许列表都不改。
- 不做多域名切换。基址写成常量 `https://omofun.in`（站点公告说最新域名是 omofun.tv，以后需要时再加）。
- 不做通用的网页选择器系统，仍沿用“每个站点手写一个抓取器”的现有做法。
- 不支持剧场版/电影页面（见下方“已知限制”）。

## 已知限制（2026-09-29 补充）

omofun 对“剧场版/电影”类条目用的详情页选集结构和电视动画不一样：

- 电视动画（如芙莉莲）：`/vod/play/<vodId>/ep<N>.html`（`parseOmofunEpisodes` 按此格式解析）。
- 电影（如《名侦探柯南 高速公路的堕天使》，vodId `2026341892`）：`/vod/play/<vodId>/movie.html?vod=<变体>`，
  例如 `?vod=ep720p`、`?vod=qiang_xian_ban`（枪版）、`?vod=tc`（台配）、`?vod=zheng_pian`（正片）——
  这些看起来是同一部电影的不同版本/清晰度，不是顺序剧集。

当前实现的正则是锚定在 `ep(\d+)\.html` 上的，遇到电影页面会匹配不到任何链接，`parseOmofunEpisodes` 静默返回空列表。
效果：该条目在 OmoFun 这个源上显示“暂无播放源”，但不会抛异常、不会影响其他已注册的数据源（anime1/xifan/agedm/mikan）对同一条目的播放。

用户决定：暂不实现电影支持（2026-09-29 决定，跳过）。如果以后要做，需要先确认电影播放页对应的 `_dyn_plays` 端点路径
（可能是 `/_dyn_plays/<vodId>/movie` 或按变体区分），并决定“多个 `vod=` 变体”要建模成一个 episode 的多条播放线路，
还是拆成多个 episode。

## 站点分析（2026-09-28 用 curl 验证）

- MacCMS 站，主题是 mxpro，前面有 Cloudflare。桌面 UA 直接返回 200，没有质询；所有接口都不需要 Referer。
- **搜索**：`GET /vod/search.html?wd=<关键词>`
  - 每条结果是 `div.module-card-item.module-item`。
  - 标题取 `.module-card-item-title strong`。
  - 链接形如 `/vod/detail/<vodId>.html`。
  - `.module-item-note` 是更新状态，例如“更新至第28集”。
- **详情**：`GET /vod/detail/<vodId>.html`
  - 只看到一个线路标签（`data-dropdown-value="OmoFun"`）。
  - 剧集链接形如 `/vod/play/<vodId>/ep<N>.html`，`<span>` 里是“第01集”。
- **播放**：播放页里**没有** `player_aaaa`。页面上的内联 jQuery 请求 `GET /_dyn_plays/<vodId>/ep<N>`，返回：
  ```json
  {"video_plays":[{"play_data":"https://…/index.m3u8","src_site":"gszy"}, …],
   "html_content":"<li>…</li>"}
  ```
  前端用 DPlayer 以 HLS 方式播放 `video_plays[0]`，出错时提示“加载失败，请切换线路”。
- **线路质量**：以《葬送的芙莉莲》第 1 集为例，共 20 条，其中有重复 URL，去重后剩 16 条。可达性很不一致：
  - 返回 200：gsuus、bfvvs、bfikuncdn、modujx10、xluuss、xmyysw。
  - 返回 403：ffzy、ukzy。
  - 返回 404：cdnlz13、cdnlz14。
  - DNS 或连接失败：jisuzyv、qqqrst、ijycnd、cctvm3u8、cntvoss。

  所以必须先去重，并在解析时探测可用性。
- 和已有但未注册的 `dilidili_api.dart`（`/_get_play` 返回 `play_data`）属于同一类站点。

## §1 架构

新增文件：

| 文件 | 职责 |
|---|---|
| `lib/data/omofun/omofun_models.dart` | `OmofunCandidate{vodId, title}`、`OmofunEpisode{vodId, ep, title}`、`OmofunPlaybackSource`，以及纯函数解析器：`parseOmofunSearch`、`parseOmofunEpisodes`、`parseOmofunPlays` |
| `lib/data/omofun/omofun_api.dart` | `OmofunApi(dio)`，以及 `@riverpod` 的 `omofunDio`、`omofunProbeDio`、`omofunApi` |
| `lib/data/omofun/m3u8_line_prober.dart` | 与站点无关的 `probeM3u8Lines<T>` |

修改：
- `lib/domain/media/media_registry.dart`：
  - 新增适配器 `OmofunMediaSource`。
  - 在 `mediaSources` 列表里把它插到 Agedm 之后、Mikan RSS 之前。
- 改完后运行 `dart run build_runner build --delete-conflicting-outputs`。

数据流：
1. `search(title)`：请求 `GET https://omofun.in/vod/search.html?wd=<title>`。
   - 遍历 `div.module-card-item`，标题取 `.module-card-item-title strong`。
   - vodId 用正则 `/vod/detail/(\d+)\.html` 从链接里取。
   - 缺标题或缺 vodId 的卡片跳过。
   - 由 `matchBest` 负责挑选结果（沿用现有流程）。
2. `listEpisodes(candidate)`：请求 `GET /vod/detail/<vodId>.html`。
   - 只取第一个剧集列表容器里的 `a[href^="/vod/play/<vodId>/ep"]`。
   - 标题取 `<span>` 文本（例如“第01集”）。
   - 保持页面顺序，按 href 去重。
   - 从 href 解析出 `ep`。
3. `resolvePlayback(episode)`：请求 `GET /_dyn_plays/<vodId>/ep<N>`。
   - 按 `play_data` 去重，保留首次出现的顺序。
   - 丢掉空值和非 http(s) 的项。
   - 通过直连 dio 探测线路（见 §2）。
   - 每条线路生成 `OmofunPlaybackSource{url, label: src_site, headers: {}, prefersDirectConnection: true}`。

dio 配置：
- `omofunDio`：桌面 Chrome UA，超时 15s，走全局代理（`ProxyHttpOverrides`）。
- `omofunProbeDio`：用 `IOHttpClientAdapter(createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT')` 强制直连。这样探测时的网络路径和 libmpv 播放时一致，因为 `prefersDirectConnection` 会清掉 libmpv 的代理。

## §2 线路探测与错误处理

`Future<List<T>> probeM3u8Lines<T>(List<T> lines, {required String Function(T) urlOf, required Dio dio, Duration timeout = const Duration(seconds: 4)})`

- 所有线路用 `Future.wait` 并发探测，每条都是 `GET`，`ResponseType.stream`。
- 读到第一个数据块（≤1KB）就取消请求。每条线路的总超时是 `timeout`。
- 判定为存活的条件：状态码是 2xx，**并且**去掉 BOM 和前导空白后，响应体以 `#EXTM3U` 开头。
- 超时、DNS 失败、连接失败、403、404、返回 HTML 等情况一律静默丢弃。
- 结果保持原有顺序。只探测顶层 m3u8，不递归去检查子播放列表或分片。

错误处理：

| 情况 | 行为 |
|---|---|
| 搜索或详情请求出现网络错误 | 抛出异常；控制器会按源隔离，其他源不受影响 |
| 没有搜索结果 | 返回 `[]` |
| 没有剧集 | 返回 `[]` |
| `/_dyn_plays` 出错，或去重后为空 | 抛 `StateError('omofun: no playable lines')` |
| 全部线路探测失败，或探测器出现意外异常 | 退回为返回全部去重后的线路（不过滤），交给播放器的自动回退 |

## §3 测试

使用 mocktail 的 `MockDio`，测试数据是内联的精简版真实 HTML/JSON，并用注释标明抓取日期（写法同 `test/data/agedm/agedm_api_test.dart`）。

- `test/data/omofun/omofun_models_test.dart`
  - 搜索解析：正常解析；没有结果时为空；跳过格式有问题的卡片。
  - 详情解析：保持顺序；去重；只保留当前 vodId 的剧集链接。
  - `_dyn_plays` 解析：去重并保留顺序；丢掉空值和非 http 项；label 等于 src_site。
- `test/data/omofun/omofun_api_test.dart`：请求 URL 与 `wd` 参数正确，解析器接入正确。
- `test/data/omofun/m3u8_line_prober_test.dart`：用假的 `HttpClientAdapter` 按 URL 返回不同响应。
  - 200 且以 `#EXTM3U` 开头的保留。
  - 403、404、返回 HTML、连接错误的丢弃。
  - 超时（注入约 50ms 的超时）的丢弃。
  - 结果保持原有顺序。
  - 带 BOM 或前导空白的仍判定为存活。
- `test/domain/media/omofun_media_source_test.dart`
  - 只返回存活线路，并且 `prefersDirectConnection == true`。
  - 全部探测失败时返回全部线路。
  - 没有可用线路时抛 `StateError`。
- `omofunProbeDio`：即使设置了全局 `HttpOverrides` 代理，`findProxy` 仍返回 `'DIRECT'`。

## 验收

- `flutter analyze` 没有新增错误；`flutter test` 全部通过。
- 手动运行 `flutter run -d macos`：《葬送的芙莉莲》第 1 集能通过 OmoFun 播放，线路列表里只出现存活线路。
