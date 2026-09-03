import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/playback_speed_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('PlaybackSpeedController', () {
    late MockSettingsStorage storage;
    late ProviderContainer container;

    setUp(() {
      storage = MockSettingsStorage();
      container = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWith((ref) async => storage)],
      );
      addTearDown(container.dispose);
    });

    test('build reads the persisted playback speed', () async {
      when(() => storage.getPlaybackSpeed()).thenReturn(1.5);
      final result = await container.read(playbackSpeedControllerProvider.future);
      expect(result, 1.5);
    });

    test('build defaults to 1.0 when nothing is persisted', () async {
      when(() => storage.getPlaybackSpeed()).thenReturn(1.0);
      final result = await container.read(playbackSpeedControllerProvider.future);
      expect(result, 1.0);
    });

    test('setPlaybackSpeed persists and updates state', () async {
      when(() => storage.getPlaybackSpeed()).thenReturn(1.0);
      when(() => storage.setPlaybackSpeed(any())).thenAnswer((_) async {});
      await container.read(playbackSpeedControllerProvider.future);

      await container
          .read(playbackSpeedControllerProvider.notifier)
          .setPlaybackSpeed(2.0);

      verify(() => storage.setPlaybackSpeed(2.0)).called(1);
      expect(container.read(playbackSpeedControllerProvider).value, 2.0);
    });
  });
}
