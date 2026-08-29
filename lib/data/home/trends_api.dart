// lib/data/home/trends_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'trends_models.dart';

part 'trends_api.g.dart';

class TrendsApi {
  TrendsApi(this._dio);
  final Dio _dio;

  Future<TrendsResponse> getTrends() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/trends');
    return TrendsResponse.fromJson(response.data!);
  }
}

@riverpod
TrendsApi trendsApi(Ref ref) => TrendsApi(ref.watch(dioProvider));
