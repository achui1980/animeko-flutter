// lib/domain/play/episode_play_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../media/media_registry.dart';
import '../media/media_source.dart';
import 'subject_episodes_controller.dart';

part 'episode_play_controller.g.dart';

@riverpod
class EpisodePlayController extends _$EpisodePlayController {
  @override
  Future<MediaPlaybackSource> build({required MergedEpisode episode}) {
    final sources = ref.watch(mediaSourcesProvider);
    final source = sources.firstWhere((s) => s.id == episode.sourceId);
    return source.resolvePlayback(episode.episode);
  }
}
