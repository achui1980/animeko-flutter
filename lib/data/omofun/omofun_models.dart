import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../domain/media/media_source.dart';

const omofunSourceId = 'omofun';

/// A search hit on omofun.in (`/vod/detail/<vodId>.html`).
class OmofunCandidate implements MediaCandidate {
  const OmofunCandidate({required this.vodId, required this.title});

  final String vodId;

  @override
  final String title;

  @override
  String get sourceId => omofunSourceId;
}

/// One episode, played via `/_dyn_plays/<vodId>/ep<ep>`.
class OmofunEpisode implements MediaEpisode {
  const OmofunEpisode({
    required this.vodId,
    required this.ep,
    required this.title,
  });

  final String vodId;
  final int ep;

  @override
  final String title;

  @override
  String get sourceId => omofunSourceId;
}

/// One m3u8 line from `video_plays`. CDN hosts are mainland resource
/// sites, so libmpv should bypass the user's proxy.
class OmofunPlaybackSource extends MediaPlaybackSource {
  const OmofunPlaybackSource({required this.url, required this.label});

  @override
  final String url;

  @override
  final String? label;

  @override
  Map<String, String> get headers => const {};

  @override
  bool get prefersDirectConnection => true;
}

final _detailHref = RegExp(r'/vod/detail/(\d+)\.html');

/// Parses `/vod/search.html?wd=` result cards. Cards without a title or a
/// numeric vodId are skipped.
List<OmofunCandidate> parseOmofunSearch(String html) {
  final doc = html_parser.parse(html);
  final results = <OmofunCandidate>[];
  for (final card in doc.querySelectorAll('div.module-card-item')) {
    final link = card.querySelector('.module-card-item-title a');
    if (link == null) continue;
    final title = (link.querySelector('strong')?.text ?? link.text).trim();
    final match = _detailHref.firstMatch(link.attributes['href'] ?? '');
    if (title.isEmpty || match == null) continue;
    results.add(OmofunCandidate(vodId: match.group(1)!, title: title));
  }
  return results;
}

/// Parses the first `.module-play-list-content` of a detail page. Links
/// outside that list (recommendations etc.) are ignored.
List<OmofunEpisode> parseOmofunEpisodes(String html, String vodId) {
  final list = html_parser
      .parse(html)
      .querySelector('.module-play-list-content');
  if (list == null) return const [];
  final hrefPattern = RegExp(
    '^/vod/play/${RegExp.escape(vodId)}/ep(\\d+)\\.html\$',
  );
  final seen = <String>{};
  final episodes = <OmofunEpisode>[];
  for (final a in list.querySelectorAll('a')) {
    final href = a.attributes['href'] ?? '';
    final match = hrefPattern.firstMatch(href);
    if (match == null || !seen.add(href)) continue;
    final ep = int.parse(match.group(1)!);
    final span = a.querySelector('span')?.text.trim() ?? '';
    episodes.add(
      OmofunEpisode(vodId: vodId, ep: ep, title: span.isEmpty ? '第$ep集' : span),
    );
  }
  return episodes;
}

/// Parses the `/_dyn_plays` JSON. Dedupes by url (first wins), drops empty
/// and non-http(s) entries, labels each line with its `src_site`.
List<OmofunPlaybackSource> parseOmofunPlays(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map) return const [];
  final plays = decoded['video_plays'];
  if (plays is! List) return const [];

  final seen = <String>{};
  final lines = <OmofunPlaybackSource>[];
  for (final play in plays) {
    if (play is! Map) continue;
    final raw = play['play_data'];
    if (raw is! String) continue;
    final url = raw.trim();
    final scheme = Uri.tryParse(url)?.scheme;
    if (scheme != 'http' && scheme != 'https') continue;
    if (!seen.add(url)) continue;
    final site = play['src_site'];
    final label = site is String && site.trim().isNotEmpty
        ? site.trim()
        : '线路${lines.length + 1}';
    lines.add(OmofunPlaybackSource(url: url, label: label));
  }
  return lines;
}
