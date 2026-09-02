# Plan 1b-3：番剧详情页完善（简介/角色制作人员/收藏状态/自评分/我的收藏）设计文档

## 背景

现有的 `SubjectDetailScreen`（`lib/ui/subject/subject_detail_screen.dart`）是 Xifan MediaSource 集成时顺带做出来的最简版本：只有封面图 + 合并后的剧集列表（`MergedEpisode`，来自 `anime1.me`/`稀饭动漫` 两个 `MediaSource`）。它完全没有用到 Bangumi/Ani 服务端真正的“番剧详情”数据——简介、标签、评分、角色/制作人员、以及最重要的：用户自己的收藏状态和自评分。

Plan 1b-1 早已建好了 Drift 表结构（`lib/data/local_database.dart` 里的 `Subjects`/`Episodes`/`SubjectCollections`/`SearchHistory`），并在文档注释里写明这是为未来的 Plan 1b-2/1b-3（详情）和 Plan 1b-4（云同步）预留的，但目前完全没有被使用。本设计**不会**把这些 Drift 表用起来——直接调服务端 API，缓存/离线/脏数据同步全部推迟到 Plan 1b-4。

本设计的服务端接口全部来自阅读 `/Users/portz/js/animeko/client/src/commonMain/gen/me/him188/ani/client/apis/SubjectsAniApi.kt` 及相关 model 文件得到的真实字段名（与 Plan 1a 反推 OAuth 字段时用的是同一手法，因为真正的 OpenAPI spec 需要仅限维护者的 token）。

## 范围

**包含：**
- 番剧详情页扩充：简介、标签、官方评分/排名、角色列表（含配音演员）、制作人员列表（横向头像展示，不支持点进去）
- 收藏状态管理：5 种状态（想看/在看/看过/搁置/弃坑）+ 移除收藏
- 自评分：1-10 分 + 评论 + 是否私密
- 新增“我的收藏”页面：按 5 种收藏状态筛选查看

**明确不包含（沿用 `docs/superpowers/specs/2026-08-28-plan1b-series-design.md` 已确认的排除项，并新增本轮讨论中确认的排除项）：**
- 他人评论/评分文字列表（只展示自己的）
- 角色/人物独立详情页（不支持点进去，只做横向头像展示）
- “讨论”Tab（现有 Kotlin 客户端里也只是占位，未实现）
- 单集观看进度追踪（“看到第几集”，与本 App 的 `MediaSource` 剧集列表无关联，不在本轮范围）
- 本地 Drift 缓存/离线/脏数据同步（推迟到 Plan 1b-4）
- BT/web-selector/CEF/一起看/个性化/引导（沿用既有排除）

## 架构

新增文件遵循本项目已有的约定（json_serializable models + Riverpod `@riverpod` controller，直接 dio 调用，不引入 repository/cache 层——与 Search/Schedule/Xifan 的做法一致）：

```
lib/data/subject/
  subject_api.dart      # SubjectApi: getSubject / updateCollection / deleteCollection / getCharacters / getStaff / getMyCollections
  subject_models.dart   # SubjectDetail, SelfRating, RelatedCharacter, StaffMember, CollectionType enum, MyCollectionsPage

lib/domain/subject/
  subject_detail_controller.dart     # @riverpod family(subjectId): 拉取 SubjectDetail
  subject_collection_controller.dart # @riverpod family(subjectId): 变更操作 —— setCollectionType() / removeFromCollection() / submitRating()
  my_collections_controller.dart     # @riverpod family(CollectionType filter): "我的收藏"页的分页列表

lib/ui/subject/
  subject_detail_screen.dart  # 现有文件，扩充（不重写）：在现有（完全不变）的合并剧集列表之上，加入封面/简介/标签/角色制作人员横向列表/收藏状态按钮/评分输入
lib/ui/collection/
  my_collection_screen.dart   # 新增：5 种状态的分段控制 + SubjectCard 列表
```

