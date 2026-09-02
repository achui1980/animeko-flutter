# Plan 1e — Phase B: Account Page + Settings Redesign + Theme Wiring

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the user a real account page (profile + sign-out, using the already-implemented but UI-less `AuthController.signOut()`) and a redesigned, grouped-list settings page that actually lets the user switch dark/light/system theme — which also means wiring Phase A's `AppTheme`/`ThemeModeController` into `MaterialApp.router` in `main.dart` for the first time (Phase A deliberately left this unwired; see the design doc's "架构 §1" note that `main.dart` consumes `themeModeControllerProvider`, and the design doc's phase table §156 assigning "设置页重做" to this phase — a theme switch with no visible effect would ship a broken control).

**Architecture:** Three small additions plus two screen changes, all following existing patterns 1:1:

1. **Data layer** (`lib/data/user/`): `SelfUser` model (`@JsonSerializable()`, same style as `SubjectDetail` in `subject_models.dart`) + `UserApi` (`GET /v1/me`, same class shape as `SubjectApi` in `subject_api.dart`, built on the shared `dioProvider`).
2. **Domain layer** (`lib/domain/user/`): `selfUserProvider` — a bare `@riverpod Future<SelfUser> selfUser(Ref ref)` function provider (no Notifier needed; the account screen is the only consumer, no mutations).
3. **Theme wiring** (`lib/app/main.dart`): `AnimekoFlutterApp` (already a `ConsumerWidget`) starts watching `themeModeControllerProvider` and passes `theme`/`darkTheme`/`themeMode` to `MaterialApp.router`.
4. **Settings split**: the existing `SettingsScreen` (currently *only* a proxy form) is split into a new `ProxySettingsScreen` (the old body, verbatim, at a new route `/settings/proxy`) and a rewritten `SettingsScreen` (grouped list: 通用/网络/账户 groups, per the design doc's "页面级改动" table).
5. **New `AccountScreen`** (`lib/ui/account/account_screen.dart`): avatar + nickname (from `selfUserProvider`) + a "退出登录" list item that confirms via dialog before calling `AuthController.signOut()` — the router's existing `redirect:` logic already sends a signed-out user back to `/login` automatically, so no explicit navigation is needed after sign-out.
6. **Router**: two new `GoRoute`s, `/account` and `/settings/proxy`, in `lib/app/router.dart` (the `/account` navigation target already exists as a button in `buildStandardActions()` from Phase A — it just 404s today).

**Tech Stack:** `dio: ^5.11.0`, `json_annotation: ^4.11.0` / `json_serializable: ^6.13.0` (codegen, same as `subject_models.dart`), `flutter_riverpod: 3.3.1` / `riverpod_annotation: 4.0.2` / `riverpod_generator: 4.0.3`, `go_router: ^17.5.0`, `mocktail: ^1.0.5`.

**Design doc:** `docs/superpowers/specs/2026-09-02-plan1e-ui-redesign-design.md` (see "架构 §1" for the theme-wiring line, "页面级改动" table for the settings/account page specs, "数据与 API 变更" for the confirmed real `GET /v1/me` shape).

**Global constraint carried over from the design doc:** `GET /v1/me` requires `auth-jwt` auth, already carried automatically by the shared `dioProvider`'s `AuthInterceptor` — `UserApi` must not create its own `Dio` instance.

---

### Task 1: `SelfUser` model

**Files:**
- Create: `lib/data/user/user_models.dart`
- Create: `test/data/user/user_models_test.dart`

- [ ] **Step 1: Write the failing test.**
  ```bash
  mkdir -p lib/data/user test/data/user
  ```
  `test/data/user/user_models_test.dart`:
  ```dart
  import 'package:animeko_flutter/data/user/user_models.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    group('SelfUser', () {
      test('fromJson parses all required and optional fields', () {
        final json = {
          'id': 'u1',
          'nickname': 'Alice',
          'hasPassword': true,
          'isBangumiSessionValid': true,
          'email': 'a@example.com',
          'smallAvatar': 'https://example.com/s.png',
          'mediumAvatar': 'https://example.com/m.png',
          'largeAvatar': 'https://example.com/l.png',
          'registerTime': 1700000000000,
          'lastLoginTime': 1700000001000,
          'clientVersion': '1.0.0',
          'bangumiUsername': 'alice_bgm',
        };

        final user = SelfUser.fromJson(json);

        expect(user.id, 'u1');
        expect(user.nickname, 'Alice');
        expect(user.hasPassword, true);
        expect(user.isBangumiSessionValid, true);
        expect(user.mediumAvatar, 'https://example.com/m.png');
        expect(user.bangumiUsername, 'alice_bgm');
      });

      test('fromJson tolerates missing optional fields', () {
        final json = {
          'id': 'u2',
          'nickname': 'Bob',
          'hasPassword': false,
          'isBangumiSessionValid': false,
        };

        final user = SelfUser.fromJson(json);

        expect(user.id, 'u2');
        expect(user.email, isNull);
        expect(user.mediumAvatar, isNull);
      });
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/data/user/user_models_test.dart` — expect `Target of URI doesn't exist: 'package:animeko_flutter/data/user/user_models.dart'.`

- [ ] **Step 3: Implement.**
  `lib/data/user/user_models.dart`:
  ```dart
  // lib/data/user/user_models.dart
  import 'package:json_annotation/json_annotation.dart';

  part 'user_models.g.dart';

  /// The current user's own profile. Verified against the real
  /// `AniAniSelfUser` model (Kotlin generated client
  /// `models/AniAniSelfUser.kt`) -- see the design doc's "数据与 API
  /// 变更" section. Returned by `GET /v1/me`.
  @JsonSerializable()
  class SelfUser {
    const SelfUser({
      required this.id,
      required this.nickname,
      required this.hasPassword,
      required this.isBangumiSessionValid,
      this.email,
      this.smallAvatar,
      this.mediumAvatar,
      this.largeAvatar,
      this.registerTime,
      this.lastLoginTime,
      this.clientVersion,
      this.bangumiUsername,
    });

    final String id;
    final String nickname;
    final bool hasPassword;
    final bool isBangumiSessionValid;
    final String? email;
    final String? smallAvatar;
    final String? mediumAvatar;
    final String? largeAvatar;
    final int? registerTime;
    final int? lastLoginTime;
    final String? clientVersion;
    final String? bangumiUsername;

    factory SelfUser.fromJson(Map<String, dynamic> json) => _$SelfUserFromJson(json);

    Map<String, dynamic> toJson() => _$SelfUserToJson(this);
  }
  ```

- [ ] **Step 4: Generate codegen.** `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Run test, confirm pass.** `flutter test test/data/user/user_models_test.dart` — expect 2/2 to pass.

- [ ] **Step 6: Full regression check.** `flutter test` + `flutter analyze` (baseline unchanged — this file has no riverpod import, so no new `depend_on_referenced_packages` count).

- [ ] **Step 7: Commit.**
  ```
  git add lib/data/user/user_models.dart lib/data/user/user_models.g.dart test/data/user/user_models_test.dart
  git commit -m "feat(user): add SelfUser model"
  ```

---

### Task 2: `UserApi`

**Files:**
- Create: `lib/data/user/user_api.dart`
- Create: `test/data/user/user_api_test.dart`

- [ ] **Step 1: Write the failing test.**
  `test/data/user/user_api_test.dart`:
  ```dart
  import 'package:animeko_flutter/data/user/user_api.dart';
  import 'package:dio/dio.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';

  class MockDio extends Mock implements Dio {}

  Response<Map<String, dynamic>> jsonResponse(
    Map<String, dynamic> body, {
    String path = '/',
  }) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  void main() {
    late MockDio dio;
    late UserApi api;

    setUp(() {
      dio = MockDio();
      api = UserApi(dio);
    });

    group('getSelf', () {
      final selfJson = {
        'id': 'u1',
        'nickname': 'Alice',
        'hasPassword': true,
        'isBangumiSessionValid': true,
        'mediumAvatar': 'https://example.com/m.png',
      };

      test('GETs /v1/me', () async {
        when(() => dio.get<Map<String, dynamic>>(any()))
            .thenAnswer((_) async => jsonResponse(selfJson));

        await api.getSelf();

        verify(() => dio.get<Map<String, dynamic>>('/v1/me')).called(1);
      });

      test('parses the response into a SelfUser', () async {
        when(() => dio.get<Map<String, dynamic>>(any()))
            .thenAnswer((_) async => jsonResponse(selfJson));

        final user = await api.getSelf();

        expect(user.id, 'u1');
        expect(user.nickname, 'Alice');
        expect(user.mediumAvatar, 'https://example.com/m.png');
      });
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/data/user/user_api_test.dart` — expect `Target of URI doesn't exist: 'package:animeko_flutter/data/user/user_api.dart'.`

- [ ] **Step 3: Implement.**
  `lib/data/user/user_api.dart`:
  ```dart
  // lib/data/user/user_api.dart
  import 'package:dio/dio.dart';
  import 'package:riverpod_annotation/riverpod_annotation.dart';

  import '../api_client.dart';
  import 'user_models.dart';

  part 'user_api.g.dart';

  /// Direct calls against the real `https://api.animeko.org` server (via
  /// the shared [dioProvider], which already carries the Plan-1b-1
  /// `AuthInterceptor`) -- same style as `SubjectApi`.
  class UserApi {
    UserApi(this._dio);
    final Dio _dio;

    /// GET /v1/me -- the current user's own profile. Requires auth-jwt
    /// authentication.
    Future<SelfUser> getSelf() async {
      final response = await _dio.get<Map<String, dynamic>>('/v1/me');
      return SelfUser.fromJson(response.data!);
    }
  }

  @riverpod
  UserApi userApi(Ref ref) => UserApi(ref.watch(dioProvider));
  ```

- [ ] **Step 4: Generate codegen.** `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Run test, confirm pass.** `flutter test test/data/user/user_api_test.dart` — expect 2/2 to pass.

- [ ] **Step 6: Full regression check.** `flutter test` + `flutter analyze` (expect +1 `depend_on_referenced_packages` from this new riverpod-importing test file — same known category, not a regression).

- [ ] **Step 7: Commit.**
  ```
  git add lib/data/user/user_api.dart lib/data/user/user_api.g.dart test/data/user/user_api_test.dart
  git commit -m "feat(user): add UserApi.getSelf()"
  ```

---

### Task 3: `selfUserProvider`

**Files:**
- Create: `lib/domain/user/self_user_controller.dart`
- Create: `test/domain/user/self_user_controller_test.dart`

- [ ] **Step 1: Write the failing test.**
  ```bash
  mkdir -p lib/domain/user test/domain/user
  ```
  `test/domain/user/self_user_controller_test.dart`:
  ```dart
  import 'package:animeko_flutter/data/user/user_api.dart';
  import 'package:animeko_flutter/data/user/user_models.dart';
  import 'package:animeko_flutter/domain/user/self_user_controller.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';
  import 'package:riverpod/riverpod.dart';

  class MockUserApi extends Mock implements UserApi {}

  const _user = SelfUser(
    id: 'u1',
    nickname: 'Alice',
    hasPassword: true,
    isBangumiSessionValid: true,
  );

  void main() {
    late MockUserApi api;
    late ProviderContainer container;

    setUp(() {
      api = MockUserApi();
      container = ProviderContainer(overrides: [userApiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);
    });

    test('reads the self profile from UserApi', () async {
      when(() => api.getSelf()).thenAnswer((_) async => _user);

      final result = await container.read(selfUserProvider.future);

      expect(result.id, 'u1');
      expect(result.nickname, 'Alice');
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/domain/user/self_user_controller_test.dart` — expect `Target of URI doesn't exist: 'package:animeko_flutter/domain/user/self_user_controller.dart'.`

- [ ] **Step 3: Implement.**
  `lib/domain/user/self_user_controller.dart`:
  ```dart
  // lib/domain/user/self_user_controller.dart
  import 'package:riverpod_annotation/riverpod_annotation.dart';

  import '../../data/user/user_api.dart';
  import '../../data/user/user_models.dart';

  part 'self_user_controller.g.dart';

  /// The current user's own profile. The account screen is the only
  /// consumer -- no caching/refresh policy beyond Riverpod's default is
  /// needed.
  @riverpod
  Future<SelfUser> selfUser(Ref ref) async {
    final api = ref.watch(userApiProvider);
    return api.getSelf();
  }
  ```

- [ ] **Step 4: Generate codegen.** `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Run test, confirm pass.** `flutter test test/domain/user/self_user_controller_test.dart` — expect 1/1 to pass.

- [ ] **Step 6: Full regression check.** `flutter test` + `flutter analyze` (expect +1 `depend_on_referenced_packages`, same known category).

- [ ] **Step 7: Commit.**
  ```
  git add lib/domain/user/self_user_controller.dart lib/domain/user/self_user_controller.g.dart test/domain/user/self_user_controller_test.dart
  git commit -m "feat(user): add selfUserProvider"
  ```

---

### Task 4: Wire `AppTheme`/`ThemeModeController` into `main.dart`

**Files:**
- Modify: `lib/app/main.dart`
- Create: `test/app/main_test.dart`

- [ ] **Step 1: Write the failing test.**
  `test/app/main_test.dart`:
  ```dart
  import 'package:animeko_flutter/app/main.dart';
  import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';

  class _FakeThemeModeController extends ThemeModeController {
    @override
    Future<ThemeMode> build() async => ThemeMode.dark;
  }

  void main() {
    testWidgets('applies AppTheme.light()/dark() and the persisted ThemeMode', (tester) async {
      final container = ProviderContainer(
        overrides: [
          themeModeControllerProvider.overrideWith(() => _FakeThemeModeController()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const AnimekoFlutterApp()),
      );
      await tester.pump();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
      expect(app.themeMode, ThemeMode.dark);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/app/main_test.dart` — expect the assertion on `app.themeMode` to fail (`ThemeMode.system` default, not `ThemeMode.dark`), since `main.dart` doesn't read `themeModeControllerProvider` yet.

- [ ] **Step 3: Implement.**
  In `lib/app/main.dart`, add imports and update `AnimekoFlutterApp.build`:
  ```dart
  import '../domain/settings/theme_mode_controller.dart';
  import 'theme/app_theme.dart';
  ```
  ```dart
  class AnimekoFlutterApp extends ConsumerWidget {
    const AnimekoFlutterApp({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final router = ref.watch(appRouterProvider);
      final themeMode = ref.watch(themeModeControllerProvider).valueOrNull ?? ThemeMode.system;
      return MaterialApp.router(
        title: 'Animeko',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
      );
    }
  }
  ```
  (`main()` itself is unchanged.)

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/app/main_test.dart` — expect 1/1 to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (expect +1 `depend_on_referenced_packages` for the new test file; no change to `main.dart`'s own analyze status since it already imports riverpod).

- [ ] **Step 6: Commit.**
  ```
  git add lib/app/main.dart test/app/main_test.dart
  git commit -m "feat(theme): wire AppTheme and ThemeModeController into MaterialApp.router"
  ```

---

### Task 5: Extract `ProxySettingsScreen`

**Files:**
- Create: `lib/ui/settings/proxy_settings_screen.dart` (copy of current `settings_screen.dart` body, renamed class)
- Create: `test/ui/settings/proxy_settings_screen_test.dart`

- [ ] **Step 1: Write the failing test.**
  ```bash
  mkdir -p test/ui/settings
  ```
  `test/ui/settings/proxy_settings_screen_test.dart`:
  ```dart
  import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
  import 'package:animeko_flutter/ui/settings/proxy_settings_screen.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';

  class _FakeProxySettingsController extends ProxySettingsController {
    _FakeProxySettingsController([this._value]);
    String? _value;

    @override
    Future<String?> build() async => _value;

    @override
    Future<void> setProxy(String url) async {
      _value = url.trim();
      state = AsyncData(_value);
    }

    @override
    Future<void> clearProxy() async {
      _value = null;
      state = const AsyncData(null);
    }
  }

  Widget _wrap(ProxySettingsController fake) {
    return ProviderScope(
      overrides: [proxySettingsControllerProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: ProxySettingsScreen()),
    );
  }

  void main() {
    testWidgets('shows the persisted proxy URL and saves a new one', (tester) async {
      final fake = _FakeProxySettingsController('http://127.0.0.1:2222');
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      expect(find.text('http://127.0.0.1:2222'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'http://10.0.0.1:8080');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('已保存'), findsOneWidget);
    });

    testWidgets('clears the proxy', (tester) async {
      final fake = _FakeProxySettingsController('http://127.0.0.1:2222');
      await tester.pumpWidget(_wrap(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('清除代理'));
      await tester.pumpAndSettle();

      expect(find.text('已清除代理'), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/ui/settings/proxy_settings_screen_test.dart` — expect `Target of URI doesn't exist: 'package:animeko_flutter/ui/settings/proxy_settings_screen.dart'.`

- [ ] **Step 3: Implement.** Copy the *current* `lib/ui/settings/settings_screen.dart` verbatim to `lib/ui/settings/proxy_settings_screen.dart`, renaming `SettingsScreen`/`_SettingsScreenState` to `ProxySettingsScreen`/`_ProxySettingsScreenState` and the AppBar title from `'设置'` to `'代理设置'`:
  ```dart
  // lib/ui/settings/proxy_settings_screen.dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../domain/settings/proxy_settings_controller.dart';

  /// Split out of the original `SettingsScreen` so the redesigned
  /// `SettingsScreen` (Task 6) can link to this as an independent
  /// sub-page (`/settings/proxy`) instead of reimplementing the proxy
  /// form inline.
  class ProxySettingsScreen extends ConsumerStatefulWidget {
    const ProxySettingsScreen({super.key});

    @override
    ConsumerState<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
  }

  class _ProxySettingsScreenState extends ConsumerState<ProxySettingsScreen> {
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
      if (mounted) setState(() => _errorText = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      }
    }

    Future<void> _clear() async {
      _controller.clear();
      await ref.read(proxySettingsControllerProvider.notifier).clearProxy();
      if (mounted) setState(() => _errorText = null);
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
        appBar: AppBar(title: const Text('代理设置')),
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

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/ui/settings/proxy_settings_screen_test.dart` — expect 2/2 to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (expect +1 `depend_on_referenced_packages`).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/settings/proxy_settings_screen.dart test/ui/settings/proxy_settings_screen_test.dart
  git commit -m "feat(settings): extract ProxySettingsScreen from SettingsScreen"
  ```

---

### Task 6: Rewrite `SettingsScreen` as a grouped list

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart` (full rewrite — the old proxy-form body now lives in `ProxySettingsScreen`, Task 5)
- Create: `test/ui/settings/settings_screen_test.dart`

- [ ] **Step 1: Write the failing test.**
  `test/ui/settings/settings_screen_test.dart`:
  ```dart
  import 'package:animeko_flutter/domain/auth/auth_controller.dart';
  import 'package:animeko_flutter/domain/auth/auth_state.dart';
  import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
  import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
  import 'package:animeko_flutter/ui/settings/settings_screen.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:go_router/go_router.dart';

  class _FakeAuthController extends AuthController {
    @override
    AuthState build() => const AuthAuthenticated('user-1');
  }

  class _FakeThemeModeController extends ThemeModeController {
    @override
    Future<ThemeMode> build() async => ThemeMode.dark;
  }

  class _FakeProxySettingsController extends ProxySettingsController {
    @override
    Future<String?> build() async => 'http://127.0.0.1:2222';
  }

  Widget _wrap() {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        GoRoute(
          path: '/settings/proxy',
          builder: (context, state) => const Scaffold(body: Text('PROXY PAGE')),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => const Scaffold(body: Text('ACCOUNT PAGE')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController()),
        themeModeControllerProvider.overrideWith(() => _FakeThemeModeController()),
        proxySettingsControllerProvider.overrideWith(() => _FakeProxySettingsController()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void main() {
    testWidgets('shows the persisted theme mode, proxy address, and auth summary', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final darkTile = tester.widget<RadioListTile<ThemeMode>>(
        find.widgetWithText(RadioListTile<ThemeMode>, '深色'),
      );
      expect(darkTile.groupValue, ThemeMode.dark);
      expect(find.text('http://127.0.0.1:2222'), findsOneWidget);
      expect(find.text('已登录'), findsOneWidget);
    });

    testWidgets('tapping the proxy entry navigates to /settings/proxy', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('代理设置'));
      await tester.pumpAndSettle();

      expect(find.text('PROXY PAGE'), findsOneWidget);
    });

    testWidgets('tapping the account entry navigates to /account', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('账户设置'));
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT PAGE'), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/ui/settings/settings_screen_test.dart` — expect failures (no `RadioListTile`/'代理设置'/'账户设置' in the current proxy-only `SettingsScreen`).

- [ ] **Step 3: Implement.**
  `lib/ui/settings/settings_screen.dart` (full replacement):
  ```dart
  // lib/ui/settings/settings_screen.dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';

  import '../../domain/auth/auth_controller.dart';
  import '../../domain/auth/auth_state.dart';
  import '../../domain/settings/proxy_settings_controller.dart';
  import '../../domain/settings/theme_mode_controller.dart';

  /// Grouped-list settings page (Plan 1e phase B), aligned with the
  /// reference Animeko app's grouped-settings layout. Unlike the
  /// reference app's fully transparent `SettingsScope` container, this
  /// keeps Flutter's default M3 `Card` per group -- it already gives the
  /// same grouping affordance without a custom container widget.
  class SettingsScreen extends ConsumerWidget {
    const SettingsScreen({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final themeMode = ref.watch(themeModeControllerProvider);
      final proxy = ref.watch(proxySettingsControllerProvider);
      final authState = ref.watch(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;

      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsGroup(
              title: '通用',
              children: [
                themeMode.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => ListTile(title: Text('加载主题设置失败：$error')),
                  data: (mode) => Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('跟随系统'),
                        value: ThemeMode.system,
                        groupValue: mode,
                        onChanged: (value) => _setThemeMode(ref, value),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('浅色'),
                        value: ThemeMode.light,
                        groupValue: mode,
                        onChanged: (value) => _setThemeMode(ref, value),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('深色'),
                        value: ThemeMode.dark,
                        groupValue: mode,
                        onChanged: (value) => _setThemeMode(ref, value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsGroup(
              title: '网络',
              children: [
                ListTile(
                  title: const Text('代理设置'),
                  subtitle: Text(proxy.valueOrNull ?? '未设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/proxy'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsGroup(
              title: '账户',
              children: [
                ListTile(
                  title: const Text('账户设置'),
                  subtitle: Text(isAuthenticated ? '已登录' : '未登录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/account'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    void _setThemeMode(WidgetRef ref, ThemeMode? mode) {
      if (mode == null) return;
      ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
    }
  }

  class _SettingsGroup extends StatelessWidget {
    const _SettingsGroup({required this.title, required this.children});

    final String title;
    final List<Widget> children;

    @override
    Widget build(BuildContext context) {
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...children,
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/ui/settings/settings_screen_test.dart` — expect 3/3 to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (expect +1 `depend_on_referenced_packages`).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/settings/settings_screen.dart test/ui/settings/settings_screen_test.dart
  git commit -m "feat(settings): redesign SettingsScreen as a grouped list"
  ```

---

### Task 7: `AccountScreen`

**Files:**
- Create: `lib/ui/account/account_screen.dart`
- Create: `test/ui/account/account_screen_test.dart`

- [ ] **Step 1: Write the failing test.**
  ```bash
  mkdir -p lib/ui/account test/ui/account
  ```
  `test/ui/account/account_screen_test.dart`:
  ```dart
  import 'package:animeko_flutter/data/user/user_models.dart';
  import 'package:animeko_flutter/domain/auth/auth_controller.dart';
  import 'package:animeko_flutter/domain/auth/auth_state.dart';
  import 'package:animeko_flutter/domain/user/self_user_controller.dart';
  import 'package:animeko_flutter/ui/account/account_screen.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';

  class _FakeAuthController extends AuthController {
    bool signOutCalled = false;

    @override
    AuthState build() => const AuthAuthenticated('user-1');

    @override
    Future<void> signOut() async {
      signOutCalled = true;
      state = const AuthUnauthenticated();
    }
  }

  const _user = SelfUser(
    id: 'u1',
    nickname: 'Alice',
    hasPassword: true,
    isBangumiSessionValid: true,
  );

  Widget _wrap(_FakeAuthController fakeAuth) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => fakeAuth),
        selfUserProvider.overrideWith((ref) async => _user),
      ],
      child: const MaterialApp(home: AccountScreen()),
    );
  }

  void main() {
    testWidgets('shows the nickname and signs out after confirming', (tester) async {
      final fakeAuth = _FakeAuthController();
      await tester.pumpWidget(_wrap(fakeAuth));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);

      await tester.tap(find.text('退出登录').first);
      await tester.pumpAndSettle();
      expect(find.text('确定要退出登录吗？'), findsOneWidget);

      await tester.tap(find.text('退出登录').last);
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCalled, isTrue);
    });

    testWidgets('cancelling the sign-out dialog does not sign out', (tester) async {
      final fakeAuth = _FakeAuthController();
      await tester.pumpWidget(_wrap(fakeAuth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCalled, isFalse);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/ui/account/account_screen_test.dart` — expect `Target of URI doesn't exist: 'package:animeko_flutter/ui/account/account_screen.dart'.`

- [ ] **Step 3: Implement.**
  `lib/ui/account/account_screen.dart`:
  ```dart
  // lib/ui/account/account_screen.dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../domain/auth/auth_controller.dart';
  import '../../domain/user/self_user_controller.dart';
  import '../common/error_retry_view.dart';
  import '../common/loading_view.dart';

  /// New page (Plan 1e phase B) showing the current user's own profile
  /// with a sign-out entry. `AuthController.signOut()` already existed
  /// (Plan 1a) but had no UI entry point until this page.
  class AccountScreen extends ConsumerWidget {
    const AccountScreen({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final selfUser = ref.watch(selfUserProvider);

      return Scaffold(
        appBar: AppBar(title: const Text('账户')),
        body: selfUser.when(
          loading: () => const LoadingView(),
          error: (error, stack) => ErrorRetryView(
            message: '加载账户信息失败：$error',
            onRetry: () => ref.invalidate(selfUserProvider),
          ),
          data: (user) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: user.mediumAvatar != null
                      ? NetworkImage(user.mediumAvatar!)
                      : null,
                  child: user.mediumAvatar == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.nickname,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出登录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出登录'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(authControllerProvider.notifier).signOut();
      }
    }
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/ui/account/account_screen_test.dart` — expect 2/2 to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (expect +1 `depend_on_referenced_packages`).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/account/account_screen.dart test/ui/account/account_screen_test.dart
  git commit -m "feat(account): add AccountScreen with sign-out"
  ```

---

### Task 8: Wire `/account` and `/settings/proxy` routes

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `test/app/router_test.dart`

- [ ] **Step 1: Write the failing test.** Append to `test/app/router_test.dart` (keep the existing two tests unchanged; add imports for `SelfUser`/`selfUserProvider`/`proxySettingsControllerProvider` alongside the existing ones, and two new local fakes):
  ```dart
  // New imports, alongside the existing ones at the top of the file:
  import 'package:animeko_flutter/data/user/user_models.dart';
  import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
  import 'package:animeko_flutter/domain/user/self_user_controller.dart';

  // New fake, alongside _FakeAuthController:
  class _FakeProxySettingsController extends ProxySettingsController {
    @override
    Future<String?> build() async => null;
  }
  ```
  New test cases, appended inside `void main() { ... }`:
  ```dart
  testWidgets('navigating to /account renders AccountScreen with the self profile', (
    tester,
  ) async {
    final fake = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => fake),
        selfUserProvider.overrideWith(
          (ref) async => const SelfUser(
            id: 'u1',
            nickname: 'Alice',
            hasPassword: true,
            isBangumiSessionValid: true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    GoRouter? router;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router!);
          },
        ),
      ),
    );
    await tester.pump();
    fake.state = const AuthAuthenticated('user-1');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    router!.push('/account');
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('navigating to /settings/proxy renders ProxySettingsScreen', (tester) async {
    final fake = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => fake),
        proxySettingsControllerProvider.overrideWith(() => _FakeProxySettingsController()),
      ],
    );
    addTearDown(container.dispose);

    GoRouter? router;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router!);
          },
        ),
      ),
    );
    await tester.pump();
    fake.state = const AuthAuthenticated('user-1');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    router!.push('/settings/proxy');
    await tester.pumpAndSettle();

    expect(find.text('代理设置'), findsWidgets);
  });
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/app/router_test.dart` — expect a `GoException`/no-matching-location failure since `/account` and `/settings/proxy` aren't registered routes yet.

- [ ] **Step 3: Implement.**
  In `lib/app/router.dart`, add imports:
  ```dart
  import '../ui/account/account_screen.dart';
  import '../ui/settings/proxy_settings_screen.dart';
  ```
  Add two routes next to the existing `/settings`/`/collection` routes:
  ```dart
  GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  GoRoute(path: '/settings/proxy', builder: (context, state) => const ProxySettingsScreen()),
  GoRoute(path: '/account', builder: (context, state) => const AccountScreen()),
  GoRoute(path: '/collection', builder: (context, state) => const MyCollectionScreen()),
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/app/router_test.dart` — expect 4/4 to pass (2 pre-existing + 2 new).

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (baseline unchanged — `router_test.dart` already imports riverpod, no new file).

- [ ] **Step 6: Commit.**
  ```
  git add lib/app/router.dart test/app/router_test.dart
  git commit -m "feat(router): add /account and /settings/proxy routes"
  ```

---

## Definition of Done

- [ ] `flutter test` passes in full (baseline 273 + this plan's ~15 new tests, all green).
- [ ] `flutter analyze` reports only the pre-existing 3 known categories (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`) with `depend_on_referenced_packages` incremented by the number of new riverpod-importing test files added — zero genuinely new issue categories.
- [ ] All 8 tasks' commits are present in `git log` on `main`.
- [ ] Toggling the theme radio buttons on `/settings` visibly switches the whole app between light/dark (manual check — this is the one thing Phase A could not verify since `main.dart` wasn't wired yet).
- [ ] Tapping the account icon in any tab's AppBar (`buildStandardActions()`, from Phase A) now successfully opens `/account` instead of 404ing.
- [ ] Signing out from `/account` returns the user to `/login` (via the pre-existing router `redirect:` logic — no new redirect code needed).
- [ ] (Manual, non-blocking) Real-device/simulator check against a real logged-in session: confirm `GET /v1/me` actually returns the shape assumed by `SelfUser` (this plan's model is built from the *Kotlin client's* declared shape, not a captured real response).

**Not in scope for this phase** (tracked in the design doc for Phases C–F): Home/Search/Schedule adopting `AnimeCoverCard`/`AnimeListItem`/`buildStandardActions`; the subject detail page's immersive header; the my-collection page adopting `AnimeListItem`/`EmptyView`; the player screen's forced dark theme wrapper.
