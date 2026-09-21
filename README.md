# AniMeow (animeko_flutter)

[Animeko](https://github.com/open-ani/animeko) 的 Flutter 重写版：基于 Bangumi 的追番 /
在线播放客户端。原项目为 Kotlin Multiplatform + Compose Multiplatform，本仓库是从零开始的
Flutter 实现，**当前阶段只支持 macOS 桌面端**（Android / Windows 的产物只在发布流水线中构建，
尚未作为开发目标验证）。

架构与设计取舍见 `docs/superpowers/specs/` 与 `docs/superpowers/plans/` 下的设计文档，
入口文档：`docs/superpowers/specs/2026-08-27-flutter-migration-phase1-design.md`。

## 环境要求

| 依赖 | 版本 / 说明 |
| --- | --- |
| Flutter SDK | **推荐 3.41.6**（stable，Dart SDK `^3.11.4`）——已在本仓库端到端验证 |
| Xcode + Command Line Tools | 构建 macOS Runner 必需 |
| Homebrew 依赖 | 见下方 |

> **⚠️ 多个 Flutter SDK 共存的坑**：如果机器上装了多个 Flutter SDK（例如 fvm、
> 手动装的不同版本），务必确认 `which flutter` 解析到的是同一个版本，且
> **交互式 shell 和非交互式 shell（Xcode Run Script 阶段会用非交互式 shell）
> 解析出的 `flutter` 必须一致**——否则同一次构建会混用两个 SDK 的
> `macos/Flutter/ephemeral`，报出类似
> `target 'wakelock_plus' referenced in product 'wakelock-plus' is empty` 的
> 错误。`pubspec.yaml` 里已用 `flutter: config: enable-swift-package-manager: false`
> 固定了插件集成方式（CocoaPods，不受 Flutter 版本默认值影响），但 SDK 本身
> 仍需保持统一。

### 需要额外用 Homebrew 安装的依赖

```bash
brew install cocoapods     # flutter build/run macos 解析插件 Pod 必需
brew install rqbit         # BT 播放源的下载内核（运行时依赖）
brew install create-dmg    # 仅打包 DMG 时需要（tools/build_dmg.sh）
```

- **cocoapods**：`macos/Podfile` 使用 `use_frameworks!` 管理插件，缺少 `pod` 命令时
  `flutter run -d macos` 会在 pod install 阶段失败。
- **rqbit**：`lib/data/torrent/rqbit_engine.dart` 通过 `Process.start('rqbit', ...)` 从
  `PATH` 中启动一个本地 BT 服务进程（sidecar），用于 Mikan / RSS 磁力链路的边下边播。
  没装它时应用可以正常启动，但选择 BT 播放源会失败；在线（非 BT）源不受影响。
  注意：为了能派生该子进程，macOS 端已关闭 App Sandbox。
- **create-dmg**：只有执行 `tools/build_dmg.sh` 打 DMG 时才需要，日常开发可跳过。

验证环境：

```bash
flutter doctor
flutter devices            # 应能看到 macos (darwin-arm64)
```

## 本地启动

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成 *.g.dart，首次必须执行
flutter run -d macos
```

- 真正的入口逻辑在 `lib/app/main.dart`，`lib/main.dart` 只是 `export ... show main` 的转发，
  所以默认的 `flutter run` 就能用。
- 无需任何 `--dart-define` / 环境变量，后端地址与 Bangumi OAuth 均已内置。
- 迭代过程中若持续修改 Riverpod provider、Drift 表或 `@JsonSerializable` 模型，
  另开一个终端跑 watch 模式：

  ```bash
  dart run build_runner watch --delete-conflicting-outputs
  ```

- 目标设备固定为 macOS（`-d macos`）；Web / 移动端未作为开发目标验证。

## 测试与静态检查

```bash
flutter test                                  # 全量用例
flutter test test/domain/auth/auth_controller_test.dart
flutter test --plain-name "initial state is AuthUnauthenticated"  # 按用例名跑单个测试
flutter analyze                               # 不允许出现 error
dart format lib test
```

## 打包

```bash
./scripts/build_macos.sh    # pub get + 代码生成 + flutter build macos --release
                            # 产物：build/macos/Build/Products/Release/AniMeow.app
./tools/build_dmg.sh        # 在上一步基础上打 DMG，产物：build/dmg/AniMeow.dmg
```

发布走 `.github/workflows/release.yml`：推送 `v*` tag 或手动触发 workflow_dispatch，
会构建 macOS DMG、Windows zip 和按 ABI 拆分的 Android APK 并上传到 GitHub Release。

## 安装（发布版）

前往 [Releases](../../releases) 下载对应平台的安装包。

#### macOS 安装说明（未签名应用）

本应用未经 Apple 公证，从浏览器下载后会被系统标记隔离，首次打开需手动去除：

1. 双击 DMG → 拖 `AniMeow.app` 到「应用程序」文件夹
2. **打开「终端」执行（最可靠）**：
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/AniMeow.app
   ```
3. 然后正常双击打开（若仍提示，可再尝试右键点击 app → 打开 → 确认）

> 较新 macOS（Sequoia 等）收紧了「右键打开」绕过，若直接双击提示「已损坏」或「无法验证开发者」，请务必先执行上面的终端命令。

#### 启动时弹窗要求输入「Mac 密码」是怎么回事？

打开应用时，可能会看到系统弹窗：

> **「AniMeow」想要使用你存储在钥匙串「登录」中的机密信息。请输入钥匙串「登录」的密码。**

这是 **macOS 系统级的钥匙串授权弹窗，不是应用在索要你的账号密码**：

- 应用把 Bangumi 登录态（access / refresh token）存在 macOS 钥匙串里，而不是明文配置文件里；
  启动时会在显示界面之前先读取它，用于自动恢复登录状态（见 `lib/app/main.dart` 的
  `restoreSession()` 与 `lib/data/auth/secure_token_storage.dart`）。
- 由于本应用**没有 Apple 开发者签名**（ad-hoc 签名，`CODE_SIGN_IDENTITY = "-"`），
  macOS 无法把这条钥匙串记录稳定地绑定到某个可信的签名身份上，因此每次读取都要你
  手动授权一次。签名过的正式应用不会有这个弹窗。
- 你输入的是 **Mac 登录密码（= 钥匙串「登录」的密码）**，由系统的安全框架校验；
  应用本身拿不到这个密码，也不会上传任何东西。

处理方式：

- 点击「**始终允许**」，之后一般不再提示（更新到新版本或重新构建后，签名变化可能会再问一次）。
- 不想输入也没关系：点「拒绝 / 取消」只是读不到已保存的登录态，应用会以未登录状态启动，
  重新登录 Bangumi 即可，其它功能不受影响。
- 也可以在「钥匙串访问 / 密码」里搜索 `ani_session` 查看或删除这条记录。

#### Windows 安装说明

1. 解压 zip 到任意目录
2. 双击 `AniMeow.exe` 运行

## 使用提示

- 播放页支持多个数据源切换（anime1.me / 稀饭动漫 / AGE动漫 / Mikan 等），建议**优先选择「稀饭动漫」**作为播放源，其余数据源可在稀饭动漫无法播放时作为备选。

## 目录结构

```
lib/
  app/       入口、go_router 路由与重定向、主题、依赖注入
  domain/    UseCase / controller 逻辑（Riverpod provider），纯 Dart
  data/      Repository 实现、手写的 dio API client、Drift 数据库、本地存储封装
  platform/  平台相关胶水代码（浏览器唤起、平台信息）
  ui/        页面与组件，按功能分子目录
test/        与 lib/ 一一对应
scripts/     构建脚本
tools/       打包脚本
docs/        设计文档与实现计划
```

开发约定（状态管理、代码生成、持久化、提交规范等）见 [AGENTS.md](AGENTS.md)。
