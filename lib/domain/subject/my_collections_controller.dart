import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_models.dart';

part 'my_collections_controller.g.dart';

const _pageSize = 20;

/// The loaded slice of the "My Collection" list plus whether another
/// page might still be available. [hasMore] uses the standard
/// "short page = last page" heuristic -- a fetched page with fewer
/// items than [_pageSize] means there's nothing left to load. This
/// doesn't require trusting [PaginatedCollections.total]'s exact
/// semantics against the real server (see the NOTE on that class).
class MyCollectionsPage {
  const MyCollectionsPage({required this.items, required this.hasMore});

  final List<MyCollectionSubject> items;
  final bool hasMore;
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
    return MyCollectionsPage(items: page.items, hasMore: page.items.length >= _pageSize);
  }

  /// Fetches the next page (offset = current list length) and appends
  /// it. No pull-to-refresh (design doc, YAGNI) -- leaving and
  /// re-entering the page re-runs [build] instead.
  Future<void> loadMore() async {
    final current = await future;
    final page = await ref
        .read(subjectApiProvider)
        .getMyCollections(type: type, offset: current.items.length, limit: _pageSize);
    state = AsyncData(
      MyCollectionsPage(
        items: [...current.items, ...page.items],
        hasMore: page.items.length >= _pageSize,
      ),
    );
  }
}
