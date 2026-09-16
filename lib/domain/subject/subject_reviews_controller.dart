// lib/domain/subject/subject_reviews_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/review_models.dart';
import '../../data/subject/subject_api.dart';

part 'subject_reviews_controller.g.dart';

/// The accumulated reviews the UI renders: every row fetched so far, plus
/// whether another page exists after the last one fetched.
///
/// Deliberately NOT an accumulated [PaginatedReviews]. That class's
/// `hasMore` is `total > items.length`, and `total` is a per-request
/// has-more sentinel (`limit + 1`) that is only meaningful for a single
/// page exactly as returned by `SubjectApi.getReviews`. Compare a page-2
/// sentinel against an accumulated list and it silently goes false: with
/// [SubjectReviewsController.pageSize] 20 on a subject that has 100
/// reviews, page 2 reports `total: 21` while 40 rows have accumulated,
/// `21 > 40` is false, and load-more stops at 40 -- stranding 60 rows with
/// no error anywhere. So [hasMore] is stored, taken from the freshly
/// fetched page alone. `MyCollectionsPage`
/// (`lib/domain/subject/my_collections_controller.dart:34`) keeps a
/// per-page `hasMore` field for the same reason.
class SubjectReviewsPage {
  const SubjectReviewsPage({required this.items, required this.hasMore});

  /// Every review fetched so far, first page first.
  final List<SubjectReview> items;

  /// Whether another page exists after the last one fetched.
  final bool hasMore;
}

/// Other users' short reviews (热门评价). Paginated by offset, accumulating
/// into a single [SubjectReviewsPage] so the sheet can just render
/// `state.items`.
///
/// The detail page's right-column card shows only the first few of these;
/// the 查看全部 sheet shows everything and calls [loadMore].
///
/// Failure is silent at the UI level (the 热门评价 card hides) -- see the
/// design doc's 「加载 / 错误 / 空态」 table.
@riverpod
class SubjectReviewsController extends _$SubjectReviewsController {
  /// Rows per request. The backend's default is 30; 20 is plenty for a
  /// first paint and keeps the payload small.
  static const int pageSize = 20;

  @override
  Future<SubjectReviewsPage> build({required int subjectId}) async {
    final page = await ref
        .watch(subjectApiProvider)
        .getReviews(subjectId: subjectId, offset: 0, limit: pageSize);
    return SubjectReviewsPage(items: page.items, hasMore: page.hasMore);
  }

  /// Fetches the next page and appends it. No-op while the first page is
  /// still in flight, after it failed, or once
  /// [SubjectReviewsPage.hasMore] is false.
  Future<void> loadMore() async {
    // `AsyncValue.value` is the nullable getter in Riverpod 3 (there is no
    // `valueOrNull`): null while the first page is in flight and after it
    // failed, which is exactly when there is nothing to append to.
    final current = state.value;
    if (current == null || !current.hasMore) return;

    final next = await ref
        .read(subjectApiProvider)
        .getReviews(
          subjectId: subjectId,
          offset: current.items.length,
          limit: pageSize,
        );
    // `hasMore` comes from the freshly fetched page and is never
    // recomputed against the accumulated list -- see [SubjectReviewsPage].
    state = AsyncData(
      SubjectReviewsPage(
        items: [...current.items, ...next.items],
        hasMore: next.hasMore,
      ),
    );
  }
}
