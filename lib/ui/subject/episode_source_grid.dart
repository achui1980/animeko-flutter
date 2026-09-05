import 'package:flutter/material.dart';

import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';
import 'episode_source_sheet.dart' show sourceLabel;

export 'episode_source_sheet.dart' show sourceLabel;

/// Flat, chip-filterable grid of [MergedEpisode]s.
///
/// Shown inside [EpisodeSourceSheet] (subject-detail page) and inside the
/// player's episode/source drawer. Filtering by source is a pure
/// client-side operation over the already-fetched [episodes] list; no
/// filter choice is persisted across opens.
class EpisodeSourceGrid extends StatefulWidget {
  const EpisodeSourceGrid({
    super.key,
    required this.episodes,
    required this.sources,
    required this.onEpisodeSelected,
    this.currentEpisode,
  });

  final List<MergedEpisode> episodes;
  final List<MediaSource> sources;
  final ValueChanged<MergedEpisode> onEpisodeSelected;

  /// The episode currently playing, if any. When set, the matching pill
  /// (by sourceId + title) renders filled instead of outlined.
  final MergedEpisode? currentEpisode;

  @override
  State<EpisodeSourceGrid> createState() => _EpisodeSourceGridState();
}

class _EpisodeSourceGridState extends State<EpisodeSourceGrid> {
  String? _selectedSourceId;

  List<String> get _sourceIds {
    final seen = <String>{};
    final ids = <String>[];
    for (final episode in widget.episodes) {
      if (seen.add(episode.sourceId)) {
        ids.add(episode.sourceId);
      }
    }
    return ids;
  }

  bool _isCurrent(MergedEpisode episode) {
    final current = widget.currentEpisode;
    if (current == null) return false;
    return current.sourceId == episode.sourceId &&
        current.title == episode.title;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedSourceId == null
        ? widget.episodes
        : widget.episodes
              .where((episode) => episode.sourceId == _selectedSourceId)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('全部'),
                  selected: _selectedSourceId == null,
                  onSelected: (_) => setState(() => _selectedSourceId = null),
                ),
              ),
              for (final sourceId in _sourceIds)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(sourceLabel(widget.sources, sourceId)),
                    selected: _selectedSourceId == sourceId,
                    onSelected: (_) =>
                        setState(() => _selectedSourceId = sourceId),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final episode in filtered)
              _EpisodePill(
                episode: episode,
                isCurrent: _isCurrent(episode),
                onTap: () => widget.onEpisodeSelected(episode),
              ),
          ],
        ),
      ],
    );
  }
}

class _EpisodePill extends StatelessWidget {
  const _EpisodePill({
    required this.episode,
    required this.isCurrent,
    required this.onTap,
  });

  final MergedEpisode episode;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      episode.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (isCurrent) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: child,
    );
  }
}
