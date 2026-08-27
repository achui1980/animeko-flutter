// test/domain/auth/auth_controller_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_api.dart';
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/platform/browser_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockBangumiOAuthApi extends Mock implements BangumiOAuthApi {}

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class MockBrowserLauncher extends Mock implements BrowserLauncher {}

void main() {
  late MockBangumiOAuthApi api;
  late MockSecureTokenStorage storage;
  late MockBrowserLauncher launcher;
  late ProviderContainer container;

  setUpAll(() {
    // mocktail requires a registered fallback value for any() matchers
    // whose static type is a custom class (storage.saveTokens(any())
    // below uses AniTokens, which is not one of mocktail's built-in
    // registered types like String/int/bool).
    registerFallbackValue(
      const AniTokens(accessToken: '', refreshToken: '', expiresAtMillis: 0),
    );
  });

  setUp(() {
    api = MockBangumiOAuthApi();
    storage = MockSecureTokenStorage();
    launcher = MockBrowserLauncher();
    container = ProviderContainer(
      overrides: [
        bangumiOAuthApiProvider.overrideWithValue(api),
        secureTokenStorageProvider.overrideWithValue(storage),
        browserLauncherProvider.overrideWithValue(launcher),
        authPollIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);

    when(() => launcher.open(any())).thenAnswer((_) async => true);
    when(() => storage.saveTokens(any())).thenAnswer((_) async {});
  });

  test('initial state is AuthUnauthenticated', () {
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test(
    'register flow: oauth -> open browser -> poll (425 then success) -> authenticated',
    () async {
      when(
        () => api.oauth(
          requestId: any(named: 'requestId'),
          os: any(named: 'os'),
          arch: any(named: 'arch'),
        ),
      ).thenAnswer(
        (_) async => const OAuthRedirectResponse(url: 'https://bgm.tv/x'),
      );

      var callCount = 0;
      when(() => api.getResult(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return null; // simulates HTTP 425
        return const UserAuthRoutingLoginResponse(
          userId: 'user-1',
          tokens: AniTokens(
            accessToken: 'a',
            refreshToken: 'r',
            expiresAtMillis: 1,
          ),
        );
      });

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.login(isRegister: true);

      expect(callCount, 2);
      verify(() => launcher.open('https://bgm.tv/x')).called(1);
      verify(() => storage.saveTokens(any())).called(1);
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).userId, 'user-1');
    },
  );

  test('bind flow calls api.bind instead of api.oauth', () async {
    when(
      () => api.bind(
        requestId: any(named: 'requestId'),
        os: any(named: 'os'),
        arch: any(named: 'arch'),
      ),
    ).thenAnswer(
      (_) async => const OAuthRedirectResponse(url: 'https://bgm.tv/y'),
    );
    when(() => api.getResult(any())).thenAnswer(
      (_) async => const UserAuthRoutingLoginResponse(
        userId: 'user-2',
        tokens: AniTokens(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAtMillis: 1,
        ),
      ),
    );

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.login(isRegister: false);

    verify(
      () => api.bind(
        requestId: any(named: 'requestId'),
        os: any(named: 'os'),
        arch: any(named: 'arch'),
      ),
    ).called(1);
    verifyNever(
      () => api.oauth(
        requestId: any(named: 'requestId'),
        os: any(named: 'os'),
        arch: any(named: 'arch'),
      ),
    );
  });

  test('emits AuthError when the oauth call throws', () async {
    when(
      () => api.oauth(
        requestId: any(named: 'requestId'),
        os: any(named: 'os'),
        arch: any(named: 'arch'),
      ),
    ).thenThrow(Exception('network down'));

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.login(isRegister: true);

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthError>());
    expect((state as AuthError).message, contains('network down'));
  });
}
