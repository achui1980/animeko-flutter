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

    // The account summary now sits above this entry, pushing it below the
    // default test viewport fold -- scroll it into view before tapping.
    await tester.ensureVisible(find.text('代理设置'));
    await tester.pump();
    await tester.tap(find.text('代理设置'));
    await tester.pumpAndSettle();

    expect(find.text('PROXY PAGE'), findsOneWidget);
  });
}
