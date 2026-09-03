# Settings/Bottom-Nav Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote Settings to a 4th peer tab in the bottom `NavigationBar` (alongside Home/Search/Schedule), merge the standalone `/account` page's content into the top of the Settings page, and trim the shared `buildStandardActions()` AppBar helper down to just the "我的收藏" icon.

**Architecture:** Extract the account-summary UI (avatar, nickname, sign-out) out of the doomed `AccountScreen` into a small, dependency-isolated `AccountSummarySection` widget, embed it at the top of `SettingsScreen`, delete the old standalone account page and its `/account` route, move `/settings` from a top-level pushed route into a 4th `StatefulShellBranch` of the existing `StatefulShellRoute.indexedStack`, and add a matching 4th `NavigationDestination` to `MainShell`.

**Tech Stack:** Flutter (Material 3), Riverpod 3.2.1 (`flutter_riverpod`), go_router ^17.5.0.

**Design doc:** `docs/superpowers/specs/2026-09-03-settings-bottom-nav-redesign-design.md`

---

### Task 1: Extract `AccountSummarySection`

**Files:**
- Create: `lib/ui/settings/account_summary_section.dart`
- Test: `test/ui/settings/account_summary_section_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ui/settings/account_summary_section_test.dart`:

```dart
import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/domain/user/self_user_controller.dart';
import 'package:animeko_flutter/ui/settings/account_summary_section.dart';
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
    child: const MaterialApp(home: Scaffold(body: AccountSummarySection())),
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

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/settings/account_summary_section_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:animeko_flutter/ui/settings/account_summary_section.dart'.`

- [ ] **Step 3: Write the implementation**

Create `lib/ui/settings/account_summary_section.dart`:

```dart
// lib/ui/settings/account_summary_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/auth_controller.dart';
import '../../domain/user/self_user_controller.dart';
import '../common/error_retry_view.dart';
import '../common/loading_view.dart';

/// Account summary shown at the top of the Settings page. Extracted from
/// the old standalone `AccountScreen` (now deleted, see Task 3) so it can
/// be embedded inline in `SettingsScreen` instead of requiring a separate
/// `/account` destination.
class AccountSummarySection extends ConsumerWidget {
  const AccountSummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfUser = ref.watch(selfUserProvider);

    return selfUser.when(
      loading: () => const LoadingView(),
      error: (error, stack) => ErrorRetryView(
        message: '加载账户信息失败：$error',
        onRetry: () => ref.invalidate(selfUserProvider),
      ),
      data: (user) => Column(
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
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

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/settings/account_summary_section_test.dart`
Expected: PASS — 2/2 tests pass.

- [ ] **Step 5: Full regression**

Run: `flutter test`
Expected: All existing tests still pass, plus these 2 new ones (baseline 311 + 2 = 313).

Run: `flutter analyze`
Expected: Same 3 known issue categories as baseline (22 issues), +1 `depend_on_referenced_packages`... **no** — this test file imports `flutter_riverpod`, not plain `package:riverpod`, so the count should stay at 22 (unchanged from baseline). If `flutter analyze` reports something different, investigate before moving on.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/settings/account_summary_section.dart test/ui/settings/account_summary_section_test.dart
git commit -m "feat(settings): extract AccountSummarySection widget"
```

---

### Task 2: Embed `AccountSummarySection` in `SettingsScreen`, remove the old 账户 group

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart`
- Modify: `test/ui/settings/settings_screen_test.dart`

- [ ] **Step 1: Update the test first**

Replace the full contents of `test/ui/settings/settings_screen_test.dart` with:

