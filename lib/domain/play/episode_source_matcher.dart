import '../../data/rss/rss_media_source.dart';
import 'subject_episodes_controller.dart';

/// A reusable, precomputed view over a scraper result set that answers
/// "which sources have an episode at grid position N?" in O(sources) per
/// lookup.
///
/// [matchEpisodeSources] does the same job but rebuilds its per-source
/// grouping on every call. The episode grid asks that question once per
/// rendered button, which made it O(buttons x episodes) -- tolerable at the
/// old hard cap of 100 buttons, but the episode list now comes from the
/// Animeko backend's embedded array with no `limit=100` truncation, so a
/// show like 航海王 has 1155 episodes. Build the index once per grid build
/// and reuse it for every button.
class EpisodeSourceIndex {
  const EpisodeSourceIndex._(this._bySource, this._byEpisodeNumber);

  /// Episodes grouped by `sourceId`, each group keeping [MergedEpisode]'s
  /// original relative order (that order *is* the positional match key).
  /// Insertion order of the groups themselves is preserved too, so results
  /// come back in the order sources first appeared.
  final Map<String, List<MergedEpisode>> _bySource;

  /// Per source, a parsed-episode-number lookup for [RssEpisode] entries.
  /// First entry wins on duplicates, matching the linear first-match scan
  /// this replaced.
  final Map<String, Map<int, MergedEpisode>> _byEpisodeNumber;

  factory EpisodeSourceIndex.from(List<MergedEpisode> allMerged) {
    final bySource = <String, List<MergedEpisode>>{};
    final byEpisodeNumber = <String, Map<int, MergedEpisode>>{};

    for (final merged in allMerged) {
      bySource.putIfAbsent(merged.sourceId, () => []).add(merged);

      final episode = merged.episode;
      if (episode is RssEpisode) {
        byEpisodeNumber
            .putIfAbsent(merged.sourceId, () => {})
            .putIfAbsent(episode.episodeNumber, () => merged);
      }
    }

    return EpisodeSourceIndex._(bySource, byEpisodeNumber);
  }

  /// Every source's best match for grid position [ordinalIndex] (0-based).
  /// See [matchEpisodeSources] for the matching rules and their caveats.
  List<MergedEpisode> matchesAt(int ordinalIndex) {
    final matches = <MergedEpisode>[];

    for (final entry in _bySource.entries) {
      // RSS/BT episode lists are keyed by parsed episode number, not by list
      // position (a source may be missing an episode, or list them out of
      // order relative to the grid). ordinalIndex is 0-based; episode
      // numbers parsed from release titles are 1-based, hence the +1.
      final byNumber = _byEpisodeNumber[entry.key]?[ordinalIndex + 1];
      if (byNumber != null) {
        matches.add(byNumber);
        continue;
      }

      final episodes = entry.value;
      if (ordinalIndex < episodes.length) {
        matches.add(episodes[ordinalIndex]);
      }
    }

    return matches;
  }
}

/// Finds every [MergedEpisode] across [allMerged]'s sources whose
/// position -- within that source's own original list order -- equals
/// [ordinalIndex] (0-based). Used to map an episode's position in the
/// canonical episode-number grid back to the scraper-side episodes that
/// (probably) correspond to it, without any title parsing: matching is
/// purely positional, since episode-title formats aren't consistent across
/// sources (see the design doc's Section 3 and Risks -- this assumes each
/// source's own episode list is already in the correct episode order, which
/// holds for every source registered today but isn't independently
/// verified).
///
/// A source with fewer than `ordinalIndex + 1` episodes simply
/// contributes no match (no error). The returned list preserves
/// [allMerged]'s original source-grouping order (i.e. the order each
/// source's first episode first appeared in [allMerged], which is the
/// order `SubjectEpisodesController` queried `mediaSourcesProvider`'s
/// sources in); it may be empty (no source has an episode at that
/// position), contain exactly one match, or contain one match per
/// registered source.
///
/// Convenience wrapper for a single lookup. If you are looking up many
/// ordinals against the same [allMerged], build one [EpisodeSourceIndex]
/// instead -- this rebuilds the grouping every call.
List<MergedEpisode> matchEpisodeSources({
  required int ordinalIndex,
  required List<MergedEpisode> allMerged,
}) => EpisodeSourceIndex.from(allMerged).matchesAt(ordinalIndex);
