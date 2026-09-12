import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/media/media_source.dart';
import '../../domain/media/title_parser.dart';
import '../torrent/rqbit_engine.dart';
import '../torrent/torrent_playback_source.dart';
import 'mikan_subject_locator.dart';
import 'mikan_subject_mapping_repository.dart';
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
    this.subjectSearchUrl,
    this.bangumiFeedUrl,
  });

  final String name;
  final String searchUrl;
  final String iconUrl;

  /// Template with a `{keyword}` placeholder for this source's *subject*
  /// (条目) search page -- an HTML page, not a feed. Only Mikan has one; it
  /// is consumed by `MikanSubjectLocator` (see [mikanSubjectLocator]) to
  /// resolve a Bangumi subjectId to this source's own subject id. Null for
  /// sources that only offer keyword search.
  final String? subjectSearchUrl;

  /// Template with a `{bangumiId}` placeholder for this source's complete
  /// per-subject feed. When non-null AND the subject mapping resolves,
  /// [RssMediaSource.search] fetches this instead of [searchUrl] -- a
  /// keyword search only returns releases whose *torrent title* contains
  /// every whitespace-separated part of the keyword, which silently drops
  /// whole subtitle groups (design doc "背景与问题"). Null for sources with
  /// no per-subject feed, whose behavior is then unchanged.
  final String? bangumiFeedUrl;
}

/// Mikan's 条目 (subject) search page template, shared by
/// [mikanRssSourceConfig] and the [mikanSubjectLocator] provider so neither
/// has to null-assert the other's copy.
const _mikanSubjectSearchUrl =
    'https://mikanani.me/Home/Search?searchstr={keyword}';

