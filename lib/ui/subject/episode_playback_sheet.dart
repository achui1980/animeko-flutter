import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/play/last_played_episode_storage.dart';
import '../../data/subject/subject_episode_models.dart';
import '../../domain/media/media_registry.dart';
import '../../domain/play/episode_source_matcher.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/continue_watching_controller.dart';
import 'episode_source_sheet.dart' show sourceLabel;

/// Modal bottom sheet for exactly one episode's playback sources --
/// opened by tapping a number in `EpisodeNumberGrid`.
///
/// Unlike `EpisodeSourceSheet` (which lists every episode across every
/// source, and which nothing in `lib/` constructs any more -- only its own
/// test does; the grid it wrapped, `EpisodeSourceGrid`, is still live in
/// `lib/ui/player/player_screen.dart:726`), this always
/// shows exactly one episode's matched candidates (via
/// [matchEpisodeSources]), even when there's only one -- see the
/// design doc's Section 3 (Q8: interaction consistency, never
/// auto-skip straight to playback). Reads live from
/// `subjectEpisodesControllerProvider` so it auto-refreshes if the
/// background scraper fetch is still in flight when opened.
class EpisodePlaybackSheet extends ConsumerWidget {
  const EpisodePlaybackSheet({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.ordinalIndex,
    required this.episode,
  });

  final int subjectId;
  final String subjectName;
  final int ordinalIndex;
  final SubjectEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mergedAsync = ref.watch(
      subjectEpisodesControllerProvider(
        subjectId: subjectId,
        subjectName: subjectName,
      ),
    );
    final sources = ref.watch(mediaSourcesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              episode.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            mergedAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              // Any failure to fetch/match the scraper-side episode
              // list (including MediaNotFoundException) is shown the
              // same as "no source matched" -- see the design doc's
              // Section 3.
              error: (error, stack) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('暂无播放源'),
              ),
              data: (merged) {
                final matches = matchEpisodeSources(
                  ordinalIndex: ordinalIndex,
                  allMerged: merged,
                );
                if (matches.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('暂无播放源'),
                  );
                }
                return Column(
                  children: [
                    for (final match in matches)
                      ListTile(
                        title: Text(sourceLabel(sources, match.sourceId)),
                        trailing: FilledButton(
                          onPressed: () async {
                            // Remember which Bangumi episode was opened so
                            // the detail page's 继续观看 button can point
                            // back at it. This is the ONLY place that still
                            // knows the Bangumi `episodeId` -- `PlayerScreen`
                            // only ever sees `MergedEpisode`.
                            final storage = await ref.read(
                              lastPlayedEpisodeStorageProvider.future,
                            );
                            await storage.set(subjectId, episode.episodeId);
                            // `lastPlayedEpisodeStorageProvider` yields a
                            // mutable object, so nothing re-emits on write --
                            // invalidate the derived provider explicitly or
                            // the button keeps its old label.
                            ref.invalidate(
                              continueWatchingProvider(subjectId: subjectId),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            context.push(
                              '/subject/$subjectId/play'
                              '?name=${Uri.encodeComponent(subjectName)}',
                              extra: match,
                            );
                          },
                          child: const Text('播放'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
