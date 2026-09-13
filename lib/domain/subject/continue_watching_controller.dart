// lib/domain/subject/continue_watching_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/play/last_played_episode_storage.dart';
import '../../data/subject/subject_episode_models.dart';
import 'subject_main_episodes_controller.dart';

part 'continue_watching_controller.g.dart';

/// Which episode the detail page's primary button should play.
///
/// * stored episode id still present in the main-episode list -> that
///   episode (button reads 「继续观看 第 N 集」)
/// * nothing stored, or the stored id no longer exists (the subject's
///   episode list changed) -> the first main episode (button reads
///   「开始观看」)
/// * no main episodes at all -> null, and the caller hides the button
///
/// (Those three branches are the design doc's 「新增『最近播放集数』」
/// section, `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`.)
///
/// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
/// never garbage-collected -- it exposes only `get`/`set`, no delete, so a
/// subject can drop episodes, or the id can come from a different data
/// revision, and the entry still lingers.
///
/// The result carries no "was this resumed?" flag on purpose: a caller that
/// needs to pick between the two button labels compares this episode's id
/// against `lastPlayedEpisodeStorageProvider`
/// (`lib/data/play/last_played_episode_storage.dart`) itself.
@riverpod
Future<SubjectEpisode?> continueWatching(
  Ref ref, {
  required int subjectId,
}) async {
  final episodes = await ref.watch(
    subjectMainEpisodesControllerProvider(subjectId: subjectId).future,
  );
  if (episodes.isEmpty) return null;

  final storage = await ref.watch(lastPlayedEpisodeStorageProvider.future);
  final lastPlayedId = storage.get(subjectId);
  if (lastPlayedId == null) return episodes.first;

  for (final episode in episodes) {
    if (episode.episodeId == lastPlayedId) return episode;
  }
  return episodes.first;
}
