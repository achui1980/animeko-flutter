import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_image_cache_repository.dart';
import '../../data/subject/subject_models.dart';
import 'subject_detail_controller.dart';

part 'subject_collection_controller.g.dart';

/// The mutable slice of subject state this controller owns --
/// `collectionType`/`selfRating` only, read once from
/// [SubjectDetailController]'s already-fetched [SubjectDetail] (avoids a
/// duplicate `getSubject` request) and then mutated locally as the user
/// changes their collection status or rating.
class SubjectCollectionState {
  const SubjectCollectionState({required this.collectionType, required this.selfRating});

  final CollectionType? collectionType;
  final SelfRating selfRating;

  SubjectCollectionState copyWith({CollectionType? collectionType, SelfRating? selfRating}) =>
      SubjectCollectionState(
        collectionType: collectionType ?? this.collectionType,
        selfRating: selfRating ?? this.selfRating,
      );

  /// Distinct from [copyWith] -- passing `collectionType: null` there
  /// means "keep the current value" (a plain named param can't
  /// distinguish "omitted" from "explicitly null"), so clearing needs
  /// its own method.
  SubjectCollectionState clearCollectionType() =>
      SubjectCollectionState(collectionType: null, selfRating: selfRating);
}

@riverpod
class SubjectCollectionController extends _$SubjectCollectionController {
  @override
  Future<SubjectCollectionState> build({required int subjectId}) async {
    final detail = await ref.watch(subjectDetailControllerProvider(subjectId: subjectId).future);
    return SubjectCollectionState(collectionType: detail.collectionType, selfRating: detail.selfRating);
  }

  /// Optimistically updates [state] to [type] before the `PATCH`
  /// resolves, then rolls back to the pre-call state if it fails
  /// (design doc "收藏状态切换"). Rethrows on failure so the caller can
  /// show a one-off error -- see `SubjectDetailScreen` (Task 10).
  ///
  /// If [imageUrl] is given (the caller knows the subject's cover image
  /// URL -- see `_CollectionButtons` in `subject_detail_screen.dart`),
  /// records it to the local image cache once the remote update
  /// succeeds, so `MyCollectionsController` can show a cover for a list
  /// endpoint that itself never returns one (design doc "写入路径").
  /// A failure to write the cache is swallowed -- it must never surface
  /// as a collection-update failure, since the remote update already
  /// succeeded by that point (design doc "风险与已知限制").
  Future<void> setCollectionType(CollectionType type, {String? imageUrl}) async {
    final previous = state;
    final current = await future;
    state = AsyncData(current.copyWith(collectionType: type));
    try {
      await ref.read(subjectApiProvider).updateCollection(subjectId, collectionType: type);
    } catch (_) {
      state = previous;
      rethrow;
    }
    if (imageUrl != null) {
      try {
        await ref.read(subjectImageCacheRepositoryProvider).save(subjectId, imageUrl);
      } catch (_) {
        // Best-effort local cache only -- never let this fail the
        // (already-succeeded) collection-status update.
      }
    }
  }

  /// Same optimistic-update-then-rollback treatment as
  /// [setCollectionType], but clears the collection status entirely via
  /// `DELETE`.
  Future<void> removeFromCollection() async {
    final previous = state;
    final current = await future;
    state = AsyncData(current.clearCollectionType());
    try {
      await ref.read(subjectApiProvider).deleteCollection(subjectId);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// NOT optimistic (design doc "评分提交") -- local state is only
  /// updated after the `PATCH` succeeds; on failure the caller keeps the
  /// user's input in the still-open rating form for retry rather than
  /// this controller attempting a rollback.
  ///
  /// Preserves the existing [SelfRating.tags] from the current state --
  /// this UI has no tag-editing affordance, and the `PATCH` sends the
  /// whole `selfRating` object (replacing it wholesale server-side), so
  /// hardcoding an empty list here would silently wipe out tags set via
  /// another client.
  Future<void> submitRating(int score, {String? comment, bool isPrivate = false}) async {
    if (score < 1 || score > 10) {
      throw ArgumentError.value(score, 'score', 'must be between 1 and 10');
    }
    final current = await future;
    final rating = SelfRating(
      score: score,
      tags: current.selfRating.tags,
      isPrivate: isPrivate,
      comment: comment,
    );
    await ref.read(subjectApiProvider).updateCollection(subjectId, selfRating: rating);
    state = AsyncData(current.copyWith(selfRating: rating));
  }
}
