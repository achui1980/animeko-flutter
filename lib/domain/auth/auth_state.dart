/// State machine for the Bangumi OAuth login flow.
///
/// See docs/superpowers/specs/2026-08-27-flutter-migration-phase1-design.md
/// section 6 ("服务器托管回调 + 客户端轮询") for the flow this models:
/// unauthenticated -> awaitingBrowser -> polling -> authenticated | error.
sealed class AuthState {
  const AuthState();
}

/// No session yet; user has not started the login flow.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// The OAuth link was fetched from the server and the system browser was
/// opened; about to start polling for the result.
class AuthAwaitingBrowser extends AuthState {
  const AuthAwaitingBrowser(this.requestId);
  final String requestId;
}

/// Actively polling GET /v2/users/bangumi/result. The server responds with
/// HTTP 425 Too Early until the Bangumi callback has landed.
class AuthPolling extends AuthState {
  const AuthPolling(this.requestId);
  final String requestId;
}

/// Login succeeded; tokens have been persisted to secure storage.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.userId);
  final String userId;
}

/// Login failed. `message` is a human-readable description, not parsed
/// from any particular exception type.
class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
