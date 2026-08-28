// test/data/auth/session_refresher_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth/session_api.dart';
import 'package:animeko_flutter/data/auth/session_refresher.dart';
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

  test('a successful refresh persists and returns the new session', () async {
    when(() => api.refreshToken('old-refresh')).thenAnswer(
      (_) async => const UserAuthRoutingLoginResponse(
        userId: 'user-1',
        tokens: AniTokens(
          accessToken: 'new-a',
          refreshToken: 'new-r',
          expiresAtMillis: 999,
        ),
      ),
    );
    when(() => storage.saveSession(any())).thenAnswer((_) async {});

    final session = await refresher.refresh('old-refresh');

    expect(session, isNotNull);
    expect(session!.userId, 'user-1');
    verify(() => storage.saveSession(any())).called(1);
  });

  test('a failed refresh clears storage and returns null', () async {
    when(() => api.refreshToken('expired')).thenThrow(Exception('401'));
    when(() => storage.clear()).thenAnswer((_) async {});

    final session = await refresher.refresh('expired');

    expect(session, isNull);
    verify(() => storage.clear()).called(1);
  });

  test(
    'a successful API refresh but a failed local save does NOT clear storage',
    () async {
      when(() => api.refreshToken('old-refresh')).thenAnswer(
        (_) async => const UserAuthRoutingLoginResponse(
          userId: 'user-1',
          tokens: AniTokens(
            accessToken: 'new-a',
            refreshToken: 'new-r',
            expiresAtMillis: 999,
          ),
        ),
      );
      when(() => storage.saveSession(any())).thenThrow(Exception('disk full'));

      final session = await refresher.refresh('old-refresh');

      expect(session, isNull);
      verifyNever(() => storage.clear());
    },
  );

  test(
    'refresh() never throws even if clearing storage itself fails',
    () async {
      when(() => api.refreshToken('expired')).thenThrow(Exception('401'));
      when(() => storage.clear()).thenThrow(Exception('keychain unavailable'));

      final session = await refresher.refresh('expired');

      expect(session, isNull);
    },
  );
}
