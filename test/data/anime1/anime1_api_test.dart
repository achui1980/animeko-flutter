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
    // Real anime1.me search-result markup (captured live, 2026-09-01): the
    // `rel="category tag"` anchor's href is a WordPress *pretty permalink*
    // (`/category/<season>/<slug>`), which never contains a `cat=` query
    // param. The only place the numeric category ID actually appears is a
    // `category-<id>` CSS class on the enclosing `<article>`. This fixture
    // intentionally mirrors that real shape instead of an invented
    // `?cat=<id>` href, which was the original (wrong) assumption.
    const searchResultsHtml = '''
<html><body>
  <article id="post-23350" class="post-23350 post type-post status-publish format-standard hentry category-87">
    <h2 class="entry-title"><a href="https://anime1.me/23350" rel="bookmark">葬送的芙莉蓮 [12]</a></h2>
    <footer class="entry-footer"><span class="cat-links">分類:
      <a href="https://anime1.me/category/2023%e5%b9%b4%e7%a7%8b%e5%ad%a3/%e8%91%ac%e9%80%81%e7%9a%84%e8%8a%99%e8%8e%89%e8%98%ad" rel="category tag">葬送的芙莉蓮</a>
    </span></footer>
  </article>
  <article id="post-23310" class="post-23310 post type-post status-publish format-standard hentry category-87">
    <h2 class="entry-title"><a href="https://anime1.me/23310" rel="bookmark">葬送的芙莉蓮 [11]</a></h2>
    <footer class="entry-footer"><span class="cat-links">分類:
      <a href="https://anime1.me/category/2023%e5%b9%b4%e7%a7%8b%e5%ad%a3/%e8%91%ac%e9%80%81%e7%9a%84%e8%8a%99%e8%8e%89%e8%98%ad" rel="category tag">葬送的芙莉蓮</a>
    </span></footer>
  </article>
  <div id="sidebar">
    <a href="https://anime1.me/category/some-other-unrelated-widget-link" class="widget-link">Unrelated sidebar link (no rel attribute, no enclosing article)</a>
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

    test('skips a category-tag link whose enclosing article has no numeric category-N class', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => htmlResponse('''
<html><body>
  <article id="post-1" class="post-1 post type-post status-publish format-standard hentry">
    <footer><span class="cat-links"><a href="https://anime1.me/category/no-id-here" rel="category tag">缺少分類編號</a></span></footer>
  </article>
</body></html>
'''),
      );

      final categories = await api.searchCategories('anything');

      expect(categories, isEmpty);
    });
  });

  group('fetchCategoryEpisodes', () {
    const page1Html = '''
<html><body>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1002">葬送的芙莉蓮 [12]</a></h2></article>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1001">葬送的芙莉蓮 [11]</a></h2></article>
  <nav class="pagination">
    <a class="next page-numbers" href="https://anime1.me/page/2/?cat=87">Next</a>
  </nav>
</body></html>
''';
    const page2Html = '''
<html><body>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1000">葬送的芙莉蓮 [10]</a></h2></article>
</body></html>
''';

    test('fetches https://anime1.me/?cat=<id>', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body></body></html>'));

      await api.fetchCategoryEpisodes(87);

      verify(
        () => dio.get<String>('https://anime1.me/?cat=87', options: any(named: 'options')),
      ).called(1);
    });

    test('parses episode title and page URL from each article', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('''
<html><body>
  <article><h2 class="entry-title"><a href="https://anime1.me/?p=1001">葬送的芙莉蓮 [12]</a></h2></article>
</body></html>
'''));

      final episodes = await api.fetchCategoryEpisodes(87);

      expect(episodes, hasLength(1));
      expect(episodes.single.title, '葬送的芙莉蓮 [12]');
      expect(episodes.single.pageUrl, 'https://anime1.me/?p=1001');
    });

    test('follows pagination via "next page-numbers" links', () async {
      when(() => dio.get<String>('https://anime1.me/?cat=87', options: any(named: 'options')))
          .thenAnswer((_) async => htmlResponse(page1Html));
      when(() => dio.get<String>('https://anime1.me/page/2/?cat=87', options: any(named: 'options')))
          .thenAnswer((_) async => htmlResponse(page2Html));

      final episodes = await api.fetchCategoryEpisodes(87);

      expect(episodes.map((e) => e.title), [
        '葬送的芙莉蓮 [12]',
        '葬送的芙莉蓮 [11]',
        '葬送的芙莉蓮 [10]',
      ]);
    });

    test('stops when there is no next-page link', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(page2Html));

      await api.fetchCategoryEpisodes(87);

      verify(() => dio.get<String>(any(), options: any(named: 'options'))).called(1);
    });
  });

  group('resolvePlaybackUrl', () {
    // Verified against the live site (2026-09-01): `data-apireq` is
    // percent-encoded (URL-encoded) JSON, not base64. This fixture's raw
    // attribute value decodes (via Uri.decodeComponent) to
    // `{"foo":"bar"}`.
    const episodePageHtml = '''
<html><body>
  <div class="video-js" data-apireq="%7B%22foo%22%3A%22bar%22%7D"></div>
</body></html>
''';

    Response<Map<String, dynamic>> apiJsonResponse(Map<String, dynamic> data) {
      return Response(
        data: data,
        requestOptions: RequestOptions(path: 'https://v.anime1.me/api'),
        statusCode: 200,
      );
    }

    test('extracts data-apireq, decodes it, and POSTs it as form field "d"', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(episodePageHtml));
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => apiJsonResponse({
            's': [
              {'src': 'https://video.example.com/720p.mp4', 'type': 'video/mp4'},
            ],
          }));

      await api.resolvePlaybackUrl('https://anime1.me/?p=1001');

      verify(
        () => dio.post<Map<String, dynamic>>(
          'https://v.anime1.me/api',
          data: {'d': '{"foo":"bar"}'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('returns the parsed Anime1PlaybackSource from the API response', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(episodePageHtml));
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => apiJsonResponse({
            's': [
              {'src': 'https://video.example.com/720p.mp4', 'type': 'video/mp4'},
            ],
          }));

      final source = await api.resolvePlaybackUrl('https://anime1.me/?p=1001');

      expect(source.url, 'https://video.example.com/720p.mp4');
    });

    test('throws FormatException when the page has no data-apireq attribute', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no video here</body></html>'));

      expect(
        () => api.resolvePlaybackUrl('https://anime1.me/?p=1001'),
        throwsFormatException,
      );
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
