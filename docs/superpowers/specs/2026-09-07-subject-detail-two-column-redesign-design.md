# 详情页两栏布局重设计（对齐 Animeko 原版截图）

日期：2026-09-07。状态：已批准（Approved）。

## 背景

用户提供了一张截图，并确认这是 Animeko 原版（Kotlin Multiplatform 应用）详情页的真实截图（非第三方镜像站）。截图展示了一个深色主题、两栏布局的详情页：

- **左栏**：封面图、"开始观看"/"已在看"按钮、收藏/在看/想看统计数字、"作品信息"区块（放送开始日期/话数/别名/标签 chips）、标题、简介、"选集"网格（每个按钮显示集数数字+小标题摘要，部分集数无标题）、"角色"横向头像行（角色名/CV 名）。
- **右侧栏**：评分柱状分布图（1-10 分数区间）、"热门评价"（头像/用户名/星级/评论文本）、"制作人员"表格（两列 key-value，同一 role 可以出现多行，不去重）。

本设计建立在刚完成的 Bangumi 剧集列表重构功能（`docs/superpowers/specs/2026-09-07-subject-detail-bangumi-episodes-redesign-design.md`，实现提交范围 `2ab47aa`..`136c62b`）之上，继续改造同一个 `SubjectDetailScreen` 页面（`lib/ui/subject/subject_detail_screen.dart`），把整体布局改为两栏，并新增/调整若干展示区块。

## 范围

**范围内：**
1. 整体页面结构改为固定两栏布局（不做响应式窄屏回退，本应用当前仅面向 macOS 桌面）。
2. 新增左栏"作品信息"区块：放送开始日期、话数、别名、标签。
3. 剧集网格每个按钮新增标题摘要行。
4. "角色"区块从垂直列表改为横向头像行。
5. 新增右栏"制作人员"表格（从现有 `_CastStaffSection` 中移出并改版）。
6. 头图区去掉放送日期显示（迁移到新的"作品信息"区块，避免重复）。

**范围外（本次不做）：**
1. 收藏/在看/想看集合收藏统计数字 —— 需要新的 Bangumi 聚合收藏数据接口。
2. 评分柱状分布图（1-10 分数区间直方图）—— 需要新的按分数区间分布的接口字段。
3. 热门评价列表 —— 需要全新的 Bangumi 评论/评价接口集成，是所有延后项中最复杂的一项。
4. "已在看"快捷继续观看按钮 —— 现有的"点击剧集号码→弹出播放源选择"交互保持为唯一入口。
5. `_RatingSection`（当前登录用户自己的评分组件）保持原位，不迁移到右栏。
6. "角色"区块的"查看全部"链接不实现任何点击/导航/展开逻辑，仅作静态占位文字。

## 现状代码基线

- `lib/ui/subject/subject_detail_screen.dart`：当前是单列纵向 `ListView`，结构为：沉浸式头图（`_ImmersiveHeader`/`_HeaderInfo`，内含评分星级·排名·放送日期的 `·` 分隔行，放送日期是刚完成的 Bangumi 剧集功能里加的）→ `_SubjectInfoSection`（简介 `ExpandableSummary` + 标签 `SubjectTagsRow` + 评分区 `_RatingSection`）→ `_BangumiEpisodesSection`（新的 Bangumi 驱动剧集号码网格，watches `subjectBangumiEpisodesControllerProvider`）→ `_CastStaffSection`（内含"角色"和"制作人员"两个垂直 `_PersonList`）。
- `lib/data/subject/subject_models.dart` 的 `SubjectDetail` 模型目前**没有** `aliases` 字段，但该应用自有后端 `api.animeko.org` 的 `/v2/subjects/{id}` 原始响应里**已经包含** `aliases` 字段（本会话此前的研究已确认，该后端把 Bangumi 原始数据基本原样透传），只是当前 Dart 模型没有解析/暴露它——新增该字段属于低风险的模型扩展，不需要新接口，但需要跟着跑一次 `build_runner` 重新生成。
- `lib/data/subject/bangumi_episode_models.dart` 的 `BangumiEpisode` 已有 `displayName`（nameCn 优先，回退 name）getter，本次剧集网格加标题摘要不需要新字段/新接口。
- `subjectBangumiEpisodesControllerProvider` 已获取的剧集列表长度（`data.length`）可以直接当作"话数"字段使用，不需要新字段/新接口。
- 角色数据 `RelatedCharacter{index, character: CharacterInfo{name, imageUrl}, role}` 已有横向头像行需要的字段；CV/配音演员名字段的确切路径在写实施计划时需重新核对当前 `subject_models.dart` 源码确认。
- 制作人员数据来自 `StaffApi.getStaff(subjectId)` / `StaffMember{name, imageUrl, role}`（确切文件位置在写实施计划时需重新核对，推测在 `subject_api.dart`/`subject_models.dart` 内），已有右栏表格所需的全部字段，不需要新接口。
- `lib/ui/subject/subject_detail_screen.dart` 里已有 `_formatAirDateYearMonth` 辅助函数（上一个 Bangumi 剧集功能的 Task 6/commit `958e3ce` 加的），本次会迁移复用而不是删除重写。
- `lib/ui/subject/episode_source_grid.dart`/`episode_source_sheet.dart`（供 `PlayerScreen` 内嵌抽屉复用）必须保持完全不变——本次重构只涉及页面布局/展示，不涉及播放源选择逻辑。

