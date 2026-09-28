import 'package:animeko_flutter/data/omofun/m3u8_line_prober.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http_adapter.dart';

const _m3u8 = '#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:10,\nseg0.ts\n';

void main() {
  Dio dioWith(Map<String, Future<ResponseBody> Function()> routes) =>
      Dio()..httpClientAdapter = FakeHttpAdapter(routes);

  test('keeps only 2xx #EXTM3U lines, preserving original order', () async {
    final dio = dioWith({
      'https://a.test/1.m3u8': respond(_m3u8),
      'https://b.test/2.m3u8': respond('forbidden', 403),
      'https://c.test/3.m3u8': respond('nope', 404),
      'https://d.test/4.m3u8': respond('<html>blocked</html>'),
      'https://f.test/6.m3u8': respond(_m3u8),
    });
    final lines = [
      'https://a.test/1.m3u8',
      'https://b.test/2.m3u8',
      'https://c.test/3.m3u8',
      'https://d.test/4.m3u8',
      'https://e.test/unreachable.m3u8',
      'https://f.test/6.m3u8',
    ];
    final live = await probeM3u8Lines(lines, urlOf: (l) => l, dio: dio);
    expect(live, ['https://a.test/1.m3u8', 'https://f.test/6.m3u8']);
  });

  test('drops lines slower than the timeout', () async {
    final dio = dioWith({
      'https://slow.test/x.m3u8': () => Future.delayed(
        const Duration(seconds: 1),
        () => ResponseBody.fromString(_m3u8, 200),
      ),
      'https://fast.test/x.m3u8': respond(_m3u8),
    });
    final live = await probeM3u8Lines(
      ['https://slow.test/x.m3u8', 'https://fast.test/x.m3u8'],
      urlOf: (l) => l,
      dio: dio,
      timeout: const Duration(milliseconds: 50),
    );
    expect(live, ['https://fast.test/x.m3u8']);
  });

  test('empty input returns empty output', () async {
    expect(
      await probeM3u8Lines(<String>[], urlOf: (l) => l, dio: Dio()),
      isEmpty,
    );
  });

  group('looksLikeM3u8', () {
    test('accepts BOM and leading whitespace', () {
      // UTF-8 BOM bytes followed by whitespace and the tag.
      expect(
        looksLikeM3u8([0xEF, 0xBB, 0xBF, ...'\n  #EXTM3U\n'.codeUnits]),
        isTrue,
      );
      expect(looksLikeM3u8(' \n#EXTM3U'.codeUnits), isTrue);
    });

    test('rejects html and empty bodies', () {
      expect(looksLikeM3u8('<html>'.codeUnits), isFalse);
      expect(looksLikeM3u8(const []), isFalse);
    });
  });
}
