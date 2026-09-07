# 详情页剧集列表改为 Bangumi 驱动 + 播放源延迟选择 设计

日期：2026-09-07。状态：已批准（Approved）。

## 背景与目标

当前 `SubjectDetailScreen`（`lib/ui/subject/subject_detail_screen.dart`）的剧集/播放入口是：页面最底部一个单一的"开始观看 (N集)"按钮，点击后弹出 `EpisodeSourceSheet`（包裹 `EpisodeSourceGrid`）——一个扁平的、按数据源筛选 chip 的剧集+源合并列表。剧集的"存在与否"和"数量"完全由各爬虫数据源（`Anime1MediaSource`/`XifanMediaSource`，`YinghuaMediaSource`/`DilidiliMediaSource` 已因不稳定被停用）通过标题模糊匹配（`lib/domain/media/title_matcher.dart` 的 `matchBest`，仅在**番剧整体**层面做模糊匹配，从不做逐集对账）得出的 `MergedEpisode` 列表决定，与 Bangumi 官方的剧集数据完全无关。

用户希望：
1. 参考 Animeko（原 KMP 应用）/Bangumi 网站的详情页布局风格。
2. 剧集列表应该由 **Bangumi 官方的剧集数据**驱动（数量、编号），而不是由爬虫合并结果驱动。
3. 播放源选择应该**延迟到点击具体某一集时**才进行，而不是像现在这样一次性把所有源的所有剧集都摊平展示出来。
4. 现有详情页布局不够好，需要重新设计。
5. 尽可能多地展示 Bangumi 自身的番剧数据。

这是对此前两份设计文档（`2026-09-01-xifan-media-source-design.md`、`2026-09-05-subject-detail-player-redesign-design.md`）中反复确认的"合并展示、不引入选源 UI、不做逐集 Bangumi 对账"架构决策的**有意反转**——已与用户明确确认这是刻意的方向调整，不是误操作。

## 范围

**范围内：**
- 新增 Bangumi 剧集列表 API 集成（当前代码库中完全不存在）。
- 新增剧集号码网格 UI，替换现有单一"开始观看"按钮。
- 新增单集点击 → 播放源弹窗的交互逻辑（复用/改造现有 `EpisodeSourceSheet` 组件，重新限定到单一剧集）。
- 详情页整体结构重新排序。
- 展示 `airDate`（放送日期，已抓取但当前 UI 从未展示）。

**范围外（见「第 6 段：明确不在本次范围内事项」）：** 制作人员/infobox 类新接口、关联作品功能、超过 100 集的番剧、自动选源/记忆偏好源引擎、多线路播放自动回退逻辑改动、Yinghua/Dilidili 启用状态改动、整站视觉换皮。

## 现状代码基线（供实现阶段参考，无需重新调研）

- `lib/data/subject/subject_api.dart` + `subject_models.dart`：`SubjectDetail{id,name,nameCn,summary,airDate,tags,score,rank,collectionType,selfRating}`，通过 `GET /v2/subjects/{id}` 获取；角色/制作人员/收藏分别有独立接口。`SubjectDetail` 没有封面图字段（`imageUrl` 来自路由 query 参数）。`airDate` 已抓取但当前 UI 从未展示。
- **当前代码库中完全没有 Bangumi 剧集列表 API**（已通过 grep 确认无 `v0/episodes` 等相关代码）。所有 `*Episode` 类均为爬虫侧模型（`Anime1Episode`/`XifanEpisode`/`YinghuaEpisode`/`DilidiliEpisode`/`MediaEpisode`/`MergedEpisode`）。
- `lib/ui/subject/subject_detail_screen.dart`（500行）现有结构：沉浸式头图区（`_ImmersiveHeader`）→ 简介/标签/评分区（`_SubjectInfoSection`）→ 角色/制作人员（`_CastStaffSection`）→ `Divider()` → 单一"开始观看 (N集)"按钮，点击弹出 `EpisodeSourceSheet`。
- `MergedEpisode{episode: MediaEpisode, sourceId: String}`（`lib/domain/play/subject_episodes_controller.dart:30-37`）——剧集身份完全来自爬虫源，与 Bangumi 无关。`SubjectEpisodesController.build` 并发查询所有已注册的 `MediaSource`（当前只有 Anime1 + Xifan），对每个源做番剧整体标题模糑匹配（阈值 0.6），匹配成功后拉取该源全部剧集并摊平合并成一个 `List<MergedEpisode>`。单源失败会被静默吞掉；只有全部源都没有匹配到内容时才抛出 `MediaNotFoundException`。
- 路由（`lib/app/router.dart`）：详情页 `GET /subject/:subjectId`；播放页 `GET /subject/:subjectId/play`（`extra` 必须是 `MergedEpisode`）。

