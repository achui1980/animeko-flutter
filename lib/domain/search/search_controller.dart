// lib/domain/search/search_controller.dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/search/search_api.dart';
import '../../data/search/search_sort_by.dart';
import '../subject_card.dart';

part 'search_controller.g.dart';

/// Delay before firing a search after the last keystroke. Overridden to
/// [Duration.zero] in tests so debounced searches run instantly.
@riverpod
Duration searchDebounceDuration(Ref ref) =>
    const Duration(milliseconds: 400);

@riverpod
class SearchController extends _$SearchController {
  Timer? _debounce;

  @override
  Future<List<SubjectCard>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return const [];
  }

  void search({
    required String keywords,
    List<String>? tags,
    SearchSortBy? sortBy,
  }) {
    _debounce?.cancel();

    if (keywords.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }

    _debounce = Timer(ref.read(searchDebounceDurationProvider), () async {
      state = const AsyncLoading();
      try {
        final api = ref.read(searchApiProvider);
        final response = await api.search(
          keywords: keywords,
          tags: tags,
          sortBy: sortBy,
        );
        state = AsyncData(
          response.items.map(SubjectCard.fromSearchResult).toList(),
        );
      } catch (e, st) {
        state = AsyncError(e, st);
      }
    });
  }
}
