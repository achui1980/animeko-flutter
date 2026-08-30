// lib/data/api_client.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth/refresh_result.dart';
import 'auth/secure_token_storage.dart';
import 'auth/session_refresher.dart';
import 'auth_interceptor.dart';

part 'api_client.g.dart';

/// Single fixed ani-api-server endpoint for Phase 1. No failover to
/// alternate servers (danmaku-cn/danmaku-global/s1-animeko) is implemented
/// — see design doc "本地持久化"/服务器地址处理 note under Phase 1 scope.
const aniApiBaseUrl = 'https://api.animeko.org';

const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 15);

/// A plain `Dio` pointed at [aniApiBaseUrl] with no interceptors attached.
/// Used both by the main `dio()` provider (as its starting point, before
/// interceptors are added) and by anything that must never recurse
/// through [AuthInterceptor] -- see `SessionRefresher`.
Dio rawAniDio() {
  return Dio(
    BaseOptions(
      baseUrl: aniApiBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    ),
  );
}

/// Attempts a token refresh and translates the outcome into the plain
/// boolean contract required by [AuthInterceptor]'s [RefreshTokenFn].
///
/// Extracted as a standalone (rather than inline-closure) function so it
/// can be unit-tested directly with a mocked [SessionRefresher] -- see
/// `test/data/api_client_test.dart`. This matters because
/// [SessionRefresher.refresh] returns a non-nullable [RefreshResult]
/// (never `null`), so the boolean must come from a switch/pattern match
/// on [RefreshSuccess] vs [RefreshFailure] rather than a null check.
Future<bool> refreshTokenForInterceptor(
  SecureTokenStorage storage,
  SessionRefresher refresher,
) async {
  final session = await storage.readSession();
  if (session == null) return false;
  final result = await refresher.refresh(session.tokens.refreshToken);
  return switch (result) {
    RefreshSuccess() => true,
    RefreshFailure() => false,
  };
}

@riverpod
Dio dio(Ref ref) {
  final dio = rawAniDio();
  final storage = ref.watch(secureTokenStorageProvider);
  final refresher = ref.watch(sessionRefresherProvider);

  dio.interceptors.add(
    AuthInterceptor(
      dio,
      storage,
      () => refreshTokenForInterceptor(storage, refresher),
    ),
  );

  return dio;
}
