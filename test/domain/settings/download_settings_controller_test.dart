import 'dart:io';

import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/download_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('DownloadSettingsController', () {
    late MockSettingsStorage storage;
    late ProviderContainer container;

    setUp(() {
      storage = MockSettingsStorage();
      container = ProviderContainer(
        overrides: [
          settingsStorageProvider.overrideWith((ref) async => storage),
          defaultDownloadDirectoryProvider.overrideWith(
            (ref) async => '/support/downloads',
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'uses the application-support downloads directory by default',
      () async {
        when(() => storage.getDownloadDirectory()).thenReturn(null);

        expect(
          await container.read(downloadSettingsControllerProvider.future),
          '/support/downloads',
        );
      },
    );

    test('setDownloadDirectory persists and updates state', () async {
      final directory = await Directory.systemTemp.createTemp('animeko-test-');
      addTearDown(directory.delete);
      when(() => storage.getDownloadDirectory()).thenReturn(null);
      when(() => storage.setDownloadDirectory(any())).thenAnswer((_) async {});
      await container.read(downloadSettingsControllerProvider.future);

      await container
          .read(downloadSettingsControllerProvider.notifier)
          .setDownloadDirectory(directory.path);

      verify(() => storage.setDownloadDirectory(directory.path)).called(1);
      expect(
        container.read(downloadSettingsControllerProvider).value,
        directory.path,
      );
    });
  });
}