## 设计

### 第 1 段：整体两栏布局结构

`SubjectDetailScreen` 改为固定两栏布局：

```
沉浸式头图区（封面/模糊背景/标题/评分星级/排名/收藏状态chips —— 去掉放送日期，见第6段）
─────────────────────────────────────────────────────────────────
│ 左栏（Expanded flex:2，主内容）  │ 右栏（Expanded flex:1，较窄侧栏）│
│                                │                                │
│ 【新增】作品信息 区块           │ 【新增】制作人员 表格           │
│ 简介 + 标签（ExpandableSummary）│ （其余空间留白，为将来的评分   │
│ 评分区（_RatingSection，不变） │  分布图/热门评价预留）          │
│ 剧集网格（BangumiEpisodeGrid， │                                │
│   新增每集标题摘要）            │                                │
│ 角色（改为横向头像行）           │                                │
─────────────────────────────────────────────────────────────────
```

头图区（`_ImmersiveHeader`/`_HeaderInfo`）保持在页面顶部横跨全宽，不参与两栏拆分。两栏区域用一个 `Row` 包裹：左栏 `Expanded(flex: 2)` 容纳原来大部分内容；右栏 `Expanded(flex: 1)` 容纳新的制作人员表格。整体仍包裹在外层 `ListView`/`SingleChildScrollView` 中支持整页滚动，两栏内部不单独滚动（简化实现）。不做响应式窄屏回退——本应用当前仅面向 macOS 桌面（Phase 1 范围）。

### 第 2 段：新增"作品信息"区块

左栏新增"作品信息"（Work Info）区块，位置在头图区之后、简介之前。内容：

- **放送开始日期**：复用 `_formatAirDateYearMonth` 风格的格式化逻辑（如"2026年7月"），从头图区迁移至此（见第6段）。
- **话数**：直接取 `subjectBangumiEpisodesControllerProvider` 已获取列表的长度（`data.length`），不需要新字段/新接口。
- **别名**：新增 `SubjectDetail.aliases` 字段（`List<String>`），从 `api.animeko.org` `/v2/subjects/{id}` 响应中已经存在但当前未解析的 `aliases` 字段解析而来，不需要新接口。
- **标签**：复用现有 `SubjectTag`/`SubjectTagsRow`。**去重决定**：标签从当前位置（`_SubjectInfoSection` 内，紧随简介之后）迁移到本区块内（在别名之后渲染），不在两处同时出现——`_SubjectInfoSection` 之后只保留简介文本。

实现方式：一个简单的 `Column`，内含若干 `Text` 行 + 末尾一个 `SubjectTagsRow`，不需要表格/卡片组件。

### 第 3 段：选集网格加标题摘要

`BangumiEpisodeGrid`/`_EpisodeNumberButton`（`lib/ui/subject/bangumi_episode_grid.dart`）在数字下方新增一行小字标题摘要，取自已有的 `BangumiEpisode.displayName` getter（不需要新字段/新接口）：

- 按钮内部改为两行：第一行数字（不变），第二行标题摘要，字号更小、单行截断（`maxLines: 1, overflow: TextOverflow.ellipsis`）。
- 若 `displayName` 为空字符串，只显示数字，不留空白占位行——按钮高度与只有数字时一致。
- 三态视觉逻辑（正常/灰置/加载中）完全不变，只是内容多了一行。
- 按钮尺寸从当前固定 `Size(48, 40)` 改为更宽一些以容纳文字（例如固定宽度约 96px，高度不变或略增）——具体数值到写实施计划时再定。

低风险，纯 UI 展示层修改，不涉及数据模型/接口变化。

