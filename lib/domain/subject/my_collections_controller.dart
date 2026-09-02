import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_models.dart';

part 'my_collections_controller.g.dart';

const _pageSize = 20;

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.
@riverpod
class MyCollectionsController extends _$MyCollectionsController {
  @override
  Future<List<MyCollectionSubject>> build({required CollectionType? type}) async {
    final page = await ref
        .watch(subjectApiProvider)
        .getMyCollections(type: type, offset: 0, limit: _pageSize);
    return page.items;
  }

  /// Fetches the next page (offset = current list length) and appends
  /// it. No pull-to-refresh (design doc, YAGNI) -- leaving and
  /// re-entering the page re-runs [build] instead.
  Future<void> loadMore() async {
    final current = await future;
    final page = await ref
        .read(subjectApiProvider)
        .getMyCollections(type: type, offset: current.length, limit: _pageSize);
    state = AsyncData([...current, ...page.items]);
  }
}
