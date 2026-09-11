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
| Flutter SDK | stable 3.41+（Dart SDK `^3.11.4`） |
| Xcode + Command Line Tools | 构建 macOS Runner 必需 |
| Homebrew 依赖 | 见下方 |

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
