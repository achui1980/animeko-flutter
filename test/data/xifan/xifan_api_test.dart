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
}
