# 稀饭动漫 MediaSource 集成设计

## 背景与范围

当前 app 只有一个在线播放数据源：anime1.me（`lib/data/anime1/`、`lib/domain/play/`、`lib/ui/subject/`、`lib/ui/player/`，已上线并经过多轮真实站点验证与修复，见 commit `aece47d`/`ddc8e03`/`3fd9154`）。本设计为其新增第二个数据源：**稀饭动漫**（https://anime.xifanacg.com/），并顺势把"单数据源"架构改造为可扩展的多数据源架构。

### 稀饭动漫的技术调研结论（均已通过真实请求验证）

稀饭动漫的整条链路（搜索→详情→选集→播放地址解析→播放）**全部是纯静态 HTML + 内嵌 JS 变量，不需要 WebView/CEF 渲染或执行任何 JS**：

- **搜索**：`GET https://dm1.xfdm.pro/search.html?wd=<关键词>` —— 静态 HTML，无验证码。（注意：`https://anime.xifanacg.com/search/wd/<title>.html` 这条路径**有验证码拦截，不可用**；`dm1.xfdm.pro` 是同后端的镜像域名，与 `anime.xifanacg.com` 共享同一套数字 bangumi ID，已通过对同一 ID 分别请求两个域名验证。）搜索结果解析：每个结果项在 `.thumb-content` 内，标题在 `.thumb-txt`，详情页链接在 `.thumb-menu > a`（形如 `/bangumi/<id>.html`）。
- **详情页**：`GET /bangumi/<id>.html` —— 静态 HTML；剧集列表已直接嵌入：`.anthology-tab` 列出各条播放线路（如"稀饭新番主线-1"），每条线路对应一个 `.anthology-list-play > li > a` 列表（剧集标题 + 链接，形如 `/watch/<id>/<line>/<episode>.html`）。
- **播放页**：`GET /watch/<id>/<line>/<episode>.html` —— 视频地址以内嵌 `<script>` 中的 JS 变量形式直接出现在原始 HTML 里：`var player_aaaa = {"encrypt":N, "url":"...", ...}`，可用正则/字符串解析直接提取，无需执行 JS。
- **解密规则**（已读取真实的 `/static/js/player.js?t=a20260901` 源码确认，注意路径是 `/static/js/` 不是 `/static/player/`）：`encrypt` 字段为 `'0'`（或缺失）时 `url` 原样使用；为 `'1'` 时对 `url` 做百分号解码（对应 Dart 的 `Uri.decodeComponent`）；为 `'2'` 时先 base64 解码再百分号解码（对应 `base64Decode` + `Uri.decodeComponent`）。三种情况都是纯字符串/base64运算，不需要 JS 执行。另确认 `playerconfig.js` 里配置的 4 条线路（`xfxf1`/`AL`/`xfy2`/`CS`）的 `parse`（皮肤包装层）都指向同一个通用播放器皮肤域名 `player.moedot.net`，这只是外观包装，解密后的 `url` 本身已经是可直接播放的地址（已用 curl 验证，见下），因此可以完全跳过 `parse` 机制。
- **视频 CDN**：解密后的地址（如 `https://apn.moedot.net/...`）会 302 重定向到 `hydownload.pan.wo.cn/openapi/download?fid=...`（中国联通"沃云盘"）。已用 curl 验证该地址**完全无需任何请求头**（不需要 Referer/Cookie/User-Agent）即可访问，且支持 HTTP Range 请求（验证返回 `206 Partial Content`，实际下载了真实 MP4 字节并用 `file` 命令确认）。这与 anime1.me 的 CDN（需要 Referer+Cookie）不同。

### 明确排除的范围

- 不实现 WebView/CEF —— 已证实不需要。
- 不处理稀饭动漫的验证码拦截搜索路径（`anime.xifanacg.com/search/wd/...`）—— 改用无验证码的 `dm1.xfdm.pro/search.html` 路径。
- 不引入数据源选择 UI —— 结果自动合并展示（见"数据流"一节）。
- 不为弹幕、评分、追番等功能做任何改动。

## 架构

新增 `lib/domain/media/` 层定义统一的数据源抽象；现有的 `Anime1Api`（不改动核心逻辑）与新的 `XifanApi` 都通过一层轻量适配器实现该抽象；`SubjectEpisodesController` 改造为并发遍历所有已注册数据源并合并结果。