const mikanRssSourceConfig = RssSourceConfig(
  name: 'mikan',
  // mikanani.me is Mikan's official domain. An earlier revision pointed at
  // the `mikan.tangbai.cc` mirror, which turned out to be unreachable from
  // some networks (it never responds, unlike a clean DNS/TLS failure). The
  // official domain uses the exact same `/RSS/Search?searchstr=` endpoint
  // and RSS/torrent XML shape, so this is a drop-in swap.
  searchUrl: 'https://mikanani.me/RSS/Search?searchstr={keyword}',
  subjectSearchUrl: _mikanSubjectSearchUrl,
  bangumiFeedUrl: 'https://mikanani.me/RSS/Bangumi?bangumiId={bangumiId}',
  iconUrl: 'https://mikanani.me/favicon.ico',
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
  RssMediaSource(
    this.config,
    this._dio,
    this._engine, {
    MikanSubjectLocator? locator,
    MikanSubjectMappingRepository? mappingRepository,
  }) : assert(
         (locator == null) == (mappingRepository == null),
         'locator and mappingRepository are an all-or-nothing pair: the '
         'per-subject feed is only used when both are present, so passing '
         'just one silently reverts every search to the lossy keyword '
         'search with no error anywhere.',
       ),
       _locator = locator,
       _mappings = mappingRepository;

  final RssSourceConfig config;
  final Dio _dio;
  final RqbitEngine _engine;

  /// Both null for RSS sources that have no per-subject feed (see
  /// [RssSourceConfig.bangumiFeedUrl]) and in tests that only exercise the
  /// keyword-search path.
  final MikanSubjectLocator? _locator;
  final MikanSubjectMappingRepository? _mappings;

  @override
  String get id => config.name;

  @override
  String get displayName => config.name;

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) async {
    final keywordUrl = _keywordSearchUrl(title);
    final feedUrl = await _resolveFeedUrl(title, subjectId);

    var items = const <RssItem>[];
    if (feedUrl != keywordUrl) {
      items = await _tryFetchItems(feedUrl);
    }
    // An empty per-bangumi feed means the mapping is stale (Mikan retired
    // that bangumiId) or the endpoint changed. Cached positive mappings
    // never expire and nothing ever deletes them, so without this retry the
    // source would silently contribute nothing for that subject forever.
    // The keyword search is lossy, but it beats contributing nothing.
    if (items.isEmpty) {
      final response = await _dio.get<String>(keywordUrl);
      items = parseRssFeed(response.data ?? '');
    }
    final groups = groupByEpisode(items);

    return [
      RssSeriesCandidate(sourceId: config.name, title: title, groups: groups),
    ];
  }

  /// The feed's items, or an empty list when the request fails or the body
  /// is unparseable. Only ever used for the *optional* per-bangumi feed:
  /// [search] treats an empty result as "retry the keyword search", so a
  /// failure here degrades instead of failing the source. A throw on the
  /// keyword request itself is deliberately left to propagate.
  Future<List<RssItem>> _tryFetchItems(String url) async {
    try {
      final response = await _dio.get<String>(url);
      return parseRssFeed(response.data ?? '');
    } catch (_) {
      return const [];
    }
  }

  /// The complete per-subject feed when this source has one and the subject
  /// mapping resolves, else today's keyword search. Both paths return the
  /// same RSS shape, so everything downstream is unchanged.
  Future<String> _resolveFeedUrl(String title, int? subjectId) async {
    final bangumiFeedUrl = config.bangumiFeedUrl;
    final locator = _locator;
    final mappings = _mappings;
    if (subjectId == null ||
        bangumiFeedUrl == null ||
        locator == null ||
        mappings == null) {
      return _keywordSearchUrl(title);
    }

    final bangumiId = await _resolveBangumiId(
      subjectId: subjectId,
      nameCn: title,
      locator: locator,
      mappings: mappings,
    );
    if (bangumiId == null) return _keywordSearchUrl(title);
    return bangumiFeedUrl.replaceAll('{bangumiId}', '$bangumiId');
  }

  String _keywordSearchUrl(String title) =>
      config.searchUrl.replaceAll('{keyword}', Uri.encodeQueryComponent(title));

  /// Cache first, then the locator, whose answer is written back only when it
  /// was *conclusive*. Returns null on ANY problem: a mapping is an
  /// optimization, never a precondition, so a broken cache or an unlocatable
  /// subject must degrade to keyword search rather than fail the source
  /// (design doc "错误处理").
  ///
  /// [MikanLocateOutcome.undetermined] is deliberately not persisted: a
  /// stored `null` means "confirmed absent from Mikan" and is honoured for
  /// [MikanSubjectMappingRepository.negativeTtl], so caching one transient
  /// network failure would pin the subject to the lossy keyword search for
  /// 7 days -- and nothing ever deletes a mapping row, so the network
  /// recovering would not help. Not caching it costs at most a re-resolve on
  /// the next visit.
  Future<int?> _resolveBangumiId({
    required int subjectId,
    required String nameCn,
    required MikanSubjectLocator locator,
    required MikanSubjectMappingRepository mappings,
  }) async {
    try {
      final cached = await mappings.lookup(subjectId);
      if (cached != null) return cached.bangumiId;

      // Null when the subject was never cached locally, in which case the
      // locator simply skips its Japanese-name keyword candidate.
      final nameJp = await mappings.readJapaneseName(subjectId);
      final resolved = await locator.resolveBangumiId(
        subjectId: subjectId,
        nameCn: nameCn,
        nameJp: nameJp,
      );
      if (resolved.outcome != MikanLocateOutcome.undetermined) {
        // A failed cache write must not discard an answer we already paid
        // 1-6 HTTP requests for; worst case the next visit re-resolves it.
        try {
          await mappings.save(subjectId, resolved.bangumiId);
        } catch (_) {
          // Intentionally ignored -- see above.
        }
      }
      // Null for both `absent` and `undetermined`: either way *this* call
      // falls back to the keyword search.
      return resolved.bangumiId;
    } catch (_) {
      return null;
    }
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
  return dio;
}

/// Resolves Bangumi subject ids to Mikan bangumi ids for
/// [RssMediaSource.search].
///
/// Deliberately built on the same [mikanRssDio] as the feed requests: the
/// 条目 search page and bangumi pages live on the same host and need the
/// same proxy handling and timeout bounds. Reads the shared
/// [_mikanSubjectSearchUrl] const rather than
/// [mikanRssSourceConfig]'s nullable copy, so no null-assert is needed.
@riverpod
MikanSubjectLocator mikanSubjectLocator(Ref ref) => MikanSubjectLocator(
  ref.watch(mikanRssDioProvider),
  searchUrlTemplate: _mikanSubjectSearchUrl,
);
