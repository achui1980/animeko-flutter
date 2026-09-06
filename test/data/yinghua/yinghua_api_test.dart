import 'package:animeko_flutter/data/yinghua/yinghua_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late YinghuaApi api;

  setUp(() {
    dio = MockDio();
    api = YinghuaApi(dio);
  });

  Response<String> htmlResponse(String body) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );
  }

  group('search', () {
    // Real www.yinghua2.com search-result markup (captured live,
    // 2026-09-05): each result is one <li> under
    // ul.stui-vodlist__media, title+link both at `.detail h3.title a`.
    const searchResultsHtml = '''
<html><body>
  <ul class="stui-vodlist__media col-pd clearfix">
    <li class="active clearfix">
      <div class="thumb"><a href="/index.php/vod/detail/id/58802.html"></a></div>
      <div class="detail">
        <h3 class="title"><a href="/index.php/vod/detail/id/58802.html">鬼灭之刃 剧场版 无限城篇第一章 猗窝座再来</a></h3>
      </div>
    </li>
    <li class="active clearfix">
      <div class="thumb"><a href="/index.php/vod/detail/id/76362.html"></a></div>
      <div class="detail">
        <h3 class="title"><a href="/index.php/vod/detail/id/76362.html">成长秀～向日葵马戏团～</a></h3>
      </div>
    </li>
  </ul>
</body></html>
''';

    test('sends the title as the "wd" query param', () async {
      when(
        () => dio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      await api.search('鬼灭之刃');

      verify(
        () => dio.get<String>(
          'https://www.yinghua2.com/index.php/vod/search.html',
          queryParameters: {'wd': '鬼灭之刃'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('parses title and numeric id from each result', () async {
      when(
        () => dio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      final results = await api.search('鬼灭之刃');

      expect(results, hasLength(2));
      expect(results[0].id, 58802);
      expect(results[0].title, '鬼灭之刃 剧场版 无限城篇第一章 猗窝座再来');
      expect(results[1].id, 76362);
      expect(results[1].title, '成长秀～向日葵马戏团～');
    });

    test('returns an empty list when there are no results', () async {
      when(
        () => dio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => htmlResponse('<html><body>no results</body></html>'),
      );

      final results = await api.search('nonexistent');

      expect(results, isEmpty);
    });
  });

  group('listEpisodes', () {
    // Real detail-page markup (captured live, 2026-09-05): a title can
    // have multiple "lines", each its own div.stui-pannel.stui-pannel-bg
    // block with its own .stui-content__playlist. Episodes with the same
    // title across blocks are merged into one YinghuaEpisode with an
    // ordered list of URLs (first-seen line first); 第01集 appears in
    // both 线路1 and 线路4, while 第02集 only exists in 线路1.
    const detailPageHtml = '''
<html><body>
  <div class="stui-pannel stui-pannel-bg clearfix">
    <div class="stui-pannel-box b playlist mb">
      <div class="stui-pannel_hd">
        <div class="stui-pannel__head bottom-line active clearfix">
          <h3 class="title"><img src="/statics/icon/icon_30.png"/>线路1</h3>
        </div>
      </div>
      <div class="stui-pannel_bd col-pd clearfix">
        <ul class="stui-content__playlist clearfix">
          <li><a href="/index.php/vod/play/id/76362/sid/5/nid/1.html">第01集</a></li>
          <li><a href="/index.php/vod/play/id/76362/sid/5/nid/2.html">第02集</a></li>
        </ul>
      </div>
    </div>
  </div>
  <div class="stui-pannel stui-pannel-bg clearfix">
    <div class="stui-pannel-box b playlist mb">
      <div class="stui-pannel_hd">
        <div class="stui-pannel__head bottom-line active clearfix">
          <h3 class="title"><img src="/statics/icon/icon_30.png"/>线路4</h3>
        </div>
      </div>
      <div class="stui-pannel_bd col-pd clearfix">
        <ul class="stui-content__playlist clearfix">
          <li><a href="/index.php/vod/play/id/76362/sid/2/nid/1.html">第01集</a></li>
        </ul>
      </div>
    </div>
  </div>
</body></html>
''';

    test(
      'fetches https://www.yinghua2.com/index.php/vod/detail/id/<id>.html',
      () async {
        when(
          () => dio.get<String>(any(), options: any(named: 'options')),
        ).thenAnswer((_) async => htmlResponse('<html><body></body></html>'));

        await api.listEpisodes(76362);

        verify(
          () => dio.get<String>(
            'https://www.yinghua2.com/index.php/vod/detail/id/76362.html',
            options: any(named: 'options'),
          ),
        ).called(1);
      },
    );

    test('merges episodes with the same title across line blocks', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(detailPageHtml));

      final episodes = await api.listEpisodes(76362);

      expect(episodes, hasLength(2));

      // 第01集 exists in both 线路1 and 线路4: merged into one episode
      // with both URLs, first-seen line (线路1, sid/5) first.
      expect(episodes[0].title, '第01集');
      expect(episodes[0].playPageUrls, [
        'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/5/nid/1.html',
        'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/2/nid/1.html',
      ]);

      // 第02集 only exists in 线路1: single-URL entry.
      expect(episodes[1].title, '第02集');
      expect(episodes[1].playPageUrls, [
        'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/5/nid/2.html',
      ]);
    });

    test('returns an empty list when the page has no line blocks', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => htmlResponse('<html><body>no episodes</body></html>'),
      );

      final episodes = await api.listEpisodes(9999);

      expect(episodes, isEmpty);
    });
  });

  group('resolvePlaybackUrl', () {
    // Real play-page script content (captured live, 2026-09-05):
    // player_aaaa has a nested vod_data object -- extraction must
    // brace-balance, not stop at the first "}". encrypt is always 0.
    String playPageHtml(String url) =>
        '''
<html><body>
<script type="text/javascript">
var player_aaaa={"flag":"play","encrypt":0,"trysee":0,"points":0,
"link":"/index.php/vod/play/id/76362/sid/1/nid/1.html","link_next":"","link_pre":"",
"vod_data":{"vod_name":"成长秀","vod_actor":"","vod_director":"","vod_class":"日韩动漫"},
"url":"$url","url_next":"","from":"modum3u8","server":"no","note":"","id":"76362","sid":5,"nid":1}
</script>
</body></html>
''';

    const primaryUrl =
        'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/5/nid/1.html';
    const fallbackUrl =
        'https://www.yinghua2.com/index.php/vod/play/id/76362/sid/2/nid/1.html';

    test('uses the url as-is with a defensive Referer header', () async {
      when(
        () => dio.get<String>(primaryUrl, options: any(named: 'options')),
      ).thenAnswer(
        (_) async => htmlResponse(
          playPageHtml(
            'https://play.modujx11.com/20260705/gteTofLu/index.m3u8',
          ),
        ),
      );

      final sources = await api.resolvePlaybackUrl([primaryUrl]);

      expect(sources, hasLength(1));
      expect(
        sources.single.url,
        'https://play.modujx11.com/20260705/gteTofLu/index.m3u8',
      );
      expect(sources.single.headers['Referer'], 'https://www.yinghua2.com/');
    });

    test(
      'throws FormatException when there is no player_aaaa variable',
      () async {
        when(
          () => dio.get<String>(primaryUrl, options: any(named: 'options')),
        ).thenAnswer(
          (_) async => htmlResponse('<html><body>no player here</body></html>'),
        );

        expect(
          () => api.resolvePlaybackUrl([primaryUrl]),
          throwsFormatException,
        );
      },
    );

    test(
      'throws FormatException when player_aaaa has no "url" field',
      () async {
        when(
          () => dio.get<String>(primaryUrl, options: any(named: 'options')),
        ).thenAnswer(
          (_) async => htmlResponse('''
<html><body><script>
var player_aaaa={"flag":"play","encrypt":0,"vod_data":{"vod_name":"x"}}
</script></body></html>
'''),
        );

        expect(
          () => api.resolvePlaybackUrl([primaryUrl]),
          throwsFormatException,
        );
      },
    );

    test(
      'skips a candidate that throws and returns the successful one',
      () async {
        when(
          () => dio.get<String>(primaryUrl, options: any(named: 'options')),
        ).thenThrow(
          DioException(requestOptions: RequestOptions(path: primaryUrl)),
        );
        when(
          () => dio.get<String>(fallbackUrl, options: any(named: 'options')),
        ).thenAnswer(
          (_) async => htmlResponse(
            playPageHtml('https://play.example.com/fallback.m3u8'),
          ),
        );

        final sources = await api.resolvePlaybackUrl([primaryUrl, fallbackUrl]);

        expect(sources, hasLength(1));
        expect(sources.single.url, 'https://play.example.com/fallback.m3u8');
      },
    );

    test(
      'throws FormatException when every candidate fails to resolve',
      () async {
        when(
          () => dio.get<String>(primaryUrl, options: any(named: 'options')),
        ).thenAnswer(
          (_) async => htmlResponse('<html><body>no player here</body></html>'),
        );
        when(
          () => dio.get<String>(fallbackUrl, options: any(named: 'options')),
        ).thenThrow(
          DioException(requestOptions: RequestOptions(path: fallbackUrl)),
        );

        expect(
          () => api.resolvePlaybackUrl([primaryUrl, fallbackUrl]),
          throwsFormatException,
        );
      },
    );
  });

  test(
    'yinghuaApiProvider builds a YinghuaApi backed by yinghuaDioProvider',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final api = container.read(yinghuaApiProvider);
      expect(api, isA<YinghuaApi>());
    },
  );

  test('yinghuaDioProvider sets a non-empty User-Agent header', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(yinghuaDioProvider);
    expect(dio.options.headers['User-Agent'], isNotEmpty);
  });
}
