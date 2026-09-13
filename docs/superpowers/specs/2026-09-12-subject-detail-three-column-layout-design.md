# 番剧详情页三栏布局改版 — 设计文档

日期：2026-09-12
状态：已批准

## 背景与目标

现在的详情页（`lib/ui/subject/subject_detail_screen.dart`，780 行）结构是：

```
沉浸式模糊头图（封面 + 标题 + 星级 + 排名 + 5 个收藏状态 chip）
─────────────────────────────────────────────
左栏 Expanded(flex:2)          │ 右栏 Expanded(flex:1)
  作品信息                      │   评分柱状图
  简介 + 标签                   │   制作人员表
  评分区（我的评分）             │
  选集网格                      │
  角色横向头像行                 │
```

参考 Animeko（原 KMP 应用）的详情页，改成**左 / 中 / 右三栏**：

```
AppBar（仅返回箭头，无标题）
─────────────────────────────────────────────────────────────────
左栏 200px        │ 中栏 Expanded              │ 右栏 300px
  封面 200×286    │   中文名（大字号）           │  ┌ 评分卡 ─────────┐
  继续观看 第N集   │   原名（小字号灰色）         │  │ 7.0 ★★★☆      │
  ＋追番 / ★在看▾ │   2026年7月 · 连载至09 ·    │  │ #2715 · 1,232人 │
  ─────────────  │   预定全11话                │  │ 柱状图 1..10    │
  7,781 收藏      │   ─────────────────────    │  │        ☆打分   │
  5,959 在看      │   简介（显示更多）           │  └────────────────┘
  1,449 想看      │   ─────────────────────    │  ┌ 热门评价 查看全部›┐
  ─────────────  │   选集    连载至09·预定全11话│  │ 头像 昵称        │
  作品信息         │   [01][02][03][04][05][06] │  │ 评论文字         │
   放送开始 …      │   [07][08][09][10][11]     │  │ ×3             │
   话数 11        │   ─────────────────────    │  └────────────────┘
   别名 …         │   角色         查看全部 ›    │  ┌ 制作人员 查看全部›┐
   标签 chips     │   ◯ ◯ ◯ ◯ ◯ ◯ ◯ ◯       │  │ 原作  中村飒希    │
                 │   名字 / CV                 │  │ 音乐  桥本由香利  │
                 │                            │  └────────────────┘
```

同时修掉两个在设计过程中发现的现存 bug（见"现存缺陷"一节）。

## 范围

**做**

- 页面骨架改为三栏，去掉沉浸式模糊头图。
- 一个断点的响应式回退（宽屏三栏 / 窄屏单列堆叠）。
- 修 `CharacterInfo` 与 staff 的反序列化缺陷。
- 新增收藏统计数字（收藏 / 在看 / 想看）。
- 新增角色 CV 名字。
- 新增热门评价卡片 + 查看全部 bottom sheet。
- 制作人员改由 `infobox` 驱动，删掉 `/staff` 接口链路。
- 收藏状态控件从 5 个平铺 chip 改为「主按钮 + 下拉菜单」。
- 「我的评分」从左栏内联展开区改为右栏评分卡里的 `☆ 打分` → 对话框。
- 新增一个极小的「最近播放集数」记录，支撑「继续观看 第 N 集」按钮。
- 把 `subject_detail_screen.dart` 拆成多个聚焦的小文件。

**不做**

- **完整的单集观看进度系统**（已看/未看打勾、跳集乱序处理、与选集网格联动、云同步）。服务端确认没有任何单集已看标记，本轮只做"最近播放的是第几集"这一个标量。
- **缓存管理 / 下载**：应用没有下载功能，参考图上的「缓存管理」按钮不做。
- **分享**：没有分享功能，参考图右上角的分享图标不做。
- **角色 / 人物详情页**：三个「查看全部」都开 bottom sheet，不新增路由。
- **职位 / 角色的整数码 → 中文标签映射表**：不建。制作人员用 `infobox` 的中文 key；角色的 `role`（主角/配角/客串）不显示。
- **骨架屏**：主数据加载中用居中 `CircularProgressIndicator`。
- **两栏各自独立滚动**：整页一个滚动容器。

