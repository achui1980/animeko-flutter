// lib/data/auth/bangumi_oauth_models.dart

/// Response of GET /v2/users/bangumi/oauth and GET /v2/users/bangumi/bind.
/// Field shape verified against the Kotlin-generated
/// `AniOAuthRedirectResponse` model (client/src/commonMain/gen/.../models).
class OAuthRedirectResponse {
  const OAuthRedirectResponse({required this.url});

  final String url;

  factory OAuthRedirectResponse.fromJson(Map<String, dynamic> json) {
    return OAuthRedirectResponse(url: json['url'] as String);
  }
}

/// Verified against the Kotlin-generated `AniAniTokens` model.
class AniTokens {
  const AniTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtMillis,
    this.bangumiAccessToken,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresAtMillis;
  final String? bangumiAccessToken;

  factory AniTokens.fromJson(Map<String, dynamic> json) {
    return AniTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAtMillis: json['expiresAtMillis'] as int,
      bangumiAccessToken: json['bangumiAccessToken'] as String?,
    );
  }
}

/// Response of GET /v2/users/bangumi/result once the server has a result.
/// Verified against the Kotlin-generated `AniUserAuthRoutingLoginResponse`
/// model. The `user` field of the Kotlin model is intentionally omitted —
/// Phase 1a only needs `userId` and `tokens`.
class UserAuthRoutingLoginResponse {
  const UserAuthRoutingLoginResponse({
    required this.userId,
    required this.tokens,
  });

  final String userId;
  final AniTokens tokens;

  factory UserAuthRoutingLoginResponse.fromJson(Map<String, dynamic> json) {
    return UserAuthRoutingLoginResponse(
      userId: json['userId'] as String,
      tokens: AniTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}
