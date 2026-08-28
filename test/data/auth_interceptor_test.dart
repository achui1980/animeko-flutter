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
  _FakeAdapter(this.validBearer, {this.errorStatusCode = 401});

  final String validBearer;

  /// Status code returned when the Authorization header does not match
  /// [validBearer]. Defaults to 401 (the case the interceptor's
  /// refresh-and-retry logic is designed to handle); tests that want to
  /// verify non-401 errors pass through untouched can override this.
  final int errorStatusCode;
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
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      errorStatusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockSecureTokenStorage storage;

  setUp(() {
    storage = MockSecureTokenStorage();
  });

  Dio buildDio(
    _FakeAdapter adapter,
    SecureTokenStorage storage,
    RefreshTokenFn refresh,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio, storage, refresh));
    return dio;
  }

  test('attaches the stored access token as a Bearer header', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'u',
        tokens: AniTokens(
          accessToken: 'good-token',
          refreshToken: 'r',
          expiresAtMillis: 1,
        ),
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

    await expectLater(
      dio.get<Map<String, dynamic>>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.seenAuthHeaders, [null]);
  });

  test(
    'refreshes once and retries on a 401, succeeding with the fresh token',
    () async {
      var readCount = 0;
      when(() => storage.readSession()).thenAnswer((_) async {
        readCount++;
        final token = readCount == 1 ? 'stale-token' : 'fresh-token';
        return StoredSession(
          userId: 'u',
          tokens: AniTokens(
            accessToken: token,
            refreshToken: 'r',
            expiresAtMillis: 1,
          ),
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
      expect(adapter.seenAuthHeaders, [
        'Bearer stale-token',
        'Bearer fresh-token',
      ]);
    },
  );

  test(
    'gives up after a failed refresh without a second retry attempt',
    () async {
      when(() => storage.readSession()).thenAnswer(
        (_) async => const StoredSession(
          userId: 'u',
          tokens: AniTokens(
            accessToken: 'stale-token',
            refreshToken: 'r',
            expiresAtMillis: 1,
          ),
        ),
      );
      final adapter = _FakeAdapter('never-matches');
      var refreshCalls = 0;
      final dio = buildDio(adapter, storage, () async {
        refreshCalls++;
        return false;
      });

      await expectLater(
        dio.get<Map<String, dynamic>>('/x'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 1);
      expect(adapter.seenAuthHeaders, ['Bearer stale-token']);
    },
  );

  test(
    'non-401 errors pass through untouched and never trigger a refresh',
    () async {
      when(() => storage.readSession()).thenAnswer(
        (_) async => const StoredSession(
          userId: 'u',
          tokens: AniTokens(
            accessToken: 'good-token',
            refreshToken: 'r',
            expiresAtMillis: 1,
          ),
        ),
      );
      // validBearer never matches 'good-token', so every request falls into
      // the adapter's error branch, which here returns 500 instead of 401.
      final adapter = _FakeAdapter(
        'never-matches-anything',
        errorStatusCode: 500,
      );
      var refreshCalls = 0;
      final dio = buildDio(adapter, storage, () async {
        refreshCalls++;
        return true;
      });

      await expectLater(
        dio.get<Map<String, dynamic>>('/y'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 0);
    },
  );

  test(
    're-401 after a "successful" refresh does not trigger a second refresh call',
    () async {
      // storage always returns the same stale session -- the retried
      // request will therefore also fail to match the adapter's expected
      // bearer token, causing a *second* 401. The _retriedFlag must stop
      // the interceptor from calling refresh again for that second 401.
      when(() => storage.readSession()).thenAnswer(
        (_) async => const StoredSession(
          userId: 'u',
          tokens: AniTokens(
            accessToken: 'stale-token',
            refreshToken: 'r',
            expiresAtMillis: 1,
          ),
        ),
      );
      final adapter = _FakeAdapter('never-matches');
      var refreshCalls = 0;
      final dio = buildDio(adapter, storage, () async {
        refreshCalls++;
        return true;
      });

      await expectLater(
        dio.get<Map<String, dynamic>>('/x'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 1);
      expect(adapter.seenAuthHeaders, [
        'Bearer stale-token',
        'Bearer stale-token',
      ]);
    },
  );

  test('concurrent 401s share a single in-flight refresh call', () async {
    var readCount = 0;
    when(() => storage.readSession()).thenAnswer((_) async {
      readCount++;
      // Both concurrently-fired requests' initial token-attach calls
      // (readCount 1 and 2) must see the stale token so that they both
      // genuinely 401 and race into the refresh path -- only reads after
      // that (i.e. the post-refresh retries) should see the fresh token.
      final token = readCount <= 2 ? 'stale-token' : 'fresh-token';
      return StoredSession(
        userId: 'u',
        tokens: AniTokens(
          accessToken: token,
          refreshToken: 'r',
          expiresAtMillis: 1,
        ),
      );
    });
    final adapter = _FakeAdapter('fresh-token');
    var refreshCalls = 0;
    final dio = buildDio(adapter, storage, () async {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return true;
    });

    final responses = await Future.wait([
      dio.get<Map<String, dynamic>>('/x'),
      dio.get<Map<String, dynamic>>('/x'),
    ]);

    expect(responses[0].statusCode, 200);
    expect(responses[1].statusCode, 200);
    expect(refreshCalls, 1);
  });

  test('storage.readSession() throwing does not hang the request', () async {
    when(
      () => storage.readSession(),
    ).thenThrow(Exception('keychain unavailable'));
    final adapter = _FakeAdapter('irrelevant');
    var refreshCalls = 0;
    final dio = buildDio(adapter, storage, () async {
      refreshCalls++;
      return false;
    });

    await expectLater(
      dio.get<Map<String, dynamic>>('/x'),
      throwsA(isA<DioException>()),
    ).timeout(const Duration(seconds: 5));
    expect(adapter.seenAuthHeaders, [null]);
    // The 401 caused by the missing header still triggers exactly one
    // refresh attempt (as normal for any 401); the key assertion is that
    // the initial storage failure did not cause a hang.
    expect(refreshCalls, 1);
  });
}
