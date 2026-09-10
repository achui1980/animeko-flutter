import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';

void main() {
  late String xmlBody;

  setUpAll(() {
    xmlBody = File('test/fixtures/mikan_rss_search_sample.xml').readAsStringSync();
  });

  group('parseRssFeed', () {
    test('parses all items from the fixture', () {
      final items = parseRssFeed(xmlBody);
      expect(items, hasLength(10));
    });

    test('reads pubDate from the nested torrent element, not item level', () {
      final items = parseRssFeed(xmlBody);
      final first = items.first;
      expect(first.pubDate, isNotNull);
      expect(first.pubDate!.year, 2026);
      expect(first.pubDate!.month, 9);
      expect(first.pubDate!.day, 9);
    });

    test('extracts the .torrent enclosure url, never a magnet link', () {
      final items = parseRssFeed(xmlBody);
      for (final item in items) {
        expect(item.torrentUrl, startsWith('https://'));
        expect(item.torrentUrl, endsWith('.torrent'));
        expect(item.torrentUrl, isNot(contains('magnet:')));
      }
    });

    test('extracts real content length matching enclosure length', () {
      final items = parseRssFeed(xmlBody);
      expect(items.first.contentLength, 745432704);
    });

    test('preserves the raw RSS title verbatim (including entities)', () {
      final items = parseRssFeed(xmlBody);
      final secondItem = items[1];
      expect(secondItem.title, contains('澄空学园&动漫国字幕组'));
    });

    test('skips malformed items without throwing', () {
      const malformed = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"><channel><title>t</title><link>l</link><description>d</description>
<item><guid isPermaLink="false">bad</guid><link>l</link><title>bad item</title><description>d</description></item>
<item><guid isPermaLink="false">[G][Show][1][MP4]</guid><link>https://mikan.tangbai.cc/Home/Episode/x</link><title>[G][Show][1][MP4]</title><description>d</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/x</link><contentLength>100</contentLength><pubDate>2026-01-01T00:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="100" url="https://mikan.tangbai.cc/Download/20260101/x.torrent" /></item>
</channel></rss>''';

      final items = parseRssFeed(malformed);
      expect(items, hasLength(1));
      expect(items.first.title, '[G][Show][1][MP4]');
    });
  });
}
