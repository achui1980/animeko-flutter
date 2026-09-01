import 'package:animeko_flutter/data/xifan/xifan_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late XifanApi api;

  setUp(() {
    dio = MockDio();
    api = XifanApi(dio);
  });

  Response<String> htmlResponse(String body) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );
  }

  group('search', () {
    // Real dm1.xfdm.pro/anime.xifanacg.com search-result markup (captured
    // live, 2026-09-01): each result's title lives in a `.thumb-txt`
    // element and its detail-page link lives in a separate `.thumb-menu
    // > a` element, in matching order -- NOT nested inside one common
    // container (unverified assumption: index-pairing is used here
    // because no single enclosing element was confirmed live; adjust if
    // this proves wrong once manually re-verified against the real
    // site).
    const searchResultsHtml = '''
<html><body>
  <div class="thumb-content"><div class="thumb-txt cor4 hide">鬼灭之刃</div></div>
  <div class="thumb-menu"><a target="_self" href="/bangumi/1001.html" class="button cr3">播放正片</a></div>
  <div class="thumb-content"><div class="thumb-txt cor4 hide">鬼灭之刃 无限城篇</div></div>
  <div class="thumb-menu"><a target="_self" href="/bangumi/1050.html" class="button cr3">播放正片</a></div>
</body></html>
''';

    test('sends the title as the "wd" query param to dm1.xfdm.pro', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      await api.search('鬼灭之刃');

      verify(
        () => dio.get<String>(
          'https://dm1.xfdm.pro/search.html',
          queryParameters: {'wd': '鬼灭之刃'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('pairs each .thumb-txt title with its matching .thumb-menu > a link', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      final results = await api.search('鬼灭之刃');

      expect(results, hasLength(2));
      expect(results[0].id, 1001);
      expect(results[0].title, '鬼灭之刃');
      expect(results[1].id, 1050);
      expect(results[1].title, '鬼灭之刃 无限城篇');
    });

    test('returns an empty list when there are no results', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no results</body></html>'));

      final results = await api.search('nonexistent');

      expect(results, isEmpty);
    });

    test('skips a link whose href has no numeric bangumi ID', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('''
<html><body>
  <div class="thumb-content"><div class="thumb-txt cor4 hide">无效结果</div></div>
  <div class="thumb-menu"><a href="/some-other-page.html">无效</a></div>
</body></html>
'''));

      final results = await api.search('anything');

      expect(results, isEmpty);
    });
  });

  group('listEpisodes', () {
    // Real bangumi detail-page markup (captured live, 2026-09-01): the
    // episode list for one "line"/source lives in a
    // `.anthology-list-play > li > a` list. A bangumi page can offer
    // several lines (e.g. "稀饭新番主线-1"/"-2", "稀饭备用-1"), each with
    // its own separate episode list -- this implementation deliberately
    // only reads the *first* `.anthology-list-play` on the page (v1
    // simplification: no line-switching/merging within one source, which
    // is a different axis from the cross-source merge in
    // `SubjectEpisodesController`).
    const detailPageHtml = '''
<html><body>
  <div class="anthology">
    <div class="anthology-tab"><a>稀饭新番主线-1</a><a>稀饭新番主线-2</a></div>
    <div class="anthology-list-box">
      <ul class="anthology-list-play">
        <li><a class="hide this-link" href="/watch/1001/1/1.html">第01集</a></li>
        <li><a class="hide this-link" href="/watch/1001/1/2.html">第02集</a></li>
      </ul>
      <ul class="anthology-list-play">
        <li><a class="hide this-link" href="/watch/1001/2/1.html">第01集</a></li>
        <li><a class="hide this-link" href="/watch/1001/2/2.html">第02集</a></li>
      </ul>
    </div>
  </div>
</body></html>
''';

    test('fetches https://dm1.xfdm.pro/bangumi/<id>.html', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body></body></html>'));

      await api.listEpisodes(1001);

      verify(
        () => dio.get<String>('https://dm1.xfdm.pro/bangumi/1001.html', options: any(named: 'options')),
      ).called(1);
    });

    test('parses episodes from only the first anthology-list-play', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(detailPageHtml));

      final episodes = await api.listEpisodes(1001);

      expect(episodes, hasLength(2));
      expect(episodes[0].title, '第01集');
      expect(episodes[0].watchPageUrl, 'https://dm1.xfdm.pro/watch/1001/1/1.html');
      expect(episodes[1].title, '第02集');
      expect(episodes[1].watchPageUrl, 'https://dm1.xfdm.pro/watch/1001/1/2.html');
    });

    test('returns an empty list when the page has no anthology-list-play', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no episodes</body></html>'));

      final episodes = await api.listEpisodes(9999);

      expect(episodes, isEmpty);
    });
  });
}
