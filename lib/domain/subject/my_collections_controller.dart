import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_image_cache_repository.dart';
import '../../data/subject/subject_models.dart';

part 'my_collections_controller.g.dart';

const _pageSize = 20;

/// The loaded slice of the "My Collection" list plus whether another
/// page might still be available. [hasMore] uses the standard
/// "short page = last page" heuristic -- a fetched page with fewer
/// items than [_pageSize] means there's nothing left to load. This
/// doesn't require trusting [PaginatedCollections.total]'s exact
/// semantics against the real server (see the NOTE on that class).
///
/// [imageUrls] is a locally-cached `subjectId -> imageUrl` lookup (see
/// `SubjectImageCacheRepository`) -- `GET /v2/subjects/list` itself
/// never returns an image field (see `MyCollectionSubject`'s doc
/// comment), so this is the only source of cover images for this page.
/// A subject with no entry here has never been collected/re-collected
/// via the detail page's collection buttons while its image URL was
/// known (design doc "范围外").
class MyCollectionsPage {
  const MyCollectionsPage({
    required this.items,
    required this.hasMore,
    this.imageUrls = const {},
  });

  final List<MyCollectionSubject> items;
  final bool hasMore;
  final Map<int, String> imageUrls;
}

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.
@riverpod
class MyCollectionsController extends _$MyCollectionsController {
  @override
  Future<MyCollectionsPage> build({required CollectionType? type}) async {
    final page = await ref
        .watch(subjectApiProvider)
        .getMyCollections(type: type, offset: 0, limit: _pageSize);
    final imageUrls = await _imageUrlsFor(page.items);
    return MyCollectionsPage(
      items: page.items,
      hasMore: page.items.length >= _pageSize,
      imageUrls: imageUrls,
    );
  }

  /// Fetches the next page (offset = current list length) and appends
  /// it. No pull-to-refresh (design doc, YAGNI) -- leaving and
  /// re-entering the page re-runs [build] instead.
  Future<void> loadMore() async {
    final current = await future;
    final page = await ref
        .read(subjectApiProvider)
        .getMyCollections(
          type: type,
          offset: current.items.length,
          limit: _pageSize,
        );
    final newImageUrls = await _imageUrlsFor(page.items);
    state = AsyncData(
      MyCollectionsPage(
        items: [...current.items, ...page.items],
        hasMore: page.items.length >= _pageSize,
        imageUrls: {...current.imageUrls, ...newImageUrls},
      ),
    );
  }

  /// Best-effort: a local Drift read failure here (e.g. a disk error) must
  /// never fail the whole page load just to show cover images, which are
  /// non-critical enrichment on top of the always-authoritative remote
  /// list. Mirrors the write path's best-effort handling in
  /// `SubjectCollectionController.setCollectionType`.
  Future<Map<int, String>> _imageUrlsFor(
    List<MyCollectionSubject> items,
  ) async {
    try {
      // `.toList()`: mocktail's exact-argument matcher (`DeepCollectionEquality`)
      // only does element-wise comparison when both sides are `List`s -- a lazy
      // `Iterable` actual argument against a `List`-literal stub (e.g.
      // `when(() => imageCacheRepo.getFor([1]))`) falls through to the `any()`
      // catch-all instead of matching. Materializing to a `List` here also
      // avoids passing a lazy iterable across the repository boundary, which
      // is good practice regardless of the test-tooling reason.
      return await ref
          .read(subjectImageCacheRepositoryProvider)
          .getFor(items.map((item) => item.subjectId).toList());
    } catch (_) {
      return {};
    }
  }
}
