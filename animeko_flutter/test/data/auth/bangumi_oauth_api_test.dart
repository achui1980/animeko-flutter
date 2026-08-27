import 'package:animeko_flutter/data/auth/bangumi_oauth_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late BangumiOAuthApi api;

  setUp(() {
    dio = MockDio();
    api = BangumiOAuthApi(dio);
  });

  Response<Map<String, dynamic>> jsonResponse(Map<String, dynamic> data) {
    return Response(
      requestOptions: RequestOptions(path: '/'),
      data: data,
      statusCode: 200,
    );
  }

  group('oauth', () {
    test('GETs /v2/users/bangumi/oauth with requestId/os/arch and parses url', () async {
      when(() => dio.get<Map<String, dynamic>>(
            '/v2/users/bangumi/oauth',
            queryParameters: {'requestId': 'req-1', 'os': 'macos', 'arch': 'arm64'},
          )).thenAnswer((_) async => jsonResponse({'url': 'https://bgm.tv/x'}));

      final result = await api.oauth(requestId: 'req-1', os: 'macos', arch: 'arm64');

      expect(result.url, 'https://bgm.tv/x');
    });
  });

  group('bind', () {
    test('GETs /v2/users/bangumi/bind with requestId/os/arch and parses url', () async {
      when(() => dio.get<Map<String, dynamic>>(
            '/v2/users/bangumi/bind',
            queryParameters: {'requestId': 'req-2', 'os': 'macos', 'arch': 'arm64'},
          )).thenAnswer((_) async => jsonResponse({'url': 'https://bgm.tv/y'}));

      final result = await api.bind(requestId: 'req-2', os: 'macos', arch: 'arm64');

      expect(result.url, 'https://bgm.tv/y');
    });
  });

  group('getResult', () {
    test('returns parsed response on 200', () async {
      when(() => dio.get<Map<String, dynamic>>(
            '/v2/users/bangumi/result',
            queryParameters: {'requestId': 'req-3'},
          )).thenAnswer((_) async => jsonResponse({
            'userId': 'user-1',
            'tokens': {
              'accessToken': 'a',
              'refreshToken': 'r',
              'expiresAtMillis': 123,
            },
          }));

      final result = await api.getResult('req-3');

      expect(result, isNotNull);
      expect(result!.userId, 'user-1');
    });

    test('returns null on HTTP 425 Too Early', () async {
      when(() => dio.get<Map<String, dynamic>>(
            '/v2/users/bangumi/result',
            queryParameters: {'requestId': 'req-4'},
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/v2/users/bangumi/result'),
        response: Response(
          requestOptions: RequestOptions(path: '/v2/users/bangumi/result'),
          statusCode: 425,
        ),
        type: DioExceptionType.badResponse,
      ));

      final result = await api.getResult('req-4');

      expect(result, isNull);
    });

    test('rethrows on other error status codes', () async {
      when(() => dio.get<Map<String, dynamic>>(
            '/v2/users/bangumi/result',
            queryParameters: {'requestId': 'req-5'},
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/v2/users/bangumi/result'),
        response: Response(
          requestOptions: RequestOptions(path: '/v2/users/bangumi/result'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      ));

      expect(() => api.getResult('req-5'), throwsA(isA<DioException>()));
    });
  });
}
