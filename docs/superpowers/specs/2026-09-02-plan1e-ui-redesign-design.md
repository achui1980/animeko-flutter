# Plan 1e：UI 整体重新设计（对齐 Animeko 视觉风格）+ 设置/账户页

## 背景

当前 Flutter App 的每个页面都是"功能优先、样式从简"地搭出来的（详情见调研记录）：

- **完全没有自定义主题**——`lib/app/main.dart` 的 `MaterialApp.router` 没有传 `theme`/`darkTheme`/`themeMode`，全项目用 Flutter 默认蓝色 Material 3 主题，不支持深色模式。
- **没有通用组件库**——Home/Search/Schedule/我的收藏 四个页面各自内联实现了相似但不一致的番剧卡片/列表项样式，AppBar 的"收藏"+"设置"两个按钮在三个 Tab 页面里重复写了三份几乎相同的代码。
- **详情页是纯 `ListView` 堆叠**，没有沉浸式头图、没有统一的圆角/间距规范。
- **设置页目前只有"代理设置"一项内容**（`lib/ui/settings/settings_screen.dart`），没有主题切换、没有账户管理。
- **账户体系有后端能力但没有前端入口**：`AuthController.signOut()`（`lib/domain/auth/auth_controller.dart:149`）已经实现好了登出逻辑，但 UI 上没有任何地方调用它；用户也看不到自己的登录状态/昵称/头像（`login_screen.dart` 里"Logged in as $id"那行文字由于路由重定向逻辑几乎不可见）。

用户反馈"现在的UI太难看了操作也不直观"，明确要求：**参照原版 Animeko（Kotlin/Compose）的视觉风格重做整个 App**，并顺带补上几个"简单配置"：账户/登录设置页、代理设置入口、深浅色主题切换。

本设计基于两次代码调研：
- Flutter 现状调研（`lib/` 全量代码阅读）
- 原版 Animeko 设计系统调研（`/Users/portz/js/animeko` 下 `app/shared/ui-foundation`、`ui-adaptive`、`ui-exploration`、`ui-subject`、`ui-settings`、`video-player` 等模块的真实 Compose 代码）

以及为账户页新增而额外确认的真实服务端接口：`GET /v1/me`（见"数据与 API 变更"节）。

## 范围

**包含：**

1. **主题系统**：基于种子色的 Material 3 动态配色（对齐 Animeko 默认种子色 `#4F378B`），支持浅色/深色/跟随系统三态切换，持久化到本地。
2. **通用组件库**：统一的番剧卡片组件、统一的 Tab AppBar 封装、统一的 Loading/Empty/Error 状态组件、Tag/Chip 组件。
3. **页面级重新设计**（视觉层面，不改变现有信息架构/接口调用逻辑）：
   - Home / Search / Schedule 三个 Tab 页
   - 番剧详情页（沉浸式头图、封面比例、Tag 样式统一）
   - 我的收藏页（卡片化列表项）
   - 设置页重做（分组列表式，含主题切换 + 代理设置入口）
   - **新增**账户/个人中心页（头像 + 昵称 + 登出，调用新确认的 `GET /v1/me`）
4. **播放页**：仅接入深色主题（`alwaysDarkInEpisodePage` 思路的简化版——播放页固定深色），**不**改动播放控制条本身（media_kit 默认控制条暂时保留，弹幕相关 UI 已在 Plan 1d 调研中确认推后，见 (b2)）。

**明确不包含（对齐原版但本轮推迟，避免范围爆炸）：**

