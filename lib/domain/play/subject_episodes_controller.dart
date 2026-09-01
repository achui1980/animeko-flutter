// lib/domain/play/subject_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';
import '../media/title_matcher.dart';

part 'subject_episodes_controller.g.dart';

/// Thrown when no anime1.me category matches the requested subject title
/// with sufficient confidence (see [matchBest]). Not a network/parsing
/// failure -- retrying without changing the title produces the same
/// result, so the UI shows an empty "not found" state instead of a retry
/// button (see `SubjectDetailScreen`).
///
/// NOTE: this is replaced by the source-agnostic `MediaNotFoundException`
/// in Task 10, once this controller queries multiple sources.
class Anime1NotFoundException implements Exception {
  const Anime1NotFoundException();

  @override
  String toString() =>
      'Anime1NotFoundException: no matching anime1.me category found';
}

@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<Anime1Episode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final api = ref.watch(anime1ApiProvider);
    final categories = await api.searchCategories(subjectName);
    final best = matchBest(categories, subjectName);
    if (best == null) {
      throw const Anime1NotFoundException();
    }
    return api.fetchCategoryEpisodes(best.id);
  }
}
