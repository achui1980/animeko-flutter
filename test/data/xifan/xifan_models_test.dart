import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XifanBangumi', () {
    test('implements MediaCandidate with sourceId "xifan"', () {
      const bangumi = XifanBangumi(
        id: 1001,
        title: '鬼灭之刃',
        backend: XifanBackend.htmlMirror,
      );
      expect(bangumi, isA<MediaCandidate>());
      expect(bangumi.sourceId, 'xifan');
      expect(bangumi.title, '鬼灭之刃');
      expect(bangumi.backend, XifanBackend.htmlMirror);
    });
  });

  group('XifanEpisode', () {
    test('implements MediaEpisode with sourceId "xifan"', () {
      const episode = XifanEpisode(
        title: '第01集',
        backend: XifanBackend.htmlMirror,
        watchPageUrls: ['https://dm1.xfdm.pro/watch/1001/1/1.html'],
      );
      expect(episode, isA<MediaEpisode>());
      expect(episode.sourceId, 'xifan');
      expect(episode.watchPageUrls, [
        'https://dm1.xfdm.pro/watch/1001/1/1.html',
      ]);
      expect(episode.supabaseEpisodeId, isNull);
    });

    test('defaults watchPageUrls to empty for a Supabase-backed episode', () {
      const episode = XifanEpisode(
        title: '第01集',
        backend: XifanBackend.supabase,
        supabaseEpisodeId: 122517,
      );
      expect(episode.watchPageUrls, isEmpty);
      expect(episode.supabaseEpisodeId, 122517);
    });
  });

  group('XifanPlaybackSource', () {
    test('implements MediaPlaybackSource, defaulting headers to empty', () {
      const source = XifanPlaybackSource(
        url: 'https://apn.moedot.net/d/wo/1/a.mp4',
      );
      expect(source, isA<MediaPlaybackSource>());
      expect(source.url, 'https://apn.moedot.net/d/wo/1/a.mp4');
      expect(source.headers, isEmpty);
    });
  });
}
