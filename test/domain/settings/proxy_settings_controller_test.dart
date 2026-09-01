import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('validateProxyUrl', () {
    test('accepts an empty string (means clear)', () {
      expect(validateProxyUrl(''), isNull);
    });

    test('accepts a valid http:// URL', () {
      expect(validateProxyUrl('http://127.0.0.1:2222'), isNull);
    });

    test('rejects a socks5:// URL', () {
      expect(
        validateProxyUrl('socks5://127.0.0.1:1080'),
        '暂不支持该协议（当前仅支持 http://）',
      );
    });

    test('rejects a URL with no scheme', () {
      expect(
        validateProxyUrl('127.0.0.1:2222'),
        '暂不支持该协议（当前仅支持 http://）',
      );
    });

    test('rejects a malformed http:// URL with no port', () {
      expect(
        validateProxyUrl('http://127.0.0.1'),
        '地址格式不正确，请输入如 http://127.0.0.1:2222',
      );
    });
  });

  group('ProxySettingsController', () {
    late MockSettingsStorage storage;
    late ProviderContainer container;

    setUp(() {
      storage = MockSettingsStorage();
      container = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWith((ref) async => storage)],
      );
      addTearDown(container.dispose);
    });

    test('build reads the persisted proxy URL', () async {
      when(() => storage.getProxyUrl()).thenReturn('http://127.0.0.1:2222');
      final result = await container.read(proxySettingsControllerProvider.future);
      expect(result, 'http://127.0.0.1:2222');
    });

    test('build returns null when nothing is persisted', () async {
      when(() => storage.getProxyUrl()).thenReturn(null);
      final result = await container.read(proxySettingsControllerProvider.future);
      expect(result, isNull);
    });

    test('setProxy persists and updates state', () async {
      when(() => storage.getProxyUrl()).thenReturn(null);
      when(() => storage.setProxyUrl(any())).thenAnswer((_) async {});
      await container.read(proxySettingsControllerProvider.future);

      await container
          .read(proxySettingsControllerProvider.notifier)
          .setProxy('http://127.0.0.1:2222');

      verify(() => storage.setProxyUrl('http://127.0.0.1:2222')).called(1);
      expect(
        container.read(proxySettingsControllerProvider).value,
        'http://127.0.0.1:2222',
      );
    });

    test(
      'setProxy throws FormatException for an invalid URL without touching storage',
      () async {
        when(() => storage.getProxyUrl()).thenReturn(null);
        await container.read(proxySettingsControllerProvider.future);

        await expectLater(
          () => container
              .read(proxySettingsControllerProvider.notifier)
              .setProxy('socks5://x:1'),
          throwsA(isA<FormatException>()),
        );
        verifyNever(() => storage.setProxyUrl(any()));
      },
    );

    test('clearProxy persists null and updates state', () async {
      when(() => storage.getProxyUrl()).thenReturn('http://127.0.0.1:2222');
      when(() => storage.setProxyUrl(any())).thenAnswer((_) async {});
      await container.read(proxySettingsControllerProvider.future);

      await container.read(proxySettingsControllerProvider.notifier).clearProxy();

      verify(() => storage.setProxyUrl(null)).called(1);
      expect(container.read(proxySettingsControllerProvider).value, isNull);
    });
  });
}
