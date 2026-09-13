import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_models.dart';

part 'subject_detail_controller.g.dart';

/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating/favorite counters/infobox). Cast
/// ([SubjectCharacters]) is fetched via a separate provider so it can
/// fail independently without affecting this one -- see the design
/// doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).
///
/// Staff is NOT a separate provider: the 制作人员 card reads
/// `SubjectDetail.staffFields` off this payload, because the
/// `/v2/subjects/{id}/staff` endpoint only labels each credit with an
/// opaque integer `position` code and no human-readable role name.
@riverpod
class SubjectDetailController extends _$SubjectDetailController {
  @override
  Future<SubjectDetail> build({required int subjectId}) {
    return ref.watch(subjectApiProvider).getSubject(subjectId);
  }
}

/// Cast (characters + voice actors, per `SubjectApi.getCharacters`
/// always requesting `withActors=true`). `SubjectDetailScreen` hides
/// this whole section on error rather than showing a retry button.
@riverpod
class SubjectCharacters extends _$SubjectCharacters {
  @override
  Future<List<RelatedCharacter>> build({required int subjectId}) {
    return ref.watch(subjectApiProvider).getCharacters(subjectId);
  }
}