- **Material You 动态取色**（Android 12+ 读取系统壁纸取色 / 桌面读取系统强调色）——原版是可选项，本轮固定用种子色生成配色，不接入平台取色 API。
- **详情页"取封面主色重新生成整页主题"**（`MaterialThemeFromPaletteAndImage`）——需要额外的调色板提取库和逐页面 MaterialTheme 包裹，复杂度高，推迟。
- **毛玻璃 App Chrome 效果**（Haze 库的 AppBar/NavigationBar 模糊）——Flutter 没有直接对应库，需要自制 `BackdropFilter` 方案，推迟。
- **动画渐变背景**（详情页 `enableAnimatedGradientSubjectPage`）——推迟。
- **宽屏自适应布局**（NavigationRail / PermanentDrawer，原版按 `WindowSizeClass` 切换布局）——本 App 目标主要是手机端，本轮只做 `NavigationBar` 底部导航布局，不做平板/桌面宽屏的导航形态切换。
- **M3 `Carousel` 轮播组件**（原版首页"最近热门"用的贝塞尔轮播）——Flutter 没有直接对应组件，首页对应区块改用普通横向 `ListView`/卡片替代，保留视觉相似度但不做轮播交互效果。
- **种子色自定义 / 预设色板选择器**——用户需求原文只是"深浅色主题切换"，本轮不做换色功能，种子色固定为 `#4F378B`。
- **缓存管理 Tab**——原版底部导航有"探索/追番/缓存管理"三个 Tab，本 App 没有离线下载缓存功能，继续保持现有 **Home/Search/Schedule** 三个 Tab，不新增/不改名。
- **观看历史页面**——原版个人中心有"观看历史"入口，本 App 没有对应功能，账户页不加这一项。
- **弹幕相关 UI**——已在 Plan 1d 调研中确认整体推后（见 (b2)）。
- **详情页 Tab 切换（详情/评论/讨论）**——本 App 详情页已经是单页信息流（Plan 1b-3 已实现，见历史），本轮不引入 Tab+HorizontalPager 结构，只优化现有信息流的视觉样式（头图/卡片/间距）。

## 架构

### 1. 主题系统

新增 `lib/app/theme/` 目录：

```
lib/app/theme/
  app_theme.dart          # AppTheme.light() / AppTheme.dark()：ColorScheme.fromSeed + useMaterial3
  app_spacing.dart         # 响应式间距辅助函数（对齐 Animeko 的 WindowSizeClass 思路，简化为宽度阈值判断）
```

关键决策：

- **种子色** `const kSeedColor = Color(0xFF4F378B)`（与 Animeko 默认种子色一致），用 `ColorScheme.fromSeed(seedColor: kSeedColor, brightness: ...)` 生成浅色/深色两套配色。Flutter `ColorScheme.fromSeed` 默认算法（HCT Tonal Spot）与 Animeko 用的 `com.materialkolor` 默认 `PaletteStyle.TonalSpot` 是同一套色彩算法，视觉上应非常接近，**不需要额外三方取色库**。
  - Flutter 3.41（本项目 SDK 版本，已确认）的 `ColorScheme` 已包含 `surfaceContainerLowest/Low/(默认)/High/Highest` 全套色阶角色，可以直接复用 Animeko 的色阶分层用法（见下方"色阶角色映射"）。
- **Typography/Shape**：不做自定义，直接用 `useMaterial3: true` 的 Flutter 默认值——这与 Animeko 自身的选择一致（它也没有自定义 Typography 数值刻度或全局 Shapes，只替换了字体族，本轮不做字体替换）。
- **色阶角色映射**（对齐 Animeko 的 `AniThemeDefaults`）：
  | 用途 | 颜色角色 |
  |---|---|
  | 页面背景 | `colorScheme.surfaceContainerLowest` |
  | 底部导航栏 / AppBar 滚动后容器色 | `colorScheme.surfaceContainer` |
  | 装饰性卡片（弱强调） | `colorScheme.surfaceContainerLow` |
  | 主体卡片（番剧卡片、收藏列表卡片） | `colorScheme.surfaceContainerHigh` |
