import 'package:animeko_flutter/domain/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NetworkError message mentions the connection', () {
    expect(const NetworkError().message, contains('connection'));
  });

  test('ServerError message includes the status code', () {
    expect(const ServerError(500).message, contains('500'));
  });

  test('AuthExpiredError message tells the user to log in again', () {
    expect(const AuthExpiredError().message, contains('log in again'));
  });

  test('UnknownAppError message includes the underlying cause', () {
    expect(const UnknownAppError('boom').message, contains('boom'));
  });
}
