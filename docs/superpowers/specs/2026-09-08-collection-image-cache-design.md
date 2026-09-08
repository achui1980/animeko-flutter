# 收藏/改状态时本地记录封面图，补全"我的收藏"列表图片 设计

日期：2026-09-08。状态：已批准（Approved）。

## 背景

用户反馈：首页能看到番剧封面图，"我的收藏"页看不到。排查确认这不是渲染 bug，而是数据源问题：

- 收藏列表接口 `GET /v2/subjects/list`（`SubjectApi.getMyCollections`）对应的 wire model `MyCollectionSubject`（`lib/data/subject/subject_models.dart:202-247`）**本身没有图片字段**——该类的文档注释是原作者 2026-09-02 实测确认后写下的：`AniSubjectCollection` 没有 image 字段，因此这个列表天生没有封面图。
- 单条目详情接口 `GET /v2/subjects/{id}`（`SubjectDetail`）同样没有图片字段（也是实测确认的 "deliberately lean subset"）。
- 目前代码里唯一能返回图片 URL 的三个接口是 trending、home-recommendations、search（分别对应 `TrendingSubject.imageLarge`、`SubjectRecommendation.imageUrl`、`SubjectSearchResult.imageLarge`），以及 schedule（`ScheduledAnimeSubject.imageLarge`）。这四个接口都不支持"按已知的一批 subjectId 批量查图"。
- 统一映射层 `lib/domain/subject_card.dart` 的 `SubjectCard.fromMyCollectionSubject` 因此没有传 `imageUrl`，落到默认值 `null`；UI 渲染时 `card.imageUrl ?? ''` 变成空字符串，`Image.network('')` 走 `errorBuilder` 分支显示占位图标——这一段链路本身没有问题，是上游数据从源头就缺失。

讨论后确认的可行修复方向：**当用户在详情页收藏/修改收藏状态时，如果当时页面上已知这个 subject 的封面图 URL（来自首页/推荐/搜索/放送表带过来的导航参数），就把 `subjectId -> imageUrl` 这条映射持久化到本地 SQLite；"我的收藏"列表读取时用本地缓存补全图片**。明确排除的方向：不做"用首页在场信息做内存缓存"（首页热门/推荐和用户实际收藏是两批不同的 subject，重合无保证，覆盖不到老番）；不做"收藏列表逐条额外发请求补图"（请求量大且用 search-by-name 匹配不可靠）；不等后端补字段（不在前端可控范围）。

用户明确要求持久化到本地（"App 重启后依然要在"），而非纯内存缓存。

## 关键发现

- `lib/data/local_database.dart` 里已有 4 张 Drift 表（`Subjects`、`Episodes`、`SubjectCollections`、`SearchHistory`），但**目前完全没有任何业务代码读写它们**——是 Phase 1b-2/1b-3/1b-4 预留的空壳骨架。`AppDatabase.schemaVersion` 目前是 `1`，`MigrationStrategy` 只有一个 `beforeOpen`（开 `PRAGMA foreign_keys = ON`），从未升过版本，仓库里没有任何历史 migration 可参照。
- `SubjectCollections` 表的文档注释明确说明它是给未来"云同步"（Plan 1b-4，`dirty`/`syncedAt` 字段）预留的，语义跟"图片缓存"无关。不应该往这张表塞 `imageUrl` 列——会污染其单一职责，且该表所有列目前都是必填/无默认值（比如 `collectionType` 是 `text()()` 非空无默认），插入一条只想存图片的行还要为不相关字段编造占位值，不合理。因此设计为**新建一张专用表**。
- "收藏/改状态"操作在代码里有两条**互相独立**的调用路径：
  1. `SubjectCollectionController.setCollectionType`/`removeFromCollection`（`lib/domain/subject/subject_collection_controller.dart:35-97`）——被 `subject_detail_screen.dart` 里的 `_CollectionButtons` 使用，这是详情页顶部的收藏状态切换。
  2. `_StatusMenuButton`（`lib/ui/collection/my_collection_screen.dart:191-233`）——收藏页编辑模式下直接改状态，绕过上面的 controller，直接调 `SubjectApi.updateCollection`/`deleteCollection`。
  路径2 天生拿不到图片 URL（它的数据源 `MyCollectionSubject` 本来就没图），所以只能覆盖路径1。
- 路径1 目前 `imageUrl` 传递被截断：`SubjectDetailScreen`（有 `imageUrl` 字段，来自路由参数）→ `_ImmersiveHeader`（`imageUrl` 传到这一层，第 231-249 行）→ `_HeaderInfo`（第 251-296 行，**没有继续接收 `imageUrl`**）→ `_CollectionButtons`（第 319-407 行，只有 `subjectId`）。好消息：`_ImmersiveHeader`/`_CollectionButtons` 只在 `imageUrl != null` 时才会被构建（`subject_detail_screen.dart:38-40` 的 `if (imageUrl != null)` gate），所以只要按钮被渲染出来，`imageUrl` 在附近作用域一定非空，只是需要补一路显式传参。
- 从"我的收藏"页本身点进详情页时，`imageUrl` 一定是 `null`（因为 `SubjectCard.fromMyCollectionSubject` 没设置它），这种情况下整个 `_ImmersiveHeader` 不渲染，收藏按钮也看不到——这是现有代码行为，不在本次改动范围内。

