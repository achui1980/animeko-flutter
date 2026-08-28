// test/data/auth/session_api_test.dart
import 'package:animeko_flutter/data/auth/session_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late SessionApi api;

  setUp(() {
    dio = MockDio();
    api = SessionApi(dio);
  });

  test(
    'refreshToken POSTs to /v2/users/auth/refresh with the refresh token',
    () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/v2/users/auth/refresh',
          data: {'refreshToken': 'old-refresh'},
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v2/users/auth/refresh'),
          data: {
            'userId': 'user-1',
            'tokens': {
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
              'expiresAtMillis': 123,
            },
          },
        ),
      );

      final result = await api.refreshToken('old-refresh');

      expect(result.userId, 'user-1');
      expect(result.tokens.accessToken, 'new-access');
    },
  );

  test('a non-2xx response rethrows the DioException as-is', () async {
    final requestOptions = RequestOptions(path: '/v2/users/auth/refresh');
    when(
      () => dio.post<Map<String, dynamic>>(
        '/v2/users/auth/refresh',
        data: {'refreshToken': 'expired'},
      ),
    ).thenThrow(
      DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      ),
    );

    expect(() => api.refreshToken('expired'), throwsA(isA<DioException>()));
  });
}
