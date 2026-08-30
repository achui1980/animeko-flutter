import 'package:animeko_flutter/data/search/search_api.dart';
import 'package:animeko_flutter/data/search/search_sort_by.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late SearchApi api;

  setUp(() {
    dio = MockDio();
    api = SearchApi(dio);
  });

  Response<Map<String, dynamic>> jsonResponse(Map<String, dynamic> data) {
    return Response(
      data: data,
      requestOptions: RequestOptions(path: '/v2/subjects/search'),
      statusCode: 200,
    );
  }

  test('search always sends q, omits tags/sortBy when not provided', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'items': <dynamic>[]}));

    await api.search(keywords: 'frieren');

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/subjects/search',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured['q'], 'frieren');
    expect(captured.containsKey('tags'), isFalse);
    expect(captured.containsKey('sortBy'), isFalse);
  });

  test('search joins tags as CSV and sends sortBy wire value', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'items': <dynamic>[]}));

    await api.search(
      keywords: 'frieren',
      tags: const ['Fantasy', 'Drama'],
      sortBy: SearchSortBy.rankAsc,
    );

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/subjects/search',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured['tags'], 'Fantasy,Drama');
    expect(captured['sortBy'], 'rankAsc');
  });

  test('search omits tags param when list is empty', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'items': <dynamic>[]}));

    await api.search(keywords: 'frieren', tags: const []);

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/subjects/search',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured.containsKey('tags'), isFalse);
  });

  test('search parses response ignoring unknown JSON keys', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => jsonResponse({
        'items': [
          {
            'id': 42,
            'name': 'Sousou no Frieren',
            'nameCn': '葬送的芙莉莲',
            'summary': 'ignored field not in our model',
            'imageLarge': 'https://example.com/frieren.jpg',
            'nsfw': false,
            'airDate': '2023-09-29',
            'ratingTotal': 12345,
            'favorite': {
              'wish': 1,
              'done': 2,
              'doing': 3,
              'onHold': 4,
              'dropped': 5,
            },
            'tags': [
              {'name': 'Fantasy', 'count': 100},
            ],
            'mainEpisodeCount': 28,
            'lightRelatedPersonInfoList': <dynamic>[],
            'score': '9.1',
            'rank': 3,
          },
        ],
      }),
    );

    final response = await api.search(keywords: 'frieren');

    expect(response.items, hasLength(1));
    expect(response.items.single.id, 42);
    expect(response.items.single.name, 'Sousou no Frieren');
    expect(response.items.single.nameCn, '葬送的芙莉莲');
    expect(response.items.single.imageLarge, 'https://example.com/frieren.jpg');
    expect(response.items.single.airDate, '2023-09-29');
    expect(response.items.single.tags.single.name, 'Fantasy');
    expect(response.items.single.tags.single.count, 100);
    expect(response.items.single.score, '9.1');
  });

  test('searchApiProvider builds a SearchApi backed by dioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(searchApiProvider);
    expect(api, isA<SearchApi>());
  });
}
