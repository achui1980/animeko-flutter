// test/data/home/trends_api_test.dart
import 'package:animeko_flutter/data/home/trends_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late TrendsApi api;

  setUp(() {
    dio = MockDio();
    api = TrendsApi(dio);
  });

  test('getTrends GETs /v1/trends and parses the response', () async {
    when(() => dio.get<Map<String, dynamic>>('/v1/trends')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/v1/trends'),
        statusCode: 200,
        data: {
          'trendingSubjects': [
            {
              'bangumiId': 42,
              'nameCn': '测试动漫',
              'imageLarge': 'https://example.com/img.jpg',
            },
          ],
        },
      ),
    );

    final result = await api.getTrends();

    expect(result.trendingSubjects, hasLength(1));
    expect(result.trendingSubjects.first.bangumiId, 42);
    expect(result.trendingSubjects.first.nameCn, '测试动漫');
    expect(
      result.trendingSubjects.first.imageLarge,
      'https://example.com/img.jpg',
    );
  });
}