## 第 1 段：整体页面结构调整

新的页面自上而下顺序：
1. 沉浸式头图区（封面/模糊背景/标题/评分星级/排名/收藏状态 chips，大体不变，新增展示 `airDate`，见第 5 段）
2. **【新增】剧集号码网格**（紧凑数字按钮 01 02 03……，数量/编号完全来自 Bangumi 官方剧集数据，替换现有的单一"开始观看 (N集)"按钮）
3. 简介 + 标签（`ExpandableSummary` + `SubjectTagsRow`，不变）
4. 评分区（`_RatingSection`，不变）
5. 角色/制作人员（`_CastStaffSection`，不变，位置相对不变，只是因为剧集网格挪到前面了整体往后移一位）

即：剧集选择从"页面最底部、点一个大按钮再弹出全屏筛选列表"，变成"页面靠前位置的一排剧集号码，点哪一集就弹那一集的播放源"。

## 第 2 段：剧集号码网格 UI/数据来源

- **架构决策（重要变更）**：调研发现本应用现有后端 `https://api.animeko.org`（`lib/data/api_client.dart` 的 `aniApiBaseUrl`，本应用所有现存 API 客户端——`subject_api.dart`/`home_recommendations_api.dart`/`schedule_api.dart`/`trends_api.dart`/`user_api.dart`/`search_api.dart`/`session_api.dart`/`bangumi_oauth_api.dart`——都经由此域名）**完全没有剧集列表接口**：对真实 subject（如 id=400602《葬送的芳莉莲》）逐一实测了 20+ 个猜测路径（`/v0/episodes?subject_id=`、`/v2/subjects/{id}/episodes`、`/v1/subjects/{id}/episodes`、`/v2/episodes?subjectId=` 等），均为路由级 404；唯一确认存在的相关路由是单集详情 `GET /v2/subjects/{id}/episodes/{episodeId:Long}`（返回语义级 404 "Episode with id 1 of subject 400602 not found"，证明路由真实存在但无法枚举/发现某个 subject 下有哪些 `episodeId`）；`/openapi.json` 存在但返回 401，此沙箱环境中无可用鉴权凭据可解锁。**已与用户确认：改为绕开 `api.animeko.org`，由 Flutter 客户端直接调用 Bangumi 官方公开 API `https://api.bgm.tv`**——这是本应用中第一个不经由自有后端、直接对接 Bangumi 官方接口读取数据的客户端（现有 `bangumi_oauth_api.dart` 仅通过自有后端代理 OAuth 流程，并非直接数据读取）。
- **已通过真实请求核实 Bangumi 官方接口的确切响应形状**（`curl "https://api.bgm.tv/v0/episodes?subject_id=400602&type=0&limit=1"`，真实返回，非猜测）：
  ```json
  {
    "data": [
      {
        "airdate": "2023-09-29",
        "name": "冒険の終わり",
        "name_cn": "冒险结束",
        "duration": "00:26:00",
        "desc": "……（较长的分集简介，本次不展示）",
        "ep": 1,
        "sort": 1,
        "id": 1227087,
        "subject_id": 400602,
        "comment": 297,
        "type": 0,
        "disc": 0,
        "duration_seconds": 1560
      }
    ],
    "total": 28,
    "limit": 1,
    "offset": 0
  }
  ```
  顶层为分页包裹对象 `{data: [...], total, limit, offset}`，`total`（该请求实测=28）与该 subject 的 `infobox.话数`字段（同为 28）一致，可交叉验证。请求已用 `type=0` 查询参数在服务端侧过滤掉 SP/OP/ED，故客户端通常无需再次按 `type` 过滤，但模型仍保留 `type` 字段作为防御性二次校验。
  端点：`GET https://api.bgm.tv/v0/episodes`，查询参数 `subject_id`（必填）、`type`（可选，0=正片/1=SP/2=OP/3=ED）、`limit`（默认视 Bangumi 官方文档而定，本次固定传 `100`）、`offset`（本次不做分页，固定 `0`）。**无需鉴权即可读取**（未带任何 Authorization header 即拿到完整数据）。
