// lib/domain/download/download_source_resolver.dart
import '../play/subject_episodes_controller.dart';

/// Registered HTTP direct-link sources that support downloading, in
/// priority order. Must stay in sync with `DownloadWorker.enqueue`'s own
/// allow-list (`lib/data/download/download_worker.dart`) -- BT/RSS sources
/// (e.g. `'mikan'`) are deliberately excluded (see the design spec's
/// explicit out-of-scope list).
const downloadableSourcePriority = ['anime1', 'xifan'];

/// One episode (identified by [title], the join key across sources --
/// mirrors how `EpisodeNumberGrid` already groups [MergedEpisode]s) and
/// every HTTP-downloadable source that has it, ordered by
/// [downloadableSourcePriority].
class EpisodeDownloadOption {
  const EpisodeDownloadOption({required this.title, required this.candidates});

  final String title;

  /// Downloadable-source candidates for this episode. Empty when no
  /// registered HTTP download source has it (e.g. Mikan/BT only).
  final List<MergedEpisode> candidates;

  bool get isDownloadable => candidates.isNotEmpty;

  /// The source that should actually be used if the caller doesn't need to
  /// show every option (e.g. the player's single-episode download button,
  /// or the "download selected" batch action).
  MergedEpisode? get preferred => candidates.isEmpty ? null : candidates.first;
}

int _priorityOf(String sourceId) {
  final index = downloadableSourcePriority.indexOf(sourceId);
  return index == -1 ? downloadableSourcePriority.length : index;
}

/// Groups [merged] by episode title, keeping only HTTP-downloadable source
/// candidates per group (ordered by priority). One [EpisodeDownloadOption]
/// per distinct title, in the order titles first appear in [merged]. Pure
/// function -- no network, no Flutter import -- shared by the episode
/// selection tab, batch "download selected", the player's single-episode
/// download button, and `DownloadQueueController.retry`.
List<EpisodeDownloadOption> resolveDownloadOptions(
  List<MergedEpisode> merged,
) {
  final byTitle = <String, List<MergedEpisode>>{};
  for (final episode in merged) {
    byTitle.putIfAbsent(episode.title, () => []).add(episode);
  }
  return byTitle.entries
      .map(
        (entry) => EpisodeDownloadOption(
          title: entry.key,
          candidates: entry.value
              .where(
                (e) => downloadableSourcePriority.contains(e.sourceId),
              )
              .toList()
            ..sort((a, b) => _priorityOf(a.sourceId).compareTo(_priorityOf(b.sourceId))),
        ),
      )
      .toList();
}

/// Resolves the best downloadable candidate for a single episode by
/// [episodeTitle] -- e.g. for the player's download button when the
/// currently-playing source (which may be Mikan/BT) isn't itself
/// downloadable, or for `DownloadQueueController.retry` re-selecting a
/// source after the original one stopped having the episode. Returns null
/// when no registered HTTP source has this episode.
MergedEpisode? resolvePreferredDownloadSource(
  List<MergedEpisode> merged,
  String episodeTitle,
) {
  final matches = merged
      .where(
        (e) =>
            e.title == episodeTitle &&
            downloadableSourcePriority.contains(e.sourceId),
      )
      .toList()
    ..sort((a, b) => _priorityOf(a.sourceId).compareTo(_priorityOf(b.sourceId)));
  return matches.isEmpty ? null : matches.first;
}