## 范围内

1. **新表**：`lib/data/local_database.dart` 新增 `SubjectImageCache` 表：
   ```dart
   class SubjectImageCache extends Table {
     IntColumn get subjectId => integer()();
     TextColumn get imageUrl => text()();
     @override
     Set<Column> get primaryKey => {subjectId};
   }
   ```
   加入 `@DriftDatabase(tables: [...])` 列表；`schemaVersion` 从 `1` 升到 `2`；`MigrationStrategy` 补 `onUpgrade: (m, from, to) async { if (from < 2) await m.createTable(subjectImageCache); }`，保留现有 `beforeOpen`。跑 `dart run build_runner build --delete-conflicting-outputs` 重新生成 `local_database.g.dart`。
2. **DB provider**：新增 `lib/data/local_database.dart`（或新文件）里的 `@Riverpod(keepAlive: true) AppDatabase appDatabase(Ref ref) => AppDatabase();`——目前仓库里没有任何 `AppDatabase` 的 Riverpod provider，DB 连接需要跨页面存活。
3. **Repository**：新增 `lib/data/subject/subject_image_cache_repository.dart`：
   - `Future<void> save(int subjectId, String imageUrl)`：`insertOrReplace` 语义的 upsert。
   - `Future<Map<int, String>> getFor(Iterable<int> subjectIds)`：按一批 id 批量查询。
   - 对应 `@riverpod` provider（普通 provider 依赖 `appDatabaseProvider` 即可，不需要单独 keepAlive）。
4. **写入路径**（详情页收藏/改状态时记录）：
   - `subject_detail_screen.dart`：`_ImmersiveHeader` → `_HeaderInfo` → `_CollectionButtons` 三处构造函数补传 `imageUrl`（字符串，非空，因为只在 gate 内构建）。
   - `SubjectCollectionController.setCollectionType` 签名改为 `setCollectionType(CollectionType type, {String? imageUrl})`；`updateCollection` 成功后，若 `imageUrl != null`，调用 repository 的 `save(subjectId, imageUrl)`（fire-and-forget 或 await 均可，失败不应影响收藏状态本身的成功——即图片缓存写入失败要吞掉/日志记录，不能让 `setCollectionType` 抛错）。
   - `_CollectionButtons._setType` 回调把 `widget.imageUrl` 传给 `setCollectionType`。
   - `removeFromCollection` 不清缓存（保留旧图片；即便之后重新收藏，缓存值会被下一次 `save` 覆盖，不影响正确性，避免过度设计）。
5. **读取路径**（收藏列表合并本地图片）：
   - `MyCollectionsController`（`lib/domain/subject/my_collections_controller.dart`）新增私有 helper，在 `build()`/`loadMore()` 拿到 `page.items` 后，调 repository `getFor(items.map((i) => i.subjectId))`，得到 `Map<int, String>`。
   - `MyCollectionsPage` 新增字段 `final Map<int, String> imageUrls`（不改动 `MyCollectionSubject` 这个纯 wire model）。
   - `SubjectCard.fromMyCollectionSubject` 工厂加一个可选具名参数：`factory SubjectCard.fromMyCollectionSubject(MyCollectionSubject s, {String? imageUrl}) => SubjectCard(id: s.subjectId, name: s.name, nameCn: s.nameCn, imageUrl: imageUrl);`。
   - `my_collection_screen.dart` 渲染时改为 `SubjectCard.fromMyCollectionSubject(subject, imageUrl: page.imageUrls[subject.subjectId])`。
6. **测试**（按仓库 test 树 1:1 镜像惯例）：
   - 扩展 `test/data/local_database_test.dart`：加 `subjectImageCache` 表 round-trip 测试。
   - 新增 `test/data/subject/subject_image_cache_repository_test.dart`：用 `NativeDatabase.memory()` 测 `save`/`getFor`（包括 upsert 覆盖旧值、空 id 列表、部分命中）。
   - 扩展 `test/domain/subject/subject_collection_controller_test.dart`：新增一组测试，验证 `setCollectionType(type, imageUrl: 'x')` 会调用 repository 的 `save`；不传 `imageUrl` 时不调用；`save` 抛异常时不影响 `setCollectionType` 本身的成功返回。
   - 扩展 `test/domain/subject/my_collections_controller_test.dart`：验证 `build()`/`loadMore()` 返回的 `imageUrls` 正确合并了本地缓存数据（mock repository 或直接用内存 DB）。
   - 扩展 `test/domain/subject_card_test.dart`（若存在）：验证 `fromMyCollectionSubject` 在传入 `imageUrl` 时正确赋值。

