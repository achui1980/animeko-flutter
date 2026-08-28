// test/data/auth/secure_token_storage_test.dart
import 'dart:convert';

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

  test('saveSession writes userId and the full token triple as one JSON blob', () async {
    when(
      () => backing.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((_) async {});

    await storage.saveSession(
      const StoredSession(
        userId: 'user-1',
        tokens: AniTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          expiresAtMillis: 1700000000000,
        ),
      ),
    );

    final captured = verify(
      () => backing.write(key: 'ani_session', value: captureAny(named: 'value')),
    ).captured.single as String;
    final decoded = jsonDecode(captured) as Map<String, dynamic>;
    expect(decoded, {
      'userId': 'user-1',
      'accessToken': 'access-1',
      'refreshToken': 'refresh-1',
      'expiresAtMillis': 1700000000000,
      'bangumiAccessToken': null,
    });
  });

  test('readSession round-trips a previously saved session', () async {
    when(() => backing.read(key: 'ani_session')).thenAnswer(
      (_) async => jsonEncode({
        'userId': 'user-2',
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresAtMillis': 42,
        'bangumiAccessToken': 'bgm-token',
      }),
    );

    final session = await storage.readSession();

    expect(session, isNotNull);
    expect(session!.userId, 'user-2');
    expect(session.tokens.accessToken, 'a');
    expect(session.tokens.bangumiAccessToken, 'bgm-token');
  });

  test('readSession returns null when nothing is stored', () async {
    when(() => backing.read(key: 'ani_session')).thenAnswer((_) async => null);

    expect(await storage.readSession(), isNull);
  });

  test('readSession returns null for corrupt JSON instead of throwing', () async {
    when(() => backing.read(key: 'ani_session')).thenAnswer((_) async => 'not json{{{');

    expect(await storage.readSession(), isNull);
  });

  test('clear deletes the single session key', () async {
    when(() => backing.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    await storage.clear();

    verify(() => backing.delete(key: 'ani_session')).called(1);
  });
}
