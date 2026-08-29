# Plan 1b-2 设计：首页 + 搜索 + 时间表

## 背景

Plan 1b-1（数据基础层）已完成并推送到 `origin/main`：会话持久化+刷新、`AuthInterceptor`、Drift 本地数据库骨架（未接入任何 provider）、`json_serializable` 工具链（已验证可用，无永久代码）。本文档覆盖 Plan 1b 系列设计文档中原定的 Plan 1b-2 范围：首页（热门轮播+推荐）、搜索（关键词+标签过滤）、新番时间表。

## 范围确认（brainstorming 阶段逐一确认）

1. **组合方式**：首页+搜索+时间表三者合并为一个计划（不再拆分），与系列设计文档原定范围一致。
2. **数据模型深度**：仅构建卡片级最小字段（id/name/nameCn/封面图/评分/标签/上映日期），不构建详情页所需的完整字段（角色/制作人员/关联作品/完整剧集列表）——这些留给 Plan 1b-3。
3. **持久化**：本计划仅做纯网络请求，不接入 Plan 1b-1 已建但未使用的 Drift 本地数据库；Drift 接入（作为收藏/评分状态的持久层）留给 Plan 1b-3。
4. **Plan 1a/1b-1 遗留问题 I-A、I-B**：本计划内一并修复（因为本计划是第一个真正通过 `dioProvider` 接入业务仓库/多屏幕的计划，此前这两个问题都是"休眠"状态，现在会被激活）。
5. **导航结构**：底部 Tab 导航（首页/搜索/时间表 三个平级 Tab），登录态由 `go_router` 的 `redirect` 统一网关控制。
6. **搜索过滤器范围**（因真实 API 契约与系列设计文档原假设不符而修正）：仅实现关键词+标签+排序，不做季度过滤（时间表 Tab 已有专门的季度端点）、不做评分区间过滤（真实 API 的 `ratings`/`airDates` 是格式不明的不透明字符串参数，YAGNI 不做）。

## API 契约调研结论（逐字核对 `/Users/portz/js/animeko/client/src/commonMain/gen/me/him188/ani/client/`）

**关键发现：这 4 组端点没有共享的"卡片"模型——每组返回形状互不兼容的轻量级 subject 结构**，因此 Dart 侧需要一个统一的内部 `SubjectCard` 模型 + 各来源专属的映射函数，而不能直接复用生成代码风格的单一模型。

### 1. Trends（首页热门轮播）
- `GET /v1/trends`，**公开**（`requiresAuthentication=false`），无参数。
- 响应：`{trendingSubjects: [{bangumiId: Int, nameCn: String, imageLarge: String}]}` —— 只有 3 个字段，无评分/标签。

### 2. Home Recommendations（首页推荐）
- `GET /v2/home/recommendations`，声明需要 `auth-jwt`（历史经验：这个声明可能是死代码，未必真的强制鉴权，需在实现时用真实请求验证）。
- 参数：`offset?: Int`, `limit?: Int`（均可选，query）。
- 响应：`{total: Long, items: [{subjectName, subjectNameCn, imageUrl, desc1, desc2, subjectId?: Long, uri?: String}]}` —— 无评分/标签，`desc1`/`desc2` 是服务端拼好的自由文本描述。

### 3. Search（搜索）
- `GET /v2/subjects/search`，声明需要 `auth-jwt`（同样需实测验证是否真的强制）。
- 参数：`q: String`（必填）、`offset?/limit?: Int`、`tags?: List<String>`（CSV）、`airDates?/ratings?/ranks?: List<String>`（CSV，格式不明——**本计划不使用**）、`includeNsfw?: enum{include,only,exclude}`、`sortBy?: enum`、`fields?: List<enum>`（响应字段选择器，本计划用默认全量即可，不做字段裁剪）。
- **`sortBy` 真实枚举值**（修正系列设计文档中猜测的 `MATCH/RANK/COLLECTION/DATE`）：`relevance | airDateAsc | airDateDesc | ratingAsc | ratingDesc | rankAsc | rankDesc | collectionDesc`。
- 响应：`{items: [{id: Long, name, nameCn, summary, imageLarge, nsfw: Bool, airDate, ratingTotal: Int, favorite: {wish,done,doing,onHold,dropped 各为Int}, tags: [{name,count}], mainEpisodeCount: Int, lightRelatedPersonInfoList, score?: String, rank?: Int}]}` —— **无 `total` 字段**（不同于收藏列表接口），也**无 `collectionType`**（搜索结果不带当前用户的收藏状态）。这是 4 组里字段最丰富的一个。

### 4. Schedule（时间表）
全部**公开**（`requiresAuthentication=false`）：
- `GET /v1/schedule/airing?today=<ISO日期>&timeZone=<tz>` → `{list: [{date: String, list: [{subject: {subjectId: Long, name, nameCn, imageLarge}, episode: {episodeId, name, nameCn, airDate, type: Int, sort, ep?}, airingTime: String}]}]}` —— 按日期分组的一周播出列表，对应现有 Kotlin 客户端"按星期分页+今天高亮"的时间表 UI，是本计划时间表 Tab 的主数据源。
- `GET /v1/schedule/seasons/latest` → 最近几个季度的完整列表（本计划不使用，仅记录供 Plan 1c/1d 或未来扩展参考）。
- `GET /v1/schedule/seasons` / `GET /v1/schedule/season/{seasonId}` → 季度列表/单季度新番列表（本计划不使用）。