## 范围外

- 不改后端接口，不新增任何远程 API 调用。
- 不做"收藏列表逐条额外请求补图"的 workaround。
- 不做纯内存（首页/推荐/搜索/放送表刷到即记录）的缓存方案——已与用户确认排除，效果覆盖不全且用户明确要求持久化。
- 不处理 `_StatusMenuButton`（收藏页编辑模式直接改状态）路径的图片写入——该路径天生没有图片数据源，无法写入，也不清空已有缓存。
- 不回填历史收藏数据的图片——只有本次改动上线后的收藏/改状态操作才会写入缓存；老数据要等用户下次经过路径1（详情页收藏按钮，且当时 `imageUrl` 非空）才会补上。
- 不引入图片磁盘缓存库（如 `cached_network_image`）——这是完全独立的"图片文件缓存"问题（当前项目里两层缓存基础设施都是空白，但本次只解决"URL 字符串缺失"这一层）。
- 不给 `Subjects`/`Episodes`/`SearchHistory` 表做任何改动。

## 现状代码基线

- `lib/data/local_database.dart`（85 行）：`AppDatabase` 目前 `schemaVersion => 1`；`@DriftDatabase(tables: [Subjects, Episodes, SubjectCollections, SearchHistory])`；`MigrationStrategy` 只有 `beforeOpen`。
- `lib/domain/subject_card.dart`：`SubjectCard` 是纯值类，`fromMyCollectionSubject(MyCollectionSubject s) => SubjectCard(id: s.subjectId, name: s.name, nameCn: s.nameCn)`（无 `imageUrl` 参数）。
- `lib/domain/subject/subject_collection_controller.dart`（97 行）：`SubjectCollectionController`（`@riverpod class`，autoDispose，family 参数 `subjectId`）；`setCollectionType(CollectionType type)` 目前无 `imageUrl` 参数，乐观更新后调 `subjectApiProvider.updateCollection`。
- `lib/domain/subject/my_collections_controller.dart`（53 行）：`MyCollectionsController`（`@riverpod class`，autoDispose，family 参数 `type: CollectionType?`）；`build()`/`loadMore()` 各自独立调 `subjectApiProvider.getMyCollections`，无本地合并逻辑；`MyCollectionsPage` 目前只有 `items`/`hasMore` 两个字段。
- `lib/ui/subject/subject_detail_screen.dart`：`SubjectDetailScreen(imageUrl)`（第21-31行）→ `_ImmersiveHeader(subjectId, imageUrl)`（第231-249行，`if (imageUrl != null)` gate 在第38-40行）→ `_HeaderInfo(subjectId, subject)`（第251-296行，无 imageUrl）→ `_CollectionButtons(subjectId)`（第319-407行，无 imageUrl），`_setType` 回调在第339-358行调 `subjectCollectionControllerProvider(subjectId:).notifier.setCollectionType(type)`。
- `lib/ui/collection/my_collection_screen.dart`（233行）：`_CollectionList.build`（第137-181行）用 `SubjectCard.fromMyCollectionSubject(subject)` 构造卡片并传给 `AnimeListItem(imageUrl: card.imageUrl ?? '')`；`_StatusMenuButton`（第191-233行）绕开 controller 直接调 `SubjectApi`。
- `lib/ui/subject/subject_navigation.dart`（21行）：`openSubjectDetail` 把 `card.imageUrl`（可能为 null）编码进路由 query 参数传给详情页。

## 风险与已知限制

- **schema 迁移路径未经真实验证**：这是本项目第一次真正需要 `onUpgrade`（此前一直是 `schemaVersion = 1`，新装用户走 `onCreate` 直接建全部表，不会触发 `onUpgrade`）。需要专门测试"从版本1数据库升级到版本2"这条路径（比如手动构造一个版本1的 sqlite 文件，或用 drift 自带的 schema 测试工具），否则线上已安装用户可能升级失败。
- **图片缓存写入失败的静默处理**：如果 `subjectImageCacheRepository.save` 因为磁盘/DB 异常失败，不应该让用户感知到"收藏失败"（因为远程 `updateCollection` 已经成功）。设计上要求把这次写入包一层 try/catch 吞掉（可以打日志），但这意味着**图片缓存偶发丢失不会有任何用户可见的提示**，属于预期行为（缓存本质上是"best effort"补充，不是核心数据）。
- **覆盖不完整是设计的固有取舍**：只有"详情页收藏/改状态且当时 imageUrl 非空"这一条路径会写入缓存。用户从未做过这个操作的老收藏、或者每次都是从"我的收藏"页直接改状态（路径2）的条目，会一直没有图片，直到用户经过一次路径1。已跟用户确认这是可接受的范围。
