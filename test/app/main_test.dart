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