## 现存缺陷（本轮顺带修掉）

设计阶段对 `https://api.animeko.org` 做了实测（测试用 subject 302286，BLEACH 千年血戦篇），发现三处线上形状与代码模型不符：

1. **角色头像从来没显示过。** `CharacterInfo`（`lib/data/subject/subject_models.dart:139-150`）声明了 `imageUrl`，但线上没有这个 key —— 实际是 `imageMedium` / `imageLarge`。`nameCn` 也没解析，所以名字显示的是日文原名。`json_serializable` 会静默丢弃未声明的 key，所以这个 bug 一直没报错。该文件 `:134-138` 的注释本身就标注了 `imageUrl` 是未经验证的猜测。

2. **制作人员表从来没渲染过。** `StaffMember`（`subject_models.dart:180-192`）期望 `{name（必填）, imageUrl, role}`，而线上是 `{index, person:{id,name,nameCn,type,imageLarge,imageMedium,summary}, position:int}`。必填的 `name` 缺失 → `_$StaffMemberFromJson` 抛异常 → `subjectStaffProvider` 永远是 error 状态 → `_StaffSection` 是静默失败的 section，于是整块从来没出现过。该文件 `:175-179` 也已承认整个形状是猜的。

3. **`getCharacters` / `getStaff` 连信封都是错的。** 两个方法都写成 `_dio.get<Map<String, dynamic>>(...)` 然后读 `response.data!['items'] as List<dynamic>`（`lib/data/subject/subject_api.dart:54-63`、`:70-78`），但线上返回的是**裸 JSON 数组**，没有 `items` 外层对象。dio 拿到数组时 `data` 是 `List`，转型成 `Map<String, dynamic>` 直接抛异常。也就是说角色区块和上面第 1 条说的头像问题是叠加的——**角色区块同样从来没渲染过**，不只是头像空白。修复必须同时改信封（改成 `_dio.get<List<dynamic>>`）和模型字段，只改模型是不够的。

另外纠正三份历史设计文档的错误结论：

- `docs/superpowers/specs/2026-09-08-rating-histogram-design.md:7` 说收藏统计需要"全新的聚合收藏接口"——错。`GET /v2/subjects/{id}` 已经返回 `favorite: {wish, done, doing, onHold, dropped}`，只是没解析。
- `2026-09-07-subject-detail-two-column-redesign-design.md:27,117` 和 `2026-09-08-rating-histogram-design.md:29` 把热门评价列为"所有延后项中最复杂的一项"——错。`GET /v2/subjects/{id}/reviews` 存在且可用。
- `2026-09-07-subject-detail-two-column-redesign-design.md:17,63` 以"本应用当前仅面向 macOS 桌面"为理由明确拒绝响应式回退。这个前提已经不成立：`android/`、`ios/`、`windows/` 平台目录都已存在，release workflow 会发布 macOS `.dmg` + Windows `.zip` + Android `.apk`（见 `2026-09-06-multiplatform-release-workflow-design.md:16-33`）。所以本轮加一个断点。

## 后端接口实测结果

所有读接口无需鉴权。

### `GET /v2/subjects/{id}`

顶层 key：`id, type, name, nameCn, infobox, platform, summary, nsfw, airDate, aliases, favorite, tags, metaTags, score, scoreDetails, rank, selfRating, episodes, airingInfo, relations`

本轮新用到的两个：

```json
"favorite": {"wish":2138, "done":7420, "doing":1102, "onHold":360, "dropped":177}
```