- **深色模式切换**：
  - `ThemeMode` 三态：`system` / `light` / `dark`（直接复用 Flutter 自带 `ThemeMode` enum，不需要自定义枚举）。
  - 持久化：扩展现有 `lib/data/settings/settings_storage.dart` 的 `SettingsStorage`，新增 `getThemeMode()` / `setThemeMode(ThemeMode)`（新 key `theme_mode`，存字符串 `"system"|"light"|"dark"`），做法与现有 `getProxyUrl`/`setProxyUrl` 完全一致。
  - 新增 `lib/domain/settings/theme_mode_controller.dart`：`@riverpod class ThemeModeController extends _$ThemeModeController`，`build()` 读取持久化值，`setThemeMode(ThemeMode)` 写入+更新 state——与现有 `ProxySettingsController` 是同一套 Riverpod Notifier 模式，直接照抄结构。
  - `lib/app/main.dart` 的 `AnimekoFlutterApp` 改为 `watch(themeModeControllerProvider)`，把 `theme: AppTheme.light()`、`darkTheme: AppTheme.dark()`、`themeMode: ...` 传给 `MaterialApp.router`。
- **响应式间距**：`app_spacing.dart` 提供 `double pagePadding(BuildContext context)`：宽度 `< 600` 返回 `16.0`，否则返回 `24.0`（简化 Animeko 的紧凑/宽屏两档设计，不区分 pane/card 两套数值）。

### 2. 通用组件库

新增 `lib/ui/common/` 下的组件（`error_retry_view.dart` 已存在，保留不改）：

```
lib/ui/common/
  error_retry_view.dart     # 已存在，不变
  anime_cover_card.dart      # AnimeCoverCard：竖版封面卡片（Home/Search 用），封面比例 849:1200
  anime_list_item.dart       # AnimeListItem：横条卡片（我的收藏/Schedule 用），对齐 Animeko 148dp 高横条卡片
  tag_chip.dart              # TagChip：32dp 高、8dp 圆角、1dp outlineVariant 描边，对齐 Animeko Tag.kt
  app_action_bar.dart        # buildStandardActions(context)：收藏/设置/头像 三个 IconButton，供 Home/Search/Schedule 的 AppBar.actions 复用，消除三份重复代码
  loading_view.dart          # 统一 Center(CircularProgressIndicator()) 封装（当前各页面直接写，改为复用）
  empty_view.dart            # 统一空状态（图标+文字），我的收藏页当前的"还没有收藏任何番剧"迁移到这里
```

设计要点（对齐调研发现的原版数值）：

- `AnimeCoverCard`：封面 `AspectRatio(aspectRatio: 849/1200)` + `ClipRRect(borderRadius: 16)`（对齐 `MaterialTheme.shapes.large`），容器色 `surfaceContainerHigh`，标题 `titleMedium` 单行省略。
- `AnimeListItem`：固定高度 148dp，左侧封面（同比例裁剪）+ 右侧标题/副标题列，容器色 `surfaceContainerHigh`，圆角 12dp（对齐 `shapes.medium`）。
- `TagChip`：`Container(height: 32, decoration: BoxDecoration(border: Border.all(width:1, color: outlineVariant), borderRadius: 8))`。
- `app_action_bar.dart` 不是一个 Widget，而是一个返回 `List<Widget>` 的辅助函数，接收 `BuildContext` + 是否已登录状态，登录已完成后把原来的"设置"图标之外，再加一个头像 `IconButton`/`CircleAvatar`（点击跳转新的账户页 `/account`）——复用 Animeko"头像入口=个人中心"的交互模式，但用独立页面代替原版的 Popup（更贴合移动端全屏导航习惯，降低 Flutter 实现复杂度）。

### 3. 页面级改动

