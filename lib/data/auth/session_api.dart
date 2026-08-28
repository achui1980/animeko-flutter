// lib/data/auth/session_api.dart
import 'package:dio/dio.dart';

import 'bangumi_oauth_models.dart';

/// POST /v2/users/auth/refresh -- refreshes an Ani session using a stored
/// refresh token. Verified against the Kotlin-generated
/// `UserAuthenticationAniApi.refreshToken` / `AniRefreshTokenRequest` /
/// `AniUserAuthRoutingLoginResponse` models (NOT
/// `/v2/users/bangumi/loginWithRefreshToken`, which binds an Ani account
/// to an existing *Bangumi* refresh token -- a different, unrelated
/// operation. See this plan's header for the correction.)
class SessionApi {
  SessionApi(this._dio);

  final Dio _dio;

  Future<UserAuthRoutingLoginResponse> refreshToken(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v2/users/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return UserAuthRoutingLoginResponse.fromJson(response.data!);
  }
}
