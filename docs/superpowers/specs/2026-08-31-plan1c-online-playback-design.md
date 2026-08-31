# Plan 1c：在线数据源播放（anime1.me）设计文档

> 状态：设计阶段（brainstorming 已完成，待用户审阅）
> 关联：`docs/superpowers/specs/2026-08-27-flutter-migration-phase1-design.md`（Phase 1 总体设计，Plan 1c 属于其"在线数据源播放"范围）、`docs/superpowers/specs/2026-08-28-plan1b-series-design.md`（明确 Plan 1c 不依赖 Plan 1b-3/1b-4，仅需 Plan 1b-1 的网络/认证基础）
> 前置条件：Plan 1b-1（数据基础层）、Plan 1b-2（Home/Search/Schedule）均已完成并合并到 `main`

## 背景与范围

当前 Flutter 版 animeko 应用（迁移自 Kotlin/Compose Multiplatform 项目 `/Users/portz/js/animeko/`）已完成 Home/Search/Schedule 三个浏览页面，但点击任意番剧卡片（`SubjectCard`）没有任何反应——没有详情页，也没有播放能力。本计划的目标是让用户能够：

1. 点击一个番剧卡片，进入一个最简详情页（封面+简介+剧集列表）。
2. 点击某一集，进入播放页并实际播放视频。

**v1 数据源：仅 anime1.me。** 不使用 Jellyfin/Emby/Ikaros（这些都要求用户自建私有媒体服务器），也不使用原 Kotlin 项目里已实现的任何数据源方案。anime1.me 是公开的免费动画播放网站，无需用户配置任何账号/服务器即可播放——这是选择它作为 v1 目标的核心原因："不要自建媒体，只要能播放一个数据源"。

**anime1.me 技术细节（均为第三方开源逆向工程结果，无官方文档，均需在实施阶段用真实抓包验证）**：
- 是一个 WordPress 站点，每部番剧对应一个 WordPress 分类（`cat_id`）。
- 番剧内每一集是一篇 WordPress 文章，标题里包含集数信息。
- 搜索使用 WordPress 原生 `/?s=关键词`。
- 每篇文章 HTML 里嵌有 `data-apireq="<base64>"` 属性；将其 base64 解码得到一段 JSON，POST 到 `https://v.anime1.me/api` 即可换取真实的 mp4/m3u8 播放直链。
- 反盗链机制仅依赖 `Referer` HTTP 请求头（设为 `https://anime1.me` 即可），没有验证码或 JS 签名校验。
- **没有官方 Bangumi ID 映射**（不像 Ikaros），必须依赖标题字符串匹配将 Bangumi 条目关联到 anime1.me 的分类。

**明确排除（推迟到 v2 及以后，或归入其他计划）**：
- Jellyfin/Emby/Ikaros 等需要用户自建服务器的数据源。
- "稀饭动漫"等需要 CES/WebView 渲染网页才能拿到播放地址的 web-selector 数据源（这属于 Phase 3 范围，技术路线完全不同，需要启动 CEF 做 `extractVideo`/`matchWebVideo`，还要处理人机验证）。
- BT/PT 下载播放（Phase 2，需 FFI 桥接 `anitorrent` C++ 核心，已在总体设计中明确排除于 Phase 1）。
- 弹幕（严格归入 Plan 1d，本计划完全不涉及弹幕拉取、合并、渲染、发送）。
- 番剧详情页的评分、追番收藏、进度云同步（归入 Plan 1b-3/1b-4，本计划仅做最简详情页展示，不做交互式收藏/评分）。
- 选源 UI、多数据源优先级排序、字幕组/分辨率/字幕语言偏好选择（因为 v1 只有一个数据源，原 Kotlin 项目 `ui-mediaselect` 里的复杂选源排序算法本次完全不需要）。
- 手势控制的进阶功能：滑动调节音量/亮度、长按快进、手势锁。

## 架构

延续 Plan 1b 系列已建立的 `data/domain/ui` 三层分层模式：