```json
"infobox": {
  "template": "Infobox animanga/TVAnime",
  "fields": [
    {"key":"原作",     "values":[{"v":"「BLEACH」久保帯人（集英社…）"}]},
    {"key":"音乐",     "values":[{"v":"鷺巣詩郎"}]},
    {"key":"系列构成", "values":[{"v":"田口智久、平松正樹"}]}
  ]
}
```

`infobox` 里实际观测到的 key（部分）：中文名、别名、话数、放送开始（`"2022年10月10日"`，已是中文格式）、放送星期、放送结束、官方网站、在线播放平台、播放电视台、其他电视台、链接、其他、Copyright、原作、监修、系列构成、人物设定、导演、脚本、分镜、演出、动作作画监督、美术监督、美术设计、色彩设计、道具设计、剪辑、摄影监督、CG 导演、3DCG、音响监督、音响、音效、音乐、音乐制作、音乐制作人、OP・ED 分镜、特效、动画制作、主题歌编曲/作曲/作词/演出、製作、企画、计划管理(Planning Manager)、制片人、助理制片人、原作協力、制作管理。

其他已确认事实：

- `score` 是**字符串**（`"7.9"`）；`rank` 是 int；`scoreDetails` 的 key 是字符串 `"1".."10"`。
- **没有** `total` / `ratingTotal` 字段，"N 人评分"必须由 `scoreDetails.values` 求和得到（现有代码 `subject_detail_screen.dart:648` 已经这么做）。
- **没有任何封面图字段**（`imageUrl`/`image`/`images`/`cover` 全部不存在）。封面继续走路由 query param + Drift `SubjectImageCache`。
- `episodes[i]` 形状：`{episodeId, subjectId, sort:"1", ep:"1", type:"MAIN", name, nameCn, description, airdate, disc, duration:"00:24:07"}`。`description` 和 `duration` 线上有但未建模，本轮不用。**没有已看标记。**

### `GET /v2/subjects/{id}/characters?withActors=true`

返回**裸 JSON 数组**（没有 `items` 信封），302286 有 104 项：

```json
{"index":0,
 "character":{"id":3320, "name":"黒崎一護", "nameCn":"黑崎一护",
   "imageLarge":"https://api.animeko.org/v2/characters/3320/image?size=large",
   "imageMedium":".../image?size=medium",
   "actors":[{"id":4716,"name":"森田成一","nameCn":"森田成一","type":1,
              "imageLarge":"…","imageMedium":"…","summary":""}]},
 "role":1}
```

请求里**已经**带了 `withActors=true`（`subject_api.dart:57`），所以 CV 数据一直在传输、一直被丢掉。

### `GET /v2/subjects/{id}/staff`

裸数组，302286 有 343 项，`{index, person:{…}, position:int}`。**`position` 是整数码，302286 一个 subject 就出现了 52 个不同的码**，没有映射表完全无法显示。本轮**弃用此接口**，改用 `infobox`。

### `GET /v2/subjects/{id}/reviews?limit=&offset=`

```json
{"total": 31,
 "items": [
   {"id":"bangumi:302286:1261526", "subjectId":302286, "source":"bangumi",
    "author":{"id":"1261526", "nickname":"Guating",
              "avatarUrl":"https://static.myani.org/bangumi/avatars/1261526/c49f899d85642d15.jpg"},
    "contentBbcode":"对比老tv质的飞跃，观感不错，新加的内容是很好的补充。",
    "updatedAt":"2026-09-11T13:56:03Z", "rating":8, "likeCount":0}
 ]}
```

- 默认 `limit` 30，`limit` / `offset` 都生效（offset 已验证返回不同作者）。
- **`total` 不是真总数**。实测 limit=1→total=2、limit=3→total=4、limit=10→total=11、limit=50→total=51，即"还有更多"时它恒等于 `limit+1`。只能当 has-more 哨兵用：`hasMore = total > items.length`。这一点必须写进模型的注释，否则后来人一定会误用。
- 正文字段是 `contentBbcode`，BBCode 格式，需要剥标签。

