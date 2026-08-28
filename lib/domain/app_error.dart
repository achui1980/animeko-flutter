/// Typed representation of failures surfaced to the UI, replacing raw
/// exception `toString()` text (Plan 1a follow-up M3). Pure Dart, no Dio
/// or Flutter import -- the domain layer must not know about either.
sealed class AppError {
  const AppError();

  /// Short human-readable message; UI code may show this directly.
  String get message;
}

class NetworkError extends AppError {
  const NetworkError();

  @override
  String get message => 'Could not reach the server. Check your connection.';
}

class ServerError extends AppError {
  const ServerError(this.statusCode);

  final int statusCode;

  @override
  String get message => 'Server error ($statusCode).';
}

class AuthExpiredError extends AppError {
  const AuthExpiredError();

  @override
  String get message => 'Your session has expired. Please log in again.';
}

class UnknownAppError extends AppError {
  const UnknownAppError(this.cause);

  final Object cause;

  @override
  String get message => 'Something went wrong: $cause';
}
