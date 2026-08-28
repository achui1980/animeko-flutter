// lib/data/auth_interceptor.dart
import 'dart:async';

import 'package:dio/dio.dart';

import 'auth/secure_token_storage.dart';

/// Returns true if the refresh succeeded (new tokens are now in storage),
/// false otherwise.
typedef RefreshTokenFn = Future<bool> Function();

/// Attaches the current Ani access token (if any) as a Bearer
/// Authorization header to every outgoing request made through the Dio
/// instance it is installed on, and on a 401 response attempts exactly
/// one token refresh + request retry before giving up. See Plan 1a
/// follow-up M3 and the Plan 1b series design doc's "网络层" section.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._storage, this._refresh);

  final Dio _dio;
  final SecureTokenStorage _storage;
  final RefreshTokenFn _refresh;

  static const _retriedFlag = 'ani_auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _attachToken(options).then((_) => handler.next(options));
  }

  Future<void> _attachToken(RequestOptions options) async {
    final session = await _storage.readSession();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.tokens.accessToken}';
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    if (status != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }
    unawaited(_retryAfterRefresh(err, handler));
  }

  Future<void> _retryAfterRefresh(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final refreshed = await _refresh();
    if (!refreshed) {
      handler.next(err);
      return;
    }
    final options = err.requestOptions;
    options.extra[_retriedFlag] = true;
    await _attachToken(options);
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