- **新模型 `BangumiEpisode`**：`id`（Bangumi 剧集 ID，`int`）、`sort`（集数序号，`num`——注意 Bangumi 官方字段是 `sort`，用于排序及跟爬虫剧集顺序匹配）、`name`/`nameCn`（原名/中文名，对应 wire 字段 `name`/`name_cn`，展示优先用中文名，为空则回退原名）、`airdate`（播出日期，`String`，对应 wire 字段 `airdate`）、`type`（`int`，0=正片/1=SP/2=OP/3=ED 等——**本次只展示 type=0 的正片**，SP/OP/ED 不放入号码网格，尽管请求时已用 `type=0` 参数过滤，模型仍保留该字段做二次防御性过滤）。`desc`/`duration`/`comment`/`disc`/`duration_seconds`/`ep`/`subject_id` 等其它 wire 字段本次不建模（YAGNI，当前 UI 不需要）。
- **新增 API 客户端**：新文件（如 `lib/data/subject/bangumi_episodes_api.dart`），独立的 `Dio` 实例、独立的 base URL 常量（`https://api.bgm.tv`，与 `lib/data/api_client.dart` 的 `aniApiBaseUrl` 完全分离，不共用现有的认证/拦截器配置，因为该请求本身不需要鉴权且目标域名不同）。
- **新增 Provider**：`SubjectBangumiEpisodesController(subjectId)`，独立于现有的 `subjectEpisodesControllerProvider`（爬虫源），两者并行获取，互不阻塞。
- **号码网格 UI/交互**：`Wrap` 排列的紧凑数字按钮（圆角小方块），按 `sort` 升序，标签 `01`/`02`……。三种视觉状态：
  1. 有匹配播放源 = 正常可点击；
  2. 暂无匹配播放源 = 灰置/低透明度，仍可点击，点击后弹窗显示"暂无播放源"；
  3. 加载中 = 中性态，不强行区分 1/2，等爬虫抓完后自动刷新。
- 网格上方保留小标题"剧集"，不做筛选 chip（不再是扁平按数据源筛选的列表）。

## 第 3 段：单集点击 → 播放源弹窗交互逻辑

- 新增纯函数 `matchEpisodeSources({required int ordinalIndex, required List<MergedEpisode> allMerged})`——按 `sourceId` 分组已缓存的 `MergedEpisode` 列表，取每个源列表中序号为 `ordinalIndex` 的一项（**序号匹配**，而不是标题解析，因为标题格式在各源之间不一致）；如果某源集数不足 `ordinalIndex`，该源不贡献候选，无报错。返回值可能是 0 个、1 个或多个匹配的 `MergedEpisode`。
- 弹窗（复用/改造 `EpisodeSourceSheet` 的外壳，重新限定到单一剧集而非整份列表）展示：
  - ≥1 个匹配 → 每个源一行，带"播放"按钮（导航到 `PlayerScreen`，逻辑与今天一致）——**即使只有 1 个匹配也一定弹窗展示**（见下方决策），不自动跳过弹窗直接播放。
  - 0 个匹配 → 显示"暂无播放源"文本，无可点击项。
  - 背景爬虫抓取仍在进行时点击 → 弹窗展示加载中状态，抓取完成后自动刷新内容，无需用户手动重试。
- **决策：即使某一集只匹配到唯一一个源，也始终通过弹窗展示（而不是自动跳转播放）**，理由是交互一致性——每次点击某一集都走相同的"弹窗选择"流程，避免"有时候直接播放、有时候弹窗"的不一致体验。

## 第 4 段：数据层改动汇总

