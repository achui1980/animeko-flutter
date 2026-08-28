# Plan 1b 系列设计：番剧浏览/搜索/详情/评分 + 本地持久化 + 云同步

## 背景

Plan 1a（项目脚手架 + 网络层 + Bangumi OAuth 登录）已完成并验证：真实 OAuth 登录可对接生产环境 `https://api.animeko.org`，token 落盘 Keychain。本设计文档覆盖 Phase 1 设计文档中原定的 Plan 1b 范围——"番剧浏览/搜索/详情/评分 + 本地持久化 + 云同步"。

在 brainstorming 过程中确认，用户希望这部分做到**与现有 Kotlin/Compose 版 Animeko 功能对等**。经对 `ui-exploration`（首页/搜索/时间表）和 `ui-subject`（详情/评分/收藏/角色/制作人员）两个模块的详细调研，这个范围本身已经大到需要再拆分——不能是单一一个 Plan，需要按照 Phase 1 本身拆成 1a/1b/1c/1d 的思路，把 Plan 1b 继续拆成 4 个连续子计划。本文档一次性覆盖这 4 个子计划的整体设计；每个子计划仍各自走一次独立的 `writing-plans → subagent-driven-development` 实施周期。

## 子计划拆解

```
Plan 1b-1  数据基础层：网络层升级 + 模型 + Drift 持久化 + Plan 1a 遗留问题修复 + 会话恢复
Plan 1b-2  首页 + 搜索：热门轮播/继续观看/推荐、搜索(关键词+标签+季度+评分过滤)、时间表
Plan 1b-3  详情 + 评分 + 收藏：番剧详情页、自评分、收藏状态管理、"我的收藏"库页面
Plan 1b-4  云同步：本地↔云端收藏/进度双向同步
```

依赖顺序：1b-1 是其余三个的基础（无网络层/持久化，后面无法开工）；1b-2 和 1b-3 可并行设计但建议按此顺序实施（1b-3 依赖 1b-1 的收藏表结构）；1b-4 依赖 1b-1（数据基础）和 1b-3（收藏/评分的本地写入逻辑），因为同步的对象就是 1b-3 产生的本地状态变更。

## Plan 1a 遗留问题的处理（并入 Plan 1b-1）

`docs/superpowers/plans/2026-08-28-plan1a-followups.md` 中标注"在 Plan 1b 之前做"的两项，作为 Plan 1b-1 的前置任务：

- **I4**：把 `_os`/`_arch` 平台检测从 `AuthController`（domain 层）抽取到 `lib/platform/platform_info.dart`，提供 `@riverpod PlatformInfo platformInfo(Ref)`。修正 Android 架构判断（`aarch64` vs `arm64-v8a`，32 位 ARM 的 fallback 错误），并在测试中改用 `captureAny` 断言精确值，堵住"三个真实 bug 里三个都被 `any()` 掩盖"的测试覆盖漏洞。
- **I5**：`SecureTokenStorage` 从三个独立 key 改为单一 JSON blob 原子写入/读取，为本子计划新增的"会话恢复"逻辑提供一致性保证（避免读到部分写入的中间状态）。

同时处理 M3（引入 typed error：network / server / cancelled / unknown，替代裸 `e.toString()`）——因为 Plan 1b 要新增的十几个接口都需要统一错误处理，此时补上比事后重构便宜。

I1/I2/I3/M4-M10 等纯粹关于登录 UI 本身（重试按钮、超时、日志）的项，与本次范围无关，继续留在 follow-ups 文档里，不在本系列处理。

## 明确排除的功能（本系列范围之外）

调研发现"详情页"实际包含比预想更多的子功能，以下部分明确排除：

- **他人评价/评论列表**（读取别人的评分文字、点赞、举报）——与"评论区"精神一致，遵循 Phase 1 设计文档原有排除项。仅实现**自己的**评分/评论（打分本身是收藏流程的一部分，必须要有）。
- **人物/角色详情页**（照片、简介、演出作品列表、评论区）——详情页上只做角色/制作人员的**横向头像列表展示**，不支持点进去查看人物独立详情页。
- **"讨论"Tab**——现有 Kotlin 客户端里这个 Tab 本身也只是 "coming soon" 占位，未实现，不是我们的目标。
- 沿用 Phase 1 已排除项：BT/dmhy/mikan、自定义 web-selector 源、CEF WebView 取流、一起看、个性化设置深度定制、新手引导。

## 技术架构

### 网络层：手写模型 + `json_serializable`，无需 OpenAPI token

调研确认 `https://api.animeko.org/openapi.json` 需要仅维护者才有的 Bearer token，animeko 项目自己的 CI 也从不运行该 codegen task（直接构建已提交的生成代码）。因此本系列延续 Plan 1a 处理 OAuth 端点的策略：**从 `/Users/portz/js/animeko/client/src/commonMain/gen/me/him188/ani/client/` 里已提交的 Kotlin 生成代码逐字反推字段**，手写对应的 Dart 请求方法。

区别于 Plan 1a（只有 3 个端点，纯手写 `fromJson`）：这次涉及 `SubjectsAniApi`/`HomeAniApi`/`TrendsAniApi`/`ScheduleAniApi`/`CharactersAniApi`/`PersonsAniApi`/`SubjectRelationsAniApi` 等约十几个接口、二十多个模型，字段量明显更大。为降低出错风险和维护成本，**模型类用 `@JsonSerializable()` 标注 + `build_runner` 本地生成 `fromJson`/`toJson`**（`json_serializable` 包，纯本地代码生成，不依赖任何网络/token），字段定义仍手写（照抄反推的 Kotlin 字段），但序列化逻辑不再手写。

