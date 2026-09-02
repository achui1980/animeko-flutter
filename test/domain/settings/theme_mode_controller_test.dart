import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('ThemeModeController', () {
    late MockSettingsStorage storage;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(ThemeMode.system);
    });

    setUp(() {
      storage = MockSettingsStorage();
      container = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWith((ref) async => storage)],
      );
      addTearDown(container.dispose);
    });

    test('build reads the persisted theme mode', () async {
      when(() => storage.getThemeMode()).thenReturn(ThemeMode.dark);
      final result = await container.read(themeModeControllerProvider.future);
      expect(result, ThemeMode.dark);
    });

    test('build defaults to ThemeMode.system when nothing is persisted', () async {
      when(() => storage.getThemeMode()).thenReturn(null);
      final result = await container.read(themeModeControllerProvider.future);
      expect(result, ThemeMode.system);
    });

    test('setThemeMode persists and updates state', () async {
      when(() => storage.getThemeMode()).thenReturn(null);
      when(() => storage.setThemeMode(any())).thenAnswer((_) async {});
      await container.read(themeModeControllerProvider.future);

      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(ThemeMode.light);

      verify(() => storage.setThemeMode(ThemeMode.light)).called(1);
      expect(
        container.read(themeModeControllerProvider).value,
        ThemeMode.light,
      );
    });
  });
}