```dart
import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
import 'package:animeko_flutter/domain/user/self_user_controller.dart';
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

const _user = SelfUser(
  id: 'u1',
  nickname: 'Alice',
  hasPassword: true,
  isBangumiSessionValid: true,
);

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: '/settings/proxy',
        builder: (context, state) => const Scaffold(body: Text('PROXY PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _FakeAuthController()),
      themeModeControllerProvider.overrideWith(() => _FakeThemeModeController()),
      proxySettingsControllerProvider.overrideWith(() => _FakeProxySettingsController()),
      selfUserProvider.overrideWith((ref) async => _user),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the persisted theme mode, proxy address, and account summary', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // RadioListTile no longer carries its own groupValue (deprecated in
    // favor of an ancestor RadioGroup) -- assert on the RadioGroup itself.
    final radioGroup = tester.widget<RadioGroup<ThemeMode>>(
      find.byType(RadioGroup<ThemeMode>),
    );
    expect(radioGroup.groupValue, ThemeMode.dark);
    expect(find.text('http://127.0.0.1:2222'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('tapping the proxy entry navigates to /settings/proxy', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('代理设置'));
    await tester.pumpAndSettle();

    expect(find.text('PROXY PAGE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: FAIL — the first test's `expect(find.text('Alice'), findsOneWidget)` fails because `SettingsScreen` doesn't render `AccountSummarySection` yet (0 widgets found).

- [ ] **Step 3: Write the implementation**

Replace the full contents of `lib/ui/settings/settings_screen.dart` with:

```dart
// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/settings/proxy_settings_controller.dart';
import '../../domain/settings/theme_mode_controller.dart';
import 'account_summary_section.dart';

/// Grouped-list settings page. The account summary (avatar, nickname,
/// sign-out) lives at the top, followed by the 通用/网络 groups -- see
/// the Settings/bottom-nav redesign design doc for why account info
/// moved here instead of staying on a separate `/account` page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final proxy = ref.watch(proxySettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AccountSummarySection(),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '通用',
            children: [
              themeMode.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => ListTile(title: Text('加载主题设置失败：$error')),
                data: (mode) => RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (value) => _setThemeMode(ref, value),
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(title: Text('跟随系统'), value: ThemeMode.system),
                      RadioListTile<ThemeMode>(title: Text('浅色'), value: ThemeMode.light),
                      RadioListTile<ThemeMode>(title: Text('深色'), value: ThemeMode.dark),
                    ],
                  ),
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
                subtitle: Text(proxy.value ?? '未设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/proxy'),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
```

Note what changed from the previous version: the `authControllerProvider`/`AuthState` imports and the "账户" `_SettingsGroup` (with its `ListTile` pushing to `/account`) are gone; `AccountSummarySection()` is inserted at the top of the `ListView`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: PASS — 2/2 tests pass.

- [ ] **Step 5: Full regression**

Run: `flutter test`
Expected: All tests pass (baseline 313 from Task 1, unchanged count since this task replaces 3 old tests with 2 new ones in the same file — net −1, so expect 312).

Run: `flutter analyze`
Expected: Same 3 known categories, count unchanged from Task 1's 22 (this test file already imported `flutter_riverpod`, not plain `riverpod`, before this task; no new file added).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/settings/settings_screen.dart test/ui/settings/settings_screen_test.dart
git commit -m "feat(settings): embed AccountSummarySection, remove the 账户 navigation entry"
```

---

### Task 3: Delete the standalone `AccountScreen`

**Files:**
- Delete: `lib/ui/account/account_screen.dart`
- Delete: `test/ui/account/account_screen_test.dart`

- [ ] **Step 1: Delete both files**

```bash
git rm lib/ui/account/account_screen.dart test/ui/account/account_screen_test.dart
```

- [ ] **Step 2: Confirm nothing else references `AccountScreen`**

Run: `grep -rn "account_screen\|AccountScreen" lib/ test/`
Expected: No matches. (`lib/app/router.dart` still imports and references `AccountScreen` at this point — that import/route is removed in Task 6, not this task. If `grep` shows a hit in `lib/app/router.dart`, that is expected and will be resolved by Task 6; do not fix it here.)

- [ ] **Step 3: Full regression**