- `SubjectEpisodesController`（现有爬虫聚合逻辑）**代码完全不变**——仍旧在背景并发执行 `search` → `matchBest` → `listEpisodes`（对 Anime1 + Xifan），产生/缓存 `List<MergedEpisode>`；不再直接驱动 UI——UI 现在由下面的新 Provider 驱动。
- 新增 `SubjectBangumiEpisodesController`——单一职责：调用新 Bangumi 剧集接口，产生已过滤 `type==0` 并按 `sort` 排序的 `List<BangumiEpisode>`。完全独立/并行于 `SubjectEpisodesController`，互不阻塞。
- 新增纯函数 `matchEpisodeSources`（见第 3 段），无副作用，可独立单元测试。
- 网格按钮三状态判断伪代码：
  ```
  if (bangumiEpisodesLoading) → 中性/骨架图
  else if (subjectEpisodesLoading) → 中性（Bangumi 数据先到，仍保持中性直到爬虫数据到达后重渲染）
  else if (matchEpisodeSources(...).isEmpty) → 灰置
  else → 正常可点击
  ```

## 第 5 段：`airDate`（放送日期）展示位置

加入现有头部叠加层的元数据行（当前为"评分星级 · 排名"），新增第三个元素，用 `·` 分隔，如：`★★★★☆ · 排名：#12 · 2026年7月`（年-月粒度，不是完整日期）。若该行过于拥挤，降级方案是放到标题下方、评分行上方的单独一行；但默认采用同行 `·` 分隔方案，不新增布局层级。这是纯文本新增，不涉及新交互逻辑，不影响第 1-4 段已批准的结构。

## 第 6 段：明确不在本次范围内事项（Out of Scope）

1. **不新增"制作人员/infobox"类接口**：现有 `getStaff`/`getCharacters` 接口和展示方式保持不变（导演/原作/脚本等结构化信息不会新增）。
2. **不新增"关联作品/relations"功能**：不加相关条目、续作/前作等关联信息展示。
3. **不支持超过 100 集的番剧**：`limit=100` 是本次设计的硬上限，超长篇（如长年连载动画）的分页加载不在本次范围内。
4. **不引入"自动选源/记忆偏好源"引擎**：每次点击某一集都要弹窗让用户手动选，不会记住"上次选的是这个源"并跳过弹窗。
5. **不改动"多线路播放自动回退"逻辑**（`resolvePlayback` 返回候选列表、播放器自动重试）：这是之前已完成的独立功能，本次不涉及。
6. **不改动 Yinghua/Dilidili 的启用状态**：当前只有 Anime1 和 Xifan 是激活源，本次改动不会重新启用被禁用的源。
7. **不做整站视觉换皮**（如 Material 3 主题色、深色模式等）：那是另一个已完成的独立设计（`2026-09-02-plan1e-ui-redesign-design.md`），本次只改详情页的结构和数据来源，不做视觉风格大改。

## 风险与已知未知

- ~~Bangumi 剧集列表接口的确切响应字段形状尚未核实~~ **（已解决）**：已通过第 2 段中记录的真实请求核实了 `https://api.bgm.tv/v0/episodes` 的确切响应形状与字段。
- **新增风险（因架构决策变更引入，已排查确认无阻塞）**：本次改为直接调用 Bangumi 官方 `api.bgm.tv`，绕开了本应用现有的统一后端 `api.animeko.org`。已确认 `lib/data/settings/proxy_dio_config.dart` 的 `configureProxy(Dio dio, Ref ref)` 是一个与 base URL 无关的通用函数（`lib/data/dilidili/dilidili_api.dart` 等爬虫数据源客户端已采用同样方式接入代理），新的 Bangumi 直连客户端只需同样调用 `configureProxy(dio, ref)` 即可复用现有代理配置，不需要新的代理接入机制。唯一保留的差异点：该请求不经过本应用后端，因此不受后端自身可能存在的缓存/限流保护，纯粹依赖 Bangumi 官方接口自身的可用性与限流策略（已实测该接口无需鉴权即可读取）。
- `matchEpisodeSources` 的序号匹配假设"各爬虫源返回的剧集列表顺序与 Bangumi 集数顺序一致"——这是一个基于观察的合理假设（各源的 `listEpisodes` 目前确实按页面顺序返回，通常就是集数顺序），但没有做强校验；如果某个源的剧集列表顺序与实际集数不一致，会导致该源在弹窗里显示错误的集数对应关系。此风险已知但本次不做额外校验（范围外）。