关键架构决策：
- **本轮不引入 Drift/缓存层**——Plan 1b-1 预留的 `Subjects`/`Episodes`/`SubjectCollections`/`SearchHistory` 表继续保持未使用，明确推迟到未来的 Plan 1b-4（云同步）。
- **复用现有 `dioProvider`**（已经挂了 Plan 1b-1 的 auth interceptor），不需要新建 Dio 实例/provider。
- **现有的 `MergedEpisode` 合并剧集列表（来自 Xifan MediaSource 工作）完全不受影响**——不与 Bangumi 自己的 `episodes` 字段做任何对账/合并。
- **现有的 `imageUrl` 路由参数继续作为封面图来源**——`AniSubjectCollection` 本身没有图片字段，而 Home/Search/Schedule 的每个 `SubjectCard` 入口已经可靠地通过路由 query 参数传了一个可用的 `imageUrl`，无需新增图片获取逻辑。
- **“我的收藏”入口**：在每个 Tab 的 AppBar 里，紧邻现有的设置齿轮图标，新增一个书签图标，push 一个新的顶层平级路由 `/collection`——与此前 Settings 功能的接入方式完全一致，不需要改动底部导航 Shell/Tab 结构。

## 核心组件

字段名均来自真实 Kotlin client model 逐字核对：

```dart
enum CollectionType { wish, doing, done, onHold, dropped }
// JSON 取值：WISH/DOING/DONE/ON_HOLD/DROPPED —— 需要自定义 toJson/fromJson（不是默认的 camelCase → SCREAMING_SNAKE 映射）

@JsonSerializable()
class SubjectDetail {
  final int id;
  final String name;
  final String nameCn;
  final String summary;
  final String airDate;
  final List<SubjectTag> tags;       // {name, count}
  final String? score;               // 官方评分，字符串编码的浮点数
  final int? rank;
  final CollectionType? collectionType;  // 当前用户的收藏状态；null = 未收藏
  final SelfRating selfRating;        // 当前用户自己的评分；未评分时各字段为默认值
}

@JsonSerializable()
class SelfRating {
  final int score;        // 0-10，0 = 未评分
  final List<String> tags;
  final bool isPrivate;
  final String? comment;
}

@JsonSerializable()
class RelatedCharacter { final int index; final CharacterInfo character; final int role; }
@JsonSerializable()
class CharacterInfo { final String name; final String? imageUrl; }
```

```dart
class SubjectApi {
  Future<SubjectDetail> getSubject(int subjectId);              // GET  /v2/subjects/{id}
  Future<void> updateCollection(int subjectId, {CollectionType? collectionType, SelfRating? selfRating}); // PATCH /v2/subjects/{id}
  Future<void> deleteCollection(int subjectId);                  // DELETE /v2/subjects/{id}
  Future<List<RelatedCharacter>> getCharacters(int subjectId);   // GET .../characters?withActors=true
  Future<List<StaffMember>> getStaff(int subjectId);             // GET .../staff
  Future<PaginatedCollections> getMyCollections({CollectionType? type, int offset, int limit}); // GET /v2/subjects/list
}
```

`lib/domain/subject/subject_detail_controller.dart`：裸的 `@riverpod class SubjectDetailController`，`build({required int subjectId})` 直接返回 `Future<SubjectDetail>`；角色/制作人员通过两个**独立**的小 provider 拉取（各自失败不影响简介/收藏/评分区域的显示——沿用 Xifan 功能里“单个数据源静默失败”的模式）。

`lib/domain/subject/subject_collection_controller.dart`：`@riverpod class SubjectCollectionController`，`build({required int subjectId})` 初始状态读取 `SubjectDetailController` 已经拉到的 `collectionType`/`selfRating`（避免重复请求）；`setCollectionType(CollectionType type)` → 乐观本地状态更新 → 调 `updateCollection` → 失败时回滚并报错；`removeFromCollection()` → 调 `deleteCollection`；`submitRating(int score, {String? comment, bool isPrivate = false})` → 校验 score 为 1-10 → 调 `updateCollection(selfRating: ...)`。

## 数据流