### 单集观看进度：不存在

- `GET /v2/subjects/{id}/episodes/{episodeId}` 存在（200）但只有元数据，没有已看标记。
- `/v2/episodes/{id}/collection` 404、`/v2/subjects/{id}/episodeCollections` 404、`/v2/subjects/{id}/comments` 404、`/persons` 404、`/relations` 404。
- 本地只有 `PlaybackPositionStorage`（`lib/data/play/playback_position_storage.dart`），key 是 `subjectId::sourceId::标题`（爬源标题），**对不上 Bangumi 的 `episodeId`**，所以不能拿来判断"第 5 集看过没"。

## 数据层设计

### `SubjectDetail` 新增字段

`lib/data/subject/subject_models.dart`：

- `SubjectFavorite? favorite` — 新模型 `SubjectFavorite {int wish, done, doing, onHold, dropped}`，每个字段 `@JsonKey(defaultValue: 0)`；整个对象可空（老数据或异常响应可能缺）。
- `SubjectInfobox? infobox` — 新模型：
  - `SubjectInfobox {String? template, List<InfoboxField> fields}`（`fields` 默认 `[]`）
  - `InfoboxField {String key, List<InfoboxValue> values}`
  - `InfoboxValue {String? k, String v}` —— 观测到的都只有 `v`，但 Bangumi 的 infobox 规范里 `k` 可能出现，声明为可空以免再犯一次"猜形状"的错。

派生 getter（都在 `SubjectDetail` 上，纯函数、易测）：

- `String? infoboxValue(String key)` — 找到第一个 `key` 匹配的 field，返回其第一个 value 的 `v`；找不到返回 null。
- `List<InfoboxField> get staffFields` — 返回 `infobox.fields` 中 key **不在**黑名单里的项。

黑名单（非制作人员的元信息 key）：`中文名`、`别名`、`话数`、`放送开始`、`放送星期`、`放送结束`、`官方网站`、`在线播放平台`、`播放电视台`、`其他电视台`、`链接`、`其他`、`Copyright`。

**用黑名单而不是白名单**：`infobox` 的职位 key 是自由文本，不同番剧差异很大（观测到 40+ 种）。白名单会让没见过的职位消失；黑名单最坏情况是多显示一行元信息，代价小得多。

### 修 `CharacterInfo`

- 删掉线上不存在的 `imageUrl`。
- 新增 `String? nameCn`、`String? imageMedium`、`String? imageLarge`、`List<PersonInfo> actors`（`@JsonKey(defaultValue: [])`）。
- 新增 `PersonInfo {int id, String name, String? nameCn, int? type, String? imageMedium, String? imageLarge, String? summary}`。
- 显示约定沿用仓库现有的：`nameCn` 非空则用它，否则 `name`（`subject_detail_screen.dart:283` 就是这个逻辑）。CV 取 `actors.first`，`actors` 为空则不显示 CV 行。
- 头像用 `imageMedium`（横向头像行只有 64px 直径，不需要 large）。

### 删除 staff 链路

- 删 `StaffMember` 模型（`subject_models.dart:180-192`）。
- 删 `SubjectApi.getStaff`（`subject_api.dart`）。
- 删 `subjectStaffProvider`（`lib/domain/subject/subject_detail_controller.dart:35`）。
- 制作人员卡改读 `subjectDetailControllerProvider` 的 `staffFields`。**少一次网络请求**，且拿到的是中文职位名。

### 新增 reviews

`lib/data/subject/review_models.dart`：

- `ReviewAuthor {String id, String nickname, String? avatarUrl}`
- `SubjectReview {String id, int subjectId, String source, ReviewAuthor author, String? contentBbcode, String? updatedAt, int? rating, int likeCount}`（`likeCount` 默认 0）
- `PaginatedReviews {int total, List<SubjectReview> items}` + `bool get hasMore => total > items.length`
  - 类注释必须写明：后端的 `total` 是 `limit+1` 哨兵值，不是真总数，禁止用它显示"共 N 条评价"。

