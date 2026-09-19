import 'package:animeko_flutter/app/main.dart';
import 'package:animeko_flutter/app/theme/app_theme.dart';
import 'package:animeko_flutter/domain/home/trending_controller.dart';
import 'package:animeko_flutter/domain/settings/dynamic_color_controller.dart';
import 'package:animeko_flutter/domain/settings/seed_color_controller.dart';
import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeThemeModeController extends ThemeModeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.dark;
}

class _FakeDynamicColorController extends DynamicColorController {
  @override
  Future<bool> build() async => false;
}

class _FakeSeedColorController extends SeedColorController {
  @override
  Future<Color> build() async => kSeedColor;
}

void main() {
  testWidgets('applies AppTheme.light()/dark() and the persisted ThemeMode', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        themeModeControllerProvider.overrideWith(
          () => _FakeThemeModeController(),
        ),
        dynamicColorControllerProvider.overrideWith(
          () => _FakeDynamicColorController(),
        ),
        seedColorControllerProvider.overrideWith(
          () => _FakeSeedColorController(),
        ),
        // The router's initial route is now `/home` (there's no more
        // forced login wall), so this test's full-app pump reaches
        // HomeScreen and its always-on trendingProvider. Without this
        // override that fires a real, un-mocked network request whose
        // internal Dio timeout Timer is still pending when the test
        // tears down, tripping flutter_test's "A Timer is still
        // pending" assertion.
        trendingProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AnimekoFlutterApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    expect(app.themeMode, ThemeMode.dark);
  });
}
