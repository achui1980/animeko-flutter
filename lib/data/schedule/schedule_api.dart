// lib/data/schedule/schedule_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'schedule_models.dart';

part 'schedule_api.g.dart';

/// GET /v1/schedule/airing -- public endpoint, no auth required.
///
/// NOTE: the `today` (`YYYY-MM-DD`) and `timeZone` (`+HH:MM`) query param
/// formats are an unverified assumption about the real server -- they are
/// not confirmed against any spec in this repo. Adjust if the live API
/// disagrees.
class ScheduleApi {
  ScheduleApi(this._dio);
  final Dio _dio;

  Future<LatestAiringSchedule> getLatestAiringSchedule({
    required String today,
    required String timeZone,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/schedule/airing',
      queryParameters: {'today': today, 'timeZone': timeZone},
    );
    return LatestAiringSchedule.fromJson(response.data!);
  }
}

@riverpod
ScheduleApi scheduleApi(Ref ref) => ScheduleApi(ref.watch(dioProvider));
