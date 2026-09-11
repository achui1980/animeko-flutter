// lib/data/subject/bangumi_episodes_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'bangumi_episode_models.dart';

part 'bangumi_episodes_api.g.dart';

/// Base URL for Bangumi's own official public API -- **not** this
/// app's own backend (`aniApiBaseUrl` in `../api_client.dart`). This is
/// the first client in this codebase to call `api.bgm.tv` directly:
/// investigation (2026-09-07) confirmed `https://api.animeko.org` has
/// no episode-list endpoint under any of 20+ probed paths (only a
/// single-episode-by-ID lookup exists, with no way to enumerate episode
/// IDs), so this feature calls Bangumi's real public API directly
/// instead -- see the design doc's Section 2 and Risks.
const bangumiApiBaseUrl = 'https://api.bgm.tv';

const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 15);

/// Direct client for Bangumi's own public episode-list endpoint.
/// Unauthenticated -- confirmed via a live request that no auth header
/// is required to read `/v0/episodes`.
class BangumiEpisodesApi {
  BangumiEpisodesApi(this._dio);
  final Dio _dio;

  /// GET /v0/episodes?subject_id={subjectId}&type=0&limit=100 --
  /// `type=0` filters to main episodes server-side (SP/OP/ED excluded).
  /// `limit=100` is a hard cap per the design doc (no pagination this
  /// pass); series with more than 100 main episodes are out of scope.
  Future<List<BangumiEpisode>> listEpisodes(int subjectId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v0/episodes',
      queryParameters: {'subject_id': subjectId, 'type': 0, 'limit': 100},
    );
    return BangumiEpisodesResponse.fromJson(response.data!).data;
  }
}

@riverpod
Dio bangumiEpisodesDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: bangumiApiBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    ),
  );
  return dio;
}

@riverpod
BangumiEpisodesApi bangumiEpisodesApi(Ref ref) =>
    BangumiEpisodesApi(ref.watch(bangumiEpisodesDioProvider));