采用**方案 A**（轻量抽象类接口 + 简单的 Provider 列表注册），而非方案 B（Dart 3 `sealed class` 联合类型 + `switch` 穷尽匹配）——后者对目前仅 2 个数据源而言是过度设计（YAGNI）。

```
lib/domain/media/
  media_source.dart        # MediaSource / MediaCandidate / MediaEpisode / MediaPlaybackSource 抽象
  media_registry.dart      # @riverpod List<MediaSource> mediaSources(Ref ref)
  title_matcher.dart       # 从 subject_episodes_controller.dart 抽取出的标题匹配算法

lib/data/anime1/           # 现有代码，核心逻辑不变，仅新增适配器 implements 上面的抽象
lib/data/xifan/
  xifan_api.dart           # XifanApi: search / listEpisodes / resolvePlaybackUrl
  xifan_models.dart        # XifanBangumi / XifanEpisode / XifanPlaybackSource

lib/domain/play/
  subject_episodes_controller.dart  # 改造为遍历 mediaSources，Future.wait 并发查询，合并结果
  episode_play_controller.dart      # 基本不变，调用 MediaSource.resolvePlayback(episode)

lib/ui/subject/subject_detail_screen.dart  # 剧集行新增来源徽标
```

**关键约束**：除新增适配器层与迁移标题匹配算法外，anime1.me 现有的核心逻辑（HTML 解析、CDN 请求、Cookie 转发——即 commit `aece47d`/`ddc8e03`/`3fd9154` 里的内容）**完全不变**——`lib/data/anime1/anime1_api.dart` 与 `lib/data/anime1/anime1_models.dart` 本身不被修改，只是被一层新的适配器包装。

## 核心组件

### 1. `lib/domain/media/media_source.dart`（新建）

```dart
abstract class MediaCandidate {
  String get sourceId;
  String get title;
}

abstract class MediaEpisode {
  String get sourceId;
  String get title;
}

abstract class MediaPlaybackSource {
  String get url;
  Map<String, String> get headers;
}

abstract class MediaSource {
  String get id;
  String get displayName;

  Future<List<MediaCandidate>> search(String title);
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate);
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode);
}
```

三个方法内部**让异常自然向上传播**，不在这一层做任何吞掉错误的逻辑——"某个数据源失败时静默忽略"这个决策的实现位置在 `SubjectEpisodesController` 的合并步骤（见"数据流"一节），不在这里。

### 2. `lib/domain/media/media_registry.dart`（新建）

```dart
@riverpod
List<MediaSource> mediaSources(Ref ref) => [
  ref.watch(anime1MediaSourceProvider),
  ref.watch(xifanMediaSourceProvider),
];
```

新增两个薰适配器类（各自在自己的文件里定义，`anime1_media_source.dart` 放在 `lib/data/anime1/`，`xifan_media_source.dart` 放在 `lib/data/xifan/`，或者也可以直接放进 `media_registry.dart`——具体文件划分留给实施计划决定，此处只约束职责边界）：

- `Anime1MediaSource implements MediaSource`：内部持有一个 `Anime1Api`，其 `search`/`listEpisodes`/`resolvePlayback` 分别委托给现有、不作任何修改的 `Anime1Api.searchCategories`/`fetchCategoryEpisodes`/`resolvePlaybackUrl`，并把返回的 `Anime1Category`/`Anime1Episode`/`Anime1PlaybackSource` 包装成实现了 `MediaCandidate`/`MediaEpisode`/`MediaPlaybackSource` 的薰包装类（或者让 `Anime1Category` 等直接 `implements` 这些抽象接口——两种做法都可以，取决于哪种改动更小；由于 `Anime1Category`/`Anime1Episode`/`Anime1PlaybackSource` 本身字段名恰好就是 `title`/`url`/`headers`，直接让它们 `implements` 对应抽象、只需补一个 `sourceId`/`get sourceId => 'anime1'` 的 getter，是改动最小的方式）。
- `XifanMediaSource implements MediaSource`：同理委托给下面新建的 `XifanApi`。

### 3. `lib/data/xifan/xifan_models.dart`（新建）