`SubjectApi.getReviews({required int subjectId, int limit, int offset})` → `GET /v2/subjects/{id}/reviews`。

`lib/domain/subject/subject_reviews_controller.dart`：`subjectReviewsControllerProvider(subjectId:)` → `Future<PaginatedReviews>`，首屏取 20 条，带 `loadMore()`（offset 累加，追加到 items）。右栏卡片只取前 3 条显示。

`lib/data/subject/bbcode.dart`：`String stripBbcode(String input)` —— 纯函数。
- `[b]文字[/b]` → `文字`（保留内层文本，剥掉标签）
- `[img]…[/img]`、`[img=…]…[/img]` → 整段丢弃
- `[mask]…[/mask]` → **整段丢弃**（实施期追加）。`[mask]` 是 Bangumi 的马赛克文字标签（`bgm.tv/help/bbcode`，Ctrl+M），即剧透遮罩。不能只剥标签保留内层文本，否则热门评价卡会把剧透当正文直接印出来。丢弃而非展开的理由：剧透一旦被读者看到就不可挽回，而少显示几个字的预览文本是可挽回的（完整评价在 Bangumi 上还能看）。
- 未闭合标签 → 剥掉标签本身，保留剩余文本
- 不含标签 → 原样返回（仅去掉首尾空白，见下）
- 返回值 `trim()`（实施期追加）：丢弃开头/结尾的 `[img]` 后会剩下空白，不 trim 的话纯图片评价会渲染成空白 `Text`、图片开头的评价会多一个空行。在纯函数里 trim 一次，比在每个调用点各自 trim 更可靠。

### 新增「最近播放集数」

`lib/data/play/last_played_episode_storage.dart`（照 `PlaybackPositionStorage` 的写法）：

- `SharedPreferences`，key `lastPlayedEpisode:$subjectId` → `int episodeId`
- `int? get(int subjectId)` / `Future<void> set(int subjectId, int episodeId)`
- 本地存储，不同步。

`PlayerScreen` 开始播放某集时写入。

`lib/domain/subject/continue_watching_controller.dart`：`continueWatchingProvider(subjectId:)` → `Future<SubjectEpisode?>`
- 读存储拿 `episodeId`，在 `subjectMainEpisodesControllerProvider` 的列表里查。
- 查到 → 返回该集（按钮显示「继续观看 第 N 集」）。
- 没记录 / 记录指向已不存在的 `episodeId` → 返回列表第一集（按钮显示「开始观看」）。
- 列表为空 → 返回 null（按钮隐藏）。

改完这些需要跑 `dart run build_runner build --delete-conflicting-outputs`。

## UI 结构设计

`subject_detail_screen.dart` 现在 780 行、所有 section 都是同文件私有类，再加本轮内容会到 1200+ 行。拆成多个聚焦文件，**保持扁平目录**（`lib/ui/subject/` 现在就是平铺的，遵循既有风格）：