Run: `flutter test`
Expected: This will currently FAIL to compile, because `lib/app/router.dart` still imports the now-deleted `lib/ui/account/account_screen.dart`. This is expected and will be fixed in Task 6 — do **not** try to fix it in this task. Confirm the failure is exactly this import error (`Error: Couldn't resolve the package 'lib/ui/account/account_screen.dart'` or similar "file not found"-style error referencing that path), then proceed directly to committing this task's deletions. (If the plan is being executed strictly task-by-task with full regression gating every commit, execute Task 3 and Task 6 back-to-back with no other work in between, so the broken intermediate state doesn't linger.)

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(account): delete the standalone AccountScreen (merged into Settings)"
```

---

### Task 4: Trim `buildStandardActions()` to a single icon

**Files:**
- Modify: `lib/ui/common/app_action_bar.dart`
- Modify: `test/ui/common/app_action_bar_test.dart`

- [ ] **Step 1: Update the test first**

Replace the full contents of `test/ui/common/app_action_bar_test.dart` with:

```dart
import 'package:animeko_flutter/ui/common/app_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buildStandardActions returns a single collection icon button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              Scaffold(appBar: AppBar(actions: buildStandardActions(context))),
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/common/app_action_bar_test.dart`
Expected: FAIL — `findsOneWidget` for `IconButton` fails because there are currently 3, not 1.

- [ ] **Step 3: Write the implementation**

Replace the full contents of `lib/ui/common/app_action_bar.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The shared "我的收藏" (collection) icon button used by Home/Search/
/// Schedule's `AppBar.actions`. Account and Settings previously also
/// lived here, but account info is now embedded inline at the top of
/// the Settings page (see `AccountSummarySection`), and Settings itself
/// is a bottom-nav tab rather than something reached from an AppBar
/// icon (see the Settings/bottom-nav redesign design doc).
List<Widget> buildStandardActions(BuildContext context) {
  return [
    IconButton(
      icon: const Icon(Icons.bookmark),
      tooltip: '我的收藏',
      onPressed: () => context.push('/collection'),
    ),
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/common/app_action_bar_test.dart`
Expected: PASS — 1/1 test passes.

- [ ] **Step 5: Full regression**

Run: `flutter test`
Expected: All tests pass. This change removes the account icon (`Icons.account_circle_outlined`) and settings icon (`Icons.settings`) from every AppBar that calls `buildStandardActions()` (`lib/ui/home/home_screen.dart`, `lib/ui/search/search_screen.dart`, `lib/ui/schedule/schedule_screen.dart`) — none of those 3 screens' own test files assert on those specific icons existing (they were not covered before), so no other test file should need changes. If any test elsewhere in the suite fails because it asserted `Icons.account_circle_outlined` or the settings icon inside one of those 3 screens, that is a real gap this plan missed — investigate and fix inline before proceeding, since the design doc's explicit scope is "no changes to Home/Search/Schedule beyond the `buildStandardActions()` icon count."

Run: `flutter analyze`
Expected: Same 3 known categories, count unchanged (no new files, and this test file has no plain-`riverpod` import).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/common/app_action_bar.dart test/ui/common/app_action_bar_test.dart
git commit -m "feat(ui): trim buildStandardActions to just the collection icon"
```

---

### Task 5: Add a Settings destination to the bottom nav

**Files:**
- Modify: `lib/ui/shell/main_shell.dart`

- [ ] **Step 1: Write the implementation**

Replace the full contents of `lib/ui/shell/main_shell.dart` with:

```dart
// lib/ui/shell/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

This is the only change: a 4th `NavigationDestination` (`Icons.settings`, label `'Settings'`, matching the existing 3 destinations' English-label convention). `MainShell` has no dedicated test file — its correctness (4 destinations rendering, the 4th one navigating to the Settings tab and matching `navigationShell.currentIndex`) is verified end-to-end by the new router test added in Task 6, once `lib/app/router.dart` actually wires up a 4th `StatefulShellBranch` for it to render against. There is nothing to run/verify in isolation for this task — proceed directly to committing.

- [ ] **Step 2: Commit**

```bash
git add lib/ui/shell/main_shell.dart
git commit -m "feat(shell): add a Settings destination to the bottom nav"
```

---

### Task 6: Move `/settings` into the shell, delete `/account`

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `test/app/router_test.dart`

- [ ] **Step 1: Update the test first**

Replace the full contents of `test/app/router_test.dart` with:

```dart
// test/app/router_test.dart
import 'package:animeko_flutter/app/router.dart';
import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
import 'package:animeko_flutter/domain/user/self_user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A minimal fake that lets the test drive [AuthController]'s state
/// directly, mirroring the `_FakeAuthController` pattern already used in
/// Plan 1a's `login_screen_test.dart`.
class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _FakeThemeModeController extends ThemeModeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.system;
}

class _FakeProxySettingsController extends ProxySettingsController {
  @override
  Future<String?> build() async => null;
}

void main() {
  testWidgets('unauthenticated user sees the login screen, authenticated user sees Home', (
    tester,
  ) async {
    final fake = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in with Bangumi'), findsOneWidget);

    fake.state = const AuthAuthenticated('user-1');
    // Not pumpAndSettle(): HomeScreen's trendingProvider and
    // homeRecommendationsControllerProvider make real (un-mocked) network
    // calls and stay in AsyncLoading, and TrendingCarousel's auto-advance
    // Timer keeps scheduling a new animation frame every simulated 5
    // seconds for as long as it's mounted -- pumpAndSettle() never sees
    // "no more frames scheduled" and times out. A couple of bounded pumps
    // is enough for the refreshListenable-triggered redirect and the
    // route transition to complete.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Animeko'), findsOneWidget);
    expect(find.text('Log in with Bangumi'), findsNothing);
  });

  testWidgets(
    'play route without `extra` set renders a fallback instead of crashing',
    (tester) async {
      final fake = _FakeAuthController();
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith(() => fake)],
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

      // Navigate straight to the play route by URL, without ever pushing
      // through `SubjectDetailScreen` -- so `state.extra` is null, as it
      // would be after e.g. app restoration or a future deep link.
      router!.go('/subject/1/play');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Invalid navigation'), findsOneWidget);
      // No exception should have been thrown by the unguarded cast.
      expect(tester.takeException(), isNull);
    },
  );

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
    // Not pumpAndSettle(): same reason as above -- the previous /home
    // route's TrendingCarousel Timer keeps the widget tree scheduling
    // frames while it's mounted underneath.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('代理设置'), findsWidgets);
  });

  testWidgets('the Settings tab is a 4th bottom-nav destination and renders SettingsScreen', (
    tester,
  ) async {
    final fake = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => fake),
        themeModeControllerProvider.overrideWith(() => _FakeThemeModeController()),
        proxySettingsControllerProvider.overrideWith(() => _FakeProxySettingsController()),
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

    // Navigate to the Settings tab by URL, same way the other shell
    // branches (/home, /search, /schedule) are already reached elsewhere
    // in this test file.
    router!.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 3);
    expect(find.text('Alice'), findsOneWidget);
  });
}
```

Note what changed: the `'navigating to /account renders AccountScreen with the self profile'` test is removed entirely (the route no longer exists); a new test verifies the Settings tab is the 4th shell branch, that `NavigationBar.selectedIndex` is `3` when on it, and that the merged account summary (`'Alice'`) renders.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app/router_test.dart`
Expected: FAIL to compile — `lib/app/router.dart` still imports the deleted `AccountScreen` (from Task 3) and still defines `/settings` and `/account` as top-level routes rather than a 4th shell branch, so the new test's `router!.go('/settings')` would currently navigate to the old standalone `SettingsScreen` route (not inside `MainShell`), and `find.byType(NavigationDestination)` would find only 3, not 4. The build itself will actually fail first, with an unresolved-import error referencing `lib/ui/account/account_screen.dart` (from Task 3's deletion) — confirm that specific error before proceeding.

