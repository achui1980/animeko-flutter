// test/data/auth_interceptor_test.dart
import 'dart:typed_data';

import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

/// A fake transport that inspects the Authorization header it was sent
/// and returns 200 for a "valid" header, 401 otherwise -- lets us test the
/// interceptor's retry logic without a real network call.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.validBearer);

  final String validBearer;
  final List<String?> seenAuthHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final header = options.headers['Authorization'] as String?;
    seenAuthHeaders.add(header);
    if (header == 'Bearer $validBearer') {
      return ResponseBody.fromString('{"ok":true}', 200, headers: {
        'content-type': ['application/json'],
      });
    }
    return ResponseBody.fromString('{}', 401, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockSecureTokenStorage storage;

  setUp(() {
    storage = MockSecureTokenStorage();
  });

  Dio buildDio(_FakeAdapter adapter, SecureTokenStorage storage, RefreshTokenFn refresh) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio, storage, refresh));
    return dio;
  }

  test('attaches the stored access token as a Bearer header', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'u',
        tokens: AniTokens(accessToken: 'good-token', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    final adapter = _FakeAdapter('good-token');
    final dio = buildDio(adapter, storage, () async => false);

    final response = await dio.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(adapter.seenAuthHeaders, ['Bearer good-token']);
  });

  test('sends no Authorization header when nothing is stored', () async {
    when(() => storage.readSession()).thenAnswer((_) async => null);
    final adapter = _FakeAdapter('irrelevant');
    final dio = buildDio(adapter, storage, () async => false);

    await expectLater(dio.get<Map<String, dynamic>>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seenAuthHeaders, [null]);
  });

  test('refreshes once and retries on a 401, succeeding with the fresh token', () async {
    var readCount = 0;
    when(() => storage.readSession()).thenAnswer((_) async {
      readCount++;
      final token = readCount == 1 ? 'stale-token' : 'fresh-token';
      return StoredSession(
        userId: 'u',
        tokens: AniTokens(accessToken: token, refreshToken: 'r', expiresAtMillis: 1),
      );
    });
    final adapter = _FakeAdapter('fresh-token');
    var refreshCalls = 0;
    final dio = buildDio(adapter, storage, () async {
      refreshCalls++;
      return true;
    });

    final response = await dio.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(adapter.seenAuthHeaders, ['Bearer stale-token', 'Bearer fresh-token']);
  });

  test('gives up after a failed refresh without a second retry attempt', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'u',
        tokens: AniTokens(accessToken: 'stale-token', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    final adapter = _FakeAdapter('never-matches');
    var refreshCalls = 0;
    final dio = buildDio(adapter, storage, () async {
      refreshCalls++;
      return false;
    });

    await expectLater(dio.get<Map<String, dynamic>>('/x'), throwsA(isA<DioException>()));
    expect(refreshCalls, 1);
    expect(adapter.seenAuthHeaders, ['Bearer stale-token']);
  });
}
