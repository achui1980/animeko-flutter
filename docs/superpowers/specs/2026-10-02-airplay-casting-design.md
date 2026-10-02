# AirPlay 投屏功能设计

**日期**: 2026-10-02
**状态**: 已批准，待实现

## 1. 背景与目标

播放器目前仅支持本地 macOS 窗口内播放（media_kit/libmpv）。本设计为播放器新增 AirPlay
投屏能力，让用户可以把当前播放内容投到局域网内的 AirPlay 接收设备（如 Apple TV、支持
AirPlay 的电视）上播放，并在投屏期间仍能通过 App 内的占位页控制播放/暂停/进度。

不在本设计范围内：
- 弹幕（danmaku）相关内容——与投屏无关，不涉及。
- Google Cast / DLNA 等其他投屏协议——用户已明确选择 AirPlay。

## 2. 技术前提与关键限制（研究结论）

- 本项目的视频播放引擎是 **media_kit（libmpv 封装）**，并非 macOS 原生 `AVPlayer`。
  libmpv 官方明确拒绝支持 AirPlay/Chromecast（见 `mpv-player/mpv` issue #3448、#177），
  原因包括需要 mDNS 发现、AirPlay 协议本身、HLS/MPEG2-TS 转封装、H.264 profile 转码等——
  “一个桌面播放器永远不会加这些”。因此 **media_kit 无法直接获得 AirPlay 能力**，必须
  另起一条独立的原生播放通路。
- macOS 上实现真正（非镜像）AirPlay 视频投屏的受支持方式是：原生 **`AVPlayer` +
  `AVKit` 的 `AVRoutePickerView`**（macOS 10.14+）。这是与 libmpv/media_kit 完全独立的
  第二套播放引擎。真实先例：开源 macOS 应用 Airtroska（Swift，`AVPlayer` +
  `AVRoutePickerView` + 本地 HTTP 中继服务器）、商业应用 LiquidCast，均采用同一架构。
- pub.dev 上没有可用于 macOS 的现成 AirPlay Flutter 包（`flutter_to_airplay` /
  `airplay_button` / `audio_router` 均明确只支持 iOS，macOS 上不渲染任何内容）。因此必须
  手写一个 macOS 原生 Swift 插件，通过 Flutter 平台通道桥接。
- **AirPlay 接收端在标准 URL 模式下会自己直接发起网络请求**（不经过发送端 Mac 转发），
  且**不会携带发送端自定义的 HTTP header**（接收端使用自己的 `AppleCoreMedia/...`
  User-Agent）。这意味着任何依赖自定义 Cookie/Referer 才能通过 CDN 校验的播放源，在
  AirPlay URL 模式下可能直接请求失败。

## 3. 各播放源投屏可行性评估（已逐一代码核查并与用户确认范围）

本项目当前的 `MediaPlaybackSource` 具体子类及其 `headers`/`prefersDirectConnection`：

| 源 | headers 要求 | prefersDirectConnection | 投屏结论 |
|---|---|---|---|
| XifanPlaybackSource | 无（`{}`，完全无需 header，已验证） | false | ✅ 可投屏 |
| AgedmPlaybackSource | 无（`{}`） | **true**（仅限大陆 CDN，需绕过代理） | ✅ 可投屏（AirPlay 接收端本身走局域网直连，天然满足"不走代理"要求） |
| OmofunPlaybackSource | 无（`{}`，硬编码） | **true**（同 agedm） | ✅ 可投屏 |
| YinghuaPlaybackSource | `Referer: https://www.yinghua2.com/`（代码注释标注"防御性发送，未经实测验证是否必需"） | false | ✅ 可投屏（best-effort，Referer 可能并非强制要求） |
| DilidiliPlaybackSource | `Referer: https://dilidili.io/`（同样"防御性发送，未经实测验证"） | false | ✅ 可投屏（best-effort） |
| **Anime1PlaybackSource** | **动态 `Referer` + 短期会话 Cookie（e/p/h token）**，取自播放地址解析请求（`POST https://v.anime1.me/api`）的 Set-Cookie；代码注释确认（2026-09-01 实测）**缺少此 Cookie 时 CDN 返回 403** | false | ❌ **不可投屏（确认的硬性阻塞）**——Cookie 与具体一次解析请求绑定，AirPlay 接收端自己发起的直连请求无法携带 |
| TorrentPlaybackSource（Mikan/BT） | — | — | ❌ 不可投屏（用户明确排除此类来源） |
| LocalFilePlaybackSource（已下载本地文件） | — | — | ❌ 不可投屏（见下方说明） |

