import 'package:animeko_flutter/data/omofun/omofun_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures captured live from https://omofun.in on 2026-09-28, trimmed.
const _searchHtml = '''
<html><body>
<div class="module-card-item module-item">
  <div class="module-card-item-class">日漫</div>
  <a href="/vod/detail/2023103093.html" class="module-card-item-poster"><div class="module-item-cover"><div class="module-item-note">更新至第28集</div><div class="module-item-pic"><img class="lazy lazyload" data-original="/vodimg/small/2023103093.jpg" alt="葬送的芙莉莲" src="/loading.gif"></div></div></a>
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/2023103093.html"><strong>葬送的芙莉莲</strong></a></div></div>
</div>
<div class="module-card-item module-item">
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/2026838825.html"><strong>葬送的芙莉莲 第二季</strong></a></div></div>
</div>
<div class="module-card-item module-item">
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/abc.html"><strong>坏链接</strong></a></div></div>
</div>
<div class="module-card-item module-item">
  <div class="module-card-item-info"><div class="module-card-item-title"><a href="/vod/detail/1.html"><strong>  </strong></a></div></div>
</div>
</body></html>
''';

const _detailHtml = '''
<html><body>
<div class="module-list sort-list tab-list his-tab-list" id="panel1"><div class="module-play-list"><div class="module-play-list-content module-play-list-base">
<a class="module-play-list-link" href="/vod/play/2023103093/ep1.html" title="播放葬送的芙莉莲第01集"><span>第01集</span></a>
<a class="module-play-list-link" href="/vod/play/2023103093/ep2.html" title="播放葬送的芙莉莲第02集"><span>第02集</span></a>
<a class="module-play-list-link" href="/vod/play/2023103093/ep2.html" title="播放葬送的芙莉莲第02集"><span>第02集</span></a>
<a class="module-play-list-link" href="/vod/play/2023103093/ep3.html"></a>
<a class="module-play-list-link" href="/vod/play/999/ep1.html"><span>别的番</span></a>
</div></div></div>
<div class="module-play-list-content"><a href="/vod/play/2023103093/ep99.html"><span>列表外</span></a></div>
</body></html>
''';

const _playsJson = '''
{"video_plays":[
 {"play_data":"https://v.gsuus.com/play/7axxj2Ba/index.m3u8","src_site":"gszy"},
 {"play_data":"https://hn.bfvvs.com/play/DdwwgK8d/index.m3u8","src_site":"hnzy"},
 {"play_data":"https://v.gsuus.com/play/7axxj2Ba/index.m3u8","src_site":"gszy"},
 {"play_data":"","src_site":"empty"},
 {"play_data":"/_player_x_/relative.m3u8","src_site":"rel"},
 {"play_data":"https://bfikuncdn.com/20230929/f0a53bgA/index.m3u8"}
],"html_content":"<li></li>"}
''';

void main() {
  group('parseOmofunSearch', () {
    test('parses cards and skips ones without title or numeric vodId', () {
      final results = parseOmofunSearch(_searchHtml);
      expect(results.map((c) => c.vodId), ['2023103093', '2026838825']);
      expect(results.map((c) => c.title), ['葬送的芙莉莲', '葬送的芙莉莲 第二季']);
      expect(results.first.sourceId, 'omofun');
    });

    test('returns empty list when there are no cards', () {
      expect(parseOmofunSearch('<html><body>无结果</body></html>'), isEmpty);
    });
  });

  group('parseOmofunEpisodes', () {
    test('uses first list, keeps order, dedupes, filters other vodIds', () {
      final eps = parseOmofunEpisodes(_detailHtml, '2023103093');
      expect(eps.map((e) => e.ep), [1, 2, 3]);
      expect(eps.map((e) => e.title), ['第01集', '第02集', '第3集']);
      expect(eps.every((e) => e.vodId == '2023103093'), isTrue);
      expect(eps.first.sourceId, 'omofun');
    });

    test('returns empty list when there is no play list', () {
      expect(parseOmofunEpisodes('<html></html>', '1'), isEmpty);
    });
  });

  group('parseOmofunPlays', () {
    test('dedupes by url keeping first, drops empty and non-http lines', () {
      final lines = parseOmofunPlays(_playsJson);
      expect(lines.map((l) => l.url), [
        'https://v.gsuus.com/play/7axxj2Ba/index.m3u8',
        'https://hn.bfvvs.com/play/DdwwgK8d/index.m3u8',
        'https://bfikuncdn.com/20230929/f0a53bgA/index.m3u8',
      ]);
      expect(lines.map((l) => l.label), ['gszy', 'hnzy', '线路3']);
      expect(lines.every((l) => l.prefersDirectConnection), isTrue);
      expect(lines.every((l) => l.headers.isEmpty), isTrue);
    });

    test('returns empty list on malformed payloads', () {
      expect(parseOmofunPlays('not json'), isEmpty);
      expect(parseOmofunPlays('[]'), isEmpty);
      expect(parseOmofunPlays('{"video_plays":"x"}'), isEmpty);
    });
  });
}