| 文件 | 职责 |
|---|---|
| `subject_detail_screen.dart` | `Scaffold` + `AppBar` + `LayoutBuilder` 断点排布。**只管排布，不含任何 section 内容。** |
| `subject_detail_left_pane.dart` | 封面 / 继续观看 / 追番 / 收藏统计 / 作品信息 的纵向组合 |
| `subject_detail_main_pane.dart` | 标题块 / 简介 / 选集 / 角色 的纵向组合 |
| `subject_detail_side_pane.dart` | 评分卡 / 热门评价卡 / 制作人员卡 的纵向组合 |
| `subject_title_block.dart` | 中文名（大字号）+ 原名（小字号灰）+ meta 行 |
| `continue_watching_button.dart` | 「继续观看 第N集」/「开始观看」 |
| `subject_collection_action_button.dart` | 「＋追番」/「★在看 ▾」+ `PopupMenuButton` |
| `subject_collection_stats.dart` | 收藏 / 在看 / 想看 三个数字 |
| `subject_info_table.dart` | 作品信息（infobox 驱动）+ 复用 `SubjectTagsRow` |
| `subject_character_row.dart` | 横向头像行 + 名字 + CV |
| `subject_rating_card.dart` | 分数 / 星级 / #排名 / N人评分 / 柱状图 / ☆打分 |
| `subject_rating_dialog.dart` | 原 `_RatingSection` 的滑杆 + 评论框 + 仅自己可见 + 提交，搬进对话框 |
| `subject_reviews_card.dart` | 热门评价前 3 条 |
| `subject_staff_card.dart` | 制作人员表（infobox 驱动） |
| `subject_characters_sheet.dart` | 角色「查看全部」bottom sheet |
| `subject_reviews_sheet.dart` | 热门评价「查看全部」bottom sheet（带 `loadMore`） |
| `subject_staff_sheet.dart` | 制作人员「查看全部」bottom sheet |

**删除**：`subject_blurred_header.dart` + `test/ui/subject/subject_blurred_header_test.dart`（全仓库只有详情页用它，本方案不再需要沉浸式头图）。

**保留复用**：`expandable_summary.dart`（简介）、`subject_tags_row.dart`（作品信息里的标签）、`episode_number_grid.dart`（选集）、`episode_playback_sheet.dart`（点集后的播放源选择）、`lib/ui/common/rating_stars.dart`、`lib/ui/common/tag_chip.dart`、`lib/ui/common/error_retry_view.dart`。

### AppBar

去掉标题（标题已移到中栏，两处重复没意义），只保留返回箭头。不加「回首页」按钮——底部导航已经能回。

### 收藏状态控件

替换现在 5 个平铺 `ChoiceChip` + 1 个「移除」`ActionChip`（`subject_detail_screen.dart:405-420`）：

- **未收藏** → 单个主按钮「＋ 追番」，点一下 = 设为"想看"（`CollectionType.wish`）。
- **已收藏** → 主按钮显示当前状态「★ 在看 ▾」，点开 `PopupMenuButton`，菜单项为其他四个状态 + 分隔线 + 「移除」。

沿用现有 `SubjectCollectionController` 的 `setCollectionType`（乐观更新 + 失败回滚）和 `removeFromCollection`，以及现有的 `_busy` 防重复点击 + 失败 SnackBar。

### 我的评分

从左栏的内联展开区（`_RatingSection`，`subject_detail_screen.dart:432-533`）移到右栏评分卡里的 `☆ 打分` 文字按钮 → 打开 `subject_rating_dialog.dart`。对话框内容与现在完全一致（`Slider(1-10)` + 评论 `TextField` + 「仅自己可见」`SwitchListTile` + 提交），只是换了容器。已评分时按钮文案改为「☆ 已评 N 分」。

### 排布数值

- 断点常量放 `lib/app/theme/app_spacing.dart`（和 `pagePadding` 放一起，避免魔法数字再次散落）：
  `const double subjectDetailThreeColumnBreakpoint = 1000;`
- **宽屏（≥ 1000）**：`Row`
  - 左栏 `SizedBox(width: 200)`，封面 200×286（≈2:3，和现有 `849:1200` 比例一致）
  - 间距 24
  - 中栏 `Expanded`
  - 间距 24
  - 右栏 `SizedBox(width: 300)`
  - 在 1000px 最窄处：`24*2` 外边距 + 200 + 24 + 300 ⇒ 中栏约 428px。现有选集按钮 `minimumSize: Size(96, 40)`、`Wrap` 间距 8，所以最窄时中栏能排 4 列（`4*96 + 3*8 = 408`）。参考图是 6 列，宽窗口下自然会到 6 列以上；4 列是断点处的下限，可接受。