### 关于已下载本地文件被排除的说明

`LocalFilePlaybackSource.url` 直接返回本地文件系统路径（如
`/Users/.../xxx.mp4`），AirPlay 接收设备作为独立物理设备无法访问该路径。此限制**并非
技术死胡同**（不同于 anime1 的 Cookie 问题）——理论上可以搭建一个局域网可达、支持
Range 请求的本地 HTTP 中继服务器（参考 Airtroska 的 `LocalHTTPServer` 实现），把文件
通过 `http://<本机局域网IP>:port/...` 提供给 AVPlayer。但这需要额外的服务器组件、端口
管理、局域网暴露的安全考量，与当前范围不成比例。

同理，NAS 场景：若 NAS 以 SMB/AFP/NFS 挂载为本地路径（`/Volumes/NAS/...`），与本地磁盘
完全相同的限制，需要同样的中继服务器方案；只有当 NAS 自带 HTTP/DLNA 服务并暴露真正的
`http://<NAS-IP>:port/...` 局域网 URL 时才能零额外开发直接投屏——但 App 当前的"下载目录"
设置只是一个通用文件系统路径选择器，默认情况下不会区分这两种情况。

**最终决定（用户确认）**：本次不实现任何本地文件中继方案，已下载本地文件（含 NAS
挂载路径场景）明确排除在投屏范围之外，与 BT/Mikan 来源归为同一类"不支持投屏"。

## 4. 架构总览

新增一个 macOS 原生 Swift 插件（独立于 media_kit），职责：

- 持有一个 `AVPlayer` 实例，专门用于投屏播放（不是本地播放引擎的替代，只在投屏时启用）
- 通过 `AVRoutePickerView`（系统原生组件，macOS 10.14+）提供设备选择 UI——这个按钮本身
  就是系统提供的"选设备"弹窗入口，不需要自己写设备发现/选择逻辑
- 通过 Flutter `PlatformView` 把 `AVRoutePickerView` 作为一个真实原生视图嵌入到播放器
  顶部工具栏（替代/叠加一个 AirPlay 图标按钮的位置）
- 通过 `MethodChannel`（Flutter → native：开始投屏/传入 url 和起始位置/本地播放/暂停/
  跳转指令）+ `EventChannel`（native → Flutter：投屏状态变化、播放位置同步、投屏失败
  事件）做双向通信

## 5. 组件职责

**Flutter 侧（新增）**：

- `CastController`（新 Riverpod provider，`lib/domain/play/cast_controller.dart`）：维护
  投屏状态机（`idle` / `casting` / `castFailed`），持有当前投屏的 `MediaPlaybackSource`，
  转发本地播放器的 play/pause/seek 指令给原生插件（投屏期间）
- `AirPlayButton` widget（嵌入 `lib/ui/player/player_top_bar.dart`）：包装原生
  `AVRoutePickerView` 的 `PlatformView`；当前源不支持投屏时整个按钮不渲染（已确认的
  隐藏规则——不是灰显，是完全不渲染）
- `PlayerScreen` 改动：投屏开始时暂停/隐藏本地 media_kit 画面，切换为"正在投屏到 XXX"
  占位页（含本地控制条：播放/暂停/进度条，这些操作转发给 native）；投屏结束/失败时
  切回本地播放，从 native 最后汇报的位置继续本地播放（避免跳位）

**Native 侧（新增，Swift，macOS-only target）**：

