// test/data/auth/secure_token_storage_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage backing;
  late SecureTokenStorage storage;

  setUp(() {
    backing = MockFlutterSecureStorage();
    storage = SecureTokenStorage(backing);
  });

  test(
    'saveTokens writes accessToken, refreshToken, expiresAtMillis',
    () async {
      when(
        () => backing.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await storage.saveTokens(
        const AniTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          expiresAtMillis: 1700000000000,
        ),
      );

      verify(
        () => backing.write(key: 'ani_access_token', value: 'access-1'),
      ).called(1);
      verify(
        () => backing.write(key: 'ani_refresh_token', value: 'refresh-1'),
      ).called(1);
      verify(
        () =>
            backing.write(key: 'ani_expires_at_millis', value: '1700000000000'),
      ).called(1);
    },
  );

  test(
    'readAccessToken reads from the same key saveTokens writes to',
    () async {
      when(
        () => backing.read(key: 'ani_access_token'),
      ).thenAnswer((_) async => 'stored-token');

      final result = await storage.readAccessToken();

      expect(result, 'stored-token');
    },
  );

  test('readAccessToken returns null when nothing stored', () async {
    when(
      () => backing.read(key: 'ani_access_token'),
    ).thenAnswer((_) async => null);

    final result = await storage.readAccessToken();

    expect(result, isNull);
  });

  test(
    'readRefreshToken reads from the same key saveTokens writes to',
    () async {
      when(
        () => backing.read(key: 'ani_refresh_token'),
      ).thenAnswer((_) async => 'stored-refresh');

      final result = await storage.readRefreshToken();

      expect(result, 'stored-refresh');
    },
  );

  test('clear deletes all three keys', () async {
    when(() => backing.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    await storage.clear();

    verify(() => backing.delete(key: 'ani_access_token')).called(1);
    verify(() => backing.delete(key: 'ani_refresh_token')).called(1);
    verify(() => backing.delete(key: 'ani_expires_at_millis')).called(1);
  });
}
