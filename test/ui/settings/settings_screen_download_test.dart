import 'package:animeko_flutter/app/theme/app_theme.dart';
import 'package:animeko_flutter/data/user/user_models.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/domain/settings/download_settings_controller.dart';
import 'package:animeko_flutter/domain/settings/dynamic_color_controller.dart';
import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:animeko_flutter/domain/settings/seed_color_controller.dart';
import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
import 'package:animeko_flutter/domain/user/self_user_controller.dart';
import 'package:animeko_flutter/ui/settings/settings_screen.dart';
import 'package:file_selector/file_selector.dart';
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
  Future<String?> build() async => null;
}

class _FakeDynamicColorController extends DynamicColorController {
  @override
  Future<bool> build() async => false;
}

class _FakeSeedColorController extends SeedColorController {
  @override
  Future<Color> build() async => kSeedColor;
}

class _FakeDownloadSettingsController extends DownloadSettingsController {
  String? setDownloadDirectoryCalledWith;

  @override
  Future<String> build() async => '/Users/alice/Downloads/animeko';

  @override
  Future<void> setDownloadDirectory(String path) async {
    setDownloadDirectoryCalledWith = path;
    state = AsyncData(path);
  }
}

const _user = SelfUser(
  id: 'u1',
  nickname: 'Alice',
  hasPassword: true,
  isBangumiSessionValid: true,
);

Widget _wrap({
  _FakeDownloadSettingsController? downloadSettingsController,
  Future<String?> Function({String? initialDirectory})? selectDirectory,
}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(
          selectDirectory: selectDirectory ?? getDirectoryPath,
        ),
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) =>
            const Scaffold(body: Text('DOWNLOADS PAGE')),
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
        () => _FakeDynamicColorController(),
      ),
      seedColorControllerProvider.overrideWith(
        () => _FakeSeedColorController(),
      ),
      downloadSettingsControllerProvider.overrideWith(
        () => downloadSettingsController ?? _FakeDownloadSettingsController(),
      ),
      selfUserProvider.overrideWith((ref) async => _user),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the current download directory', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('下载目录', skipOffstage: false));
    await tester.pump();

    expect(find.text('下载目录'), findsOneWidget);
    expect(find.text('/Users/alice/Downloads/animeko'), findsOneWidget);
  });

  testWidgets('tapping download management navigates to /downloads', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('下载管理', skipOffstage: false));
    await tester.pump();
    await tester.tap(find.text('下载管理'));
    await tester.pumpAndSettle();

    expect(find.text('DOWNLOADS PAGE'), findsOneWidget);
  });

  testWidgets('cancelling directory selection leaves the setting unchanged', (
    tester,
  ) async {
    final controller = _FakeDownloadSettingsController();
    await tester.pumpWidget(
      _wrap(
        downloadSettingsController: controller,
        selectDirectory: ({String? initialDirectory}) async => null,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('下载目录', skipOffstage: false));
    await tester.pump();
    await tester.tap(find.text('下载目录'));
    await tester.pumpAndSettle();

    expect(controller.setDownloadDirectoryCalledWith, isNull);
  });
}