- `AirPlayCastEngine.swift`：封装 `AVPlayer` 生命周期、加载 URL（可选自定义 header，
  通过 `AVURLAsset` 的 `AVURLAssetHTTPHeaderFieldsKey`；注意 AirPlay URL 模式下接收端
  自己发请求，这个 header 不会被接收端带上——这正是 anime1 被排除的原因，对
  xifan/agedm/omofun/yinghua/dilidili 这些已选中的源不构成问题，因为它们要么不需要
  header，要么本身就是直连不代理）
- 监听 `AVPlayer.isExternalPlaybackActive`（route 连接/断开时自动触发）→ 通过
  EventChannel 通知 Flutter 切换 UI 状态
- 监听 native 侧播放失败事件（`AVPlayerItem.status == .failed`，覆盖 yinghua/dilidili
  的 403/hotlink 失败场景）→ 通过 EventChannel 上报失败原因

## 6. 支持的来源范围

投屏按钮对不支持的来源**整体隐藏**（已确认的交互规则），用户不会看到入口、不会点到
失效按钮。可投屏来源：xifan、agedm、omofun（完全支持）、yinghua、dilidili
（best-effort，Referer 要求未完全确认，失败时走错误处理流程）。不可投屏：anime1
（确认的硬性阻塞）、BT/Mikan、已下载本地文件（均为用户明确的范围排除）。

## 7. 状态同步与交互流程

1. 用户在播放器顶部点击 AirPlay 图标（即原生 `AVRoutePickerView`）→ 系统弹出设备列表
   → 用户选中一个 AirPlay 设备
2. 系统自动触发 `isExternalPlaybackActive = true` → native 上报 → `CastController`
   进入 `casting` 状态
3. Flutter 侧把当前 `MediaPlaybackSource.url`（和当前本地播放位置）通过 MethodChannel
   传给 native，native 用这个 URL 创建/替换 `AVPlayer` 的 item 并 seek 到对应位置、
   开始播放
4. 本地 UI 切换为"正在投屏到 XXX"占位页；本地 media_kit 播放器暂停并隐藏画面（已确认
   的交互规则）；占位页上的播放/暂停/进度条操作都转发给 native 的 AVPlayer
5. 用户点击"停止投屏"或系统端断开连接（`isExternalPlaybackActive` 变回 `false`）→
   native 上报最后播放位置 → Flutter 侧恢复本地 media_kit 播放，从该位置继续，占位页
   消失

## 8. 错误处理

- yinghua/dilidili 投屏后若 native 侧播放失败（`AVPlayerItem.status == .failed`）→
  EventChannel 上报 → Flutter 显示明确的失败提示（如"投屏失败，该来源可能不支持投屏，
  可尝试切换片源"）并自动退回本地播放
- 投屏设备在播放中途断开（网络问题等）→ 同样走 `isExternalPlaybackActive` 变化路径，
  自动退回本地播放，不留卡死状态

## 9. 测试策略

- Flutter 侧：`CastController` 的状态机转换（idle→casting→idle/failed）可用纯 Dart
  单测覆盖，mock MethodChannel/EventChannel 调用
- 来源白名单逻辑（哪些 `MediaPlaybackSource` 子类显示投屏按钮）可单测覆盖
- Native AVPlayer 封装 + 真实 AirPlay 设备行为（本机没有物理 Apple TV/AirPlay receiver
  可能无法自动化测试）→ 标记为手动测试清单项，需要用户在实机环境验证

## 10. 范围外事项（Explicitly out of scope）

- Google Cast / Chromecast、DLNA/UPnP 等其他投屏协议
- anime1 来源的投屏支持（除非未来专门为其实现本地 Cookie/Referer 注入中继服务器）
- 已下载本地文件 / NAS 挂载路径的投屏支持（除非未来专门实现本地 HTTP 中继服务器或
  NAS HTTP 端点探测逻辑）
- BT/Mikan 来源的投屏支持
- 全局默认投屏来源偏好记忆（与现有线路切换设计一致，不做跨会话偏好持久化）
