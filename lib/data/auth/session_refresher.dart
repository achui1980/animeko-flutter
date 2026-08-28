// lib/data/auth/session_refresher.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'secure_token_storage.dart';
import 'session_api.dart';

part 'session_refresher.g.dart';

/// Shared refresh-and-persist-or-clear logic, used both by
/// [AuthInterceptor]'s 401 handling and by `AuthController.restoreSession()`
/// at app startup, so the two don't duplicate this behavior.
class SessionRefresher {
  SessionRefresher(this._api, this._storage);

  final SessionApi _api;
  final SecureTokenStorage _storage;

  /// Attempts to refresh using [refreshToken]. On success, persists and
  /// returns the new [StoredSession]. On any failure, clears storage and
  /// returns null.
  Future<StoredSession?> refresh(String refreshToken) async {
    try {
      final result = await _api.refreshToken(refreshToken);
      final session = StoredSession(userId: result.userId, tokens: result.tokens);
      await _storage.saveSession(session);
      return session;
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }
}

/// Builds [SessionApi] on its own bare, non-intercepted [Dio] instance --
/// it must never go through [AuthInterceptor], or a failing refresh (e.g.
/// an expired refresh token) would recurse into another refresh attempt.
@riverpod
SessionApi sessionApi(Ref ref) {
  return SessionApi(rawAniDio());
}

@riverpod
SessionRefresher sessionRefresher(Ref ref) {
  return SessionRefresher(
    ref.watch(sessionApiProvider),
    ref.watch(secureTokenStorageProvider),
  );
}
