// lib/data/auth/secure_token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'bangumi_oauth_models.dart';

part 'secure_token_storage.g.dart';

/// Persists Bangumi-OAuth-derived Ani JWT tokens in the platform secure
/// store (Keychain on macOS). Kept separate from `shared_preferences`
/// (used for non-sensitive UI settings elsewhere) per the design doc's
/// "本地持久化" decision.
class SecureTokenStorage {
  SecureTokenStorage(this._backing);

  final FlutterSecureStorage _backing;

  static const _accessTokenKey = 'ani_access_token';
  static const _refreshTokenKey = 'ani_refresh_token';
  static const _expiresAtKey = 'ani_expires_at_millis';

  /// Persists [tokens]. Note: [AniTokens.bangumiAccessToken] is not stored
  /// (Phase 1a only needs the Ani JWT pair), and `expiresAtMillis` is
  /// currently write-only — reading it back for expiry checks is deferred
  /// to the session-restore work in Plan 1b.
  Future<void> saveTokens(AniTokens tokens) async {
    await _backing.write(key: _accessTokenKey, value: tokens.accessToken);
    await _backing.write(key: _refreshTokenKey, value: tokens.refreshToken);
    await _backing.write(
      key: _expiresAtKey,
      value: tokens.expiresAtMillis.toString(),
    );
  }

  Future<String?> readAccessToken() => _backing.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _backing.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _backing.delete(key: _accessTokenKey);
    await _backing.delete(key: _refreshTokenKey);
    await _backing.delete(key: _expiresAtKey);
  }
}

@riverpod
SecureTokenStorage secureTokenStorage(Ref ref) {
  // `usesDataProtectionKeychain` defaults to true in flutter_secure_storage,
  // which makes the plugin pass `kSecUseDataProtectionKeychain` to every
  // Keychain query. That keychain requires the binary to be signed with a
  // real Apple Team ID (`application-identifier` /
  // `keychain-access-groups` entitlements); locally signed builds fail with
  // `errSecMissingEntitlement` (-34018). We use the legacy file-based
  // keychain instead, which works for both local and distributed builds.
  return SecureTokenStorage(
    const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  );
}
