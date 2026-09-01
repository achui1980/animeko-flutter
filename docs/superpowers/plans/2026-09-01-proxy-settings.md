# Proxy Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user configure a global `http://` proxy (persisted across restarts) that both the main ani-api-server client and the anime1.me client route through, without needing an app restart for the change to take effect.

**Architecture:** A `SettingsStorage` (data layer, wraps `SharedPreferences`) backs a `ProxySettingsController` (domain layer, bare `@riverpod class`) that exposes the current proxy URL as `AsyncValue<String?>`. A shared `configureProxy(dio, ref)` helper wires each `Dio` instance's `HttpClient.findProxy` to re-read the controller's value on every request. A new `SettingsScreen` (reached via a gear icon in each tab's `AppBar`, pushed as a top-level route) lets the user view/edit/clear the value.

**Tech Stack:** Flutter, Riverpod 3.3.1 (`@riverpod` codegen), `shared_preferences`, `dio` (`IOHttpClientAdapter`), `go_router` 17.5.0, `mocktail` for tests.

**Design doc:** `docs/superpowers/specs/2026-09-01-proxy-settings-design.md`

---

### Task 1: Add `shared_preferences` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, in the `dependencies:` block, add a new line immediately after `media_kit_libs_video: ^1.0.7`:

```yaml
  media_kit_libs_video: ^1.0.7
  shared_preferences: ^2.5.5
```

- [ ] **Step 2: Fetch it**

Run: `flutter pub get`
Expected: completes with no errors; `pubspec.lock` is updated to include `shared_preferences` and its transitive deps (`shared_preferences_android`, `shared_preferences_foundation`, `shared_preferences_linux`, `shared_preferences_platform_interface`, `shared_preferences_web`, `shared_preferences_windows`).

- [ ] **Step 3: Sanity-check nothing broke**

Run: `flutter analyze`
Expected: same issue count/categories as before this change (no new dependency-related lint).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add shared_preferences dependency"
```

---

### Task 2: `SettingsStorage` (data layer)

**Files:**
- Create: `lib/data/settings/settings_storage.dart`
- Test: `test/data/settings/settings_storage_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/settings/settings_storage_test.dart`:

```dart
import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getProxyUrl returns null when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      expect(storage.getProxyUrl(), isNull);
    });

    test('setProxyUrl persists and getProxyUrl reads it back', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      await storage.setProxyUrl('http://127.0.0.1:2222');
      expect(storage.getProxyUrl(), 'http://127.0.0.1:2222');
    });

    test('setProxyUrl(null) clears a previously stored value', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      await storage.setProxyUrl('http://127.0.0.1:2222');
      await storage.setProxyUrl(null);
      expect(storage.getProxyUrl(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/settings/settings_storage_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/data/settings/settings_storage.dart'.`

- [ ] **Step 3: Write the implementation**

Create `lib/data/settings/settings_storage.dart`:

```dart
// lib/data/settings/settings_storage.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_storage.g.dart';

const _proxyUrlKey = 'proxy_url';

/// Thin wrapper around [SharedPreferences] for simple app settings that
/// don't need [SecureTokenStorage]'s encryption -- a proxy URL is not
/// sensitive credential material.
class SettingsStorage {
  SettingsStorage(this._prefs);
  final SharedPreferences _prefs;

  /// Returns the persisted proxy URL, or `null` if none is set (direct
  /// connection).
  String? getProxyUrl() => _prefs.getString(_proxyUrlKey);

  /// Persists [url] as the proxy URL. Passing `null` clears it (reverts to
  /// direct connection).
  Future<void> setProxyUrl(String? url) async {
    if (url == null) {
      await _prefs.remove(_proxyUrlKey);
    } else {
      await _prefs.setString(_proxyUrlKey, url);
    }
  }
}

@riverpod
Future<SettingsStorage> settingsStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsStorage(prefs);
}
```

- [ ] **Step 4: Generate the provider code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/data/settings/settings_storage.g.dart` is created with no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/settings/settings_storage_test.dart`
Expected: PASS — 3/3 tests pass.

- [ ] **Step 6: Run full suite and analyze**

Run: `flutter test`
Expected: all tests pass (previous baseline plus these 3 new ones), 0 failures.

Run: `flutter analyze`
Expected: same 3 pre-existing lint categories as before this task, no new category.

- [ ] **Step 7: Commit**

```bash
git add lib/data/settings/settings_storage.dart lib/data/settings/settings_storage.g.dart test/data/settings/settings_storage_test.dart
git commit -m "feat: add SettingsStorage backed by shared_preferences"
```

---

### Task 3: `validateProxyUrl` + `ProxySettingsController` (domain layer)

**Files:**
- Create: `lib/domain/settings/proxy_settings_controller.dart`
- Test: `test/domain/settings/proxy_settings_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/settings/proxy_settings_controller_test.dart`:

```dart
import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('validateProxyUrl', () {
    test('accepts an empty string (means clear)', () {
      expect(validateProxyUrl(''), isNull);
    });

    test('accepts a valid http:// URL', () {
      expect(validateProxyUrl('http://127.0.0.1:2222'), isNull);
    });

    test('rejects a socks5:// URL', () {
      expect(
        validateProxyUrl('socks5://127.0.0.1:1080'),
        '暂不支持该协议（当前仅支持 http://）',
      );
    });

    test('rejects a URL with no scheme', () {
      expect(
        validateProxyUrl('127.0.0.1:2222'),
        '暂不支持该协议（当前仅支持 http://）',
      );
    });

    test('rejects a malformed http:// URL with no port', () {
      expect(
        validateProxyUrl('http://127.0.0.1'),
        '地址格式不正确，请输入如 http://127.0.0.1:2222',
      );
    });
  });

  group('ProxySettingsController', () {
    late MockSettingsStorage storage;
    late ProviderContainer container;

    setUp(() {
      storage = MockSettingsStorage();
      container = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWith((ref) async => storage)],
      );
      addTearDown(container.dispose);
    });

    test('build reads the persisted proxy URL', () async {
      when(() => storage.getProxyUrl()).thenReturn('http://127.0.0.1:2222');
      final result = await container.read(proxySettingsControllerProvider.future);
      expect(result, 'http://127.0.0.1:2222');
    });

    test('build returns null when nothing is persisted', () async {
      when(() => storage.getProxyUrl()).thenReturn(null);
      final result = await container.read(proxySettingsControllerProvider.future);
      expect(result, isNull);
    });

    test('setProxy persists and updates state', () async {
      when(() => storage.getProxyUrl()).thenReturn(null);
      when(() => storage.setProxyUrl(any())).thenAnswer((_) async {});
      await container.read(proxySettingsControllerProvider.future);

      await container
          .read(proxySettingsControllerProvider.notifier)
          .setProxy('http://127.0.0.1:2222');

      verify(() => storage.setProxyUrl('http://127.0.0.1:2222')).called(1);
      expect(
        container.read(proxySettingsControllerProvider).value,
        'http://127.0.0.1:2222',
      );
    });

    test(
      'setProxy throws FormatException for an invalid URL without touching storage',
      () async {
        when(() => storage.getProxyUrl()).thenReturn(null);
        await container.read(proxySettingsControllerProvider.future);

        await expectLater(
          () => container
              .read(proxySettingsControllerProvider.notifier)
              .setProxy('socks5://x:1'),
          throwsA(isA<FormatException>()),
        );
        verifyNever(() => storage.setProxyUrl(any()));
      },
    );

    test('clearProxy persists null and updates state', () async {
      when(() => storage.getProxyUrl()).thenReturn('http://127.0.0.1:2222');
      when(() => storage.setProxyUrl(any())).thenAnswer((_) async {});
      await container.read(proxySettingsControllerProvider.future);

      await container.read(proxySettingsControllerProvider.notifier).clearProxy();

      verify(() => storage.setProxyUrl(null)).called(1);
      expect(container.read(proxySettingsControllerProvider).value, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/settings/proxy_settings_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart'.`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/settings/proxy_settings_controller.dart`:

```dart
// lib/domain/settings/proxy_settings_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/settings/settings_storage.dart';

part 'proxy_settings_controller.g.dart';

/// Validates a user-entered proxy URL. Returns `null` if [input] is valid,
/// or a user-facing error message otherwise.
///
/// v1 only supports `http://` proxies -- see the design doc's "范围" section
/// for why SOCKS5 is explicitly deferred. An empty/whitespace-only [input]
/// is treated as valid (it means "clear the proxy"); callers that need to
/// distinguish "empty" from "set" must check that themselves.
String? validateProxyUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.startsWith('http://')) {
    return '暂不支持该协议（当前仅支持 http://）';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty || uri.port == 0) {
    return '地址格式不正确，请输入如 http://127.0.0.1:2222';
  }

  return null;
}

@riverpod
class ProxySettingsController extends _$ProxySettingsController {
  @override
  Future<String?> build() async {
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getProxyUrl();
  }

  /// Validates and persists [url]. Throws [FormatException] with the
  /// validation message if [url] fails [validateProxyUrl] -- the settings
  /// screen should call [validateProxyUrl] itself first to show an inline
  /// error instead of relying on this throwing.
  Future<void> setProxy(String url) async {
    final error = validateProxyUrl(url);
    if (error != null) throw FormatException(error);

    final trimmed = url.trim();
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setProxyUrl(trimmed);
    state = AsyncData(trimmed);
  }

  /// Clears the proxy (reverts to a direct connection).
  Future<void> clearProxy() async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setProxyUrl(null);
    state = const AsyncData(null);
  }
}
```

- [ ] **Step 4: Generate the provider code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/domain/settings/proxy_settings_controller.g.dart` is created with no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/domain/settings/proxy_settings_controller_test.dart`
Expected: PASS — 10/10 tests pass (5 `validateProxyUrl` + 5 `ProxySettingsController`).

- [ ] **Step 6: Run full suite and analyze**

Run: `flutter test`
Expected: all tests pass, 0 failures.

Run: `flutter analyze`
Expected: same 3 pre-existing lint categories, no new category (a new `depend_on_referenced_packages` *instance* for this test file's direct `package:riverpod/riverpod.dart` import is expected and fine — it matches the pattern already present in every other controller test file in this repo, e.g. `test/domain/schedule/schedule_controller_test.dart`).

- [ ] **Step 7: Commit**

```bash
git add lib/domain/settings/proxy_settings_controller.dart lib/domain/settings/proxy_settings_controller.g.dart test/domain/settings/proxy_settings_controller_test.dart
git commit -m "feat: add validateProxyUrl and ProxySettingsController"
```

---

### Task 4: `configureProxy` / `decideProxy` (shared Dio proxy wiring helper)

**Files:**
- Create: `lib/data/settings/proxy_dio_config.dart`
- Test: `test/data/settings/proxy_dio_config_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/settings/proxy_dio_config_test.dart`:

```dart
import 'package:animeko_flutter/data/settings/proxy_dio_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decideProxy', () {
    test('returns DIRECT when proxyUrl is null', () {
      expect(decideProxy(null), 'DIRECT');
    });

    test('returns DIRECT when proxyUrl is empty', () {
      expect(decideProxy(''), 'DIRECT');
    });

    test('returns a PROXY directive for a valid http:// URL', () {
      expect(decideProxy('http://127.0.0.1:2222'), 'PROXY 127.0.0.1:2222');
    });

    test('returns DIRECT for a malformed proxyUrl', () {
      expect(decideProxy('not a url'), 'DIRECT');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/settings/proxy_dio_config_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/data/settings/proxy_dio_config.dart'.`

- [ ] **Step 3: Write the implementation**

Create `lib/data/settings/proxy_dio_config.dart`:

```dart
// lib/data/settings/proxy_dio_config.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/settings/proxy_settings_controller.dart';

/// Pure decision function for [HttpClient.findProxy]. Kept separate from
/// [configureProxy] so it can be unit-tested without a real [HttpClient] --
/// see the design doc's "测试策略" section.
///
/// Returns `'DIRECT'` when [proxyUrl] is null, empty, or malformed (falling
/// back to a direct connection rather than throwing), or a `'PROXY
/// host:port'` directive for a well-formed URL.
String decideProxy(String? proxyUrl) {
  if (proxyUrl == null || proxyUrl.isEmpty) return 'DIRECT';

  final proxyUri = Uri.tryParse(proxyUrl);
  if (proxyUri == null || proxyUri.host.isEmpty || proxyUri.port == 0) {
    return 'DIRECT';
  }
  return 'PROXY ${proxyUri.host}:${proxyUri.port}';
}

/// Configures [dio]'s underlying [HttpClient] to route through whatever
/// proxy is currently set in [ProxySettingsController], if any. Call this
/// once per [Dio] instance during provider construction -- the installed
/// `findProxy` closure re-reads [proxySettingsControllerProvider] on every
/// request, so changing the setting takes effect on the very next request
/// with no need to rebuild the [Dio] instance or restart the app.
void configureProxy(Dio dio, Ref ref) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) =>
          decideProxy(ref.read(proxySettingsControllerProvider).valueOrNull);
      return client;
    },
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/settings/proxy_dio_config_test.dart`
Expected: PASS — 4/4 tests pass.

- [ ] **Step 5: Run full suite and analyze**

Run: `flutter test`
Expected: all tests pass, 0 failures.

Run: `flutter analyze`
Expected: same 3 pre-existing lint categories, no new category.

- [ ] **Step 6: Commit**

```bash
git add lib/data/settings/proxy_dio_config.dart test/data/settings/proxy_dio_config_test.dart
git commit -m "feat: add decideProxy/configureProxy Dio proxy wiring helper"
```

---

### Task 5: Wire `configureProxy` into the main API's `dio()` provider

**Files:**
- Modify: `lib/data/api_client.dart`

- [ ] **Step 1: Add the import and call `configureProxy`**

In `lib/data/api_client.dart`, add this import after the existing `import 'auth_interceptor.dart';` line:

```dart
import 'settings/proxy_dio_config.dart';
```

Then change the `dio()` provider from:

```dart
@riverpod
Dio dio(Ref ref) {
  final dio = rawAniDio();
  final storage = ref.watch(secureTokenStorageProvider);
```

to:

```dart
@riverpod
Dio dio(Ref ref) {
  final dio = rawAniDio();
  configureProxy(dio, ref);
  final storage = ref.watch(secureTokenStorageProvider);
```

Leave the rest of the function (the `AuthInterceptor` wiring and `return dio;`) unchanged.

- [ ] **Step 2: Run the full suite**

Run: `flutter test`
Expected: all tests pass, 0 failures (this is a wiring-only change with no new logic, so no new test is added for it — `configureProxy` itself was already unit-tested indirectly via `decideProxy` in Task 4, and the design doc's testing strategy explicitly excludes the `findProxy` closure itself from unit testing, deferring to manual verification with a real proxy).

Run: `flutter analyze`
Expected: same 3 pre-existing lint categories, no new category.

- [ ] **Step 3: Commit**

```bash
git add lib/data/api_client.dart
git commit -m "feat: route the main API Dio client through the configured proxy"
```

---

### Task 6: Wire `configureProxy` into `anime1DioProvider`

**Files:**
- Modify: `lib/data/anime1/anime1_api.dart`

- [ ] **Step 1: Add the import and call `configureProxy`**

In `lib/data/anime1/anime1_api.dart`, add this import after the existing `import 'anime1_models.dart';` line:

```dart
import '../settings/proxy_dio_config.dart';
```

Then change the `anime1Dio()` provider from:

```dart
@riverpod
Dio anime1Dio(Ref ref) {
  // anime1.me's only anti-hotlinking check is the Referer header -- see
  // the design doc's "背景与范围" section. No auth, no other headers
  // needed.
  return Dio(BaseOptions(headers: {'Referer': 'https://anime1.me'}));
}
```

to:

```dart
@riverpod
Dio anime1Dio(Ref ref) {
  // anime1.me's only anti-hotlinking check is the Referer header -- see
  // the design doc's "背景与范围" section. No auth, no other headers
  // needed.
  final dio = Dio(BaseOptions(headers: {'Referer': 'https://anime1.me'}));
  configureProxy(dio, ref);
  return dio;
}
```

- [ ] **Step 2: Run the full suite**

Run: `flutter test`
Expected: all tests pass, 0 failures.

Run: `flutter analyze`
Expected: same 3 pre-existing lint categories, no new category.

- [ ] **Step 3: Commit**

```bash
git add lib/data/anime1/anime1_api.dart
git commit -m "feat: route the anime1.me Dio client through the configured proxy"
```

---

### Task 7: `SettingsScreen` UI

**Files:**
- Create: `lib/ui/settings/settings_screen.dart`

No test for this file, consistent with the design doc's stated testing strategy (widget tests are explicitly skipped for `SettingsScreen`, matching the established precedent for `HomeScreen`/`SearchScreen`/`ScheduleScreen`/`SubjectDetailScreen`/`PlayerScreen`).

- [ ] **Step 1: Write the implementation**

Create `lib/ui/settings/settings_screen.dart`:

```dart
// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/settings/proxy_settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _initialized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final input = _controller.text;
    final error = validateProxyUrl(input);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      await ref.read(proxySettingsControllerProvider.notifier).clearProxy();
    } else {
      await ref.read(proxySettingsControllerProvider.notifier).setProxy(trimmed);
    }
    setState(() => _errorText = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  Future<void> _clear() async {
    _controller.clear();
    await ref.read(proxySettingsControllerProvider.notifier).clearProxy();
    setState(() => _errorText = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除代理')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final proxy = ref.watch(proxySettingsControllerProvider);

    proxy.whenData((value) {
      if (!_initialized) {
        _initialized = true;
        _controller.text = value ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: proxy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载设置失败：$error')),
        data: (value) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('代理地址（例如 http://127.0.0.1:2222，留空表示直连）'),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:2222',
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(onPressed: _save, child: const Text('保存')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _clear, child: const Text('清除代理')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run the full suite and analyze**

Run: `flutter test`
Expected: all tests pass, 0 failures (no new tests added in this task).

Run: `flutter analyze`
Expected: same 3 pre-existing lint categories, no new category.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/settings/settings_screen.dart
git commit -m "feat: add SettingsScreen for configuring the proxy"
```

---

### Task 8: Router wiring, gear icons, and final verification

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/ui/home/home_screen.dart`
- Modify: `lib/ui/search/search_screen.dart`
- Modify: `lib/ui/schedule/schedule_screen.dart`

- [ ] **Step 1: Add the `/settings` route**

In `lib/app/router.dart`, add this import after `import '../ui/search/search_screen.dart';`:

```dart
import '../ui/settings/settings_screen.dart';
```

Then add a new top-level `GoRoute` as a sibling of the existing `/subject/:subjectId/play` route, before `StatefulShellRoute.indexedStack(...)`:

```dart
      GoRoute(
        path: '/subject/:subjectId/play',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          return PlayerScreen(episodePageUrl: url);
        },
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      StatefulShellRoute.indexedStack(
```

- [ ] **Step 2: Add the gear icon to `HomeScreen`**

In `lib/ui/home/home_screen.dart`, add this import after `import 'package:flutter_riverpod/flutter_riverpod.dart';`:

```dart
import 'package:go_router/go_router.dart';
```

Then change:

```dart
      appBar: AppBar(title: const Text('Animeko')),
```

to:

```dart
      appBar: AppBar(
        title: const Text('Animeko'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
```

- [ ] **Step 3: Add the gear icon to `SearchScreen`**

In `lib/ui/search/search_screen.dart`, add this import after `import 'package:flutter_riverpod/flutter_riverpod.dart';`:

```dart
import 'package:go_router/go_router.dart';
```

Then change:

```dart
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Search subjects...'),
          onChanged: (value) => ref
              .read(searchControllerProvider.notifier)
              .search(keywords: value),
        ),
      ),
```

to:

```dart
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Search subjects...'),
          onChanged: (value) => ref
              .read(searchControllerProvider.notifier)
              .search(keywords: value),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
```

- [ ] **Step 4: Add the gear icon to `ScheduleScreen`**

In `lib/ui/schedule/schedule_screen.dart`, add this import after `import 'package:flutter_riverpod/flutter_riverpod.dart';`:

```dart
import 'package:go_router/go_router.dart';
```

Then change:

```dart
      appBar: AppBar(title: const Text('Schedule')),
```

to:

```dart
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
```

- [ ] **Step 5: Regenerate provider code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with no errors. `lib/app/router.g.dart`'s content hash changes (its body's source text changed), but no other generated file is affected.

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: all tests pass, 0 failures (this task adds no new test files -- `router_test.dart`'s existing coverage of the auth-redirect flow is unaffected since `/settings` is not `/login` and the `redirect:` callback's logic is untouched).

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: same 3 pre-existing lint categories as the very start of this plan, zero new categories.

- [ ] **Step 8: Build**

Run: `flutter build macos --debug`
Expected: `✓ Built build/macos/Build/Products/Debug/animeko_flutter.app` with no errors (only pre-existing, benign CocoaPods/Swift-interop warnings, if any).

- [ ] **Step 9: Commit**

```bash
git add lib/app/router.dart lib/app/router.g.dart lib/ui/home/home_screen.dart lib/ui/search/search_screen.dart lib/ui/schedule/schedule_screen.dart
git commit -m "feat: wire /settings route and add gear icon to Home/Search/Schedule"
```

---

## Definition of Done

- `flutter test` — all tests pass (zero failures).
- `flutter analyze` — same 3 lint categories as before this plan started (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`); zero new categories. Individual-count growth within these existing categories (e.g. one more `depend_on_referenced_packages` hit per new test file that directly imports `riverpod`) is expected and fine.
- `flutter build macos --debug` succeeds.
- All 8 task commits are present in `git log` on `main`.
- **Manual verification (not automated, tracked as a follow-up, does not block completion):** with a real working `http://` proxy address entered in Settings, both the main API traffic and anime1.me traffic (in particular the video-CDN host that is known to be network-blocked without a proxy) succeed. The user's existing ambient corporate/Zscaler-style proxy is already known (from prior live testing) to be unable to reach the blocked CDN host -- a *different*, actually-working proxy/VPN endpoint is needed for this manual check to succeed.