| 页面 | 文件 | 改动概述 |
|---|---|---|
| MainShell | `lib/ui/shell/main_shell.dart` | `NavigationBar` 应用 `surfaceContainer` 容器色；图标沿用 Material 默认（不强制换成 Rounded 变体，Flutter Material Icons 本身已是圆润风格，无需额外处理）。 |
| Home | `lib/ui/home/home_screen.dart` | AppBar 用 `buildStandardActions()`；原横向 `ListView.builder` 卡片替换为 `AnimeCoverCard`；页面背景 `surfaceContainerLowest`；Section 标题统一用 `titleMedium` + 统一间距（`pagePadding`）。 |
| Search | `lib/ui/search/search_screen.dart` | AppBar 内嵌搜索框视觉优化（保持内嵌不变，仅统一圆角/背景色）；结果列表由 `ListTile` 替换为 `AnimeListItem`。 |
| Schedule | `lib/ui/schedule/schedule_screen.dart` | `ExpansionTile` 展开后的 `ListTile` 替换为 `AnimeListItem`；日期标题样式统一。 |
| 番剧详情页 | `lib/ui/subject/subject_detail_screen.dart` | 顶部封面区改为"模糊封面背景 + 渐变遮罩"沉浸式头图（`Stack` + `ImageFiltered`/`BackdropFilter` 模糊 + `Container` 渐变遮罩，简化版对齐 Animeko `SubjectBlurredBackground`，不做取色动态主题）；封面本体用 `AnimeCoverCard` 的封面部分（149:1200 比例）+ 16dp 圆角；标签 `Chip` 替换为 `TagChip`；收藏状态按钮/评分区保持现有交互逻辑不变，仅统一间距和圆角视觉。 |
| 我的收藏页 | `lib/ui/collection/my_collection_screen.dart` | `ListTile` 列表替换为 `AnimeListItem`；空状态替换为 `EmptyView`；`SegmentedButton` 视觉保留（原版也是类似的分段/Tab 切换）。 |
| 设置页 | `lib/ui/settings/settings_screen.dart` | **重做为分组列表式**（对齐 Animeko `SettingsScope.Group` 思路，Flutter 侧简化为：`ListView` + 若干个 `_SettingsGroup`（标题 `Text` + `Card`/`Container` 包裹的条目列表））：<br>① **通用**分组：主题模式选择（`RadioListTile` x3：跟随系统/浅色/深色，绑定 `ThemeModeController`）；<br>② **网络**分组：代理设置条目（`ListTile` + 副标题显示当前代理地址或"未设置"，点击跳转到现有的代理设置表单——可以保留为独立子页面 `/settings/proxy`，也可以直接内嵌展开，本设计选择**保留为独立子页面**以复用现有 `ProxySettingsController` 表单代码，改动最小）；<br>③ **账户**分组：显示登录状态摘要 + "账户设置"条目跳转 `/account`。 |
| 账户页（新增） | `lib/ui/account/account_screen.dart` | 新页面。头像（`CircleAvatar`，取 `AniAniSelfUser.mediumAvatar`，加载失败/未登录显示默认图标占位）+ 昵称居中加粗（`titleLarge`）+ 列表项：「退出登录」（红色 `error` 配色文字+图标，点击调用 `AuthController.signOut()` 并弹确认对话框防误触）。未登录态（理论上不会出现，因为路由重定向已保证进入该页面前必然是已登录状态，但仍做防御性处理显示"未登录"）。 |
| 登录页 | `lib/ui/auth/login_screen.dart` | 不改动逻辑，仅可能统一按钮/间距视觉（低优先级，可选）。 |
| 播放页 | `lib/ui/player/player_screen.dart` | 包一层强制深色 `Theme`（`Theme(data: AppTheme.dark(), child: ...)`），不改动播放器控件本身。 |

### 4. 数据与 API 变更

新增账户页需要获取当前用户的昵称/头像，之前项目里完全没有调用过用户信息接口（`AuthAuthenticated` 只存了 `userId` 字符串）。已通过阅读真实 Kotlin 生成客户端代码确认（非猜测）：

- 文件：`/Users/portz/js/animeko/client/src/commonMain/gen/me/him188/ani/client/apis/UserAniApi.kt`，model：`/Users/portz/js/animeko/client/src/commonMain/gen/me/him188/ani/client/models/AniAniSelfUser.kt`
- `GET /v1/me`（需要 `auth-jwt` 认证）→ `AniAniSelfUser`：
  ```
  id: String (必填)
  nickname: String (必填)
  hasPassword: Boolean (必填)
  isBangumiSessionValid: Boolean (必填)
  email: String? 
  smallAvatar: String? 
  mediumAvatar: String? 
  largeAvatar: String? 
  registerTime: Long? 
  lastLoginTime: Long? 
  clientVersion: String? 
  bangumiUsername: String? 
  ```