### 鉴权声明汇总
| 端点 | 声明 `requiresAuthentication` |
|---|---|
| Trends | false（公开） |
| Home Recommendations | true |
| Search | true |
| Schedule（全部4个） | false（公开） |

## 架构设计

### 数据层（`lib/data/`，每组端点独立文件，`json_serializable` 生成模型）
- `lib/data/home/trends_api.dart` + `trends_models.dart`：`TrendsApi(Dio).getTrends()`。
- `lib/data/home/home_recommendations_api.dart` + `home_recommendations_models.dart`：`.getRecommendations({int? offset, int? limit})`。
- `lib/data/search/search_api.dart` + `search_models.dart`：`.search({required String keywords, List<String>? tags, SearchSortBy? sortBy})`，`SearchSortBy` 枚举对应上述真实 wire values。
- `lib/data/schedule/schedule_api.dart` + `schedule_models.dart`：`.getLatestAiringSchedule({required String today, required String timeZone})`。
- 均通过现有 `dioProvider`（Plan 1b-1 已接好鉴权拦截器/超时），不新建独立 Dio 实例。

### 领域层（`lib/domain/`）
- `lib/domain/subject_card.dart`：统一的 `SubjectCard` 值类型（`id`/`name`/`nameCn`/`imageUrl`/`score`/`tags`/`airDate` 均除 `name` 外可空），配 4 个来源专属的 factory 映射函数（`.fromTrending`/`.fromRecommendation`/`.fromSearchResult`/`.fromScheduledSubject`）。
- `lib/domain/home/home_controller.dart`：`@riverpod class HomeController`，并行加载 Trends+Recommendations，暴露 `AsyncValue<HomeData>`（`HomeData{trending, recommendations}`）。**"继续观看"板块本计划不做**——需要 Plan 1b-3 才有的收藏状态，现在做是无意义的临时代码。
- `lib/domain/search/search_controller.dart`：`@riverpod class SearchController`，管理关键词（防抖）+标签多选+排序状态，暴露 `AsyncValue<List<SubjectCard>>`。
- `lib/domain/schedule/schedule_controller.dart`：`@riverpod class ScheduleController`，加载当前周时间表，按星期分组暴露数据。

### I-A / I-B 修复（本计划内完成，作为独立任务）
- **I-B**：`SessionRefresher.refresh()` 返回类型从 `Future<StoredSession?>` 改为一个密封的 `RefreshResult`（`RefreshSuccess(StoredSession)` / `RefreshFailure(AppError)`），让调用方能区分"网络问题稍后重试"和"会话真的失效了"。
- **I-A**：`AuthController` 新增 `signOut()` 方法（清空本地存储+状态回到 `AuthUnauthenticated`）。`api_client.dart` 里 `AuthInterceptor` 的刷新回调改为检查新的 `RefreshResult`：遇到 `RefreshFailure(AuthExpiredError)` → 调用 `authController.signOut()`（配合下面的路由 `redirect` 自动回到登录页）；遇到 `RefreshFailure(NetworkError)` → 仅让当前请求失败，不登出（避免因临时离线而错误登出用户）。

### UI 层与路由
- `lib/ui/home/home_screen.dart`、`lib/ui/search/search_screen.dart`、`lib/ui/schedule/schedule_screen.dart`。
- `lib/ui/shell/main_shell.dart`：用 go_router 的 `StatefulShellRoute` 包裹三个 Tab，提供底部导航栏。
- `lib/app/router.dart` 改造：新增 `redirect:` 回调——未登录时重定向到 `/login`；已登录且当前在 `/login` 时重定向到 Shell 的默认 Tab（首页）。

## 数据流与错误处理
延续 Plan 1a/1b-1 的模式：UI 通过 `ref.watch(xxxControllerProvider)` 拿 `AsyncValue`，用 `.when(loading/error/data)` 渲染；网络错误统一通过 `mapToAppError()`（Plan 1b-1 已建）转成 `AppError` 后展示；401 由 `AuthInterceptor` 处理刷新重试，刷新彻底失败时触发上面的 `signOut()` 全局登出流程。

## 测试策略
延续既有模式：各 API wrapper 用 mocktail mock `Dio` 做单元测试；各 Controller 用 `ProviderContainer` + provider override 做单元测试；各 Screen 做最小 widget 冒烟测试（loading/data/error 三态），参照 `LoginScreen` 测试的先例。

## Definition of Done
- `flutter test` 全部通过；`flutter analyze` 干净（不计已知的历史遗留 info 级 lint）；`flutter build macos --debug` 成功。
- 真实网络请求验证：首页能展示 Trends 轮播 + Recommendations 列表；搜索输入关键词能返回结果列表（含标签/评分展示）；时间表 Tab 能展示当前周按星期分组的新番播出列表。
- 底部 Tab 导航正常工作；未登录访问任何 Tab 会被重定向到登录页；登录成功后自动进入首页 Tab。
- I-A/I-B 均已修复并有对应单元测试（`signOut()` 被 401-且-刷新失败-时正确调用；网络错误不触发登出）。

## 不在本文档范围内
- 详情页/评分/收藏（Plan 1b-3）。
- 云同步（Plan 1b-4）。
- Drift 本地缓存接入（留给 Plan 1b-3，届时收藏状态需要持久化）。
- "继续观看"首页板块（依赖 Plan 1b-3 的收藏状态）。
- 季度浏览、评分区间搜索过滤（真实 API 不支持结构化实现，或已有更合适的入口）。