- [ ] **Step 3: Write the implementation**

Replace the full contents of `lib/app/router.dart` with:

```dart
// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth/auth_controller.dart';
import '../domain/auth/auth_state.dart';
import '../domain/play/subject_episodes_controller.dart';
import '../ui/auth/login_screen.dart';
import '../ui/collection/my_collection_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/player/player_screen.dart';
import '../ui/schedule/schedule_screen.dart';
import '../ui/search/search_screen.dart';
import '../ui/settings/proxy_settings_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/shell/main_shell.dart';
import '../ui/subject/subject_detail_screen.dart';

part 'router.g.dart';

/// Bridges Riverpod's [authControllerProvider] state changes into
/// go_router's `refreshListenable`, which is what triggers the `redirect:`
/// callback to be re-evaluated on an *external* state change (e.g. login
/// succeeding while the user is still sitting on the `/login` route).
/// Without this, go_router only re-runs `redirect:` on navigation events,
/// so a successful login would never automatically navigate the user away
/// from the login screen.
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

@riverpod
GoRouter appRouter(Ref ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, _) => notifier.notify());
  ref.onDispose(notifier.dispose);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/subject/:subjectId',
        builder: (context, state) {
          final subjectId = int.parse(state.pathParameters['subjectId']!);
          final name = state.uri.queryParameters['name'] ?? '';
          final imageUrl = state.uri.queryParameters['imageUrl'];
          return SubjectDetailScreen(
            subjectId: subjectId,
            subjectName: name,
            imageUrl: imageUrl,
          );
        },
      ),
      GoRoute(
        path: '/subject/:subjectId/play',
        builder: (context, state) {
          final extra = state.extra;
          // Guard against reaching this route without `extra` set (e.g.
          // app restoration or a future deep link) instead of letting an
          // unhandled `TypeError` crash the app -- today
          // `SubjectDetailScreen` always sets `extra` correctly.
          if (extra is! MergedEpisode) {
            return const Scaffold(
              body: Center(child: Text('Invalid navigation')),
            );
          }
          return PlayerScreen(episode: extra);
        },
      ),
      GoRoute(path: '/settings/proxy', builder: (context, state) => const ProxySettingsScreen()),
      GoRoute(path: '/collection', builder: (context, state) => const MyCollectionScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/search', builder: (context, state) => const SearchScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/schedule', builder: (context, state) => const ScheduleScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
```

