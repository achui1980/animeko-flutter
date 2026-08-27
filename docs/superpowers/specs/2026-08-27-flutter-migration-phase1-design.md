# Animeko → Flutter 迁移：总体拆解与 Phase 1（macOS 桌面核心主链）设计

## 背景与动机

Animeko（原 Ani）目前是 Kotlin Multiplatform + Compose Multiplatform 实现的一站式追番 App，支持 Android/iOS/Windows/macOS/Linux，尚无 Web 版本。团队决定整体转向 Flutter 生态（技能栈/工具链/招聘等因素），而非仅为获得 Web 端而做局部适配（如启用 Compose Multiplatform 的 Web/Wasm target）。

服务端 `ani-api-server` 是独立仓库，与本次迁移无关——客户端通过 Ktor + OpenAPI 生成的 client 调用服务端 REST API，迁移只涉及客户端重写，后端 API 契约原样复用。

BT 边下边播（基于自研 `anitorrent`，即 C++ 封装 libtorrent 的引擎）是必须保留的核心功能，不可裁剪，但技术难度和风险最高，因此单独拆出为独立阶段。

## 总体策略

- **渐进式迁移**：新建独立 Flutter 项目，与现有 KMP 仓库并行维护，不影响现有用户；不做“大爆炸式”一次性替换。
- **平台优先级**：先做 **macOS 桌面单平台**，验证核心体验后再逐步扩展到其他平台（Windows/Linux/Android/iOS，具体顺序留待 Phase 1 完成后再评估）。
- **Web 评估延后**：Web 端因浏览器沙箱限制（无法做真正 P2P BT 下载、无法“浏览器里嵌浏览器”抓取自定义数据源），注定只能是功能子集。是否值得做、何时做，留到后续阶段单独评估，不影响当前迁移路径的选择。

## 子项目拆解（阶段规划）

```
Phase 0  项目脚手架 + CI（新 Flutter repo/目录）
Phase 1  Mac 桌面核心主链（本文档设计范围，不含 BT）
Phase 2  BT 边下边播（FFI 桥接 anitorrent C++ 核心）
Phase 3  自定义数据源系统（web-selector CSS 编辑器 + CEF/WebView 取流）
Phase 4  次要功能（评论、一起看预览、个性化设置、新手引导）
Phase 5  平台扩展（Windows → Linux → Android → iOS，顺序待定）
Phase 6  Web 评估（届时重新评估是否值得做，做则是功能子集）
```

每个阶段都是独立的“设计 → 实施计划 → 执行”周期，本文档只覆盖 **Phase 1**。

## Phase 1 范围：macOS 桌面核心主链

**包含：**
- App 壳 + 路由 + 主题
- Bangumi OAuth 登录（桌面授权码流程）+ token 持久化
- 番剧浏览/搜索/详情/评分（对接现有 `ani-api-server` REST，复用 OpenAPI schema 生成 Dart client）
- 追番收藏 + 进度云同步（双向）
- 在线数据源（Jellyfin/Emby/Ikaros）搜索选源 + 播放
- 视频播放器（含手势控制）
- 弹幕：拉取弹弹play源 + Animeko 自建源，合并渲染，支持发送弹幕到自建服务

**明确排除：** BT/dmhy/mikan、自定义 web-selector 源、CEF WebView 取流、评论区、一起看、个性化设置深度定制、新手引导动画。

### anitorrent（Phase 2 预研结论，供后续排期参考）

`anitorrent` 原生核心是纯 C++（CMake 构建，链接 `libtorrent-rasterbar`），已验证 macOS/Windows/Linux 三端可编译。现有 JNI 绑定通过 SWIG 生成（`anitorrent.i` → `anitorrent_wrap.cpp`），C++ 核心与 JNI 层分离，只暴露低级 API。**结论：给 Flutter 做 FFI 桥接大概率不需要重写 BT 引擎**——只需给现有 C++ 核心新增一层 `extern "C"` 的 C API（绕开 SWIG/JNI），再用 Dart 的 `ffigen` 生成绑定即可复用现成且已验证跨平台可用的 native 库。这比用 Rust 重写一套 BT 引擎（Rust 生态没有成熟的 libtorrent 绑定）风险和工作量都小得多。此结论仅作 Phase 2 排期参考，不在 Phase 1 实施范围内。

