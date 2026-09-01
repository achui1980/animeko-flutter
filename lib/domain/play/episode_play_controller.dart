// lib/domain/play/episode_play_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';

part 'episode_play_controller.g.dart';

@riverpod
class EpisodePlayController extends _$EpisodePlayController {
  @override
  Future<Anime1PlaybackSource> build({required String episodePageUrl}) {
    final api = ref.watch(anime1ApiProvider);
    return api.resolvePlaybackUrl(episodePageUrl);
  }
}