```dart
class XifanBangumi implements MediaCandidate {
  const XifanBangumi({required this.id, required this.title});
  final int id;
  @override
  final String title;
  @override
  String get sourceId => 'xifan';
}

class XifanEpisode implements MediaEpisode {
  const XifanEpisode({required this.title, required this.watchPageUrl});
  @override
  final String title;
  /// 形如 `/watch/<id>/<line>/<episode>.html` 的相对或绝对路径，是
  /// `XifanApi.resolvePlaybackUrl` 的输入（稀饭动漫没有独立的剧集 ID
  /// 概念，同 anime1.me 的 `pageUrl` 设计一致）。
  final String watchPageUrl;
  @override
  String get sourceId => 'xifan';
}

class XifanPlaybackSource implements MediaPlaybackSource {
  const XifanPlaybackSource({required this.url});
  @override
  final String url;
  /// 稀饭动漫的视频 CDN（`hydownload.pan.wo.cn`）已验证完全不需要任何
  /// 请求头即可访问，故始终为空。
  @override
  Map<String, String> get headers => const {};
}
```

### 4. `lib/data/xifan/xifan_api.dart`（新建）

```dart
class XifanApi {
  XifanApi(this._dio);
  final Dio _dio;

  /// GET https://dm1.xfdm.pro/search.html?wd=<title>
  ///
  /// 已验证真实返回：静态 HTML，无验证码（注意不要用
  /// anime.xifanacg.com 自己的 /search/wd/<title>.html 路径，那条路径
  /// 会返回验证码拦截页）。每条结果在 `.thumb-content` 内，标题在
  /// `.thumb-txt`，详情页链接在 `.thumb-menu > a`（形如
  /// `/bangumi/<id>.html`）。
  Future<List<XifanBangumi>> search(String title) async { ... }

  /// GET https://dm1.xfdm.pro/bangumi/<id>.html（或
  /// anime.xifanacg.com 的同一路径——两个域名共享同一套数字 ID，已验证）
  ///
  /// 剧集列表直接嵌入静态 HTML：`.anthology-tab` 是各条播放线路，每条
  /// 线路对应一个 `.anthology-list-play > li > a` 列表（剧集标题+链接，
  /// 形如 `/watch/<id>/<line>/<episode>.html`）。一部作品可能有多条线
  /// 路，全部展开合并成一个列表返回（不区分线路，与 anime1.me 的单线路
  /// 设计保持一致的扁平化处理，避免引入选线路 UI）。
  Future<List<XifanEpisode>> listEpisodes(int bangumiId) async { ... }

  /// GET watch 页面，从内嵌 `<script>` 中提取
  /// `var player_aaaa = {"encrypt":N,"url":"...",...}`，按 encrypt 字段
  /// 解密：
  ///   '0' 或缺失 → url 原样使用
  ///   '1'        → Uri.decodeComponent(url)
  ///   '2'        → Uri.decodeComponent(utf8.decode(base64Decode(url)))
  /// 找不到 player_aaaa 或解密失败时抛出 FormatException（与
  /// anime1.me resolvePlaybackUrl 遇到解析失败时的做法一致）。
  ///
  /// 已验证解密后的 url 本身已是可直接播放的地址（跳过
  /// playerconfig.js 里的 `parse` 皮肤包装机制），且视频 CDN 不需要
  /// 任何请求头。
  Future<XifanPlaybackSource> resolvePlaybackUrl(String watchPageUrl) async { ... }
}

@riverpod
Dio xifanDio(Ref ref) {
  // dm1.xfdm.pro 只需要一个非空 User-Agent，不需要 Referer/Cookie
  // （与 anime1.me 不同）。
  final dio = Dio(BaseOptions(headers: {'User-Agent': 'Mozilla/5.0'}));
  configureProxy(dio, ref);
  return dio;
}

@riverpod
XifanApi xifanApi(Ref ref) => XifanApi(ref.watch(xifanDioProvider));
```

（此处只给出方法签名与职责说明，具体实现代码——正则表达式、CSS 选择器字符串——留给实施计划按上面"技术调研结论"一节列出的选择器/字段名逐一编写，并配合真实 HTML fixture 编写测试。）

### 5. `lib/domain/media/title_matcher.dart`（新建，从 `subject_episodes_controller.dart` 抽取）

