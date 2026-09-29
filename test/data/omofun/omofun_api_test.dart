import 'package:animeko_flutter/data/omofun/omofun_api.dart';
import 'package:animeko_flutter/data/omofun/omofun_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import 'fake_http_adapter.dart';

class MockDio extends Mock implements Dio {}

Response<String> plainResponse(String body) => Response(
  data: body,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

// Captured live from https://omofun.in on 2026-09-28, trimmed.
const _searchHtml = '''
<div class="module-card-item module-item"><div class="module-card-item-title"><a href="/vod/detail/2023103093.html"><strong>葬送的芙莉莲</strong></a></div></div>
''';
const _detailHtml = '''
<div class="module-play-list-content"><a href="/vod/play/2023103093/ep1.html"><span>第01集</span></a></div>
''';
const _playsJson = '''
{"video_plays":[
 {"play_data":"https://dead.test/a/index.m3u8","src_site":"jszy"},
 {"play_data":"https://live.test/b/index.m3u8","src_site":"gszy"},
 {"play_data":"https://live2.test/c/index.m3u8","src_site":"hnzy"}
]}
''';

const _episode = OmofunEpisode(vodId: '2023103093', ep: 1, title: '第01集');
const _playsUrl = 'https://omofun.in/_dyn_plays/2023103093/ep1';

void main() {
  late MockDio siteDio;
  late FakeHttpAdapter probeAdapter;
  late OmofunApi api;

  setUp(() {
    siteDio = MockDio();
    probeAdapter = FakeHttpAdapter({
      'https://live.test/b/index.m3u8': respond('#EXTM3U\n'),
      'https://live2.test/c/index.m3u8': respond('#EXTM3U\n'),
    });
    api = OmofunApi(
      siteDio,
      probeDio: Dio()..httpClientAdapter = probeAdapter,
      probeTimeout: const Duration(milliseconds: 200),
    );
  });

  void stubPlays(String body) {
    when(
      () => siteDio.get<String>(_playsUrl, options: any(named: 'options')),
    ).thenAnswer((_) async => plainResponse(body));
  }

  test('search hits /vod/search.html with wd param', () async {
    when(
      () => siteDio.get<String>(
        'https://omofun.in/vod/search.html',
        queryParameters: {'wd': '葬送的芙莉莲'},
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => plainResponse(_searchHtml));

    final results = await api.search('葬送的芙莉莲');
    expect(results.single.vodId, '2023103093');
  });

  test('listEpisodes hits the detail page', () async {
    when(
      () => siteDio.get<String>(
        'https://omofun.in/vod/detail/2023103093.html',
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => plainResponse(_detailHtml));

    final eps = await api.listEpisodes('2023103093');
    expect(eps.single.ep, 1);
  });

  test('resolvePlayback returns only live lines in original order', () async {
    stubPlays(_playsJson);
    final lines = await api.resolvePlayback(_episode);
    expect(lines.map((l) => l.label), ['gszy', 'hnzy']);
    expect(lines.every((l) => l.prefersDirectConnection), isTrue);
  });

  test(
    'resolvePlayback falls back to all lines when every probe fails',
    () async {
      probeAdapter.routes.clear();
      stubPlays(_playsJson);
      final lines = await api.resolvePlayback(_episode);
      expect(lines.map((l) => l.label), ['jszy', 'gszy', 'hnzy']);
    },
  );

  test('resolvePlayback throws StateError when there are no lines', () async {
    stubPlays('{"video_plays":[]}');
    expect(api.resolvePlayback(_episode), throwsStateError);
  });

  test('resolvePlayback throws StateError when /_dyn_plays fails', () async {
    when(
      () => siteDio.get<String>(_playsUrl, options: any(named: 'options')),
    ).thenThrow(
      DioException.connectionError(
        requestOptions: RequestOptions(path: _playsUrl),
        reason: 'down',
      ),
    );
    expect(api.resolvePlayback(_episode), throwsStateError);
  });

  test('omofunApiProvider wires up', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(omofunApiProvider), isA<OmofunApi>());
  });
}
