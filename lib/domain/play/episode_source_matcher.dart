import 'subject_episodes_controller.dart';

/// Finds every [MergedEpisode] across [allMerged]'s sources whose
/// position -- within that source's own original list order -- equals
/// [ordinalIndex] (0-based). Used to map a Bangumi episode's position
/// in the canonical episode-number grid back to the scraper-side
/// episodes that (probably) correspond to it, without any title
/// parsing: matching is purely positional, since episode-title formats
/// aren't consistent across sources (see the design doc's Section 3
/// and Risks -- this assumes each source's own episode list is already
/// in the correct episode order, which holds for every source
/// registered today but isn't independently verified).
///
/// A source with fewer than `ordinalIndex + 1` episodes simply
/// contributes no match (no error). The returned list preserves
/// [allMerged]'s original source-grouping order (i.e. the order each
/// source's first episode first appeared in [allMerged], which is the
/// order `SubjectEpisodesController` queried `mediaSourcesProvider`'s
/// sources in); it may be empty (no source has an episode at that
/// position), contain exactly one match, or contain one match per
/// registered source.
List<MergedEpisode> matchEpisodeSources({
  required int ordinalIndex,
  required List<MergedEpisode> allMerged,
}) {
  final bySource = <String, List<MergedEpisode>>{};
  for (final episode in allMerged) {
    bySource.putIfAbsent(episode.sourceId, () => []).add(episode);
  }

  final matches = <MergedEpisode>[];
  for (final episodes in bySource.values) {
    if (ordinalIndex < episodes.length) {
      matches.add(episodes[ordinalIndex]);
    }
  }
  return matches;
}
