// lib/data/auth/refresh_result.dart
import '../../domain/app_error.dart';
import 'secure_token_storage.dart';

/// Outcome of [SessionRefresher.refresh]. Unlike the previous bare
/// `StoredSession?` return type, this preserves *why* a refresh failed
/// (Plan 1a/1b-1 follow-up I-B): a [RefreshFailure] carrying a
/// [NetworkError] means the old session may still be valid (the server
/// was just unreachable), whereas one carrying an [AuthExpiredError]
/// means the refresh token itself was rejected and the session is
/// definitively dead. Callers (see `AuthController.restoreSession()` and
/// `AuthController.refreshSessionForInterceptor()`) use this distinction
/// to decide whether to sign the user out.
sealed class RefreshResult {
  const RefreshResult();
}

class RefreshSuccess extends RefreshResult {
  const RefreshSuccess(this.session);
  final StoredSession session;
}

class RefreshFailure extends RefreshResult {
  const RefreshFailure(this.error);
  final AppError error;
}