Note what changed: the `import '../ui/account/account_screen.dart';` line is gone; the `GoRoute(path: '/settings', ...)` and `GoRoute(path: '/account', ...)` top-level routes are gone; `/settings` now lives as a 4th `StatefulShellBranch`, peer to `/home`/`/search`/`/schedule`. `/settings/proxy` and `/collection` remain unchanged top-level pushed routes.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/app/router_test.dart`
Expected: PASS — 4/4 tests pass.

- [ ] **Step 5: Full regression**

Run: `flutter test`
Expected: All tests pass. Net test count change from this task: −1 (removed the `/account` test) + 1 (added the Settings-tab test) = 0, so the total should match wherever Task 5 left off (Task 5 added no tests, so still whatever Task 4 left the suite at).

Run: `flutter analyze`
Expected: Same 3 known categories. This test file already imported `flutter_riverpod` before this task, so no `depend_on_referenced_packages` change from this file. `lib/ui/account/account_screen.dart` and its test being gone (from Task 3) may have *reduced* the total analyze-issue count if either of them was contributing to `depend_on_referenced_packages` — check the actual number against what Task 4 ended at and confirm the delta is explainable (either 0, or a small negative number equal to however many riverpod-importing files were deleted in Task 3 — `account_screen_test.dart` imported `flutter_riverpod`, not plain `riverpod`, so it should **not** have been contributing to that count; if the number differs from your prediction, investigate before proceeding, don't just accept it).

- [ ] **Step 6: Commit**

```bash
git add lib/app/router.dart test/app/router_test.dart
git commit -m "feat(router): move /settings into the shell as a 4th tab, delete /account"
```

---

## Definition of Done

- `flutter test` passes in full (no failures) at the end of Task 6.
- `flutter analyze` reports only the same 3 known issue categories established throughout this project (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`) with no new category introduced.
- All 6 tasks' commits are present in `git log` on `main`, each scoped to exactly the files listed in that task.
- Bottom nav has exactly 4 destinations: Home, Search, Schedule, Settings — Settings is reachable by tapping the 4th tab, not via any AppBar icon.
- `/account` no longer exists as a route anywhere in the app; account info (avatar, nickname, sign-out) renders at the top of the Settings page instead.
- `buildStandardActions()` (used by Home/Search/Schedule's `AppBar.actions`) shows exactly one icon: "我的收藏" (collection).
- Manual/non-blocking verification (via `flutter run -d macos`, per this project's established macOS-launch pattern): confirm the 4-tab bottom nav renders and switches correctly; confirm Settings shows the account summary at the top with a working sign-out flow that redirects to `/login`; confirm the proxy-settings sub-page is still reachable by tapping "代理设置" inside Settings.
- Explicitly out of scope (per the design doc): no changes to Home/Search/Schedule/Collection/Subject-Detail/Player beyond the `buildStandardActions()` icon-count change; no changes to `/settings/proxy`'s own content or path; no deep-link/graceful-404 handling for the removed `/account` path.