```
lib/data/anime1/
  anime1_api.dart          # Anime1Api 类，三个方法：searchCategories / fetchCategoryEpisodes / resolvePlaybackUrl
  anime1_models.dart        # Anime1Category / Anime1Episode / Anime1PlaybackSource

lib/domain/play/
  subject_episodes_controller.dart # @riverpod：给定 subjectId+subjectName → 匹配分类 → 拉剧集列表 → AsyncValue<List<Anime1Episode>>
  episode_play_controller.dart     # @riverpod：给定 episodePageUrl → 解析播放地址 → AsyncValue<Anime1PlaybackSource>

lib/ui/subject/
  subject_detail_screen.dart      # ConsumerWidget，封面 + 简介 + 剧集列表
lib/ui/player/
  player_screen.dart              # ConsumerStatefulWidget，media_kit Video widget + 基本手势控制层
```

**播放引擎：media_kit（基于 libmpv）。** 这是总体迁移设计文档中已确定的技术选型（替代旧桌面版 VLC 方案），本次 Plan 1c 头脑风暴中已再次向用户正式确认。

**错误处理策略：延续 `AsyncValue`，不引入 Repository/Result 分层。** Plan 1b-2 全程使用 Riverpod 自带的 `AsyncValue` 作为错误传递手段（而不是总体设计文档中曾提及的 fpdart `Either`），Plan 1c 延续同一模式以保持一致性：`AsyncError` 直接携带原始异常，UI 用 `.when(error:...)` 统一处理。

**路由：详情页/播放页是 bottom-nav shell 之外的独立 push 路由**（不属于 Home/Search/Schedule 三个 tab 之一）：
- `/subject/:subjectId`（详情页，接受 query 参数 `name`）
- `/subject/:subjectId/play`（播放页，接受 query 参数 `url` 即剧集文章页 URL，建议全屏无 AppBar）

**数据源代码架构：直接实现具体的 `Anime1Api`，不引入通用 `MediaSource` 抽象接口。** 原 Kotlin 项目有一套完整的 `MediaSource`/`MediaSourceFactory`/SPI 自动发现机制，但那是为支持多数据源、多字幕组/分辨率选择设计的。v1 只有一个数据源，遵循 YAGNI 原则直接写具体实现；等 v2 接入第二个数据源（如 Jellyfin）时再考虑抽象出通用接口，参考现有 Plan 1b 系列的开发风格（先具体实现，需要时再抽象）。

## 核心组件设计

### `Anime1Api`（`lib/data/anime1/anime1_api.dart`）

三个方法，均为直接的 HTTP 请求 + HTML/JSON 解析，不做任何缓存：

```dart
class Anime1Api {
  Anime1Api(this._dio);
  final Dio _dio;

  /// GET https://anime1.me/?s=<title>
  /// 解析搜索结果页里指向分类页的链接（形如 `<a href=".../?cat=123">番名</a>`），
  /// 按标题去重后返回候选分类列表。
  Future<List<Anime1Category>> searchCategories(String title);

  /// GET https://anime1.me/?cat=<categoryId>
  /// 解析该分类页下每篇文章的标题（含集数信息）、文章链接、发布时间；
  /// 处理分页（WordPress 默认按发布时间倒序分页展示）。
  Future<List<Anime1Episode>> fetchCategoryEpisodes(int categoryId);

  /// GET 文章页 HTML，提取 `data-apireq="<base64>"` 属性值；
  /// base64 解码后得到一段 JSON（具体字段结构需在实施阶段实际抓包确认）；
  /// POST https://v.anime1.me/api（Content-Type: application/x-www-form-urlencoded，
  /// body 携带 d=<原始 data-apireq 字符串>），响应包含按清晰度分类的 mp4/m3u8 地址列表。
  Future<Anime1PlaybackSource> resolvePlaybackUrl(String episodePageUrl);
}
```

**HTML 解析**：使用 pub.dev 上的 `html` 包（`html_parser.parse(body)` + `document.querySelectorAll(...)`），这是本计划唯一需要新增的第三方依赖。

**Referer 请求头伪造（反盗链）**：使用一个专用的 `Dio` 实例（类似现有的 `dioProvider`，但额外设置 `baseOptions.headers['Referer'] = 'https://anime1.me'`），复用 Plan 1a/1b 已建立的"每个数据源一个 Provider 化的 Dio 实例"模式（参考 `lib/data/api_client.dart` 中 `dioProvider`/`rawAniDio` 的做法）。

