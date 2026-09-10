import '../../domain/media/media_source.dart';
import '../../domain/media/title_parser.dart';
import 'rss_parser.dart';

/// Configuration for one instance of the generic RSS BT media source.
///
/// Mirrors upstream Animeko's `rss` factory: [searchUrl] is a template with
/// a `{keyword}` placeholder.
class RssSourceConfig {
  const RssSourceConfig({
    required this.name,
    required this.searchUrl,
    required this.iconUrl,
  });

  final String name;
  final String searchUrl;
  final String iconUrl;
}

const mikanRssSourceConfig = RssSourceConfig(
  name: 'mikan',
  searchUrl: 'https://mikan.tangbai.cc/RSS/Search?searchstr={keyword}',
  iconUrl: 'https://mikan.tangbai.cc/favicon.ico',
);

/// One parsed BT release: the raw RSS item plus its parsed title metadata.
class RssRelease {
  const RssRelease({required this.item, required this.parsed});

  final RssItem item;
  final ParsedTitle parsed;
}

/// Groups raw RSS items by episode number, discarding items whose title
/// could not be parsed into an [EpisodeRange]. A single malformed item is
/// skipped via try/catch so it never prevents the rest of the feed from
/// being grouped. Ranged releases (e.g. episodes 07-10) are expanded so the
/// same release appears under every covered episode number.
Map<int, List<RssRelease>> groupByEpisode(List<RssItem> items) {
  final groups = <int, List<RssRelease>>{};
  for (final item in items) {
    try {
      final parsed = parseTitle(item.title);
      final range = parsed.episodeRange;
      if (range == null) continue;
      final release = RssRelease(item: item, parsed: parsed);
      for (final episodeNumber in range.expand()) {
        groups.putIfAbsent(episodeNumber, () => []).add(release);
      }
    } catch (_) {
      continue;
    }
  }
  return groups;
}

/// One subject-level search result: a Mikan RSS search already carries every
/// release for every episode, so all grouping happens once, at search time.
/// [listEpisodes] and [resolvePlayback] on the eventual RssMediaSource only
/// ever read from [groups]; they issue no further network requests.
class RssSeriesCandidate implements MediaCandidate {
  const RssSeriesCandidate({
    required this.sourceId,
    required this.title,
    required this.groups,
  });

  @override
  final String sourceId;
  @override
  final String title;
  final Map<int, List<RssRelease>> groups;
}

class RssEpisode implements MediaEpisode {
  const RssEpisode({
    required this.sourceId,
    required this.title,
    required this.episodeNumber,
    required this.releases,
  });

  @override
  final String sourceId;
  @override
  final String title;
  final int episodeNumber;
  final List<RssRelease> releases;
}
