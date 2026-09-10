import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/media/media_source.dart';
import '../../domain/media/title_parser.dart';
import '../settings/proxy_dio_config.dart';
import '../torrent/rqbit_engine.dart';
import '../torrent/torrent_playback_source.dart';
import 'rss_parser.dart';

part 'rss_media_source.g.dart';

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

/// Generic RSS BT media source, driven by a template [RssSourceConfig].
///
/// A single RSS search already returns every release for every episode, so
/// all parsing/grouping happens once inside [search]. [listEpisodes] and
/// [resolvePlayback] only ever read from the cached [RssSeriesCandidate],
/// issuing no further network requests.
class RssMediaSource implements MediaSource {
  RssMediaSource(this.config, this._dio, this._engine);

  final RssSourceConfig config;
  final Dio _dio;
  final RqbitEngine _engine;

  @override
  String get id => config.name;

  @override
  String get displayName => config.name;

  @override
  Future<List<MediaCandidate>> search(String title) async {
    final url = config.searchUrl.replaceAll(
      '{keyword}',
      Uri.encodeQueryComponent(title),
    );
    final response = await _dio.get<String>(url);
    final items = parseRssFeed(response.data ?? '');
    final groups = groupByEpisode(items);

    return [
      RssSeriesCandidate(sourceId: config.name, title: title, groups: groups),
    ];
  }

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async {
    final rssCandidate = candidate as RssSeriesCandidate;
    final episodeNumbers = rssCandidate.groups.keys.toList()..sort();
    return [
      for (final episodeNumber in episodeNumbers)
        RssEpisode(
          sourceId: config.name,
          title: '第 $episodeNumber 集',
          episodeNumber: episodeNumber,
          releases: rssCandidate.groups[episodeNumber]!,
        ),
    ];
  }

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(
    MediaEpisode episode,
  ) async {
    final rssEpisode = episode as RssEpisode;
    final sortedReleases = [...rssEpisode.releases]
      ..sort((a, b) {
        final resA = a.parsed.resolution ?? '';
        final resB = b.parsed.resolution ?? '';
        return resB.compareTo(resA);
      });

    return [
      for (final release in sortedReleases)
        // Reuse the RSS Dio (already proxy-aware and timeout-bounded, see
        // `mikanRssDio` below) to fetch the `.torrent` bytes: the download
        // URL is on the same host as the search feed, so it needs the same
        // proxy/timeout handling -- a fresh unconfigured `Dio()` would
        // silently bypass the user's proxy and could hang forever.
        TorrentPlaybackSource(release: release, engine: _engine, dio: _dio),
    ];
  }
}

/// Bounded so a single unreachable/hanging Mikan mirror (e.g. a
/// misconfigured proxy that accepts the connection but never completes
/// the TLS handshake) fails within a fixed time instead of blocking
/// [SubjectEpisodesController]'s `Future.wait` forever -- every other
/// registered [MediaSource] is queried concurrently and a single slow
/// source must not stall the whole episode list (see the per-source
/// try/catch in `_fetchFromSource`, which only helps once this call
/// actually throws).
const _mikanConnectTimeout = Duration(seconds: 10);
const _mikanReceiveTimeout = Duration(seconds: 10);

@riverpod
Dio mikanRssDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      headers: {'User-Agent': 'Mozilla/5.0'},
      connectTimeout: _mikanConnectTimeout,
      receiveTimeout: _mikanReceiveTimeout,
    ),
  );
  configureProxy(dio, ref);
  return dio;
}