把现有的 `matchThreshold`、`matchBestCategory`、`_normalize`、`_similarity`、`_bestSimilarity`、`_segments`，以及 Simplified→Traditional 字符映射表（`_simplifiedToTraditional`，含 commit `3fd9154` 加入的分段匹配逻辑）整体移到这个新文件，并把 `matchBestCategory` 泛化改名为 `matchBest`，签名从 `List<Anime1Category>` 改为 `List<MediaCandidate>`（因为 `MediaCandidate` 已经声明了 `title` getter，泛化后逻辑完全不需要改动，只改函数签名/参数类型）：

```dart
MediaCandidate? matchBest(List<MediaCandidate> candidates, String subjectName) {
  // 内部逻辑与现有 matchBestCategory 完全一致，只是参数类型换成了
  // MediaCandidate。
}
```

其余私有辅助函数（`_normalize` 等）原样搬移，不需要改动内部实现。

## 数据流

`SubjectEpisodesController`（`lib/domain/play/subject_episodes_controller.dart`）改造为：

```dart
/// 当所有数据源都没有找到匹配结果（或全部请求失败）时抛出。取代原来
/// anime1.me 专属的 Anime1NotFoundException，语义泛化到"任何数据源都
/// 没找到"。同样不是可重试的网络/解析错误——UI 展示为不带重试按钮的
/// 空状态，见"错误处理"一节。
class MediaNotFoundException implements Exception {
  const MediaNotFoundException();
  @override
  String toString() => 'MediaNotFoundException: no media source found this subject';
}

class MergedEpisode {
  const MergedEpisode({required this.episode, required this.sourceId});
  final MediaEpisode episode;
  final String sourceId;
}

@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final sources = ref.watch(mediaSourcesProvider);

    // 并发查询所有数据源；单个数据源失败（网络错误、解析错误、或没有
    // 匹配到候选）都不影响其他数据源的结果——见"错误处理"一节。
    final results = await Future.wait(
      sources.map((source) => _fetchFromSource(source, subjectName)),
    );

    final merged = results.expand((episodes) => episodes).toList();
    if (merged.isEmpty) {
      throw const MediaNotFoundException();
    }
    return merged;
  }

  Future<List<MergedEpisode>> _fetchFromSource(
    MediaSource source,
    String subjectName,
  ) async {
    try {
      final candidates = await source.search(subjectName);
      final best = matchBest(candidates, subjectName);
      if (best == null) return const [];
      final episodes = await source.listEpisodes(best);
      return episodes
          .map((e) => MergedEpisode(episode: e, sourceId: source.id))
          .toList();
    } catch (_) {
      // 静默忽略：单个数据源出错不应该让其他数据源的结果也丢失。
      return const [];
    }
  }
}
```

`EpisodePlayController`（`lib/domain/play/episode_play_controller.dart`）改动很小：`build()` 不再硬编码调用 `Anime1Api.resolvePlaybackUrl`，而是接收一个 `MergedEpisode`（或其内部的 `MediaEpisode` + 对应的 `MediaSource`），调用 `source.resolvePlayback(episode)`。具体传参方式（把整个 `MergedEpisode` 存到 provider 的 family 参数里，还是拆成 `episode`+`sourceId` 两个参数后在 provider 内部从 `mediaSourcesProvider` 里按 `sourceId` 查回对应的 `MediaSource`）留给实施计划决定，两种方式功能等价。

`SubjectDetailScreen`（`lib/ui/subject/subject_detail_screen.dart`）改动：

- `episodes.when(...)` 的 `data` 分支改为渲染 `List<MergedEpisode>`，每一行除了剧集标题外，额外显示一个来源徽标（例如剧集标题旁边的一个小 `Chip`/`Text`，显示 `episode.sourceId` 对应的可读名称，如"anime1.me"/"稀饭动漫"——具体使用哪个数据源的 `displayName` 还是硬编码一个映射表，留给实施计划决定）。
- `error` 分支里 `error is Anime1NotFoundException` 的判断改为 `error is MediaNotFoundException`。

`PlayerScreen`（`lib/ui/player/player_screen.dart`）**完全不变**——它已经是操作单个已解析的 `MediaPlaybackSource`（原来的具体类型 `Anime1PlaybackSource` 换成抽象类型 `MediaPlaybackSource`，字段访问方式不变：`source.url`/`source.headers`），与合并逻辑无关。