- **详情页加载**：SubjectCard 点击 → 路由带上 `subjectId`/`name`/`imageUrl` → `SubjectDetailScreen` 并行、互不阻塞地 watch 三个 provider：`subjectDetailControllerProvider(subjectId)`（主详情）、`subjectCharactersProvider(subjectId)`、`subjectStaffProvider(subjectId)`——角色/制作人员失败不影响主详情显示。已有的 `subjectEpisodesControllerProvider`（合并剧集列表）完全不受影响，独立渲染在下方。
- **收藏状态切换**：点击某个收藏状态按钮（5 种状态或"移除收藏"）→ `SubjectCollectionController.setCollectionType(type)` 立即乐观更新本地状态（按钮高亮切换）→ 后台调 `PATCH /v2/subjects/{id}` → 成功则保持；失败则回滚到旧状态 + 弹出 SnackBar 错误提示（不用 `ErrorRetryView`，因为这是一次性操作反馈，不是页面级可重试状态）。
- **评分提交**：点击"评分"打开评分输入区（1-10 星 + 可选评论输入框 + 隐私开关）→ 点击"提交"→ 校验 score 为 1-10（0=未评分，不可提交）→ 调用同一个 `PATCH` 接口（`selfRating` 字段），成功则关闭输入区并刷新显示的分数；失败则弹 SnackBar，输入内容保留以便重试（**不做乐观更新**，因为评论文本的回滚体验不如收藏按钮直观）。
- **"我的收藏"页面**：AppBar 新增书签图标 → push `/collection` → `MyCollectionsScreen` 顶部是 5 个状态的分段控制 → 每个 Tab 对应 `myCollectionsControllerProvider(type)` 的分页请求，用 `SubjectCard` 网格/列表渲染（复用 Home/Search 已有的卡片样式）→ 点击卡片 → push 回 `/subject/:subjectId`（同一个详情页，形成闭环）。分页策略：v1 只做"滚动到底部加载下一页"（下一页 `offset` 触发），不做下拉刷新（YAGNI——用户可以离开再进入页面来刷新）。

## 错误处理

- 主详情（`SubjectDetailController`）加载失败 → 复用现有 `ErrorRetryView`（页面级、可重试），与剧集列表的失败状态视觉上分开。
- 角色/制作人员加载失败 → 静默隐藏整个横向列表区块（不展示任何错误），与 Xifan/anime1.me"单源静默失败"模式一致。
- 收藏状态切换失败 / 评分提交失败 → 均为一次性 SnackBar + （仅收藏按钮）回滚乐观更新。
- "我的收藏"页面：首次加载失败 → `ErrorRetryView`；加载更多（分页）失败 → 列表底部一个小的"加载失败，点击重试"文字按钮，不影响已加载的内容。

## 测试策略

- `lib/data/subject/subject_api.dart` —— mock Dio + 贴近真实的 JSON fixture（字段名与 Kotlin model 一一对应）测试全部 6 个方法的请求构造和响应解析，包括 `CollectionType` 的自定义 JSON 映射（WISH/DOING/DONE/ON_HOLD/DROPPED）。
- 3 个新 controller —— 用 mocktail mock 掉 `SubjectApi`，纯 Riverpod 单元测试（`SubjectDetailController` 的成功/失败路径；`SubjectCollectionController` 的乐观更新+回滚逻辑作为最高优先级测试目标；`MyCollectionsController` 的分页/状态切换逻辑）。
- UI 层 —— **经与用户确认，不添加 widget 测试**，与本项目全程保持一致的零 widget 测试惯例（Home/Search/Schedule/SubjectDetailScreen/PlayerScreen/SettingsScreen 均无 widget 测试）。核心逻辑完全靠 controller 层单元测试覆盖。

## 已知的未确认事项（诚实标注，非隐藏遗漏）

1. **`StaffMember` 模型的具体字段名/结构尚未确认**——本次调研只确认了 `GET /v2/subjects/{id}/staff` 这个端点存在，没有读取对应的 Kotlin model 文件或做实际的 API 探测。实现阶段需要先做一次 curl 探测或读取对应 Kotlin model 文件，再落地真实的 `StaffMember` 类和测试。
2. **`CharacterInfo` 的 `imageUrl` 等价字段名只是推断，未经确认**——本次调研只确认了外层 wrapper `AniRelatedCharacter{index, character, role}` 的结构，没有实际读取 `AniCharacter` 本身的 Kotlin model 文件来核实其字段名（`name`/`imageUrl` 是基于项目里其它模型的命名惯例推断的，不保证准确）。

## 范围之外（明确排除，供实现阶段参考）

- 他人评论/评分文字列表
- 角色/人物独立详情页（不支持点进去）
- "讨论"Tab
- 单集观看进度追踪
- 本地 Drift 缓存/离线/脏数据同步/云同步（Plan 1b-4）
- BT/web-selector/CEF/一起看/个性化/引导
