import 'package:animeko_flutter/data/schedule/schedule_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ScheduleApi api;

  setUp(() {
    dio = MockDio();
    api = ScheduleApi(dio);
  });

  Response<Map<String, dynamic>> jsonResponse(Map<String, dynamic> data) {
    return Response(
      data: data,
      requestOptions: RequestOptions(path: '/v1/schedule/airing'),
      statusCode: 200,
    );
  }

  test('getLatestAiringSchedule sends today and timeZone as query params', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'list': <dynamic>[]}));

    await api.getLatestAiringSchedule(today: '2026-08-28', timeZone: '+08:00');

    verify(
      () => dio.get<Map<String, dynamic>>(
        '/v1/schedule/airing',
        queryParameters: {'today': '2026-08-28', 'timeZone': '+08:00'},
      ),
    ).called(1);
  });

  test('parses a date-grouped schedule with nested subject/episode', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => jsonResponse({
        'list': [
          {
            'date': '2026-08-28',
            'list': [
              {
                'subject': {
                  'subjectId': 100,
                  'name': 'Frieren',
                  'nameCn': '芙莉莲',
                  'imageLarge': 'https://example.com/f.jpg',
                },
                'episode': {
                  'episodeId': 1000,
                  'name': 'Ep 1',
                  'nameCn': '第1话',
                  'airDate': '2026-08-28',
                  'sort': '1',
                },
                'airingTime': '2026-08-28T22:00:00Z',
              },
            ],
          },
        ],
      }),
    );

    final result = await api.getLatestAiringSchedule(
      today: '2026-08-28',
      timeZone: '+08:00',
    );

    expect(result.list, hasLength(1));
    expect(result.list.single.date, '2026-08-28');
    expect(result.list.single.list.single.subject.subjectId, 100);
    expect(result.list.single.list.single.subject.nameCn, '芙莉莲');
    expect(result.list.single.list.single.episode.sort, '1');
    expect(result.list.single.list.single.airingTime, '2026-08-28T22:00:00Z');
  });

  test('scheduleApiProvider builds a ScheduleApi backed by dioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(scheduleApiProvider);
    expect(api, isA<ScheduleApi>());
  });
}
