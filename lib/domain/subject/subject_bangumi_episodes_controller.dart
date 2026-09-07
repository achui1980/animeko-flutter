import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/bangumi_episode_models.dart';
import '../../data/subject/bangumi_episodes_api.dart';

part 'subject_bangumi_episodes_controller.g.dart';

/// Fetches the Bangumi-canonical episode list for [subjectId] via
/// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
/// SP/OP/ED excluded, defensive even though the API's own `type=0`
/// query param already filters server-side), and sorts ascending by
/// [BangumiEpisode.sort].
///
/// Fully independent of `SubjectEpisodesController` -- neither provider
/// blocks the other; see the design doc's Section 4.
@riverpod
class SubjectBangumiEpisodesController
    extends _$SubjectBangumiEpisodesController {
  @override
  Future<List<BangumiEpisode>> build({required int subjectId}) async {
    final episodes = await ref
        .watch(bangumiEpisodesApiProvider)
        .listEpisodes(subjectId);
    final mainEpisodes = episodes.where((e) => e.type == 0).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return mainEpisodes;
  }
}