- **窄屏（< 1000）**：单列 `Column`
  1. 顶部横向 header：封面 120 宽 + 右侧标题块 / 继续观看 / 追番 / 收藏统计
  2. 作品信息
  3. 简介
  4. 选集
  5. 角色
  6. 评分卡 / 热门评价卡 / 制作人员卡
- 外层统一用 `pagePadding(context)`，并**清掉各 section 内部重复的 padding**（现在 `_SubjectInfoSection:216` 又套了一层 `EdgeInsets.all(16)`、`EpisodeNumberGrid` 内部又加 `horizontal: 16`，左栏被双重 padding）。
- 整页一个 `SingleChildScrollView`，三栏不单独滚动。理由：嵌套滚动在桌面端滚轮/触控板下体验很差，且现有实现的 `ListView` 只有两个 child、本来就不是懒加载，改成 `SingleChildScrollView` 不损失性能。选集网格的分段渲染（`chunkSize = 100`）继续承担长列表的性能职责。

### 收藏统计的字段映射

`favorite` 有 5 个数字，参考图只显示 3 个。映射关系明确定为：

| 显示 | 字段 |
|---|---|
| 收藏 | `done`（看过） |
| 在看 | `doing` |
| 想看 | `wish` |

`onHold`（搁置）和 `dropped`（弃番）不显示。实施时用一个真实 subject 与 Bangumi 网页上的数字对照一次，确认「收藏」确实对应 `done` 而不是五项求和。

### 中栏 meta 行的计算

参考图的 meta 行是 `2026 年 7 月 · 连载至 09 · 预定全 11 话`，三段各自的来源：

- `2026 年 7 月` — 由 `airDate` 得出，复用现有的 `_formatAirDateYearMonth`（`subject_detail_screen.dart:318`，把 `"2026-07-12"` 转成 `"2026年7月"`）。解析失败则整段省略。
- `连载至 09` — 主线集数中 `airdate` 不晚于今天的集数（`SubjectEpisode.airdate` 是 `"YYYY-MM-DD"` 字符串）。为 0 或全部已放送时省略这一段。
- `预定全 11 话` — `SubjectDetail.episodeCount`（已有的派生 getter，主线集数总数）。为 null 时省略。

三段用 ` · ` 连接，省略掉的段不留分隔符。选集区标题右侧沿用同样的「连载至 NN · 预定全 NN 话」文案，与 meta 行共用同一个计算函数（放在 `subject_title_block.dart` 里导出，或单独一个小的纯函数文件），不重复实现。

## 加载 / 错误 / 空态

现在的问题是几乎所有 section 都静默失败（`orElse: () => SizedBox.shrink()`），出错时页面看起来是"半残"而不是"出错了"。本轮分级：

| 数据源 | 失败表现 |
|---|---|
| `subjectDetailControllerProvider`（主数据） | **整页** `ErrorRetryView`。它撑起标题/简介/选集/作品信息/评分/制作人员，缺了页面没有意义。 |
| `subjectCharactersProvider` | 角色区静默隐藏（独立失败不拖累主内容，保持现状） |
| `subjectReviewsControllerProvider` | 热门评价卡静默隐藏 |
| `subjectEpisodesControllerProvider`（爬源匹配） | 保持现状：选集按钮变暗但仍可见 |
| `infobox` 为空 | 作品信息只显示能拿到的行；制作人员卡整卡隐藏 |
| `favorite` 为空 | 收藏统计整块隐藏 |
| `continueWatchingProvider` 失败 | 按钮退回「开始观看」播第一集 |
| 封面 / 角色头像 / 评价者头像 加载失败 | `errorBuilder` → 占位图标。现在 `CharacterInfo` 的 bug 导致头像全空且无占位，修完必须补上。 |

加载中：
- 主数据 loading → 整页居中 `CircularProgressIndicator`（不做骨架屏）。
- 角色 / 热门评价 loading → 卡片框架先渲染、内容区放小 spinner，避免数据到达时整页布局跳动。

