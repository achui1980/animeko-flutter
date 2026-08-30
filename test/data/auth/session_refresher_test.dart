// test/data/auth/session_refresher_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/refresh_result.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth/session_api.dart';
import 'package:animeko_flutter/data/auth/session_refresher.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionApi extends Mock implements SessionApi {}

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late MockSessionApi api;
  late MockSecureTokenStorage storage;
  late SessionRefresher refresher;

  setUpAll(() {
    registerFallbackValue(
      const StoredSession(
        userId: '',
        tokens: AniTokens(
          accessToken: '',
          refreshToken: '',
          expiresAtMillis: 0,
        ),
      ),
    );
  });

  setUp(() {
    api = MockSessionApi();
    storage = MockSecureTokenStorage();
    refresher = SessionRefresher(api, storage);
  });

  test('a successful refresh persists and returns RefreshSuccess', () async {
    const response = UserAuthRoutingLoginResponse(
      userId: 'user-1',
      tokens: AniTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresAtMillis: 999,
      ),
    );
    when(() => api.refreshToken('old-refresh')).thenAnswer(
      (_) async => response,
    );
    when(() => storage.saveSession(any())).thenAnswer((_) async {});

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshSuccess>());
    final session = (result as RefreshSuccess).session;
    expect(session.userId, 'user-1');
    expect(session.tokens.accessToken, 'new-access');
    verify(() => storage.saveSession(any())).called(1);
  });

  test('a failed API refresh clears storage and returns RefreshFailure', () async {
    when(() => api.refreshToken('old-refresh')).thenThrow(
      Exception('refresh token rejected'),
    );
    when(() => storage.clear()).thenAnswer((_) async {});

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshFailure>());
    expect((result as RefreshFailure).error, isA<UnknownAppError>());
    verify(() => storage.clear()).called(1);
  });

  test('a successful API refresh but a failed local save does NOT clear storage', () async {
    const response = UserAuthRoutingLoginResponse(
      userId: 'user-1',
      tokens: AniTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresAtMillis: 999,
      ),
    );
    when(() => api.refreshToken('old-refresh')).thenAnswer(
      (_) async => response,
    );
    when(() => storage.saveSession(any())).thenThrow(
      Exception('keychain unavailable'),
    );

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshFailure>());
    verifyNever(() => storage.clear());
  });

  test('refresh() never throws even if clearing storage itself fails', () async {
    when(() => api.refreshToken('old-refresh')).thenThrow(
      Exception('refresh token rejected'),
    );
    when(() => storage.clear()).thenThrow(Exception('keychain unavailable'));

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshFailure>());
  });
}
