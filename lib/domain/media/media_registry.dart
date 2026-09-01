// lib/domain/media/media_registry.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';
import '../../data/xifan/xifan_api.dart';
import '../../data/xifan/xifan_models.dart';
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
  Future<List<MediaCandidate>> search(String title) =>
      _api.searchCategories(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.fetchCategoryEpisodes((candidate as Anime1Category).id);

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as Anime1Episode).pageUrl);
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
  Future<List<MediaCandidate>> search(String title) => _api.search(title);

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      _api.listEpisodes((candidate as XifanBangumi).id);

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) =>
      _api.resolvePlaybackUrl((episode as XifanEpisode).watchPageUrl);
}

/// Every registered [MediaSource], queried concurrently by
/// `SubjectEpisodesController`. Add a new source here (and nowhere else)
/// to make it participate in the merged search/episode-list flow.
@riverpod
List<MediaSource> mediaSources(Ref ref) => [
      Anime1MediaSource(ref.watch(anime1ApiProvider)),
      XifanMediaSource(ref.watch(xifanApiProvider)),
    ];