## 测试策略

实现按 TDD 走（先写失败的测试）。

**数据层（纯 Dart，性价比最高）**

- `test/data/subject/subject_models_test.dart`
  - `favorite` 解析；`favorite` 缺失时为 null
  - `infobox` 解析（含 `values` 多项、`k` 缺失）
  - `infoboxValue()` 命中 / 未命中
  - `staffFields` 黑名单过滤，**含"没见过的职位仍然保留"这一条**
  - `CharacterInfo` 的 `nameCn` / `imageMedium` / `actors` 解析；`actors` 缺失时为 `[]`
- `test/data/subject/review_models_test.dart` — 重点测 `hasMore` 的哨兵语义（`total == limit+1` → true；`total == items.length` → false）
- `test/data/subject/bbcode_test.dart` — `stripBbcode`：嵌套标签、`[img]` 丢弃（含多个、跨行、大写）、`[mask]` 丢弃、未闭合标签、字面方括号（`我给[9/10]分`）原样保留、首尾空白被 trim、空字符串
- `test/data/play/last_played_episode_storage_test.dart` — get/set/未设置时为 null
- `test/domain/subject/continue_watching_controller_test.dart` — 有记录 / 无记录 / 记录指向已不存在的 episodeId / 集数列表为空
- `test/domain/subject/subject_reviews_controller_test.dart` — 首屏 + `loadMore()` 追加 + `hasMore` 翻转

**UI**

- **`test/ui/subject/subject_detail_screen_test.dart`（全新——这页的布局现在零覆盖）**
  - 1400×900：断言左/中/右三栏并列（用 `tester.getTopLeft` 比较三者的 x 坐标递增）
  - 800×900：断言单列堆叠（比较 y 坐标递增）
  - 用 `tester.view.physicalSize` + `addTearDown(tester.view.reset)`，照 `test/app/theme/app_spacing_test.dart:9` 的写法
- 各新 widget 的 widget test，其中必须覆盖的：
  - `subject_collection_action_button`：未收藏 → 「＋追番」；已收藏 → 「★在看 ▾」且菜单含其他状态 + 移除
  - `subject_character_row`：CV 行存在 / `actors` 为空时不显示 CV
  - `subject_reviews_card`：BBCode 被剥掉、最多 3 条、「查看全部」可点
  - `subject_staff_card`：infobox 驱动、黑名单 key 不出现
  - `subject_info_table`：infobox 缺字段时对应行不渲染
  - `subject_collection_stats`：`done`/`doing`/`wish` 分别对应 收藏/在看/想看；`favorite` 为 null 时整块不渲染
  - `subject_title_block`：meta 行三段齐全 / 缺 airDate / 缺 episodeCount / 全部已放送（不显示「连载至」）四种组合
  - `continue_watching_button`：有**有效**记录 → 「继续观看 第N集」；无记录 → 「开始观看」；记录已失效（存的 `episodeId` 已不在列表里）→ 「开始观看」（三种情形，与上面 `continueWatchingProvider` 的三条分支一致）
  - `subject_rating_card`：分数 / 排名 / 人数（求和得出）/ 柱状图 / 打分按钮文案随已评分状态变化
- 删 `test/ui/subject/subject_blurred_header_test.dart`

fixture 沿用仓库现有做法（内联 JSON 字符串，如 `test/data/search/search_api_test.dart:118`），infobox 用本文档记录的真实数据子集。

**验收门**：`flutter analyze` 无 error + `flutter test` 全绿。

## 已知的估算项

以下数值是设计阶段的合理估计，实施时可结合实际渲染效果微调，但**改动需在实施报告里说明**：

- 三栏宽度 200 / Expanded / 300、栏间距 24、封面 200×286
- 断点 1000
- 右栏热门评价卡显示 3 条、首屏拉 20 条
- `staffFields` 黑名单的具体条目（不同番剧的 infobox key 有差异，可能需要补充）
