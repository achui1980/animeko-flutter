// lib/data/search/search_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'search_models.dart';
import 'search_sort_by.dart';

part 'search_api.g.dart';

/// GET /v2/subjects/search -- keyword + tags + sort only (season and
/// rating-range filters are out of scope per the approved design doc).
class SearchApi {
  SearchApi(this._dio);
  final Dio _dio;

  Future<SearchResponse> search({
    required String keywords,
    List<String>? tags,
    SearchSortBy? sortBy,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/search',
      queryParameters: {
        'q': keywords,
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
        if (sortBy != null) 'sortBy': sortBy.wireValue,
      },
    );
    return SearchResponse.fromJson(response.data!);
  }
}

@riverpod
SearchApi searchApi(Ref ref) => SearchApi(ref.watch(dioProvider));
