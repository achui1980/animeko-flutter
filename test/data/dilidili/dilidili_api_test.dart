import 'package:animeko_flutter/data/dilidili/dilidili_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late DilidiliApi api;

  setUp(() {
    dio = MockDio();
    api = DilidiliApi(dio);
  });

  Response<String> htmlResponse(String body) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );
  }

  group('search', () {
    // Real dilidili.io search-result markup (captured live, 2026-09-05):
    // each result is one <dl> under .anime_list; title and the detail
    // page's /anime/<slug>/ link both live at dd h3 > a.
    const searchResultsHtml = '''
<html><body>
  <div class="anime_list" id="mydiv">
    <dl>
      <dt><a href="/anime/one-piece/" target="_blank"><img src="/a.jpg"></a></dt>
      <dd>
        <h3><a href="/anime/one-piece/" target="_blank">海贼王</a></h3>
        <p></p>
      </dd>
    </dl>
    <dl>
      <dt><a href="/anime/one-piece-movie/" target="_blank"><img src="/b.jpg"></a></dt>
      <dd>
        <h3><a href="/anime/one-piece-movie/" target="_blank">海贼王 剧场版</a></h3>
        <p></p>
      </dd>
    </dl>
  </div>
</body></html>
''';

    test('sends the title as the "q" query param with kwtype=0', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      await api.search('海贼王');

      verify(
        () => dio.get<String>(
          'https://dilidili.io/search',
          queryParameters: {'q': '海贼王', 'kwtype': '0'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('parses title and slug from each result', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(searchResultsHtml));

      final results = await api.search('海贼王');

      expect(results, hasLength(2));
      expect(results[0].slug, 'one-piece');
      expect(results[0].title, '海贼王');
      expect(results[1].slug, 'one-piece-movie');
      expect(results[1].title, '海贼王 剧场版');
    });

    test('returns an empty list when there are no results', () async {
      when(
        () => dio.get<String>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no results</body></html>'));

      final results = await api.search('nonexistent');

      expect(results, isEmpty);
    });
  });

  group('listEpisodes', () {
    // Real detail-page markup (captured live, 2026-09-05): the episode
    // label lives at `em > span`, not the whole link text (which also
    // repeats the series name).
    const detailPageHtml = '''
<html><body>
  <div class="con24 m-10 xf_news">
    <div class="time_pic list">
      <div class="time_con" style="display: block;">
        <div class="swiper-container">
          <div class="swiper-wrapper mb20">
            <div class="swiper-slide">
              <ul class="clear">
                <li><a href="/watch/one-piece-ep1176/"><em><span>第1176集</span>海贼王 第1176集</em></a></li>
                <li><a href="/watch/one-piece-ep1175/"><em><span>第1175集</span>海贼王 第1175集</em></a></li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</body></html>
''';

    test('fetches https://dilidili.io/anime/<slug>/', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body></body></html>'));

      await api.listEpisodes('one-piece');

      verify(
        () => dio.get<String>('https://dilidili.io/anime/one-piece/', options: any(named: 'options')),
      ).called(1);
    });

    test('parses episode labels from the nested em > span', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(detailPageHtml));

      final episodes = await api.listEpisodes('one-piece');

      expect(episodes, hasLength(2));
      expect(episodes[0].title, '第1176集');
      expect(episodes[0].watchPageUrl, 'https://dilidili.io/watch/one-piece-ep1176/');
      expect(episodes[1].title, '第1175集');
      expect(episodes[1].watchPageUrl, 'https://dilidili.io/watch/one-piece-ep1175/');
    });

    test('returns an empty list when the page has no episode links', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no episodes</body></html>'));

      final episodes = await api.listEpisodes('nonexistent');

      expect(episodes, isEmpty);
    });
  });

  group('resolvePlaybackUrl', () {
    const watchUrl = 'https://dilidili.io/watch/one-piece-ep1176/';

    // Real watch-page markup (captured live, 2026-09-05): multiple
    // named "lines" per episode, each its own button.play-btn[play_id].
    // Only the first is read (v1 simplification, per explicit user
    // decision).
    const watchPageHtml = '''
<html><body>
  <div class="player_switch">
    <p>无法播放？试试切换线路</p>
    <div>
      <button class="play-btn on" id="1" play_id="346921" >第1176集 (线路ML)</button>
      <button class="play-btn on" id="2" play_id="346926" >第1176集 (线路MW)</button>
      <button class="play-btn on" id="3" play_id="346928" >第1176集 (线路MS)</button>
    </div>
  </div>
</body></html>
''';

    // Real /_get_play response (captured live, 2026-09-05).
    const getPlayJson = '''
{"result": {"play_cfg": "m3u8", "play_data": "https://v.lzcdn31.com/20260830/10791_931e1c5f/index.m3u8"}, "id": "_get_play_346921"}
''';

    test('uses the first play-btn\'s play_id and returns play_data as-is', () async {
      when(
        () => dio.get<String>(watchUrl, options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(watchPageHtml));
      when(
        () => dio.get<String>(
          'https://dilidili.io/_get_play',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => htmlResponse(getPlayJson));

      final source = await api.resolvePlaybackUrl(watchUrl);

      expect(source.url, 'https://v.lzcdn31.com/20260830/10791_931e1c5f/index.m3u8');
      expect(source.headers['Referer'], 'https://dilidili.io/');

      verify(
        () => dio.get<String>(
          'https://dilidili.io/_get_play',
          queryParameters: {'id': '346921'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('throws FormatException when there is no play-btn', () async {
      when(
        () => dio.get<String>(watchUrl, options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse('<html><body>no player here</body></html>'));

      expect(
        () => api.resolvePlaybackUrl(watchUrl),
        throwsFormatException,
      );
    });

    test('throws FormatException when /_get_play has no play_data', () async {
      when(
        () => dio.get<String>(watchUrl, options: any(named: 'options')),
      ).thenAnswer((_) async => htmlResponse(watchPageHtml));
      when(
        () => dio.get<String>(
          'https://dilidili.io/_get_play',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => htmlResponse('{"result": {"play_cfg": "m3u8"}}'));

      expect(
        () => api.resolvePlaybackUrl(watchUrl),
        throwsFormatException,
      );
    });
  });

  test('dilidiliApiProvider builds a DilidiliApi backed by dilidiliDioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(dilidiliApiProvider);
    expect(api, isA<DilidiliApi>());
  });

  test('dilidiliDioProvider sets a non-empty User-Agent header', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(dilidiliDioProvider);
    expect(dio.options.headers['User-Agent'], isNotEmpty);
  });
}