### 第 4 段：角色横向头像行

"角色"区块（当前在 `_CastStaffSection` 内）从垂直 `_PersonList` 改为横向可滚动头像行：

- `SingleChildScrollView(scrollDirection: Axis.horizontal)` + `Row`，内含若干 `_CharacterAvatar` 小组件。
- 每个 `_CharacterAvatar`：圆形头像（`CircleAvatar`/`ClipOval`，来自 `RelatedCharacter.character.imageUrl`）+ 角色名（上方）+ CV/演员名（下方，小字灰色）。所有字段已存在于 `RelatedCharacter` 模型上，不需要新数据。
- 顶部保留"角色"标题 + 右侧"查看全部"文字——**明确确认：本次不实现"查看全部"的任何点击/导航/展开逻辑**，仅作静态占位文字。
- "制作人员"（Staff）从这个 section 中**完全移出**，迁移到新的右栏表格（第5段）。改造后 `_CastStaffSection` 只保留"角色"这一块；原来同时给角色和制作人员复用的 `_PersonList` widget 是否整体删除还是保留给角色专用，到写实施计划时再定。

### 第 5 段：右栏制作人员表格

新增右栏"制作人员"（Staff）表格：

- **数据来源不变**：仍用现有 `StaffApi.getStaff(subjectId)` / `StaffMember{name, imageUrl, role}`，不新增接口。
- **展示形式**：两列 key-value 表格，左列是角色（role），右列是人名。**不按 role 去重**——同一个 role 有多个人时渲染多行，每行一个 (role, name) 对，严格按接口返回顺序，不做分组合并。
- **不显示头像**：`StaffMember.imageUrl` 本次不使用（截图里制作人员表格只有文字）。
- **标题**：顶部保留"制作人员"文字标题，**不带"查看全部"**（与"角色"区块不同）。
- **加载/错误态**：复用现有 `_PersonList`/`_CastStaffSection` 已有的"静默失败就隐藏"策略——如果 staff provider 报错或返回空列表，整个表格隐藏（不显示错误提示）。
- **右栏其余空间**：如第1段所述，表格上方/周围留白，为将来评分分布图、热门评价预留。

低风险——纯粹是把已有数据换一种展示方式，不涉及新增接口。

### 第 6 段：头图区去掉放送日期

现有 `_HeaderInfo` 里评分星级/排名那一行去掉第3个用 `·` 分隔的放送日期元素（`_formatAirDateYearMonth`，上一个 Bangumi 剧集功能刚加的），恢复成只有"评分星级 · 排名"。`_formatAirDateYearMonth` 函数本身不删除，迁移到新的"作品信息"区块里复用（第2段）。净效果：放送日期从头图区搬到左栏新的作品信息区块，不会同时出现两处。

### 第 7 段：明确不在本次范围内的事项

1. 收藏/在看/想看集合收藏统计数字——需要新的 Bangumi 聚合收藏数据接口，本次不做。
2. 评分柱状分布图（1-10 分数区间直方图）——需要新的按分数区间分布的接口字段，本次不做。
3. 热门评价列表——需要全新的 Bangumi 评论/评价接口集成，是所有延后项中最复杂的一项，本次不做。
4. "已在看"快捷继续观看按钮——本次不加，现有"点击剧集号码→弹出播放源选择"交互保持为唯一入口。
5. `_RatingSection`（当前登录用户自己的评分组件）保持在左栏原位，不迁移到右栏侧边栏。
6. "角色"区块的"查看全部"链接——不添加任何点击/导航/展开逻辑，仅静态文字。

## 风险与已知未知

- 别名字段（`aliases`）的确切 JSON 字段名/形状需要在写实施计划时通过读取该应用现有的 `subject_api_test.dart` 测试夹具或做一次真实请求核实，虽然已有前期研究确认该字段存在，但精确字段名未做过字节级核对。
- 角色模型里 CV/配音演员名的确切字段路径（是否嵌套在 `CharacterInfo` 内还是单独字段）需要在写实施计划时重新读取当前 `subject_models.dart` 源码确认，本设计文档未做字节级核对。
- 制作人员数据（`StaffApi`/`StaffMember`）的确切文件位置需要在写实施计划时重新核对（推测在 `subject_api.dart`/`subject_models.dart` 内）。
- 两栏布局的具体 flex 比例（2:1）、剧集按钮的具体新尺寸数值等为设计阶段的合理估计，最终数值将在实施计划阶段结合实际渲染效果微调。