Dio 层新增：
- **鉴权拦截器**：自动附加 `Authorization: Bearer <accessToken>`（读取 Plan 1a 已有的 `SecureTokenStorage`），401 时尝试用 refresh token 调 `POST /v2/users/bangumi/loginWithRefreshToken` 刷新后重试一次，仍失败则清空会话回到登录页。
- **超时配置**：`connectTimeout`/`receiveTimeout` 补上（M3 相关，Plan 1a 遗留的裸 `Dio()` 无超时问题一并解决）。
- **Typed error 转换**：统一把 `DioException` 映射成 sealed class（`NetworkError`/`ServerError`/`AuthError`/`UnknownError`），domain 层只处理这个类型，不直接感知 Dio。

### 会话恢复（App 启动流程）

Plan 1a 明确把"重启后保持登录态"推迟到本系列。新流程：App 启动时 `SecureTokenStorage` 读取本地 token blob（I5 改造后的单一 JSON）；若有 `accessToken` 且未过期直接进入已登录态；若过期但有 `refreshToken` 则调刷新接口静默续期；都没有或刷新失败则回到 Plan 1a 的登录页。这是 `AuthController` 新增的一个 `restoreSession()` 方法，在 `app/main.dart` 启动时调用一次。

### 本地持久化（Drift）

新增表（初版，无历史数据迁移负担）：
- `subjects`：番剧基础信息缓存（id、name、nameCn、summary、tags、封面 URL、评分统计、airDate 等），作为详情页/搜索结果的本地缓存层。
- `episodes`：剧集基础信息 + 本地追番进度（`collectionType`）。
- `subject_collections`：本地收藏状态 + 自评分（`selfRating`, `comment`, `isPrivate`）+ 一个 `dirty`/`syncedAt` 字段用于标记"本地改动尚未确认同步成功"。
- `search_history`：本地搜索历史（纯本地功能，不同步云端）。

Repository 层遵循"网络优先、失败回退本地缓存"策略：详情页/搜索结果优先请求网络后写入 Drift 缓存；收藏/评分优先本地写入（乐观更新，立即反映到 UI），再异步 PATCH 到云端。

### 云同步策略

触发时机（已确认）：**App 前台启动一次 + 列表下拉刷新 + 本地收藏/评分改动后立即推送**（不设后台定时任务，保持 Phase 1 KISS）。

- **推送（本地→云端）**：`subject_collections` 表任何写入后立即触发对应的 `PATCH /v2/subjects/{id}`（携带 `collectionType`/`selfRating`）；成功后清除 `dirty` 标记；失败（网络异常/服务端拒绝）则保留 `dirty` 标记 + 向用户展示一次性提示，不做自动重试队列（超出本阶段范围，属于 M4 一类"更完善的可靠性"改进，可在后续迭代补）。
- **拉取（云端→本地）**：启动/下拉刷新时调用 `GET /v2/subjects/list`（云端收藏列表），与本地 `subject_collections` 做增量比对写入；冲突解决策略是"服务端为准"——拉取到的云端状态直接覆盖本地非 `dirty` 记录；如果本地有 `dirty` 记录且云端也有更新，本地改动优先（用户刚做的操作不能被静默覆盖），等下一次成功推送后再统一。

### 状态管理与测试策略

延续 Plan 1a 建立的模式：Riverpod `@riverpod` codegen provider/AsyncNotifier；domain 层纯 Dart 单元测试（重点覆盖收藏状态机、同步冲突解决逻辑）；data 层用 mock Dio 做 Repository 集成测试，Drift 用 in-memory 模式测试查询/迁移；UI 层 widget test 覆盖详情页评分交互、收藏状态切换等关键路径。

## 各子计划验收标准（概述，实施计划阶段会展开为逐条 Definition of Done）

- **1b-1**：`flutter test` 全绿；I4/I5 已落地并有精确断言测试；App 冷启动能自动恢复已登录会话（无需重新走 OAuth）；Drift 表结构可查询/迁移。
- **1b-2**：首页展示热门/继续观看/推荐三个区块；搜索支持关键词+至少标签过滤，结果可点击进入详情（占位跳转，1b-3 完成后才有真实详情页）。
- **1b-3**：可查看番剧详情（简介/标签/剧集列表/角色制作人员列表）；可修改收藏状态（5 种状态）；可提交自评分（10 星 + 评论 + 隐私开关）；"我的收藏"库页面按状态分类展示。
- **1b-4**：本地收藏/评分改动能在数分钟内反映到 `ani-api-server`；云端的改动（如在其他设备上做的）能在下次前台启动/下拉刷新后拉取到本地；冲突场景（本地未同步+云端同期变更）不会导致用户刚做的操作丢失。

## 不在本文档范围内

- 上文列出的明确排除功能（他人评价、人物/角色详情页、讨论 Tab）。
- Plan 1c（在线数据源播放）、Plan 1d（弹幕）——沿用 Phase 1 设计文档已有的拆解，不受本文档影响。
- Plan 1a follow-ups 中与登录 UI 本身相关、未被本文档收编的项（I1/I2/I3/M4-M10）。
