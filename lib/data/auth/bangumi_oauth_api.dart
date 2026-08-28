import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'bangumi_oauth_models.dart';

part 'bangumi_oauth_api.g.dart';

/// Thin, hand-written wrapper around the three Bangumi-OAuth endpoints on
/// ani-api-server that Phase 1a needs. See design doc section 6 for the
/// full flow. These calls require no Authorization header (verified by
/// reading the Kotlin app's session-handling code: a fresh install has no
/// session, so the Ktor Auth plugin sends no header at all, and the server
/// accepts it for the register/bind/poll endpoints).
class BangumiOAuthApi {
  BangumiOAuthApi(this._dio);

  final Dio _dio;

  /// GET /v2/users/bangumi/oauth — register-new-account flow.
  Future<OAuthRedirectResponse> oauth({
    required String requestId,
    required String os,
    required String arch,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/users/bangumi/oauth',
      queryParameters: {'requestId': requestId, 'os': os, 'arch': arch},
    );
    return OAuthRedirectResponse.fromJson(response.data!);
  }

  /// GET /v2/users/bangumi/bind — bind-to-existing-account flow.
  Future<OAuthRedirectResponse> bind({
    required String requestId,
    required String os,
    required String arch,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/users/bangumi/bind',
      queryParameters: {'requestId': requestId, 'os': os, 'arch': arch},
    );
    return OAuthRedirectResponse.fromJson(response.data!);
  }

  /// GET /v2/users/bangumi/result — poll for the login result.
  ///
  /// Returns null when the server responds with HTTP 425 Too Early,
  /// meaning the Bangumi callback has not landed yet and the caller
  /// should retry after a delay. Any other error is rethrown.
  Future<UserAuthRoutingLoginResponse?> getResult(String requestId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v2/users/bangumi/result',
        queryParameters: {'requestId': requestId},
      );
      return UserAuthRoutingLoginResponse.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 425) {
        return null;
      }
      rethrow;
    }
  }
}

@riverpod
BangumiOAuthApi bangumiOAuthApi(Ref ref) {
  return BangumiOAuthApi(ref.watch(dioProvider));
}
