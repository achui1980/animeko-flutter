// lib/ui/subject/continue_watching_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/play/last_played_episode_storage.dart';
import '../../domain/subject/continue_watching_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import 'episode_playback_sheet.dart';
import 'subject_meta_text.dart';

/// 「继续观看 第 N 集」 when there is a usable last-played record,
/// otherwise 「开始观看」, which targets the main-episode list's first
/// entry (design doc
/// `2026-09-12-subject-detail-three-column-layout-design.md` lines
/// 234-235). Sits in the left column's top button stack (design doc
/// lines 247/251), constructed by `SubjectDetailLeftPane` and by
/// `SubjectDetailScreen`'s narrow layout.
///
/// Which of the two labels shows is decided by comparing the episode
/// [continueWatchingProvider] resolved to against the id in
/// [LastPlayedEpisodeStorage]. All four of the provider's non-null
/// branches land correctly: nothing stored (null), a stale stored id, and
/// a failed storage read (the provider falls back to the first episode for
/// the last two) all compare unequal -> 「开始观看」, while a live record
/// compares equal -> 「继续观看」. The failed-read case works because this
/// widget reads the same failing provider through `.value` below, which is
/// null on an error, exactly like the nothing-stored case.
///
/// Tapping opens the same [EpisodePlaybackSheet] that tapping a number in
/// the 选集 grid opens (via `EpisodeNumberGrid.onEpisodeTap` in
/// `SubjectEpisodesSection`), with the same `ordinalIndex` contract -- the
/// episode's position in the full main-episode list, which is what
/// playback-source matching keys on (`EpisodeSourceIndex.matchesAt`). So
/// this button adds no second source-picking path of its own.
///
/// Renders nothing when [continueWatchingProvider] has no value: while it
/// is still loading, when it errored with no previous data, and when the
/// subject has no main episodes at all (the provider returns null for
/// that last one).
///
/// The design doc's failure table needs nothing extra from this widget. A
/// failed last-played read is already handled inside the provider, which
/// falls back to the first episode so the button reads 「开始观看」 (line
/// 340). A failed subject-detail fetch never reaches this widget at all,
/// because line 334 routes that one to a page-level `ErrorRetryView`.
class ContinueWatchingButton extends ConsumerWidget {
  const ContinueWatchingButton({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  final int subjectId;
  final String subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref
        .watch(continueWatchingProvider(subjectId: subjectId))
        .value;
    if (target == null) return const SizedBox.shrink();

    final episodes =
        ref
            .watch(subjectMainEpisodesControllerProvider(subjectId: subjectId))
            .value ??
        const [];
    // Normally guaranteed to be found -- `continueWatchingProvider` picked
    // `target` out of this very list. It can miss during a refresh, though:
    // the episode list settles first and only then does the provider that
    // depends on it recompute, so there is a build where a new list is
    // paired with the previous target. What makes that pairing observable
    // here is that `AsyncLoading` retains the previous value, so the `.value`
    // above keeps handing back the stale target instead of null while the
    // episode list is already fresh -- and it is only observable while
    // `continueWatching`'s second `await` (the storage provider) is still
    // pending at a frame boundary.
    final ordinalIndex = episodes.indexWhere(
      (episode) => episode.episodeId == target.episodeId,
    );
    if (ordinalIndex < 0) return const SizedBox.shrink();

    final storedEpisodeId = ref
        .watch(lastPlayedEpisodeStorageProvider)
        .value
        ?.get(subjectId);
    final resumed = storedEpisodeId == target.episodeId;
    final label = resumed
        ? '继续观看 第 ${formatEpisodeNumber(target.sort)} 集'
        : '开始观看';

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => EpisodePlaybackSheet(
            subjectId: subjectId,
            subjectName: subjectName,
            ordinalIndex: ordinalIndex,
            episode: target,
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: Text(label),
      ),
    );
  }
}
