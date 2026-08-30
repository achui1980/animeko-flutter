// lib/data/auth/session_refresher.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import '../dio_error_mapper.dart';
import 'bangumi_oauth_models.dart';
import 'refresh_result.dart';
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

  /// Attempts to refresh using [refreshToken]. On success, persists the
  /// new [StoredSession] and returns [RefreshSuccess]. Never throws: every
  /// failure mode returns a [RefreshFailure] carrying the [AppError]
  /// reason instead (see [RefreshResult]'s doc comment).
  ///
  /// The two failure modes are handled differently on purpose:
  /// - If the API call itself fails (e.g. the refresh token was rejected),
  ///   the session really is dead, so storage is cleared.
  /// - If the API call succeeds but the subsequent local write fails (e.g.
  ///   a transient keychain I/O error), the *old* session may still be
  ///   valid -- storage is deliberately left untouched rather than wiped,
  ///   so a purely local hiccup doesn't force an unrecoverable logout.
  Future<RefreshResult> refresh(String refreshToken) async {
    final UserAuthRoutingLoginResponse result;
    try {
      result = await _api.refreshToken(refreshToken);
    } catch (e) {
      await _clearSafely();
      return RefreshFailure(mapToAppError(e));
    }

    final session = StoredSession(userId: result.userId, tokens: result.tokens);
    try {
      await _storage.saveSession(session);
      return RefreshSuccess(session);
    } catch (e) {
      return RefreshFailure(mapToAppError(e));
    }
  }

  /// Clears storage, swallowing any error from the clear itself -- so that
  /// a failing cleanup can never cause [refresh] to throw.
  Future<void> _clearSafely() async {
    try {
      await _storage.clear();
    } catch (_) {
      // Best-effort cleanup; nothing more we can do if this itself fails.
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