**关于 `resolvePlaybackUrl` 的输入**：接受"剧集文章页 URL"而非某种 `episodeId`，因为 anime1.me 本身没有独立的 episode ID 概念——`Anime1Episode` 模型自带其文章 URL 字段，上层直接传递该 URL 即可，无需额外的 ID 映射层。

### Domain 层 Controller

两个 controller，均为 bare `@riverpod class`（不使用 `keepAlive`），与已有的 `HomeController`/`ScheduleController` 完全一致的模式：

```dart
@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<Anime1Episode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final api = ref.watch(anime1ApiProvider);
    final categories = await api.searchCategories(subjectName);
    final best = matchBestCategory(categories, subjectName);
    if (best == null) {
      throw Anime1NotFoundException();
    }
    return api.fetchCategoryEpisodes(best.id);
  }
}

@riverpod
class EpisodePlayController extends _$EpisodePlayController {
  @override
  Future<Anime1PlaybackSource> build({required String episodePageUrl}) {
    final api = ref.watch(anime1ApiProvider);
    return api.resolvePlaybackUrl(episodePageUrl);
  }
}
```

`SubjectEpisodesController` 使用 family 参数（`subjectId` + `subjectName`），因为匹配结果完全由输入决定，适合作为 family provider 的 key。

### 标题匹配算法

选用简单的**归一化后字符串包含 + 长度接近度打分**，不引入 Levenshtein 编辑距离等更复杂算法（v1 阶段属于过度设计）：

```dart
Anime1Category? matchBestCategory(
  List<Anime1Category> candidates,
  String subjectName,
) {
  final normalizedTarget = _normalize(subjectName); // 去空格 / 全半角统一 / 转小写
  Anime1Category? best;
  var bestScore = 0.0;
  for (final c in candidates) {
    final score = _similarity(_normalize(c.title), normalizedTarget);
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return bestScore >= 0.6 ? best : null;
}
```

`_similarity` 使用最简单的"较短标题是否被较长标题包含 + 字符集重叠比例"计算方式，不追求学术严谨性。阈值 `0.6` 是 v1 的初始猜测值，需要在实施阶段用真实 anime1.me 数据调优。如果实测效果不佳，后续可以替换为更正式的 Levenshtein/Jaro-Winkler 算法（pub.dev 有 `string_similarity` 等现成包），但那是发现具体问题后再优化的事，本设计不预先锁定。

**不使用年份/季度信息辅助匹配**——纯标题字符串相似度匹配，这是头脑风暴阶段的明确决策，以保持 v1 实现简单。

### UI 层

- **`SubjectDetailScreen`**：`ConsumerWidget`。`watch(subjectEpisodesControllerProvider(subjectId: id, subjectName: name))`，用 `.when()` 渲染封面 + 简介 + 剧集 `ListView`。与 `HomeScreen`/`ScheduleScreen` 同样是无状态的 `ConsumerWidget`。
- **`PlayerScreen`**：`ConsumerStatefulWidget`（因为需要持有 media_kit 的 `Player`/`VideoController` 实例并在 `dispose()` 时显式释放，这与 `SearchScreen` 持有 `TextEditingController` 的理由一致）。`watch(episodePlayControllerProvider(episodePageUrl: url))` 拿到播放地址后，通过 `ref.listen` 触发 `player.open(Media(source.url))`。

## 数据流

**完整链路（点击卡片 → 播放完成）**：

1. **Home/Search/Schedule → 详情页**：`SubjectCard(subjectId, name)` → `context.push('/subject/${subjectId}?name=${Uri.encodeComponent(name)}')`。`SubjectCard` 已带 `id`/`name`/`nameCn` 字段（Plan 1b-2 已建好），无需额外请求，直接用 `nameCn ?? name` 作为 anime1 匹配用的标题。路由用 query 参数传递 `name`（而非走 Riverpod 全局状态），保持 `SubjectDetailScreen` 可被 URL 直接打开（对未来深链接/浏览器历史更友好），与 go_router 的惯用法一致。

