// lib/ui/subject/episode_source_sheet.dart
import 'package:flutter/material.dart';

import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';

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

/// A bottom sheet listing every [MergedEpisode] grouped by which
/// [MediaSource] it came from. Kazumi's detail page has a similar
/// "开始观看" bottom sheet, but its groups are per-plugin search
/// results, not pre-merged episodes -- this app already has a merged
/// episode list per subject (see [SubjectEpisodesController]), so this
/// sheet only needs to group that existing list by source, not run any
/// new search. Each source's group starts expanded (there are usually
/// only 1-2 registered sources); tapping any episode calls
/// [onEpisodeSelected].
class EpisodeSourceSheet extends StatelessWidget {
  const EpisodeSourceSheet({
    super.key,
    required this.episodes,
    required this.sources,
    required this.onEpisodeSelected,
  });

  final List<MergedEpisode> episodes;
  final List<MediaSource> sources;
  final void Function(MergedEpisode episode) onEpisodeSelected;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<MergedEpisode>>{};
    for (final episode in episodes) {
      grouped.putIfAbsent(episode.sourceId, () => []).add(episode);
    }

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
              child: Text('选集', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final entry in grouped.entries)
              ExpansionTile(
                title: Text(sourceLabel(sources, entry.key)),
                initiallyExpanded: true,
                children: [
                  for (final episode in entry.value)
                    ListTile(
                      title: Text(episode.title),
                      onTap: () => onEpisodeSelected(episode),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