- 新增 `lib/data/user/user_api.dart`（`UserApi.getSelf()`，复用现有 `dioProvider`，与 `subject_api.dart` 同样的调用风格）+ `lib/data/user/user_models.dart`（`SelfUser` model，`json_serializable`，字段名逐字对照上表，`isBangumiSessionValid`/`hasPassword` 等按 Dart camelCase 默认映射即可，无需自定义 `toJson`）。
- 新增 `lib/domain/user/self_user_controller.dart`（`@riverpod Future<SelfUser> selfUser(Ref ref)`，账户页调用一次即可，不需要复杂的缓存策略）。

### 5. 路由变更

`lib/app/router.dart` 新增两个 `GoRoute`：

```dart
GoRoute(path: '/account', builder: (context, state) => const AccountScreen()),
GoRoute(path: '/settings/proxy', builder: (context, state) => const ProxySettingsScreen()), // 从现有 settings_screen.dart 拆分出来的表单部分
```

`/settings` 路由不变（`SettingsScreen` 内容重做，见上表），`/account` 从 Home/Search/Schedule 的 AppBar 头像按钮跳转（走 `app_action_bar.dart` 的辅助函数），也可以从设置页"账户"分组的条目跳转。

## 实施阶段建议

由于范围横跨"基础设施（主题/组件库）"和"逐页面视觉重做"两类工作，建议拆成以下几个可独立验证的阶段（对应未来的实现 Plan 文档，每个阶段完成后跑一次 `flutter test` + `flutter analyze` + 真机/模拟器视觉检查再进入下一阶段）：

1. **阶段 A（地基）**：主题系统（`app_theme.dart`/`app_spacing.dart`/`ThemeModeController`）+ 通用组件库（`anime_cover_card.dart`/`anime_list_item.dart`/`tag_chip.dart`/`loading_view.dart`/`empty_view.dart`/`app_action_bar.dart`）。此阶段产出的组件暂不接入任何页面，只保证组件本身可编译、有基本 widget test。
2. **阶段 B（设置/账户）**：`UserApi`/`SelfUser` model/`SelfUserController`；设置页重做；账户页新增；路由新增 `/account`、`/settings/proxy`；`AuthController.signOut()` 接入 UI。
3. **阶段 C（三个 Tab 页）**：Home/Search/Schedule 接入阶段 A 的组件库和主题。
4. **阶段 D（详情页）**：沉浸式头图 + 封面/Tag 样式统一。
5. **阶段 E（我的收藏页）**：接入 `AnimeListItem`/`EmptyView`。
6. **阶段 F（播放页，低优先级）**：接入强制深色主题包裹。

每个阶段都是独立的实现 Plan 文档（`docs/superpowers/plans/2026-09-0X-plan1e-X-....md`），遵循本项目现有的 Plan 文档模板（任务拆解 + 每个任务的 Definition of Done + 最终验证清单）。

## 验证方式

- 单元/widget 测试：新组件（`AnimeCoverCard`/`AnimeListItem`/`TagChip`）各配一个基础 widget test（渲染不崩溃、关键文案可见）；`ThemeModeController`/`SelfUserController` 参考现有 `ProxySettingsController` 的测试写法（mock `SettingsStorage`/`dioProvider`）。
- 全量回归：每阶段结束跑 `flutter test` 全量通过 + `flutter analyze` 不引入新增问题（当前基线是 19 个已知历史问题，见 (b2)）。
- 视觉验证：真机/模拟器手动过一遍改动页面，重点检查深色模式切换是否生效、封面比例是否正确、AppBar 头像入口是否可跳转账户页并成功登出。
