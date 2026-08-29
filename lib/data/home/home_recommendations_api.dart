// lib/data/home/home_recommendations_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'home_recommendations_models.dart';

part 'home_recommendations_api.g.dart';

/// GET /v2/home/recommendations -- declared auth-jwt in the OpenAPI spec.
/// The shared `dioProvider` already attaches the Authorization header via
/// AuthInterceptor, so this class does not need to handle auth itself.
class HomeRecommendationsApi {
  HomeRecommendationsApi(this._dio);
  final Dio _dio;

  Future<HomeRecommendationsResponse> getRecommendations({
    int? offset,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/home/recommendations',
      queryParameters: {
        if (offset != null) 'offset': offset,
        if (limit != null) 'limit': limit,
      },
    );
    return HomeRecommendationsResponse.fromJson(response.data!);
  }
}

@riverpod
HomeRecommendationsApi homeRecommendationsApi(Ref ref) =>
    HomeRecommendationsApi(ref.watch(dioProvider));
