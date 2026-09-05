// lib/ui/subject/episode_source_sheet.dart
import 'package:flutter/material.dart';

import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';
import 'episode_source_grid.dart';

/// Human-readable label for a merged episode's source badge. Looks up
/// the owning [MediaSource]'s [MediaSource.displayName] so this stays
/// in sync with the single source of truth instead of re-deriving it
/// from a hardcoded switch on `sourceId`. Falls back to the raw
/// `sourceId` for any `sourceId` with no matching registered source --
/// never crashes, just looks slightly less polished.
String sourceLabel(List<MediaSource> sources, String sourceId) {
  for (final source in sources) {
    if (source.id == sourceId) return source.displayName;
  }
  return sourceId;
}

/// Modal bottom sheet for picking an episode (and, implicitly, its
/// source) from the subject-detail page. Wraps [EpisodeSourceGrid] with
/// a [DraggableScrollableSheet] and a header.
class EpisodeSourceSheet extends StatelessWidget {
  const EpisodeSourceSheet({
    super.key,
    required this.episodes,
    required this.sources,
    required this.onEpisodeSelected,
  });

  final List<MergedEpisode> episodes;
  final List<MediaSource> sources;
  final ValueChanged<MergedEpisode> onEpisodeSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '选择集数',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: EpisodeSourceGrid(
                episodes: episodes,
                sources: sources,
                onEpisodeSelected: onEpisodeSelected,
              ),
            ),
          ],
        );
      },
    );
  }
}
