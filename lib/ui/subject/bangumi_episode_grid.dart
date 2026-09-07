import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/bangumi_episode_models.dart';
import '../../domain/play/episode_source_matcher.dart';
import '../../domain/play/subject_episodes_controller.dart';

/// Compact grid of Bangumi episode-number buttons (01/02/03/...),
/// replacing the old single "开始观看" button. Tapping a number opens
/// a per-episode source-selection sheet (see `EpisodePlaybackSheet`).
///
/// Each button's visual state depends on the *scraper* episode list
/// ([mergedEpisodesAsync]), matched positionally via
/// [matchEpisodeSources]: while it's still loading (and no previous
/// data is available yet), every button renders in the same
/// normal/neutral style (not yet distinguishing has-source/no-source,
/// per the design doc's Section 2 state 3); once settled with data, a
/// button renders normal/clickable if at least one scraper source has
/// an episode at that position, or dimmed (but still clickable --
/// tapping shows "暂无播放源") otherwise. If [mergedEpisodesAsync]
/// settles into an error with no previous data (e.g.
/// `MediaNotFoundException` -- no registered scraper source matched
/// the anime's title at all), every button renders dimmed as well,
/// since the "no source will ever be found" outcome is already
/// deterministic at that point.
class BangumiEpisodeGrid extends StatelessWidget {
  const BangumiEpisodeGrid({
    super.key,
    required this.episodes,
    required this.mergedEpisodesAsync,
    required this.onEpisodeTap,
  });

  final List<BangumiEpisode> episodes;
  final AsyncValue<List<MergedEpisode>> mergedEpisodesAsync;
  final void Function(int ordinalIndex, BangumiEpisode episode) onEpisodeTap;

  @override
  Widget build(BuildContext context) {
    final merged = mergedEpisodesAsync.value;
    // AsyncValue.value returns null both while genuinely loading with no
    // prior data, and when settled in an error state with no prior data
    // (e.g. MediaNotFoundException -- no scraper source matched this
    // title at all). Distinguish them: only the former should render as
    // the neutral "still loading" style; the latter is a deterministic
    // "no source will ever be found" outcome and should render the same
    // as an empty match (dimmed, but still tappable -- tapping shows
    // "暂无播放源").
    final isStillLoading = merged == null && mergedEpisodesAsync.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('剧集', style: Theme.of(context).textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < episodes.length; i++)
                _EpisodeNumberButton(
                  episode: episodes[i],
                  // merged == null means either the scraper fetch is
                  // still in flight (neutral state, not yet
                  // has/no-source) or it settled with an error and no
                  // source will ever be found (dimmed, same as an empty
                  // match) -- see isStillLoading above.
                  hasSource: merged == null
                      ? (isStillLoading ? null : false)
                      : matchEpisodeSources(
                          ordinalIndex: i,
                          allMerged: merged,
                        ).isNotEmpty,
                  onTap: () => onEpisodeTap(i, episodes[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EpisodeNumberButton extends StatelessWidget {
  const _EpisodeNumberButton({
    required this.episode,
    required this.hasSource,
    required this.onTap,
  });

  final BangumiEpisode episode;

  /// null = still loading with no previous data (neutral state); true =
  /// at least one scraper source matched; false = no source matched, or
  /// settled in an error state with no data (e.g. no scraper source
  /// matched this title at all) -- dimmed, still tappable.
  final bool? hasSource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final numberLabel = Text(episode.sort.round().toString().padLeft(2, '0'));
    final title = episode.displayName;
    final Widget child = title.isEmpty
        ? numberLabel
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              numberLabel,
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          );

    if (hasSource == false) {
      final disabledColor = Theme.of(context).disabledColor;
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(96, 40),
          foregroundColor: disabledColor,
          side: BorderSide(color: disabledColor),
        ),
        child: child,
      );
    }
    // hasSource == true or null (still loading) both render as the
    // normal/neutral clickable style -- see the class doc comment.
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
      child: child,
    );
  }
}
