import 'package:animeko_flutter/app/theme/app_theme.dart';
import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/domain/settings/dynamic_color_controller.dart';
import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:animeko_flutter/domain/settings/seed_color_controller.dart';
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

class _FakeDynamicColorController extends DynamicColorController {
  bool? setUseDynamicColorCalledWith;

  @override
  Future<bool> build() async => false;

  @override
  Future<void> setUseDynamicColor(bool enabled) async {
    setUseDynamicColorCalledWith = enabled;
    state = AsyncData(enabled);
  }
}

class _FakeSeedColorController extends SeedColorController {
  Color? setSeedColorCalledWith;

  @override
  Future<Color> build() async => kSeedColor;

  @override
  Future<void> setSeedColor(Color color) async {
    setSeedColorCalledWith = color;
    state = AsyncData(color);
  }
}

const _user = SelfUser(
  id: 'u1',
  nickname: 'Alice',
  hasPassword: true,
  isBangumiSessionValid: true,
);

Widget _wrap({
  _FakeDynamicColorController? dynamicColorController,
  _FakeSeedColorController? seedColorController,
}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/proxy',
        builder: (context, state) => const Scaffold(body: Text('PROXY PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _FakeAuthController()),
      themeModeControllerProvider.overrideWith(
        () => _FakeThemeModeController(),
      ),
      proxySettingsControllerProvider.overrideWith(
        () => _FakeProxySettingsController(),
      ),
      dynamicColorControllerProvider.overrideWith(
        () => dynamicColorController ?? _FakeDynamicColorController(),
      ),
      seedColorControllerProvider.overrideWith(
        () => seedColorController ?? _FakeSeedColorController(),
      ),
      selfUserProvider.overrideWith((ref) async => _user),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
    'shows the persisted theme mode, proxy address, and account summary',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // RadioListTile no longer carries its own groupValue (deprecated in
      // favor of an ancestor RadioGroup) -- assert on the RadioGroup itself.
      final radioGroup = tester.widget<RadioGroup<ThemeMode>>(
        find.byType(RadioGroup<ThemeMode>),
      );
      expect(radioGroup.groupValue, ThemeMode.dark);
      // The new dynamic-color toggle + palette picker push this address
      // below the default test viewport's fold -- scroll it into view first
      // (skipOffstage: false since Finder.text can't locate it to scroll to
      // otherwise -- see the "tapping the proxy entry" test's identical fix).
      await tester.ensureVisible(
        find.text('http://127.0.0.1:2222', skipOffstage: false),
      );
      await tester.pump();
      expect(find.text('http://127.0.0.1:2222'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    },
  );

  testWidgets('tapping the proxy entry navigates to /settings/proxy', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // The account summary and the new dynamic-color toggle/palette picker
    // now sit above this entry, pushing it below the default test
    // viewport's fold -- scroll it into view before tapping.
    await tester.ensureVisible(find.text('代理设置', skipOffstage: false));
    await tester.pump();
    await tester.tap(find.text('代理设置'));
    await tester.pumpAndSettle();

    expect(find.text('PROXY PAGE'), findsOneWidget);
  });

  testWidgets('toggling the dynamic-color switch calls setUseDynamicColor', (
    tester,
  ) async {
    final dynamicColorController = _FakeDynamicColorController();
    await tester.pumpWidget(
      _wrap(dynamicColorController: dynamicColorController),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(dynamicColorController.setUseDynamicColorCalledWith, true);
  });

  testWidgets('tapping a seed color swatch calls setSeedColor', (tester) async {
    final seedColorController = _FakeSeedColorController();
    await tester.pumpWidget(_wrap(seedColorController: seedColorController));
    await tester.pumpAndSettle();

    final swatchKey = ValueKey('seed_color_${seedColorPresets[1].toARGB32()}');
    await tester.ensureVisible(find.byKey(swatchKey, skipOffstage: false));
    await tester.pump();
    await tester.tap(find.byKey(swatchKey));
    await tester.pumpAndSettle();

    expect(seedColorController.setSeedColorCalledWith, seedColorPresets[1]);
  });
}
