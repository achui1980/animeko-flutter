# 代理设置功能设计文档

## 背景与动机

在对 Plan 1c（anime1.me 在线播放）功能进行人工联网验证时，发现修复了两个真实的解析 bug 后（详见 `docs/superpowers/plans/2026-08-31-plan1c-online-playback.md` 之后的修复提交 `aece47d`），番剧搜索/剧集列表已能正常从 anime1.me 获取。但实际视频 CDN 主机（例如 `chihaya.v.anime1.me` 这类动态子域名）在当前网络环境下被 SNI 级别的 TLS 连接重置阻断（直连测试确认：TCP 连接成功，但 TLS ClientHello 之后立即被重置——典型的基于域名的主动阻断特征，不是证书或服务端问题）。用户环境中已有的 ambient 代理（`HTTPS_PROXY=http://127.0.0.1:2222`，一个企业/Zscaler 类型的代理）也被验证无法访问该被墙主机。

此外确认：Dart `dart:io` 的 `HttpClient`（Dio 底层使用）**不会自动读取** `HTTPS_PROXY` 等环境变量，必须显式配置 `findProxy` 回调才能生效——这意味着当前 App 在生产环境中始终是直连的。

因此需要在 App 内提供一个可配置代理地址的设置项，让用户可以指定一个自己可用的 HTTP 代理，用于访问 anime1.me 相关资源（以及可选地，主 API）。

## 范围

**v1 包含：**
- 一个简单的设置页面，可配置一个代理地址（`http://host:port` 格式）
- 代理全局生效：同时应用于 anime1 数据源的 Dio 实例和主 API 的 Dio 实例
- 使用 `shared_preferences` 持久化保存，跨重启保留
- 修改代理设置后立即生效（下一次网络请求即使用新代理），无需重启 App
- 输入校验：仅支持 `http://` scheme；格式错误时给出明确的行内错误提示
- 提供"清除代理"操作，恢复为直连

**明确不包含（推迟到未来迭代）：**
- SOCKS5 / SOCKS4 代理支持（`dart:io` 的 `HttpClient.findProxy` 原生只支持 HTTP 代理的 `'PROXY host:port'` 格式；SOCKS5 需要引入额外的 `socks5_proxy` 包并接入 `HttpClient` 的连接工厂，复杂度显著更高）——用户输入 `socks5://` 时应给出明确的"暂不支持该协议"错误提示，而不是静默失败或被错误接受
- 多代理配置 / 按域名分流代理规则
- 代理认证（用户名密码）
- 系统代理自动检测/继承

## 架构

延续 Plan 1b/1c 已建立的三层模式（`data/` / `domain/` / `ui/`），新增文件：

```
lib/data/settings/
  settings_storage.dart          # SettingsStorage：SharedPreferences 的薄封装
                                   #   Future<String?> getProxyUrl()
                                   #   Future<void> setProxyUrl(String? url)
                                   #   key = 'proxy_url'

lib/domain/settings/
  proxy_settings_controller.dart  # @riverpod class ProxySettingsController
                                   #   extends _$ProxySettingsController（bare，非 keepAlive）
                                   #   Future<String?> build() -> 从 SettingsStorage 读取初始值
                                   #   Future<void> setProxy(String url) -> 写入存储 + 更新 state
                                   #   Future<void> clearProxy() -> 写入 null + 更新 state 为 null

lib/ui/settings/
  settings_screen.dart            # SettingsScreen: ConsumerStatefulWidget
                                   #   TextField（初始值 = 当前 proxyUrl，可能为空）
                                   #   "保存" 按钮：校验格式 -> setProxy(url) 或 clearProxy()（若为空）
                                   #   "清除代理" 按钮：直接调用 clearProxy()，无需校验
                                   #   校验失败时在 TextField 下方显示行内错误文案
```

`SettingsStorage` 不引入通用的 key-value 抽象接口（延续 Plan 1c "YAGNI，直接实现具体类型" 的架构决定）——目前只有一个设置项，暂不需要抽象。

## 核心组件设计

### `SettingsStorage`

