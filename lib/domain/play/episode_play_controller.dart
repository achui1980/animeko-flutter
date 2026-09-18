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
    // Cross-source lookup by subjectId+title (not the exact episodeKey,
    // which is source-specific) -- see the design doc's 2.4 decision.
    // Automatic source selection (`download_source_resolver.dart`) means
    // the file actually downloaded to disk for this episode may come from
    // a different source than the one currently being played (e.g.
    // watching via Mikan while the download was auto-selected from
    // anime1); a same-source-only lookup would report "not downloaded"
    // even though the file is on disk and playable.
    final local = await ref
        .read(downloadedEpisodeRepositoryProvider)
        .findCompletedForEpisode(subjectId, episode.title);
    if (local == null) return candidates;
    return [LocalFilePlaybackSource(local.localPath), ...candidates];
  }
}
