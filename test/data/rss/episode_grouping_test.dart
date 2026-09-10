import 'package:flutter_test/flutter_test.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';

RssItem _item(String title) => RssItem(
      title: title,
      torrentUrl: 'https://mikan.tangbai.cc/Download/x/x.torrent',
      contentLength: 100,
    );

void main() {
  group('groupByEpisode', () {
    test('groups a single-episode release under its episode number', () {
      final items = [_item('[Group][Show][10][1080P]')];
      final groups = groupByEpisode(items);

      expect(groups.keys, contains(10));
      expect(groups[10], hasLength(1));
    });

    test('expands a ranged release into every covered episode number', () {
      final items = [_item('[Group][Show][07-10][1080P]')];
      final groups = groupByEpisode(items);

      expect(groups.keys, containsAll([7, 8, 9, 10]));
      for (final ep in [7, 8, 9, 10]) {
        expect(groups[ep], hasLength(1));
      }
    });

    test('drops items whose episode number cannot be parsed', () {
      final items = [
        _item('[Group][Show][1080P][MP4]'),
        _item('[Group][Show][12][1080P]'),
      ];
      final groups = groupByEpisode(items);

      expect(groups.keys, [12]);
    });

    test('a single malformed item does not prevent others from grouping', () {
      final items = [
        _item('[Group][Show][12][1080P]'),
        _item('[Group][Show][13][1080P]'),
      ];
      final groups = groupByEpisode(items);

      expect(groups.keys, containsAll([12, 13]));
    });

    test('multiple releases for the same episode number are all kept', () {
      final items = [
        _item('[GroupA][Show][5][1080P]'),
        _item('[GroupB][Show][5][720P]'),
      ];
      final groups = groupByEpisode(items);

      expect(groups[5], hasLength(2));
    });
  });
}
