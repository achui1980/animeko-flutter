// test/domain/auth/auth_controller_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_api.dart';
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/refresh_result.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth/session_refresher.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/platform/browser_launcher.dart';
import 'package:animeko_flutter/platform/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockBangumiOAuthApi extends Mock implements BangumiOAuthApi {}

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class MockBrowserLauncher extends Mock implements BrowserLauncher {}

class MockSessionRefresher extends Mock implements SessionRefresher {}

void main() {
  late MockBangumiOAuthApi api;
  late MockSecureTokenStorage storage;
  late MockBrowserLauncher launcher;
  late MockSessionRefresher refresher;
  late ProviderContainer container;

  setUpAll(() {
    // mocktail requires a registered fallback value for any() matchers
    // whose static type is a custom class (storage.saveSession(any())
    // below uses StoredSession, which is not one of mocktail's built-in
    // registered types like String/int/bool).
    registerFallbackValue(
      const StoredSession(
        userId: '',
        tokens: AniTokens(accessToken: '', refreshToken: '', expiresAtMillis: 0),
      ),
    );
  });

  setUp(() {
    api = MockBangumiOAuthApi();
    storage = MockSecureTokenStorage();
    launcher = MockBrowserLauncher();
    refresher = MockSessionRefresher();
    container = ProviderContainer(
      overrides: [
        bangumiOAuthApiProvider.overrideWithValue(api),
        secureTokenStorageProvider.overrideWithValue(storage),
        browserLauncherProvider.overrideWithValue(launcher),
        sessionRefresherProvider.overrideWithValue(refresher),
        authPollIntervalProvider.overrideWithValue(Duration.zero),
        platformInfoProvider.overrideWithValue(
          const PlatformInfo(os: 'macos', arch: 'aarch64'),
        ),
      ],
    );
    addTearDown(container.dispose);

    when(() => launcher.open(any())).thenAnswer((_) async => true);
    when(() => storage.saveSession(any())).thenAnswer((_) async {});
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
      final captured = verify(
        () => api.oauth(
          requestId: captureAny(named: 'requestId'),
          os: captureAny(named: 'os'),
          arch: captureAny(named: 'arch'),
        ),
      ).captured;
      expect(
        captured[0],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(captured[1], 'macos');
      expect(captured[2], 'aarch64');
      verify(() => launcher.open('https://bgm.tv/x')).called(1);
      verify(() => storage.saveSession(any())).called(1);
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

  test('restoreSession does nothing when no session is stored', () async {
    when(() => storage.readSession()).thenAnswer((_) async => null);

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('restoreSession authenticates immediately for an unexpired token', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => StoredSession(
        userId: 'user-3',
        tokens: AniTokens(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAtMillis: DateTime.now().millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
        ),
      ),
    );

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).userId, 'user-3');
    verifyNever(() => refresher.refresh(any()));
  });

  test('restoreSession refreshes an expired token and authenticates on success', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'user-4',
        tokens: AniTokens(accessToken: 'stale', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    when(() => refresher.refresh('r')).thenAnswer(
      (_) async => const RefreshSuccess(
        StoredSession(
          userId: 'user-4',
          tokens: AniTokens(accessToken: 'fresh', refreshToken: 'r2', expiresAtMillis: 999999999999),
        ),
      ),
    );

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).userId, 'user-4');
  });

  test('restoreSession refreshes a token inside the 5-minute safety margin', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => StoredSession(
        userId: 'user-6',
        tokens: AniTokens(
          accessToken: 'stale',
          refreshToken: 'r',
          expiresAtMillis: DateTime.now().millisecondsSinceEpoch + const Duration(minutes: 3).inMilliseconds,
        ),
      ),
    );
    when(() => refresher.refresh('r')).thenAnswer(
      (_) async => const RefreshSuccess(
        StoredSession(
          userId: 'user-6',
          tokens: AniTokens(accessToken: 'fresh', refreshToken: 'r2', expiresAtMillis: 999999999999),
        ),
      ),
    );

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    verify(() => refresher.refresh('r')).called(1);
    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).userId, 'user-6');
  });

  test('restoreSession stays unauthenticated when refreshing an expired token fails', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'user-5',
        tokens: AniTokens(accessToken: 'stale', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    when(() => refresher.refresh('r')).thenAnswer((_) async => const RefreshFailure(NetworkError()));

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test(
    'restoreSession stays unauthenticated (and returns quickly) when refresh hangs '
    'longer than the startup timeout',
    () async {
      when(() => storage.readSession()).thenAnswer(
        (_) async => const StoredSession(
          userId: 'user-7',
          tokens: AniTokens(accessToken: 'stale', refreshToken: 'r', expiresAtMillis: 1),
        ),
      );
      // Slower than the 3s startup timeout, but bounded so the test itself
      // can't hang forever if the fix regresses.
      when(() => refresher.refresh('r')).thenAnswer(
        (_) => Future.delayed(
          const Duration(seconds: 10),
          () => const RefreshSuccess(
            StoredSession(
              userId: 'user-7',
              tokens: AniTokens(accessToken: 'fresh', refreshToken: 'r2', expiresAtMillis: 999999999999),
            ),
          ),
        ),
      );

      final notifier = container.read(authControllerProvider.notifier);
      final stopwatch = Stopwatch()..start();
      await notifier.restoreSession();
      stopwatch.stop();

      // Proves the app-level timeout fired rather than the test just
      // eventually awaiting the mock's real 10s delayed result.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    },
  );
}
