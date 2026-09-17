// lib/domain/play/episode_play_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../download/local_file_playback_source.dart';
import '../media/media_registry.dart';
import '../media/media_source.dart';
import 'subject_episodes_controller.dart';

part 'episode_play_controller.g.dart';

@riverpod
class EpisodePlayController extends _$EpisodePlayController {
  @override
  Future<List<MediaPlaybackSource>> build({
    required MergedEpisode episode,
    required int subjectId,
  }) async {
    final source = ref
        .watch(mediaSourcesProvider)
        .firstWhere((item) => item.id == episode.sourceId);
    final candidates = await source.resolvePlayback(episode.episode);
    final key = '$subjectId::${episode.sourceId}::${episode.title}';
    final local = await ref
        .read(downloadedEpisodeRepositoryProvider)
        .findCompleted(key);
    if (local == null) return candidates;
    return [LocalFilePlaybackSource(local.localPath), ...candidates];
  }
}
