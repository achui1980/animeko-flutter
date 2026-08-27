// test/data/auth/bangumi_oauth_models_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OAuthRedirectResponse', () {
    test('parses url from json', () {
      final result = OAuthRedirectResponse.fromJson({
        'url': 'https://bgm.tv/oauth/authorize?client_id=1&state=req-1',
      });
      expect(result.url, 'https://bgm.tv/oauth/authorize?client_id=1&state=req-1');
    });
  });

  group('AniTokens', () {
    test('parses required fields and null bangumiAccessToken', () {
      final result = AniTokens.fromJson({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresAtMillis': 1700000000000,
      });
      expect(result.accessToken, 'access-1');
      expect(result.refreshToken, 'refresh-1');
      expect(result.expiresAtMillis, 1700000000000);
      expect(result.bangumiAccessToken, isNull);
    });

    test('parses optional bangumiAccessToken when present', () {
      final result = AniTokens.fromJson({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresAtMillis': 1700000000000,
        'bangumiAccessToken': 'bgm-token-1',
      });
      expect(result.bangumiAccessToken, 'bgm-token-1');
    });
  });

  group('UserAuthRoutingLoginResponse', () {
    test('parses nested tokens object', () {
      final result = UserAuthRoutingLoginResponse.fromJson({
        'userId': 'user-42',
        'tokens': {
          'accessToken': 'access-1',
          'refreshToken': 'refresh-1',
          'expiresAtMillis': 1700000000000,
        },
      });
      expect(result.userId, 'user-42');
      expect(result.tokens.accessToken, 'access-1');
    });
  });
}
