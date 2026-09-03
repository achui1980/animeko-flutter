// lib/domain/home/home_recommendations_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home/home_recommendations_api.dart';
import '../subject_card.dart';

part 'home_recommendations_controller.g.dart';

const _pageSize = 20;

/// The loaded slice of the home page's "recommendations" grid plus
/// whether another page is available, using the server's real `total`
/// field (unlike `MyCollectionsController`'s "short page = last page"
/// heuristic, which exists there specifically because
/// `PaginatedCollections.total` was found unreliable on that different
/// endpoint -- no such issue here, see the design doc).
class HomeRecommendationsPage {
  const HomeRecommendationsPage({required this.items, required this.hasMore});

  final List<SubjectCard> items;
  final bool hasMore;
}

@riverpod
class HomeRecommendationsController extends _$HomeRecommendationsController {
  @override
  Future<HomeRecommendationsPage> build() async {
    final api = ref.watch(homeRecommendationsApiProvider);
    final response = await api.getRecommendations(offset: 0, limit: _pageSize);
    return HomeRecommendationsPage(
      items: response.items.map(SubjectCard.fromRecommendation).toList(),
      hasMore: response.items.length < response.total,
    );
  }

  /// Fetches the next page (offset = current list length) and appends
  /// it. No pull-to-refresh (design doc, YAGNI) -- leaving and
  /// re-entering the page re-runs [build] instead.
  Future<void> loadMore() async {
    final current = await future;
    if (!current.hasMore) return;
    final api = ref.read(homeRecommendationsApiProvider);
    final response = await api.getRecommendations(
      offset: current.items.length,
      limit: _pageSize,
    );
    final newItems = response.items.map(SubjectCard.fromRecommendation).toList();
    state = AsyncData(
      HomeRecommendationsPage(
        items: [...current.items, ...newItems],
        hasMore: current.items.length + newItems.length < response.total,
      ),
    );
  }
}
