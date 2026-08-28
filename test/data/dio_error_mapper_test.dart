import 'package:animeko_flutter/data/dio_error_mapper.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final options = RequestOptions(path: '/x');

  test('connection errors map to NetworkError', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );

    expect(mapToAppError(error), isA<NetworkError>());
  });

  test('a 401 response maps to AuthExpiredError', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: 401),
    );

    expect(mapToAppError(error), isA<AuthExpiredError>());
  });

  test('a 500 response maps to ServerError(500)', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: 500),
    );

    final mapped = mapToAppError(error);
    expect(mapped, isA<ServerError>());
    expect((mapped as ServerError).statusCode, 500);
  });

  test('a non-Dio object maps to UnknownAppError', () {
    final mapped = mapToAppError(Exception('boom'));

    expect(mapped, isA<UnknownAppError>());
    expect(mapped.message, contains('boom'));
  });

  test('a badResponse with no status code maps to UnknownAppError without '
      'leaking DioException diagnostic text', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
    );

    final mapped = mapToAppError(error);
    expect(mapped, isA<UnknownAppError>());
    expect(mapped.message, isNot(contains('DioException')));
  });

  test('an unknown-type DioException maps to UnknownAppError without leaking '
      'DioException diagnostic text', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.unknown,
    );

    final mapped = mapToAppError(error);
    expect(mapped, isA<UnknownAppError>());
    expect(mapped.message, isNot(contains('DioException')));
  });

  test('a cancel-type DioException maps to UnknownAppError', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
    );

    expect(mapToAppError(error), isA<UnknownAppError>());
  });
}
