import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/subject_episode_models.dart';
import '../../domain/play/episode_source_matcher.dart';
import '../../domain/play/subject_episodes_controller.dart';
import 'subject_meta_text.dart' show formatEpisodeNumber;

/// Compact grid of episode-number buttons (01/02/03/...). Tapping a number
/// opens a per-episode source-selection sheet (see `EpisodePlaybackSheet`).
///
/// Renders no section header and no page-level padding of its own: the
/// enclosing `SubjectEpisodesSection` owns the 「选集」 header row and the
/// page's left/right gutter comes from `pagePadding`.
///
/// Each button's visual state depends on the *scraper* episode list
/// ([mergedEpisodesAsync]), matched positionally via [EpisodeSourceIndex]:
/// while it's still loading (and no previous data is available yet), every
/// button renders in the same normal/neutral style (not yet distinguishing
/// has-source/no-source, per the design doc's Section 2 state 3); once
/// settled with data, a button renders normal/clickable if at least one
/// scraper source has an episode at that position, or dimmed (but still
/// clickable -- tapping shows "暂无播放源") otherwise. If
/// [mergedEpisodesAsync] settles into an error with no previous data (e.g.
/// `MediaNotFoundException` -- no registered scraper source matched the
/// anime's title at all), every button renders dimmed as well, since the
/// "no source will ever be found" outcome is already deterministic at that
/// point.
///
/// Long lists are rendered in segments of [chunkSize] behind a row of range
/// chips. Episode data now comes from the Animeko backend's embedded array
/// (see `SubjectMainEpisodesController`) with no `limit=100` truncation, so
/// 航海王 yields 1155 episodes -- and this grid is built eagerly inside the
/// detail screen's non-lazy `ListView`, meaning without segmentation every
/// one of those buttons would be constructed and laid out on every build.
class EpisodeNumberGrid extends StatefulWidget {
  const EpisodeNumberGrid({
    super.key,
    required this.episodes,
    required this.mergedEpisodesAsync,
    required this.onEpisodeTap,
  });

  /// Number of episode buttons rendered at once. Also the range-chip width.
  static const int chunkSize = 100;

  final List<SubjectEpisode> episodes;
  final AsyncValue<List<MergedEpisode>> mergedEpisodesAsync;

  /// [ordinalIndex] is the episode's position in the *full* [episodes] list,
  /// not within the visible chunk -- playback source matching depends on it.
  final void Function(int ordinalIndex, SubjectEpisode episode) onEpisodeTap;

  @override
  State<EpisodeNumberGrid> createState() => _EpisodeNumberGridState();
}

class _EpisodeNumberGridState extends State<EpisodeNumberGrid> {
  int _chunkIndex = 0;

  int get _chunkCount =>
      (widget.episodes.length / EpisodeNumberGrid.chunkSize).ceil();

  @override
  Widget build(BuildContext context) {
    final merged = widget.mergedEpisodesAsync.value;
    // AsyncValue.value returns null both while genuinely loading with no
    // prior data, and when settled in an error state with no prior data
    // (e.g. MediaNotFoundException -- no scraper source matched this title
    // at all). Distinguish them: only the former should render as the
    // neutral "still loading" style; the latter is a deterministic "no
    // source will ever be found" outcome and should render the same as an
    // empty match (dimmed, but still tappable -- tapping shows "暂无播放源").
    final isStillLoading =
        merged == null && widget.mergedEpisodesAsync.isLoading;
    // Built once per build rather than once per button: the old
    // matchEpisodeSources() call rebuilt its per-source grouping on every
    // lookup, which is O(buttons x scraper episodes).
    final sourceIndex = merged == null ? null : EpisodeSourceIndex.from(merged);

    // The episode list can shrink between builds (e.g. a refresh returning
    // fewer episodes), which would leave _chunkIndex out of range.
    final chunkIndex = _chunkCount == 0
        ? 0
        : math.min(_chunkIndex, _chunkCount - 1);
    final start = chunkIndex * EpisodeNumberGrid.chunkSize;
    final end = math.min(
      start + EpisodeNumberGrid.chunkSize,
      widget.episodes.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_chunkCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _chunkCount; i++)
                  ChoiceChip(
                    label: Text(_chunkLabel(i)),
                    selected: i == chunkIndex,
                    onSelected: (_) => setState(() => _chunkIndex = i),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = start; i < end; i++)
              _EpisodeNumberButton(
                episode: widget.episodes[i],
                // sourceIndex == null means either the scraper fetch is
                // still in flight (neutral state, not yet has/no-source)
                // or it settled with an error and no source will ever be
                // found (dimmed, same as an empty match) -- see
                // isStillLoading above.
                hasSource: sourceIndex == null
                    ? (isStillLoading ? null : false)
                    : sourceIndex.matchesAt(i).isNotEmpty,
                onTap: () => widget.onEpisodeTap(i, widget.episodes[i]),
              ),
          ],
        ),
      ],
    );
  }

  /// 1-based, inclusive range label for chunk [index], e.g. `101-200`. The
  /// last chunk is usually partial (`201-250`).
  String _chunkLabel(int index) {
    final start = index * EpisodeNumberGrid.chunkSize + 1;
    final end = math.min(
      start + EpisodeNumberGrid.chunkSize - 1,
      widget.episodes.length,
    );
    return '$start-$end';
  }
}

class _EpisodeNumberButton extends StatelessWidget {
  const _EpisodeNumberButton({
    required this.episode,
    required this.hasSource,
    required this.onTap,
  });

  final SubjectEpisode episode;

  /// null = still loading with no previous data (neutral state); true =
  /// at least one scraper source matched; false = no source matched, or
  /// settled in an error state with no data (e.g. no scraper source
  /// matched this title at all) -- dimmed, still tappable.
  final bool? hasSource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A half-episode sort (e.g. 1.5) must never round to the same 2-digit
    // label as a neighboring integer sort (e.g. 2 -> "02") -- that would be
    // an unresolvable visual collision between two distinct episodes. The
    // two branches below are provably collision-free: every non-integer
    // output contains a literal '.' (from formatEpisodeNumber), and every
    // integer-branch output is exactly 2 digits with no '.'.
    final numberText = episode.sort % 1 == 0
        ? episode.sort.toInt().toString().padLeft(2, '0')
        : formatEpisodeNumber(episode.sort);
    final numberLabel = Text(numberText);
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
