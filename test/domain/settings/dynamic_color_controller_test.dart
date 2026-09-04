import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/dynamic_color_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('DynamicColorController', () {
    late MockSettingsStorage storage;
    late ProviderContainer container;

    setUp(() {
      storage = MockSettingsStorage();
      container = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWith((ref) async => storage)],
      );
      addTearDown(container.dispose);
    });

    test('build reads the persisted value', () async {
      when(() => storage.getUseDynamicColor()).thenReturn(true);
      final result = await container.read(dynamicColorControllerProvider.future);
      expect(result, true);
    });

    test('build defaults to false when nothing is persisted', () async {
      when(() => storage.getUseDynamicColor()).thenReturn(false);
      final result = await container.read(dynamicColorControllerProvider.future);
      expect(result, false);
    });

    test('setUseDynamicColor persists and updates state', () async {
      when(() => storage.getUseDynamicColor()).thenReturn(false);
      when(() => storage.setUseDynamicColor(any())).thenAnswer((_) async {});
      await container.read(dynamicColorControllerProvider.future);

      await container
          .read(dynamicColorControllerProvider.notifier)
          .setUseDynamicColor(true);

      verify(() => storage.setUseDynamicColor(true)).called(1);
      expect(container.read(dynamicColorControllerProvider).value, true);
    });
  });
}
