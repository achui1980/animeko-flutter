// test/data/api_client_test.dart
import 'package:animeko_flutter/data/api_client.dart';
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/refresh_result.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth/session_refresher.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

class MockSessionRefresher extends Mock implements SessionRefresher {}

void main() {
  late MockSecureTokenStorage storage;
  late MockSessionRefresher refresher;

  const session = StoredSession(
    userId: 'u',
    tokens: AniTokens(
      accessToken: 'access',
      refreshToken: 'old-refresh',
      expiresAtMillis: 1,
    ),
  );

  setUp(() {
    storage = MockSecureTokenStorage();
    refresher = MockSessionRefresher();
  });

  group('refreshTokenForInterceptor', () {
    test('returns false when there is no stored session', () async {
      when(() => storage.readSession()).thenAnswer((_) async => null);

      final result = await refreshTokenForInterceptor(storage, refresher);

      expect(result, isFalse);
      verifyNever(() => refresher.refresh(any()));
    });

    test('returns true when SessionRefresher reports RefreshSuccess', () async {
      when(() => storage.readSession()).thenAnswer((_) async => session);
      when(() => refresher.refresh('old-refresh')).thenAnswer(
        (_) async => const RefreshSuccess(session),
      );

      final result = await refreshTokenForInterceptor(storage, refresher);

      expect(result, isTrue);
    });

    test(
      'returns false when SessionRefresher reports RefreshFailure '
      '(this is the exact regression: refresh() used to return a '
      'nullable StoredSession?, so a non-null RefreshResult must not '
      'be mistaken for success)',
      () async {
        when(() => storage.readSession()).thenAnswer((_) async => session);
        when(() => refresher.refresh('old-refresh')).thenAnswer(
          (_) async => const RefreshFailure(AuthExpiredError()),
        );

        final result = await refreshTokenForInterceptor(storage, refresher);

        expect(result, isFalse);
      },
    );
  });
}
