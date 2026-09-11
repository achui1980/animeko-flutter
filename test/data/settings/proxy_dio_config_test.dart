import 'dart:io';

import 'package:animeko_flutter/data/settings/proxy_dio_config.dart';
import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:animeko_flutter/domain/settings/proxy_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSettingsStorage extends Mock implements SettingsStorage {}

void main() {
  group('proxy liveness across startup', () {
    // Regression guard for "the proxy setting is forgotten every time the app
    // starts, I have to re-save it before episodes will load".
    //
    // findProxy (see configureProxy) reads the provider *synchronously* and
    // takes `.value`, which is null while the async build() is in flight. So
    // the provider element pre-warmed in main() must still be alive -- and
    // still hold its AsyncData -- by the time the first HTTP request happens.
    // If it gets auto-disposed in between, every read re-mounts a fresh
    // AsyncLoading element and every request silently decides DIRECT.
    test(
      'a synchronous read still sees the proxy after the startup pre-warm',
      () async {
        final storage = MockSettingsStorage();
        when(() => storage.getProxyUrl()).thenReturn('http://127.0.0.1:2222');
        final container = ProviderContainer(
          overrides: [
            settingsStorageProvider.overrideWith((ref) async => storage),
          ],
        );
        addTearDown(container.dispose);

        // main()'s pre-warm.
        await container.read(proxySettingsControllerProvider.future);

        // Let any scheduled auto-disposal run, as it would in the gap
        // between runApp() and the first network request.
        await Future<void>.delayed(Duration.zero);

        // findProxy's synchronous read.
        expect(
          decideProxy(container.read(proxySettingsControllerProvider).value),
          'PROXY 127.0.0.1:2222',
        );
      },
    );
  });

  group('decideProxy', () {
    test('returns DIRECT when proxyUrl is null', () {
      expect(decideProxy(null), 'DIRECT');
    });

    test('returns DIRECT when proxyUrl is empty', () {
      expect(decideProxy(''), 'DIRECT');
    });

    test('returns a PROXY directive for a valid http:// URL', () {
      expect(decideProxy('http://127.0.0.1:2222'), 'PROXY 127.0.0.1:2222');
    });

    test('returns DIRECT for a malformed proxyUrl', () {
      expect(decideProxy('not a url'), 'DIRECT');
    });

    test('returns DIRECT when the URL has no explicit port', () {
      // Regression guard: `Uri.port` defaults to 80 for http URLs with no
      // explicit port, it is never 0 -- so a naive `uri.port == 0` check
      // would silently treat this as `PROXY 127.0.0.1:80` instead of
      // rejecting it. Must use `!uri.hasPort` instead.
      expect(decideProxy('http://127.0.0.1'), 'DIRECT');
    });

    test('returns the PROXY directive for a non-loopback request', () {
      expect(
        decideProxy(
          'http://127.0.0.1:2222',
          requestUri: Uri.parse('https://api.bgm.tv/v0/episodes'),
        ),
        'PROXY 127.0.0.1:2222',
      );
    });

    test('keeps loopback requests direct even when a proxy is set', () {
      // The rqbit sidecar's HTTP API and the local streaming URLs it hands
      // to the player both live on 127.0.0.1; sending those through an
      // external proxy would break playback.
      for (final target in [
        'http://127.0.0.1:3030/torrents',
        'http://localhost:3030/torrents',
        'http://[::1]:3030/torrents',
      ]) {
        expect(
          decideProxy('http://127.0.0.1:2222', requestUri: Uri.parse(target)),
          'DIRECT',
          reason: target,
        );
      }
    });
  });

  group('ProxyHttpOverrides', () {
    test('routes every newly created HttpClient through the proxy', () {
      final client = _RecordingHttpClient();
      final overrides = ProxyHttpOverrides(
        () => 'http://127.0.0.1:2222',
        createClient: (_) => client,
      );

      expect(overrides.createHttpClient(null), same(client));
      expect(
        client.recordedFindProxy!(Uri.parse('https://api.animeko.org/v1/me')),
        'PROXY 127.0.0.1:2222',
      );
    });

    test('re-reads the setting on every request', () {
      String? proxyUrl;
      final overrides = ProxyHttpOverrides(() => proxyUrl);
      final target = Uri.parse('https://api.animeko.org/v1/me');

      expect(overrides.proxyDirectiveFor(target), 'DIRECT');
      proxyUrl = 'http://127.0.0.1:2222';
      expect(overrides.proxyDirectiveFor(target), 'PROXY 127.0.0.1:2222');
    });
  });

  group('installProxyHttpOverrides', () {
    late HttpOverrides? previous;

    // `HttpOverrides.global` is a setter with no getter; `current` reads it
    // back (there is no enclosing HttpOverrides zone in a plain test).
    setUp(() => previous = HttpOverrides.current);
    tearDown(() => HttpOverrides.global = previous);

    test('proxies process-wide traffic, including images and token '
        'refreshes, from the container\'s proxy setting', () async {
      final storage = MockSettingsStorage();
      when(() => storage.getProxyUrl()).thenReturn('http://127.0.0.1:2222');
      final container = ProviderContainer(
        overrides: [
          settingsStorageProvider.overrideWith((ref) async => storage),
        ],
      );
      addTearDown(container.dispose);
      await container.read(proxySettingsControllerProvider.future);

      installProxyHttpOverrides(container);

      // Flutter's image loading and `rawAniDio()` (used by the session
      // refresher) both build their HttpClient via the bare `HttpClient()`
      // constructor, which dart:io routes through HttpOverrides.current --
      // so installing this is what makes those honour the proxy.
      final overrides = HttpOverrides.current;
      expect(overrides, isA<ProxyHttpOverrides>());
      expect(
        (overrides! as ProxyHttpOverrides).proxyDirectiveFor(
          Uri.parse('https://lain.bgm.tv/pic/cover/l/foo.jpg'),
        ),
        'PROXY 127.0.0.1:2222',
      );
    });
  });
}

/// Captures the `findProxy` callback that [ProxyHttpOverrides] installs.
/// [HttpClient.findProxy] is a setter with no matching getter, so recording
/// it is the only way to assert on what got wired up.
class _RecordingHttpClient implements HttpClient {
  String Function(Uri url)? recordedFindProxy;

  @override
  set findProxy(String Function(Uri url)? f) => recordedFindProxy = f;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
