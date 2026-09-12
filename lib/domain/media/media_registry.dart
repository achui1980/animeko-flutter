// lib/domain/media/media_registry.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';
import '../../data/dilidili/dilidili_api.dart';
import '../../data/dilidili/dilidili_models.dart';
import '../../data/rss/rss_media_source.dart';
import '../../data/torrent/rqbit_engine.dart';
import '../../data/xifan/xifan_api.dart';
import '../../data/xifan/xifan_models.dart';
import '../../data/yinghua/yinghua_api.dart';
import '../../data/yinghua/yinghua_models.dart';
import 'media_source.dart';

part 'media_registry.g.dart';

/// Adapts the existing, unchanged [Anime1Api] to the shared [MediaSource]
/// interface. Downcasts the abstract [MediaCandidate]/[MediaEpisode]
/// parameters it receives back to [Anime1Category]/[Anime1Episode] --
/// safe because [SubjectEpisodesController] only ever passes this source
/// candidates/episodes that this same source itself produced.
class Anime1MediaSource implements MediaSource {
  Anime1MediaSource(this._api);
  final Anime1Api _api;

  @override
  String get id => 'anime1';

  @override
  String get displayName => 'anime1.me';

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.searchCategories(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.fetchCategoryEpisodes((candidate as Anime1Category).id);

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(
    MediaEpisode episode,
  ) async => [
    await _api.resolvePlaybackUrl((episode as Anime1Episode).pageUrl),
  ];
}

/// Adapts [XifanApi] to the shared [MediaSource] interface. See
/// [Anime1MediaSource]'s doc comment for the downcast-safety rationale.
class XifanMediaSource implements MediaSource {
  XifanMediaSource(this._api);
  final XifanApi _api;

  @override
  String get id => 'xifan';

  @override
  String get displayName => '稀饭动漫';

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.search(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.listEpisodes(candidate as XifanBangumi);

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl(episode as XifanEpisode);
}

/// Adapts [YinghuaApi] to the shared [MediaSource] interface. See
/// [Anime1MediaSource]'s doc comment for the downcast-safety rationale.
class YinghuaMediaSource implements MediaSource {
  YinghuaMediaSource(this._api);
  final YinghuaApi _api;

  @override
  String get id => 'yinghua';

  @override
  String get displayName => '樱花动漫';

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.search(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.listEpisodes((candidate as YinghuaBangumi).id);

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as YinghuaEpisode).playPageUrls);
}

/// Adapts [DilidiliApi] to the shared [MediaSource] interface. See
/// [Anime1MediaSource]'s doc comment for the downcast-safety rationale.
class DilidiliMediaSource implements MediaSource {
  DilidiliMediaSource(this._api);
  final DilidiliApi _api;

  @override
  String get id => 'dilidili';

  @override
  String get displayName => '嘀哩嘀哩';

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      _api.search(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.listEpisodes((candidate as DilidiliAnime).slug);

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as DilidiliEpisode).watchPageUrl);
}

/// Every registered [MediaSource], queried concurrently by
/// `SubjectEpisodesController`. Add a new source here (and nowhere else)
/// to make it participate in the merged search/episode-list flow.
///
/// [YinghuaMediaSource] is intentionally *not* registered here: its CDN
/// lines have repeatedly been observed dead/blocked in the wild (e.g. a
/// `vip.ffzy-plays.com` line returning HTTP 403 on every request), so the
/// source is disabled at the app level rather than removed outright --
/// [YinghuaMediaSource]/[YinghuaApi] remain intact and can be re-added to
/// this list if the situation improves.
///
/// [DilidiliMediaSource] is also intentionally *not* registered here:
/// users have reported playback repeatedly stalling at ~2 seconds (the
/// player's reported total duration was only ~2s, not the real episode
/// length), on at least one real title/CDN line combination. The exact
/// resolved URL was independently verified (via direct HTTP replication
/// of the app's own request chain) to be fully reachable and structurally
/// valid end-to-end -- an AES-128-encrypted HLS playlist with a relative
/// key URI, all segments and the key itself fetched successfully -- so
/// the root cause was not conclusively identified (a proxy interaction
/// with the encrypted/relative-key-URI playlist chain is suspected but
/// unconfirmed). Disabled as a stopgap per explicit user request rather
/// than left broken for users. [DilidiliMediaSource]/[DilidiliApi] remain
/// intact and can be re-added to this list if the issue is resolved.
///
@riverpod
List<MediaSource> mediaSources(Ref ref) => [
  Anime1MediaSource(ref.watch(anime1ApiProvider)),
  XifanMediaSource(ref.watch(xifanApiProvider)),
  RssMediaSource(
    mikanRssSourceConfig,
    ref.watch(mikanRssDioProvider),
    ref.watch(rqbitEngineProvider),
  ),
];
