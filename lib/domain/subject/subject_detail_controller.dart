import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_models.dart';

part 'subject_detail_controller.g.dart';

/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating). Cast ([SubjectCharacters]) and staff
/// ([SubjectStaff]) are fetched via separate providers so either can
/// fail independently without affecting this one or each other -- see
/// the design doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).
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

/// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].
@riverpod
class SubjectStaff extends _$SubjectStaff {
  @override
  Future<List<StaffMember>> build({required int subjectId}) {
    return ref.watch(subjectApiProvider).getStaff(subjectId);
  }
}
