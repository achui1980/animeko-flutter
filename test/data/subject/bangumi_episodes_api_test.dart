// test/data/subject/bangumi_episodes_api_test.dart
import 'package:animeko_flutter/data/subject/bangumi_episodes_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> jsonResponse(Map<String, dynamic> body) {
  return Response(
    data: body,
    requestOptions: RequestOptions(path: '/v0/episodes'),
    statusCode: 200,
  );
}

void main() {
  late MockDio dio;
  late BangumiEpisodesApi api;

  setUp(() {
    dio = MockDio();
    api = BangumiEpisodesApi(dio);
  });

  group('listEpisodes', () {
    final body = {
      'data': [
        {
          'airdate': '2023-09-29',
          'name': '冒険の終わり',
          'name_cn': '冒险结束',
          'ep': 1,
          'sort': 1,
          'id': 1227087,
          'type': 0,
        },
      ],
      'total': 28,
      'limit': 100,
      'offset': 0,
    };

    test('GETs /v0/episodes with subject_id, type=0, limit=100', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => jsonResponse(body));

      await api.listEpisodes(400602);

      verify(
        () => dio.get<Map<String, dynamic>>(
          '/v0/episodes',
          queryParameters: {'subject_id': 400602, 'type': 0, 'limit': 100},
        ),
      ).called(1);
    });

    test('parses the response into a list of BangumiEpisode', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => jsonResponse(body));

      final episodes = await api.listEpisodes(400602);

      expect(episodes, hasLength(1));
      expect(episodes.single.id, 1227087);
      expect(episodes.single.nameCn, '冒险结束');
    });
  });
}
