// lib/data/subject/bangumi_episode_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'bangumi_episode_models.g.dart';

/// One item of Bangumi's own public `GET /v0/episodes` response's
/// `data` array. Verified against a live request (2026-09-07,
/// `https://api.bgm.tv/v0/episodes?subject_id=400602&type=0&limit=1`):
/// ```json
/// {
///   "airdate": "2023-09-29", "name": "冒険の終わり", "name_cn": "冒险结束",
///   "duration": "00:26:00", "desc": "...", "ep": 1, "sort": 1,
///   "id": 1227087, "subject_id": 400602, "comment": 297, "type": 0,
///   "disc": 0, "duration_seconds": 1560
/// }
/// ```
/// Deliberately lean subset -- `duration`/`desc`/`ep`/`subject_id`/
/// `comment`/`disc`/`duration_seconds` are all real fields the UI
/// doesn't need (YAGNI); `json_serializable`'s generated `fromJson`
/// ignores undeclared keys, so omitting them is safe (same pattern as
/// `SubjectDetail` in `subject_models.dart`).
@JsonSerializable()
class BangumiEpisode {
  const BangumiEpisode({
    required this.id,
    required this.sort,
    required this.name,
    required this.nameCn,
    required this.airdate,
    required this.type,
  });

  final int id;
  final num sort;
  final String name;

  @JsonKey(name: 'name_cn')
  final String nameCn;

  final String airdate;

  /// 0 = 正片 (main episode), 1 = SP, 2 = OP, 3 = ED, etc. Only
  /// `type == 0` episodes are ever shown in the grid -- see
  /// `SubjectBangumiEpisodesController`.
  final int type;

  /// Display title -- prefers the Chinese name per the design doc's
  /// Section 2, falling back to the original name when no Chinese name
  /// exists.
  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory BangumiEpisode.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiEpisodeToJson(this);
}

/// Wrapper for `GET /v0/episodes`'s paginated response shape --
/// `{data: [...], total, limit, offset}`. `total`/`limit`/`offset` are
/// unused by `BangumiEpisodesApi` (no pagination this pass, see the
/// design doc's `limit=100` hard cap) but are declared so
/// `json_serializable`'s generated `fromJson` has a shape to parse the
/// full response against.
@JsonSerializable()
class BangumiEpisodesResponse {
  const BangumiEpisodesResponse({
    required this.data,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<BangumiEpisode> data;
  final int total;
  final int limit;
  final int offset;

  factory BangumiEpisodesResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiEpisodesResponseToJson(this);
}