```dart
class SettingsStorage {
  SettingsStorage(this._prefs);
  final SharedPreferences _prefs;

  static const _proxyUrlKey = 'proxy_url';

  String? getProxyUrl() => _prefs.getString(_proxyUrlKey);

  Future<void> setProxyUrl(String? url) {
    if (url == null || url.isEmpty) {
      return _prefs.remove(_proxyUrlKey);
    }
    return _prefs.setString(_proxyUrlKey, url);
  }
}

@riverpod
Future<SettingsStorage> settingsStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsStorage(prefs);
}
```

`SharedPreferences.getInstance()` 是异步的，因此 `settingsStorageProvider` 是一个 `FutureProvider`（Riverpod 生成器会据此生成 `AsyncNotifier`/`FutureProvider` 而不是同步 Provider）。

### `ProxySettingsController`

```dart
@riverpod
class ProxySettingsController extends _$ProxySettingsController {
  @override
  Future<String?> build() async {
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getProxyUrl();
  }

  Future<void> setProxy(String url) async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setProxyUrl(url);
    state = AsyncData(url);
  }

  Future<void> clearProxy() async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setProxyUrl(null);
    state = const AsyncData(null);
  }
}
```

bare `@riverpod class`（不使用 `keepAlive`），与 `HomeController`/`ScheduleController`/`SubjectEpisodesController` 等既有 controller 保持同样的模式。

### 代理地址校验（纯函数，独立可测）

```dart
/// 校验用户输入的代理地址。
/// 返回 null 表示合法；返回非空字符串表示校验失败的错误提示文案。
String? validateProxyUrl(String input) {
  if (input.isEmpty) return null; // 空 = 清除代理，视为合法
  if (!input.startsWith('http://')) {
    return '暂不支持该协议（当前仅支持 http://）';
  }
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty || uri.port == 0) {
    return '地址格式不正确，请输入如 http://127.0.0.1:2222';
  }
  return null;
}
```

放在 `lib/domain/settings/proxy_settings_controller.dart` 同一文件内（作为顶层函数，不依赖 Riverpod/Flutter），方便 `SettingsScreen` 和单元测试共同引用。

### Dio 代理接入

`lib/data/api_client.dart`（`dioProvider`/`rawAniDio`）和 `lib/data/anime1/anime1_api.dart`（`anime1DioProvider`）均需要在构造 `Dio` 实例时，通过 `IOHttpClientAdapter` 设置 `findProxy` 回调：

```dart
dio.httpClientAdapter = IOHttpClientAdapter(
  createHttpClient: () {
    final client = HttpClient();
    client.findProxy = (uri) {
      final proxyUrl = ref.read(proxySettingsControllerProvider).valueOrNull;
      if (proxyUrl == null || proxyUrl.isEmpty) return 'DIRECT';
      final parsed = Uri.parse(proxyUrl);
      return 'PROXY ${parsed.host}:${parsed.port}';
    };
    return client;
  },
);
```

**关键设计点**：`findProxy` 回调内的 `ref.read(...)` 是在**每次发起网络请求时**被调用的（`HttpClient` 在每个请求发出前都会调用 `findProxy` 决定路由），而不是在 Dio 构造时被"捕获"一次性求值。因此：
- 用户修改代理设置后，**下一次网络请求**即会使用新值，无需重建 Dio 实例、无需重启 App。
- `proxySettingsControllerProvider` 的 provider 生命周期与 `dioProvider`/`anime1DioProvider` 的生命周期是解耦的——即使 Dio provider 从未被 invalidate，代理设置的变化也能生效。

## 数据流

1. App 启动 → `ProxySettingsController.build()` 异步读取 `SharedPreferences` 中保存的代理地址（若无则为 `null`）。
2. 用户点击任一 Tab（Home/Search/Schedule）AppBar 上的齿轮图标 → `context.push('/settings')` → `SettingsScreen`。
3. `SettingsScreen` 显示当前代理地址（`ref.watch(proxySettingsControllerProvider)` 的 `.value`，若仍在加载显示占位/loading 态）。
4. 用户编辑地址 → 点击"保存"：
   - 若 `validateProxyUrl(input)` 返回错误文案 → 直接在 TextField 下方显示，不调用 controller。
   - 若输入为空 → 调用 `clearProxy()`。
   - 否则 → 调用 `setProxy(input)`。
