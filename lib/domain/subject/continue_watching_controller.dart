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
/// * reading the stored id threw -> the first main episode as well, so a
///   broken 「最近播放」 record degrades to 「开始观看」 instead of failing the
///   button (the design doc's failure table, line 340:
///   「`continueWatchingProvider` 失败 → 按钮退回「开始观看」播第一集」)
/// * no main episodes at all -> null, and the caller hides the button
///
/// (The first three branches are the design doc's 「新增『最近播放集数』」
/// section, `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`.)
///
/// A failure to load the episode list itself is deliberately NOT absorbed:
/// there is no episode to fall back to, and line 334 of the same table
/// routes that one to a whole-page `ErrorRetryView`.
///
/// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
/// never garbage-collected -- it exposes only `get`/`set`, no delete, so a
/// subject can drop episodes and the entry still lingers.
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

  // Design doc line 340 asks for 「开始观看」 rather than a broken button when
  // this provider fails, and by here a good non-empty `episodes` is already
  // in hand, so the read below degrades instead of propagating. The `try`
  // deliberately wraps only this read -- the `await` above keeps propagating,
  // because a missing episode list leaves nothing to fall back *to* (design
  // doc line 334 sends that failure to a whole-page `ErrorRetryView`).
  //
  // Caught broadly on purpose: the failure is not one type. Awaiting
  // `lastPlayedEpisodeStorageProvider` surfaces whatever
  // `SharedPreferences.getInstance()` threw
  // (`lib/data/play/last_played_episode_storage.dart:39`), while `get` is an
  // unchecked `as int?` cast (`shared_preferences_legacy.dart:121`) that
  // throws a `TypeError` -- an `Error`, not an `Exception` -- if some other
  // writer ever leaves a non-int under the key.
  final int? lastPlayedId;
  try {
    final storage = await ref.watch(lastPlayedEpisodeStorageProvider.future);
    lastPlayedId = storage.get(subjectId);
  } catch (_) {
    return episodes.first;
  }
  if (lastPlayedId == null) return episodes.first;

  for (final episode in episodes) {
    if (episode.episodeId == lastPlayedId) return episode;
  }
  return episodes.first;
}