## Phase 1 技术栈选型

### 1. 状态管理 / DI —— **Riverpod**
现有 domain 层（UseCase、`Flow`-based 状态如 `EpisodeFetchSelectPlayState`）用 `AsyncNotifier`/`StreamProvider` 几乎一一对应迁移，心智成本最低。备选 Bloc（样板更多）、GetX（"魔法"过多不利于维护），均不采用。

### 2. 网络层 —— OpenAPI 生成的 Dart client
用 [openapi-generator](https://openapi-generator.tech) 的 dart-dio 模板，直接对着现有 `ani-api-server` 的 OpenAPI schema 生成 Dart client（类似现有 Kotlin `:client` 模块的生成方式），服务端接口变化时可重新生成保持同步。不手写请求/模型代码。

### 3. 本地持久化 —— **Drift**（关系型数据）+ `shared_preferences`（配置项）+ `flutter_secure_storage`（凭证）
Drift 类型安全 SQL，语义最接近现有 Room（表结构/DAO/迁移可照搬设计），支持复杂查询和响应式 Stream。备选 Isar（NoSQL）因现有数据模型关系型特征明显，不采用。UI 偏好等非敏感配置对应现有 DataStore，用 `shared_preferences`；Bangumi OAuth access/refresh token 属于敏感凭证，明文存储不合适，改用 `flutter_secure_storage`（macOS 上基于 Keychain）单独存放。

### 4. 视频播放 —— **media_kit**（基于 libmpv）
替代现有 desktop 端 VLC via mediamp。桌面 FFI 绑定成熟，支持字幕（含 ASS 特效字幕）、多音轨、硬件加速。备选官方 `video_player` 插件桌面支持较弱，不采用。手势控制层在播放器 widget 外自建 `GestureDetector`，逻辑参照现有 video-player 模块设计。

### 5. 弹幕引擎 —— 自建 `CustomPainter` + `Ticker`
无成熟 Flutter 弹幕库能满足“双源合并 + 性能”要求。弹幕轨道分配算法可直接照搬现有 Compose Canvas 层逻辑（纯算法，无 UI 框架依赖，迁移成本主要是语言转换而非重新设计）。

### 6. Bangumi OAuth（macOS 桌面）—— 本地回环 HTTP 服务器
用 `shelf` 起一个 `localhost:PORT` 临时监听，系统默认浏览器打开授权页，回调重定向到 `http://localhost:PORT/callback` 拿 code，随后关闭临时服务器。这是桌面 OAuth 的标准做法（VSCode/gh cli 同款套路），无需注册自定义 URL scheme，避免 macOS `CFBundleURLTypes` 注册和焦点处理的额外复杂度。

## 项目结构与分层

沿用现有 KMP 项目的分层理念（UI → Domain → Data → Platform），映射到 Flutter/Dart 包结构：

```
lib/
  app/            # 入口、路由(go_router)、主题、DI 组装(Riverpod ProviderScope)
  domain/         # UseCase、纯 Dart 业务逻辑，不依赖 Flutter/Riverpod
    subject/       # 番剧信息、评分
    auth/          # Bangumi OAuth 状态机
    media/         # MediaFetcher/MediaSelector 等价逻辑（源筛选/排序）
    play/          # EpisodeFetchSelectPlayState 等价的播放状态机
    danmaku/       # 弹幕合并/轨道分配算法
  data/           # Repository 实现、生成的 API client、Drift 数据库、shared_preferences 封装
  platform/       # 平台专属代码（macOS 回环 OAuth 服务器等），未来其他平台的 expect/actual 对应此层
  ui/
    foundation/    # 基础组件（对应 ui-foundation）
    exploration/   # 首页/探索（对应 ui-exploration）
    subject/       # 详情/播放页/评分（对应 ui-subject）
    danmaku/       # 弹幕渲染 widget（对应 danmaku:ui）
    player/        # 播放器控制 UI（对应 video-player）
```

**关键原则**：`domain/` 层是纯 Dart（不 import `flutter`），保证可脱离 UI 单独单元测试，也为未来若要在其他上下文复用逻辑留余地——这是照搬现有 KMP 项目 domain 层与 Compose 解耦的优点。

## 数据流 & 错误处理

- **数据流**：UI 通过 Riverpod `Provider` 订阅 `domain` 层 UseCase 暴露的 `Stream`/`AsyncValue`；UseCase 调用 `data` 层 Repository；Repository 决定网络优先还是本地缓存优先（对应现有 Repository 的缓存策略），本地用 Drift 存储持久数据，内存用 Riverpod 的 `Provider` 缓存做去抖。
- **错误处理**：网络异常/鉴权失效等错误统一用 `Result`-like 密封类型（`fpdart` 的 `Either` 或手写 sealed class）从 domain 层向上传播，UI 层用统一的 `AsyncValue.when(error: ...)` 展示；Bangumi token 过期触发统一的重新登录拦截器（dio interceptor）。

## 测试策略

- **domain 层**：纯 Dart 单元测试（`flutter_test`/`test` package），覆盖 UseCase 逻辑、弹幕轨道分配算法、Media 选择器排序逻辑——最容易出 bug 且和 UI 无关，优先覆盖。
- **data 层**：Repository 用 mock API client 做集成测试；Drift 数据库用 in-memory 模式测试迁移和查询。
- **UI 层**：Widget test 覆盖关键交互（登录流程、播放器手势），复杂端到端场景（真实登录、真实播放）留给手动验证——与仓库现有 `runAniComposeUiTest` 风格的“可复现交互式截图测试”理念一致，后续可考虑引入类似的 golden-test 机制。

## 迁移到 Flutter 的整体风险地图（供后续 Phase 参考）

| 功能域 | Flutter 方案 | 风险 | Web 可行性 |
|---|---|---|---|
| Bangumi 浏览/搜索/时间表 | dio/OpenAPI client | 低 | 可行 |
| OAuth 登录同步 | 回环服务器 / `flutter_web_auth_2` | 中（各平台配置不同） | 需不同重定向流程 |
| 在线源播放 | 直接移植 REST 调用 | 低 | 可行 |
| BT 源解析（dmhy/mikan） | html 包解析 | 中 | 基本不可行（CORS） |
| 自定义 web-selector 源 | webview_flutter/flutter_inappwebview | 中高 | 不可行 |
| 弹幕聚合渲染 | 自建 CustomPainter/Canvas | 中（工程量大，无阻塞风险） | 可行 |
| BT 离线缓存（anitorrent） | dart:ffi 绑定 C API shim | 高 | 不可行 |
| 视频播放 | media_kit(libmpv) | 中 | 仅浏览器原生 `<video>`，格式受限 |
| 本地库 | drift/sqflite + shared_preferences | 低-中 | 受浏览器沙箱存储限制 |
| 状态管理/DI | riverpod | 低 | — |

## Phase 1 验收标准

Phase 1 完成的判定标准（Definition of Done）：

- 在 macOS 上可通过系统浏览器完成 Bangumi OAuth 登录，token 落盘（`flutter_secure_storage`）且 App 重启后保持登录态。
- 可浏览番剧列表/搜索/详情并查看评分；收藏/追番进度改动能双向同步到 `ani-api-server`（本端改动同步到云端，云端改动能拉取到本端）。
- 对接至少一个在线数据源（Jellyfin/Emby/Ikaros 任一）完成搜索选源并播放一集番剧。
- 播放页支持基本手势控制（进度拖拽、音量/亮度或类似手势，具体以现有 video-player 模块手势集为准）。
- 播放过程中弹幕正常显示，合并弹弹play源与 Animeko 自建源，且能发送弹幕到自建服务并在当前会话内看到自己发送的弹幕。
- domain 层核心逻辑（登录状态机、Media 选择排序、弹幕轨道分配）有单元测试覆盖。

BT/自定义数据源等 Phase 1 排除项不作为验收依据。

## 不在本文档范围内

- Phase 2（BT/FFI）、Phase 3（自定义数据源）、Phase 4（次要功能）、Phase 5（平台扩展）、Phase 6（Web）的详细设计——均留待各自独立的 brainstorming 周期。
- 具体的 CI/CD、发布打包流程（Phase 0 范畴）。