2. **详情页加载链路**：`SubjectDetailScreen.build()` → `ref.watch(subjectEpisodesControllerProvider(...))` → `AsyncLoading`（loading 占位）→ controller 内部依次执行：(1) `api.searchCategories(name)` [网络请求 #1] → (2) `matchBestCategory(...)` [纯计算，无网络] → (3) `api.fetchCategoryEpisodes(best.id)` [网络请求 #2] → 成功则 `AsyncData(List<Anime1Episode>)` 渲染剧集列表；匹配失败则 `AsyncError(Anime1NotFoundException)` → 显示"未找到资源"空状态（无重试按钮，因为换标题/换数据源不是"重试"能解决的问题）。**不做本地缓存**：`subjectEpisodesControllerProvider` 是非 `keepAlive` 的 family provider，用户离开详情页再返回会重新发起两次请求。这是刻意的简化——Drift 本地数据库在整个 Plan 1b 系列中都已构建但一直未被使用，Plan 1c 延续这一现状，不引入"匹配结果缓存表"。如后续发现 anime1.me 搜索接口响应慢或被限流，再考虑加 Drift 缓存表，不在 v1 设计中预置。

3. **点击剧集 → 播放页链路**：`ListTile(episode) onTap` → `context.push('/subject/${subjectId}/play?url=${Uri.encodeComponent(episode.pageUrl)}')`。`PlayerScreen.initState()` 先创建 media_kit `Player()` 实例（不立即 `open`，等地址解析完成）。`build()` 中 `ref.watch(episodePlayControllerProvider(...))` → `AsyncLoading`（播放器区域黑屏+加载指示器）→ controller 内部 `api.resolvePlaybackUrl(url)` [网络请求 #3] → 成功则 `AsyncData(Anime1PlaybackSource)`，通过 `ref.listen` 一次性触发 `player.open(Media(source.url))`；失败则显示错误提示+重试按钮（详见"错误处理"一节）。使用 `ref.listen` 而非在 `build()` 里的 `.when(data:...)` 直接调用 `player.open`，是因为 `open` 是有副作用的命令式操作，不能放在声明式的 widget `build()` 里反复触发。`episodePlayControllerProvider` 同样非 `keepAlive`、无缓存：每次进入播放页都重新解析一次真实地址（anime1.me 的直链通常有时效性，缓存旧地址反而可能导致播放失败）。

4. **退出播放页**：`PlayerScreen.dispose()` → `player.dispose()`，释放 media_kit 资源，防止后台仍在解码。

**本节核心要点**：全程只有 3 次网络请求（搜索分类、拉剧集列表、解析播放地址），零本地缓存，Riverpod provider 生命周期完全等同于页面生命周期（均为非 `keepAlive`），播放地址解析用 `ref.listen` 桥接声明式状态到 media_kit 的命令式 API。

## 错误处理

两种"错误"在语义与 UI 呈现上有明确区分：

| 场景 | 触发条件 | UI | 重试按钮 |
|---|---|---|---|
| 详情页 - 未找到资源 | `matchBestCategory` 返回 `null`，controller 抛出 `Anime1NotFoundException` | 空状态插图 + 文案"未找到该番剧的播放资源" | 无 |
| 详情页 - 网络/解析异常 | 请求失败或 HTML 解析失败 | 统一的 `ErrorRetryView`（图标 +"加载失败"+"重试"按钮） | 有 |
| 播放页 - 地址解析失败 | `resolvePlaybackUrl` 抛出异常 | 同一个 `ErrorRetryView`，替换播放器区域 | 有 |
| 播放页 - 播放本身失败 | media_kit `player.open()` 调用成功，但后续解码/网络中断 | 同一个 `ErrorRetryView`，覆盖显示在视频层上方 | 有 |

区分依据：`Anime1NotFoundException` 是一个专门的异常类型（在 `SubjectEpisodesController` 内部手动 `throw`），除此之外的所有异常都不再细分类型，统一走同一个 `ErrorRetryView` 组件。UI 层只需一次 `error is Anime1NotFoundException` 判断即可决定走哪个渲染分支。

**不复用 Plan 1b-1 的 `AppError`/`dio_error_mapper.dart` 体系。** `AppError` 是为配合 `AuthInterceptor` 的 401 刷新重试机制设计的，anime1 数据源完全不涉及用户认证，引入该体系没有实际意义。`Anime1Api` 的方法允许 dio 异常、`FormatException` 等原始异常自然抛出，`AsyncError` 天然携带原始异常对象，UI 只需 `.when(error:)` 处理，除 `Anime1NotFoundException` 特判外不关心具体异常类型。

**重试按钮的具体实现**：
- 详情页网络/解析失败重试：`ref.invalidate(subjectEpisodesControllerProvider(...))`。
- 播放页地址解析失败重试：`ref.invalidate(episodePlayControllerProvider(...))`。
- 播放本身失败（media_kit 层面）的重试是一个特例：因为这类失败发生在 `AsyncData` 已经成功之后（地址解析没问题，是实际播放阶段出的问题），仍选择 `invalidate` 同一个 `episodePlayControllerProvider`（重新解析地址 + 重新 `open`，因为 anime1.me 直链有时效性，重新解析是合理的修复动作）。这需要在 `PlayerScreen` 内用 `ref.listen` 监听 media_kit 的 `player.stream.error`（或等价的播放器错误流），一旦收到错误就将本地 `State` 标志设为"播放失败"并覆盖显示 `ErrorRetryView`；点击重试时调用同样的 `ref.invalidate(...)` 并清除该本地标志。

## 测试策略

**domain 层（纯 Dart，无 `flutter` import，优先级最高）**：
- `matchBestCategory`/`_similarity` 纯函数的单元测试：完全匹配、部分包含关系、无关标题、大小写/全半角差异等多组用例，验证 `0.6` 阈值边界行为。
- `SubjectEpisodesController`/`EpisodePlayController` 使用 mocktail mock `Anime1Api`，参照已有 `HomeController`/`ScheduleController` 的测试模式：验证匹配成功→返回剧集列表、匹配失败→抛出 `Anime1NotFoundException`、API 异常→透传为 `AsyncError`。

**data 层**：
- `Anime1Api` 的 HTML 解析测试：不依赖真实网络，使用内嵌在测试文件中的静态 HTML fixture 字符串，配合 dio 的 mock adapter 拦截请求并返回该 fixture，验证 `searchCategories`/`fetchCategoryEpisodes`/`resolvePlaybackUrl` 三个方法的解析逻辑。
- 轻量断言每次请求的 `RequestOptions.headers['Referer']` 等于 `'https://anime1.me'`，防止未来误删该反盗链头。

**UI 层**：
- 不为 `SubjectDetailScreen`/`PlayerScreen` 编写专门的 widget 测试，与 `HomeScreen`/`SearchScreen`/`ScheduleScreen` 目前的做法一致（依靠 `router_test.dart` 覆盖路由可达性）。
- `PlayerScreen` 因 media_kit 依赖原生播放器绑定，难以在 widget 测试环境中可靠模拟，**明确跳过**其 widget 测试——这是已知的覆盖缺口，而非疏漏。

**人工验证（本计划的遗留项，无法自动化）**：
- 抓包确认 `data-apireq` 的真实字段结构，以及 `v.anime1.me/api` 的真实响应格式（当前设计中这部分是"预期格式，待确认"）。
- 用真实 anime1.me 数据验证标题匹配阈值 `0.6` 是否合适。
- 真实播放至少一集，验证 media_kit + Referer 请求头组合能否成功绕过反盗链拿到可播放视频。

## 范围之外（明确不做）

- 弹幕拉取/合并/渲染/发送（Plan 1d）。
- 番剧评分、追番收藏、进度云同步（Plan 1b-3/1b-4）。
- Jellyfin/Emby/Ikaros 等需自建服务器的数据源（v2+）。
- "稀饭动漫"等需要 CEF/WebView 的 web-selector 数据源（Phase 3）。
- BT/PT 下载播放（Phase 2）。
- 多数据源选源 UI、字幕组/分辨率/字幕语言偏好设置。
- 进阶手势控制：滑动调节音量/亮度、长按快进、手势锁。
- 播放进度记忆、自动切换下一集、播放失败自动换源等原 Kotlin 项目 `PlayerExtension` 体系中的可插拔扩展功能。
