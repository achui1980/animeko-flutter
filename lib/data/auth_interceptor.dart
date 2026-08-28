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

  /// Tracks a single in-flight refresh attempt so concurrent 401s (e.g.
  /// several requests failing around the same time) share one refresh
  /// call instead of each independently racing the server -- important
  /// because a naive N-way race can have one successful refresh's
  /// session wiped out by another's "failed" refresh (which clears
  /// storage) if the server rotates refresh tokens on use.
  Future<bool>? _inFlightRefresh;

  Future<bool> _refreshOnce() {
    return _inFlightRefresh ??= _refresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _attachToken(options).then(
      (_) => handler.next(options),
      onError: (Object error, StackTrace stackTrace) {
        // If reading the stored session itself fails (e.g. a Keychain
        // access error), we must still resolve the interceptor chain --
        // otherwise the request hangs forever with no way for the caller
        // to ever see an error. Proceed without a token; the server will
        // (correctly) respond 401, which the normal onError/refresh path
        // below already knows how to handle.
        handler.next(options);
      },
    );
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
    try {
      final refreshed = await _refreshOnce();
      if (!refreshed) {
        handler.next(err);
        return;
      }
      final options = err.requestOptions;
      options.extra[_retriedFlag] = true;
      await _attachToken(options);
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      // Any other unexpected failure (e.g. the refresh callback itself
      // throwing) must still resolve the interceptor chain with the
      // *original* 401 error rather than hanging forever.
      handler.next(err);
    }
  }
}
