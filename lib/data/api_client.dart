// lib/data/api_client.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

@riverpod
Dio dio(Ref ref) {
  final dio = rawAniDio();
  final storage = ref.watch(secureTokenStorageProvider);
  final refresher = ref.watch(sessionRefresherProvider);

  dio.interceptors.add(
    AuthInterceptor(dio, storage, () async {
      final session = await storage.readSession();
      if (session == null) return false;
      final refreshed = await refresher.refresh(session.tokens.refreshToken);
      return refreshed != null;
    }),
  );

  return dio;
}
