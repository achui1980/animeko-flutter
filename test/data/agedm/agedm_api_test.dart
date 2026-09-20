import 'package:animeko_flutter/data/agedm/agedm_api.dart';
import 'package:animeko_flutter/data/agedm/agedm_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late AgedmApi api;

  setUp(() {
    dio = MockDio();
    api = AgedmApi(dio);
  });

  Response<String> plainResponse(String body) {
    return Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );
  }

  group('search', () {
    // Real https://api.agedm.io/v2/search?query=... envelope (captured
    // live, 2026-09-19), trimmed to two videos and to the fields this
    // client actually reads.
    const searchJson = '''
{
  "code": 200,
  "message": "",
  "data": {
    "videos": [
      {
        "id": 20000001,
        "name": "海贼王",
        "name_original": "ONE PIECE",
        "name_other": "航海王 / ワンピース",
        "uptodate": "第1177集",
        "type": "TV",
        "status": "连载"
      },
      {
        "id": 20260163,
        "name": "Candy Caries 蛀在糖糖里",
        "name_original": "",
        "name_other": "",
        "uptodate": "第23集",
        "type": "WEB",
        "status": "完结"
      }
    ],
    "total": 2,
    "totalPage": 1
  }
}
''';

    void stubSearch(String query, String body) {
      when(
        () => dio.get<String>(
          'https://api.agedm.io/v2/search',
          queryParameters: {'query': query, 'page': '1'},
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => plainResponse(body));
    }

    test('requests page 1 of the v2 search endpoint', () async {
      stubSearch('海贼王', searchJson);

      await api.search('海贼王');

      verify(
        () => dio.get<String>(
          'https://api.agedm.io/v2/search',
          queryParameters: {'query': '海贼王', 'page': '1'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('parses every video into an AgedmAnime', () async {
      stubSearch('海贼王', searchJson);

      final result = await api.search('海贼王');

      expect(result.map((a) => a.id), [20000001, 20260163]);
      expect(result.map((a) => a.title), ['海贼王', 'Candy Caries 蛀在糖糖里']);
      expect(result.every((a) => a.sourceId == 'agedm'), isTrue);
    });

    test('sends the longest whitespace-separated token, because the API '
        'rejects any query containing whitespace', () async {
      stubSearch('PIECE', searchJson);

      final result = await api.search('ONE PIECE');

      expect(result, isNotEmpty);
      verify(
        () => dio.get<String>(
          'https://api.agedm.io/v2/search',
          queryParameters: {'query': 'PIECE', 'page': '1'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('truncates the query to the API\'s 8-character limit', () async {
      stubSearch('Fate/Zer', searchJson);

      await api.search('Fate/Zero');

      verify(
        () => dio.get<String>(
          'https://api.agedm.io/v2/search',
          queryParameters: {'query': 'Fate/Zer', 'page': '1'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('counts CJK characters singly when truncating', () async {
      stubSearch('Re：从零开始的', searchJson);

      await api.search('Re：从零开始的异世界生活 第四季');

      verify(
        () => dio.get<String>(
          'https://api.agedm.io/v2/search',
          queryParameters: {'query': 'Re：从零开始的', 'page': '1'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('returns an empty list for code 40050, which the API also uses for '
        '"no results"', () async {
      stubSearch('zzqqxx', '{"code": 40050, "message": "参数错误！"}');

      expect(await api.search('zzqqxx'), isEmpty);
    });

    test('returns an empty list when the API returns no videos', () async {
      stubSearch('海贼王', '{"code": 200, "message": "", "data": {"videos": []}}');

      expect(await api.search('海贼王'), isEmpty);
    });

    test('returns an empty list without a request for a blank query', () async {
      expect(await api.search('   '), isEmpty);

      verifyNever(
        () => dio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      );
    });

    test('skips videos missing an id or a name', () async {
      stubSearch('海贼王', '''
{
  "code": 200,
  "data": {
    "videos": [
      {"id": 1, "name": "ok"},
      {"name": "no id"},
      {"id": 3},
      {"id": 4, "name": ""}
    ]
  }
}
''');

      final result = await api.search('海贼王');

      expect(result.map((a) => a.id), [1]);
    });

    test('throws FormatException when the response is not JSON', () async {
      stubSearch('海贼王', '<html>blocked</html>');

      expect(() => api.search('海贼王'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException when the envelope has no data', () async {
      stubSearch('海贼王', '{"code": 200, "message": ""}');

      expect(() => api.search('海贼王'), throwsA(isA<FormatException>()));
    });
  });

  group('listEpisodes', () {
    // Real https://api.agedm.io/v2/detail/20260163 payload (captured live,
    // 2026-09-19), trimmed to three episodes per line. Note there is no
    // {code, message, data} envelope here -- unlike /v2/search, the detail
    // endpoint returns the payload at the top level. `xigua` is listed in
    // `player_vip`, so it must be dropped. `hnm3u8` deliberately uses a
    // different zero-padding and carries fewer episodes than the rest.
    const detailJson = '''
{
  "video": {
    "id": 20260163,
    "name": "Candy Caries 蛀在糖糖里",
    "playlists": {
      "xigua": [["第01集", "age_vip01"], ["第02集", "age_vip02"]],
      "ffm3u8": [["第01集", "age_ff01"], ["第02集", "age_ff02"], ["第03集", "age_ff03"]],
      "hnm3u8": [["第1集", "age_hn01"], ["第2集", "age_hn02"]],
      "wolong": [["第03集", "age_wl03"], ["特别篇", "age_wlsp"]]
    }
  },
  "player_vip": "qq,youku,mgtv,qiyi,xigua,zjm3u8",
  "player_jx": {
    "vip": "https://jx.wuzhoupai.com:8443/vip/?url=",
    "zj": "https://jx.wuzhoupai.com:8443/m3u8/?url="
  },
  "player_label_arr": {
    "xigua": "西瓜",
    "ffm3u8": "非凡",
    "hnm3u8": "红牛"
  }
}
''';

    void stubDetail(int id, String body) {
      when(
        () => dio.get<String>(
          'https://api.agedm.io/v2/detail/$id',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => plainResponse(body));
    }

    test('requests the v2 detail endpoint for the anime id', () async {
      stubDetail(20260163, detailJson);

      await api.listEpisodes(20260163);

      verify(
        () => dio.get<String>(
          'https://api.agedm.io/v2/detail/20260163',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('merges every non-VIP line into one episode list keyed by episode '
        'number, numbered episodes first and in ascending order', () async {
      stubDetail(20260163, detailJson);

      final result = await api.listEpisodes(20260163);

      expect(result.map((e) => e.title), ['第01集', '第02集', '第03集', '特别篇']);
      expect(result.every((e) => e.sourceId == 'agedm'), isTrue);
    });

    test('collects every line that carries a given episode', () async {
      stubDetail(20260163, detailJson);

      final result = await api.listEpisodes(20260163);

      // 第01集/第02集 exist on ffm3u8 + hnm3u8; 第03集 on ffm3u8 + wolong;
      // 特别篇 only on wolong. The VIP `xigua` line is excluded throughout.
      expect(result[0].lines.map((l) => l.key), ['ffm3u8', 'hnm3u8']);
      expect(result[1].lines.map((l) => l.key), ['ffm3u8', 'hnm3u8']);
      expect(result[2].lines.map((l) => l.key), ['ffm3u8', 'wolong']);
      expect(result[3].lines.map((l) => l.key), ['wolong']);
    });

    test('never exposes a line listed in player_vip', () async {
      stubDetail(20260163, detailJson);

      final result = await api.listEpisodes(20260163);

      expect(
        result.expand((e) => e.lines).map((l) => l.key),
        isNot(contains('xigua')),
      );
    });

    test(
      'labels lines from player_label_arr, falling back to the key',
      () async {
        stubDetail(20260163, detailJson);

        final result = await api.listEpisodes(20260163);

        expect(result[0].lines.map((l) => l.label), ['非凡', '红牛']);
        expect(result[3].lines.single.label, 'wolong');
      },
    );

    test('builds each line URL by concatenating player_jx.zj with the '
        'already-percent-encoded token', () async {
      stubDetail(20260163, '''
{
  "video": {
    "playlists": {
      "ffm3u8": [["第01集", "age_5577TOP%2FdcSam%2BKP9"]]
    }
  },
  "player_vip": "qq",
  "player_jx": {"zj": "https://jx.wuzhoupai.com:8443/m3u8/?url="},
  "player_label_arr": {}
}
''');

      final result = await api.listEpisodes(20260163);

      expect(
        result.single.lines.single.playPageUrl,
        'https://jx.wuzhoupai.com:8443/m3u8/?url=age_5577TOP%2FdcSam%2BKP9',
      );
    });

    test('skips malformed playlist entries', () async {
      stubDetail(1, '''
{
  "video": {
    "playlists": {
      "ffm3u8": [["第01集", "age_ok"], ["第02集"], [], ["", "age_notitle"], ["第03集", ""]]
    }
  },
  "player_vip": "qq",
  "player_jx": {"zj": "https://jx/?url="},
  "player_label_arr": {}
}
''');

      final result = await api.listEpisodes(1);

      expect(result.map((e) => e.title), ['第01集']);
    });

    test(
      'throws FormatException when every playlist requires the VIP parser',
      () async {
        stubDetail(1, '''
{
  "video": {"playlists": {"qiyi": [["第01集", "age_a"]]}},
  "player_vip": "qiyi",
  "player_jx": {"zj": "https://jx/?url="},
  "player_label_arr": {}
}
''');

        expect(() => api.listEpisodes(1), throwsA(isA<FormatException>()));
      },
    );

    test('throws FormatException when player_jx.zj is missing', () async {
      stubDetail(1, '''
{
  "video": {"playlists": {"ffm3u8": [["第01集", "age_a"]]}},
  "player_vip": "qiyi",
  "player_jx": {},
  "player_label_arr": {}
}
''');

      expect(() => api.listEpisodes(1), throwsA(isA<FormatException>()));
    });

    test('throws FormatException when the payload has no playlists', () async {
      stubDetail(1, '{"video": {"id": 1}}');

      expect(() => api.listEpisodes(1), throwsA(isA<FormatException>()));
    });

    test('throws FormatException when the payload is not JSON', () async {
      stubDetail(1, '<html>nope</html>');

      expect(() => api.listEpisodes(1), throwsA(isA<FormatException>()));
    });
  });

  group('resolvePlayback', () {
    // Real https://jx.wuzhoupai.com:8443/m3u8/?url=... page (captured live,
    // 2026-09-19), trimmed to the inline script that carries the plaintext
    // direct URL. Nothing on this "zj" path is encrypted -- only the
    // /vip/ path uses the WASM cipher, which this client never touches.
    String jxPage(String url) =>
        '''
<html><body>
<div id="player"></div>
<script>
        var Vurl = '$url';
        var Vurl_id = 'eb2b4850f2db5cc6329a11c64338d94e';
        var IsM3u8 = Vurl.toLowerCase().indexOf(".m3u8") > -1;
        var VideoType = IsM3u8 ? 'm3u8' : 'mp4';
</script>
</body></html>
''';

    const episode = AgedmEpisode(
      title: '第01集',
      lines: [
        AgedmLine(key: 'ffm3u8', label: '非凡', playPageUrl: 'https://jx/?url=a'),
        AgedmLine(key: 'hnm3u8', label: '红牛', playPageUrl: 'https://jx/?url=b'),
        AgedmLine(
          key: 'wolong',
          label: '凤雏云',
          playPageUrl: 'https://jx/?url=c',
        ),
      ],
    );

    void stubLine(String url, Response<String> Function() answer) {
      when(
        () => dio.get<String>(url, options: any(named: 'options')),
      ).thenAnswer((_) async => answer());
    }

    test('extracts Vurl from every line, preserving line order', () async {
      stubLine(
        'https://jx/?url=a',
        () => plainResponse(jxPage('https://vod.feifei-kan.com/a/index.m3u8')),
      );
      stubLine(
        'https://jx/?url=b',
        () => plainResponse(jxPage('https://hn.bfvvs.com/play/b/index.m3u8')),
      );
      stubLine(
        'https://jx/?url=c',
        () => plainResponse(jxPage('https://cdn.wlcdn88.com:777/c/index.m3u8')),
      );

      final result = await api.resolvePlayback(episode);

      expect(result.map((s) => s.url), [
        'https://vod.feifei-kan.com/a/index.m3u8',
        'https://hn.bfvvs.com/play/b/index.m3u8',
        'https://cdn.wlcdn88.com:777/c/index.m3u8',
      ]);
      expect(result.map((s) => s.label), ['非凡', '红牛', '凤雏云']);
    });

    test(
      'sends no headers, matching the jx page\'s no-referrer policy',
      () async {
        stubLine(
          'https://jx/?url=a',
          () => plainResponse(jxPage('https://cdn/a.m3u8')),
        );
        stubLine('https://jx/?url=b', () => plainResponse('no url here'));
        stubLine('https://jx/?url=c', () => plainResponse('no url here'));

        final result = await api.resolvePlayback(episode);

        expect(result.single.headers, isEmpty);
      },
    );

    test('marks every candidate as needing a direct connection', () async {
      stubLine(
        'https://jx/?url=a',
        () => plainResponse(jxPage('https://cdn/a.m3u8')),
      );
      stubLine('https://jx/?url=b', () => plainResponse('no url here'));
      stubLine('https://jx/?url=c', () => plainResponse('no url here'));

      final result = await api.resolvePlayback(episode);

      // A/B-tested with libmpv itself (2026-09-19): agedm's CDNs play
      // 4/4 direct and fail 4/4 through a proxy, so the player must not
      // forward the app's proxy for them.
      expect(result.single.prefersDirectConnection, isTrue);
    });

    test('keeps a non-ASCII path segment verbatim', () async {
      stubLine(
        'https://jx/?url=a',
        () => plainResponse(
          jxPage('https://c1.rrcdnbf2.com/video/haizeiwang/第001集/index.m3u8'),
        ),
      );
      stubLine('https://jx/?url=b', () => plainResponse('nope'));
      stubLine('https://jx/?url=c', () => plainResponse('nope'));

      final result = await api.resolvePlayback(episode);

      expect(
        result.single.url,
        'https://c1.rrcdnbf2.com/video/haizeiwang/第001集/index.m3u8',
      );
    });

    test('skips lines that fail and keeps the rest, in order', () async {
      stubLine(
        'https://jx/?url=a',
        () => throw DioException(
          requestOptions: RequestOptions(path: 'https://jx/?url=a'),
        ),
      );
      stubLine(
        'https://jx/?url=b',
        () => plainResponse(jxPage('https://hn.bfvvs.com/play/b/index.m3u8')),
      );
      // A parser page that resolved nothing still returns 200 HTML.
      stubLine('https://jx/?url=c', () => plainResponse(jxPage('')));

      final result = await api.resolvePlayback(episode);

      expect(result.map((s) => s.url), [
        'https://hn.bfvvs.com/play/b/index.m3u8',
      ]);
    });

    test('throws FormatException when every line fails', () async {
      stubLine('https://jx/?url=a', () => plainResponse('nope'));
      stubLine('https://jx/?url=b', () => plainResponse('nope'));
      stubLine('https://jx/?url=c', () => plainResponse('nope'));

      expect(
        () => api.resolvePlayback(episode),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when the episode has no lines', () async {
      expect(
        () => api.resolvePlayback(const AgedmEpisode(title: '第01集', lines: [])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('providers', () {
    test('agedmApiProvider builds an AgedmApi backed by agedmDioProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(agedmApiProvider), isA<AgedmApi>());
    });

    test('agedmDioProvider sets a non-empty User-Agent header', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(agedmDioProvider).options.headers['User-Agent'],
        isNotEmpty,
      );
    });
  });
}
