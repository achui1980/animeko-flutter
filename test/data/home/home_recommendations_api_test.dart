import 'package:animeko_flutter/data/home/home_recommendations_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> fixtureResponse() {
  return Response(
    requestOptions: RequestOptions(path: '/v2/home/recommendations'),
    data: {
      'total': 1,
      'items': [
        {
          'subjectName': 'Test',
          'subjectNameCn': '测试',
          'imageUrl': 'https://x/img.jpg',
          'desc1': 'a',
          'desc2': 'b',
          'subjectId': 7,
          'uri': 'ani://subject/7',
        },
      ],
    },
  );
}

void main() {
  late MockDio dio;
  late HomeRecommendationsApi api;

  setUp(() {
    dio = MockDio();
    api = HomeRecommendationsApi(dio);
  });

  test('getRecommendations omits offset/limit query params when not given', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/v2/home/recommendations',
        queryParameters: {},
      ),
    ).thenAnswer((_) async => fixtureResponse());

    final result = await api.getRecommendations();

    expect(result.total, 1);
    expect(result.items.single.subjectId, 7);
    expect(result.items.single.subjectName, 'Test');
    expect(result.items.single.subjectNameCn, '测试');
  });

  test('getRecommendations includes offset/limit when provided', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/v2/home/recommendations',
        queryParameters: {'offset': 5, 'limit': 20},
      ),
    ).thenAnswer((_) async => fixtureResponse());

    await api.getRecommendations(offset: 5, limit: 20);

    verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/home/recommendations',
        queryParameters: {'offset': 5, 'limit': 20},
      ),
    ).called(1);
  });
}
