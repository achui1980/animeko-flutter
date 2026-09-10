import 'package:xml/xml.dart';

/// A single `<item>` from a Mikan-style RSS feed.
class RssItem {
  const RssItem({
    required this.title,
    required this.torrentUrl,
    required this.contentLength,
    this.pubDate,
  });

  final String title;
  final String torrentUrl;
  final int contentLength;
  final DateTime? pubDate;
}

/// Parses a Mikan-style RSS 2.0 feed body into a list of [RssItem].
///
/// Mikan nests `<pubDate>` inside a `<torrent>` child element (not directly
/// under `<item>`), and always publishes an HTTP `.torrent` enclosure URL
/// (never a magnet link). Items that fail to parse are skipped rather than
/// aborting the whole feed.
List<RssItem> parseRssFeed(String xmlBody) {
  final document = XmlDocument.parse(xmlBody);
  final items = <RssItem>[];

  for (final itemElement in document.findAllElements('item')) {
    try {
      final title = itemElement.getElement('title')?.innerText.trim();
      final enclosure = itemElement.getElement('enclosure');
      final torrentUrl = enclosure?.getAttribute('url');
      final lengthStr = enclosure?.getAttribute('length');

      if (title == null || torrentUrl == null || lengthStr == null) {
        continue;
      }

      final torrentElement = itemElement.getElement('torrent');
      final pubDateStr = torrentElement?.getElement('pubDate')?.innerText.trim();

      items.add(RssItem(
        title: title,
        torrentUrl: torrentUrl,
        contentLength: int.parse(lengthStr),
        pubDate: pubDateStr != null ? DateTime.tryParse(pubDateStr) : null,
      ));
    } catch (_) {
      continue;
    }
  }

  return items;
}