5. 用户点击"清除代理" → 直接调用 `clearProxy()`（不经过校验）。
6. 后续任何经过 `dioProvider`/`rawAniDio`/`anime1DioProvider` 发起的网络请求，在其 `findProxy` 回调触发时读取最新的 `proxySettingsControllerProvider` 值，决定是否经代理转发。

## 路由

新增一个顶层路由 `/settings`，作为 `StatefulShellRoute.indexedStack` 的同级兄弟节点（与 Plan 1c 中 `/subject/:subjectId` 的做法一致）：

```dart
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsScreen(),
),
```

该路由不受现有 `redirect:` 认证门禁逻辑影响（该逻辑只检查是否需要跳转到 `/login`，`/settings` 落入既有的 `else return null` 分支，无需修改 `redirect:` 回调本身）。

由于 `MainShell`（`lib/ui/shell/main_shell.dart`）本身没有共享的 AppBar（Home/Search/Schedule 三个 Tab 各自持有自己的 `AppBar`），齿轮图标需要分别添加到三个 Tab 各自的 AppBar 的 `actions:` 中（`lib/ui/home/home_screen.dart`、`lib/ui/search/search_screen.dart`、`lib/ui/schedule/schedule_screen.dart`），每处均为一个简单的 `IconButton(icon: Icon(Icons.settings), onPressed: () => context.push('/settings'))`。

## 错误处理

- 校验失败（协议不支持 / 格式不正确）：`validateProxyUrl` 返回的文案直接显示在 `TextField` 下方，不涉及网络请求，属于纯前端校验，无需 `ErrorRetryView`。
- `SharedPreferences` 读写理论上极少失败（本地存储，无网络依赖），本设计不为其单独设计重试/异常 UI；若 `getInstance()`/写入抛出异常，交由 `AsyncValue` 的默认 `.when(error:)` 分支处理（显示一个简单的错误文案即可，不要求专门的重试机制，因为这不是本功能的核心路径）。
- 代理配置错误导致后续网络请求失败（例如用户填了一个根本不存在或不可达的代理地址）：这属于正常的网络错误传播路径，会体现为 anime1/主 API 请求失败，进而在对应页面（详情页/播放页）触发已有的 `ErrorRetryView` 错误提示——不需要在设置页本身额外检测"代理是否真的可用"（不做连通性测试，保持 v1 简单）。

## 测试策略

- `SettingsStorage`：mock `SharedPreferences`（`shared_preferences` 包自带的 `SharedPreferences.setMockInitialValues` 或直接 mock 接口），测试 `getProxyUrl`/`setProxyUrl` 的读写行为，包括写入 `null`/空字符串时正确调用 `remove`。
- `ProxySettingsController`：mock `SettingsStorage`（mocktail），测试 `build()` 返回存储中的初始值、`setProxy`/`clearProxy` 正确调用存储层方法并更新 `state`。
- `validateProxyUrl`：纯函数单元测试，覆盖：空输入合法、`http://` 合法格式、非 `http://` scheme（含 `socks5://`）返回协议错误、格式错误（无 host/port）返回格式错误。
- `SettingsScreen`：不编写专门的 widget 测试（延续 Plan 1c 对新增 UI 页面跳过 widget 测试的既定做法，与 `HomeScreen`/`SearchScreen`/`ScheduleScreen`/`SubjectDetailScreen`/`PlayerScreen` 保持一致）。
- Dio 的 `findProxy` 回调本身不单独做集成测试（涉及真实网络/`HttpClient` 行为，超出单元测试合理范围）；正确性通过人工验证（配置一个真实可用的代理，确认 anime1.me 相关请求确实经过该代理）来确认，属于本功能上线前的手动验证项，不阻塞任务完成。

## 范围之外（后续可能迭代）

- SOCKS5/SOCKS4 代理支持
- 按域名/数据源分别配置不同代理（当前是全局单一代理）
- 代理认证（用户名/密码）
- 代理连通性测试/健康检查
- 系统代理自动检测
