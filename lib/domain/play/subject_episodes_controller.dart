// lib/domain/play/subject_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../media/media_registry.dart';
import '../media/media_source.dart';
import '../media/title_matcher.dart';

part 'subject_episodes_controller.g.dart';

/// Thrown when *no* registered [MediaSource] has a matching candidate
/// (or every source that had one also failed to list its episodes) for
/// the requested subject title -- see [matchBest]. Not a
/// network/parsing failure by itself (a single source's own failure is
/// swallowed silently, see `_fetchFromSource`); retrying without
/// changing the title produces the same result, so the UI shows an
/// empty "not found" state instead of a retry button (see
/// `SubjectDetailScreen`).
class MediaNotFoundException implements Exception {
  const MediaNotFoundException();

  @override
  String toString() =>
      'MediaNotFoundException: no source has a matching subject';
}

/// One [MediaEpisode] together with which [MediaSource.id] it came from
/// -- used by `SubjectDetailScreen` to show a per-episode source badge,
/// and by `EpisodePlayController` to find the right [MediaSource] to
/// resolve playback with.
class MergedEpisode {
  const MergedEpisode({required this.episode, required this.sourceId});

  final MediaEpisode episode;
  final String sourceId;

  String get title => episode.title;
}

@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final sources = ref.watch(mediaSourcesProvider);

    // Query every source concurrently -- one source's latency/failure
    // must not block or fail the others (Decision 7: silent ignore).
    final results = await Future.wait(
      sources.map((source) => _fetchFromSource(source, subjectName)),
    );

    final merged = results.expand((episodes) => episodes).toList();
    if (merged.isEmpty) {
      throw const MediaNotFoundException();
    }
    return merged;
  }

  Future<List<MergedEpisode>> _fetchFromSource(
    MediaSource source,
    String subjectName,
  ) async {
    try {
      final candidates = await source.search(subjectName);
      final best = matchBest(candidates, subjectName);
      if (best == null) return const [];
      final episodes = await source.listEpisodes(best);
      return episodes
          .map((e) => MergedEpisode(episode: e, sourceId: source.id))
          .toList();
    } catch (_) {
      // A single source's network/parse failure must not prevent other
      // sources' results from being shown, and must not surface as a
      // distinct error state -- see design doc "错误处理".
      return const [];
    }
  }
}
