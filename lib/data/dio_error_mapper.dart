import 'package:dio/dio.dart';

import '../domain/app_error.dart';

/// Converts a caught [Object] (expected to usually be a [DioException])
/// into the domain layer's [AppError] hierarchy so callers/UI never need
/// to know about Dio directly (Plan 1a follow-up M3).
AppError mapToAppError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkError();
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) return const AuthExpiredError();
        if (status != null) return ServerError(status);
        // No status code available; avoid wrapping the raw DioException
        // (its toString() is a verbose, Dio-flavored diagnostic dump) so
        // UnknownAppError.message never leaks that text to the UI.
        return const UnknownAppError(
          'the server response could not be understood',
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // Same reasoning as above: pass a fixed, human-readable cause
        // instead of the DioException itself.
        return const UnknownAppError('a network error occurred');
    }
  }
  return UnknownAppError(error);
}
