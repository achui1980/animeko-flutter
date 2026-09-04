import 'package:animeko_flutter/app/theme/app_theme.dart';
import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/seed_color_controller.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('SeedColorController', () {
    late MockSettingsStorage storage;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(const Color(0xFF000000));
    });

    setUp(() {
      storage = MockSettingsStorage();
      container = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWith((ref) async => storage)],
      );
      addTearDown(container.dispose);
    });

    test('build reads the persisted seed color', () async {
      when(() => storage.getSeedColorValue()).thenReturn(0xFF00FF00);
      final result = await container.read(seedColorControllerProvider.future);
      expect(result, const Color(0xFF00FF00));
    });

    test('build defaults to kSeedColor when nothing is persisted', () async {
      when(() => storage.getSeedColorValue()).thenReturn(null);
      final result = await container.read(seedColorControllerProvider.future);
      expect(result, kSeedColor);
    });

    test('setSeedColor persists and updates state', () async {
      when(() => storage.getSeedColorValue()).thenReturn(null);
      when(() => storage.setSeedColorValue(any())).thenAnswer((_) async {});
      await container.read(seedColorControllerProvider.future);

      const chosen = Color(0xFF006A6A);
      await container.read(seedColorControllerProvider.notifier).setSeedColor(chosen);

      verify(() => storage.setSeedColorValue(chosen.toARGB32())).called(1);
      expect(container.read(seedColorControllerProvider).value, chosen);
    });
  });
}
