import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late Anime1Api api;

  setUp(() {
    dio = MockDio();
    api = Anime1Api(dio);
  });

  Response<String> htmlResponse(String body, {String path = '/'}) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  group('searchCategories', () {
    const searchResultsHtml = '''
<html><body>
  <article>
    <h2 class="entry-title"><a href="https://anime1.me/?p=1001">葬送的芙莉蓮 [12]</a></h2>
    <span class="cat-links">
      <a href="https://anime1.me/?cat=87" rel="category tag">葬送的芙莉蓮</a>
    </span>
  </article>
  <article>
    <h2 class="entry-title"><a href="https://anime1.me/?p=1002">葬送的芙莉蓮 [11]</a></h2>
    <span class="cat-links">
      <a href="https://anime1.me/?cat=87" rel="category tag">葬送的芙莉蓮</a>
    </span>
  </article>
  <div id="sidebar">
    <a href="https://anime1.me/?cat=999">Unrelated sidebar category widget link</a>
  </div>
</body></html>
''';

    test('sends the title as the "s" query param', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      await api.searchCategories('葬送的芙莉蓮');

      verify(
        () => dio.get<String>(
          'https://anime1.me/',
          queryParameters: {'s': '葬送的芙莉蓮'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('extracts and dedupes rel="category tag" links, ignoring other links', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      final categories = await api.searchCategories('葬送的芙莉蓮');

      expect(categories, hasLength(1));
      expect(categories.single.id, 87);
      expect(categories.single.title, '葬送的芙莉蓮');
    });

    test('returns an empty list when there are no category-tag links', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no results</body></html>'));

      final categories = await api.searchCategories('nonexistent');

      expect(categories, isEmpty);
    });
  });

  test('anime1ApiProvider builds an Anime1Api backed by anime1DioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(anime1ApiProvider);
    expect(api, isA<Anime1Api>());
  });

  test('anime1DioProvider sets the Referer header required by anime1.me', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(anime1DioProvider);
    expect(dio.options.headers['Referer'], 'https://anime1.me');
  });
}
