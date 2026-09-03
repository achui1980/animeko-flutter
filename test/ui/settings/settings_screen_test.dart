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

    // RadioListTile no longer carries its own groupValue (deprecated in
    // favor of an ancestor RadioGroup) -- assert on the RadioGroup itself.
    final radioGroup = tester.widget<RadioGroup<ThemeMode>>(
      find.byType(RadioGroup<ThemeMode>),
    );
    expect(radioGroup.groupValue, ThemeMode.dark);
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
