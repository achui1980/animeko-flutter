import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XifanBangumi', () {
    test('implements MediaCandidate with sourceId "xifan"', () {
      const bangumi = XifanBangumi(id: 1001, title: '鬼灭之刃');
      expect(bangumi, isA<MediaCandidate>());
      expect(bangumi.sourceId, 'xifan');
      expect(bangumi.title, '鬼灭之刃');
    });
  });

  group('XifanEpisode', () {
    test('implements MediaEpisode with sourceId "xifan"', () {
      const episode = XifanEpisode(
        title: '第01集',
        watchPageUrl: 'https://dm1.xfdm.pro/watch/1001/1/1.html',
      );
      expect(episode, isA<MediaEpisode>());
      expect(episode.sourceId, 'xifan');
      expect(episode.watchPageUrl, 'https://dm1.xfdm.pro/watch/1001/1/1.html');
    });
  });

  group('XifanPlaybackSource', () {
    test('implements MediaPlaybackSource, defaulting headers to empty', () {
      const source = XifanPlaybackSource(url: 'https://apn.moedot.net/d/wo/1/a.mp4');
      expect(source, isA<MediaPlaybackSource>());
      expect(source.url, 'https://apn.moedot.net/d/wo/1/a.mp4');
      expect(source.headers, isEmpty);
    });
  });
}
