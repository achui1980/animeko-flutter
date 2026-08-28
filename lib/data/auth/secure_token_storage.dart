// lib/data/auth/secure_token_storage.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'bangumi_oauth_models.dart';

part 'secure_token_storage.g.dart';

/// A logged-in user's id plus their Ani token triple -- everything needed
/// to both display "logged in as X" and refresh the session without a
/// round trip through the Bangumi OAuth flow again.
class StoredSession {
  const StoredSession({required this.userId, required this.tokens});

  final String userId;
  final AniTokens tokens;
}

/// Persists the current [StoredSession] in the platform secure store
/// (Keychain on macOS) as a single atomically-written JSON blob under one
/// key, rather than several separate keys (Plan 1a follow-up I5): a save
/// is one write (no risk of a partial userId/access/refresh/expiry
/// combination if the process is interrupted mid-write) and a restore is
/// one read.
class SecureTokenStorage {
  SecureTokenStorage(this._backing);

  final FlutterSecureStorage _backing;

  static const _sessionKey = 'ani_session';

  Future<void> saveSession(StoredSession session) {
    return _backing.write(
      key: _sessionKey,
      value: jsonEncode({
        'userId': session.userId,
        'accessToken': session.tokens.accessToken,
        'refreshToken': session.tokens.refreshToken,
        'expiresAtMillis': session.tokens.expiresAtMillis,
        'bangumiAccessToken': session.tokens.bangumiAccessToken,
      }),
    );
  }

  /// Reads back the stored session, or null if nothing is stored, the
  /// stored value is corrupt, or the underlying platform-channel read
  /// itself fails for any reason (Keychain I/O failure, binding not yet
  /// initialized, permissions, etc.) -- this method never throws, mirroring
  /// the "never throws" contract of `SessionRefresher.refresh()`.
  Future<StoredSession?> readSession() async {
    try {
      final raw = await _backing.read(key: _sessionKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return StoredSession(
        userId: json['userId'] as String,
        tokens: AniTokens.fromJson(json),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => _backing.delete(key: _sessionKey);
}

@riverpod
SecureTokenStorage secureTokenStorage(Ref ref) {
  // usesDataProtectionKeychain defaults to true in flutter_secure_storage,
  // which requires the binary to be signed with a real Apple Team ID;
  // locally signed builds fail with errSecMissingEntitlement (-34018). We
  // use the legacy file-based keychain instead, which works for both
  // local and distributed builds. (Plan 1a follow-up M8 flags this as an
  // unconditional security tradeoff worth revisiting for signed release
  // builds -- not addressed in this plan.)
  return SecureTokenStorage(
    const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  );
}