## 错误处理

**详情页**（`SubjectDetailScreen`/`SubjectEpisodesController`）：当所有数据源都失败时（无论是"没有任何数据源找到匹配的候选"，还是"每个数据源的网络请求都出错"——两者在当前设计下**无法区分**，因为 `_fetchFromSource` 的 `catch` 块统一吞掉所有异常类型），UI 统一展示不带重试按钮的"未找到该番剧的播放资源"空状态文案，与现有 anime1.me 单数据源时的行为一致。**这是一个相对于旧单数据源设计的行为变化**：旧设计里网络错误会有重试按钮，与"没匹配到"的空状态是分开的；现在这两种情况被统一成同一个不可重试的空状态。此为用户明确选择保留的简化版行为（不引入按数据源分别追踪失败原因的复杂度）。

**播放页**（`PlayerScreen`/`EpisodePlayController`）：完全不变。地址解析失败（`resolvePlayback()` 抛出异常）→ `ErrorRetryView` + `ref.invalidate` 重试；播放期间失败（media_kit 解码/网络错误，发生在已成功 `open()` 之后）→ 同样的 `ErrorRetryView` 模式。这一层操作的是单个已选定的 `MergedEpisode`/具体数据源，不受多数据源合并逻辑影响。

## 测试策略

1. `test/data/xifan/xifan_api_test.dart`（新建）——用真实抓取到的 HTML/JSON 样本作为 mock `Dio` 的响应体，覆盖：`search`（含零结果情形）；`listEpisodes`（含多剧集/多线路情形，验证多条线路被扁平合并成一个列表）；`resolvePlaybackUrl`（覆盖 `encrypt` 的全部 3 种取值 + `player_aaaa` 缺失/格式错误时抛 `FormatException` 的情形）。
2. `test/domain/media/title_matcher_test.dart`（新建，从现有 `test/domain/play/subject_episodes_controller_test.dart` 里搬移标题匹配相关测试，包括 commit `3fd9154` 加入的 Simplified/Traditional 转换与分段匹配测试），适配泛化后的 `matchBest` 签名（用一个实现了 `MediaCandidate` 的测试用简单类替代 `Anime1Category`，或者直接复用 `Anime1Category`/`XifanBangumi` 均可）。
3. `test/domain/play/subject_episodes_controller_test.dart`（重写）——用两个 mock `MediaSource` 验证合并逻辑：两个都成功 → 结果正确合并且每条记录的 `sourceId` 正确；一个失败/空+一个成功 → 只返回成功那个数据源的结果（验证静默忽略）；两个都失败/空 → 抛出 `MediaNotFoundException`；验证是并发（`Future.wait`）调用而非顺序调用（例如用一个人为延迟的 mock 验证两个数据源的调用几乎同时发出）。
4. `EpisodePlayController` 相关测试——改动很小，主要验证它现在调用的是 `MediaSource.resolvePlayback`（通过 mock）而不是硬编码 `Anime1Api`。
5. 不新增任何 widget 测试（与 Plan 1c 已确立的先例一致——`SubjectDetailScreen`/`PlayerScreen`等 UI 屏幕均未曾有独立 widget 测试）。

**验收标准**：`flutter test` 全部通过（因为 `subject_episodes_controller_test.dart` 是重写而非纯增量，具体最终测试总数不在此提前锁定）；`flutter analyze` 保持现有 3 个既有分类（`use_null_aware_elements`、`depend_on_referenced_packages`、`library_private_types_in_public_api`），不引入新分类。

## 范围之外（明确不做）

- 弹幕、评分、追番、云同步 —— 与本次改动无关。
- Jellyfin/Emby/Ikaros 等需要用户自建服务器的数据源 —— 未来独立评估。
- 稀饭动漫的验证码搜索路径的自动化绕过 —— 已找到无验证码的替代搜索域名，不需要处理验证码。
- 数据源选择 UI（用户手动挑选用哪个源）—— 采用自动合并展示，不引入选源界面。
- 按数据源分别追踪/展示失败原因 —— 详情页失败统一为一种空状态，见"错误处理"一节。
