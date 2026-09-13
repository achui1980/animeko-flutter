// lib/data/subject/subject_episode_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'subject_episode_models.g.dart';

/// One item of the `episodes` array that the Animeko backend embeds in
/// `GET /v2/subjects/{id}`. Verified against live responses (2026-09-12,
/// `https://api.animeko.org/v2/subjects/302286`):
/// ```json
/// {
///   "episodeId": 1127992, "subjectId": 302286, "sort": "1", "ep": "1",
///   "type": "MAIN", "name": "THE BLOOD WARFARE", "nameCn": "血战",
///   "description": "", "airdate": "2022-10-10", "disc": 0,
///   "duration": "00:24:07"
/// }
/// ```
///
/// Two wire quirks worth knowing, both differing from Bangumi's own
/// `/v0/episodes` shape this replaced:
///  * `sort` and `ep` arrive as **strings**, not numbers.
///  * `type` is a **string enum** (`MAIN`/`SPECIAL`/`OP`/`ED`), not
///    Bangumi's numeric code where 0 meant 正片.
///
/// Sourcing episodes from here rather than `api.bgm.tv` is what makes the
/// episode list work without a proxy: `api.bgm.tv` is DNS-poisoned and
/// SNI-blocked from mainland networks, while `api.animeko.org` is directly
/// reachable. It also removes the old `limit=100` truncation -- long-running
/// shows now return their full episode list (航海王: 1155 主线剧集).
///
/// Deliberately lean subset -- `subjectId`/`description`/`disc`/`duration`
/// are real fields the UI doesn't need (YAGNI); `json_serializable`'s
/// generated `fromJson` ignores undeclared keys, so omitting them is safe
/// (same pattern as `SubjectDetail` in `subject_models.dart`).
@JsonSerializable()
class SubjectEpisode {
  const SubjectEpisode({
    required this.episodeId,
    required this.sort,
    required this.ep,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.airdate,
  });

  @JsonKey(defaultValue: 0)
  final int episodeId;

  /// Ordering key across *all* episode types. Parsed defensively via
  /// [_sortFromJson] because the backend stringifies it.
  @JsonKey(fromJson: _sortFromJson, toJson: _sortToJson)
  final num sort;

  /// Episode number within its type. Nullable because `SPECIAL` entries
  /// can omit it.
  final String? ep;

  /// `MAIN` | `SPECIAL` | `OP` | `ED`. Only [isMain] entries are shown in
  /// the grid -- see `SubjectMainEpisodesController`.
  @JsonKey(defaultValue: '')
  final String type;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String nameCn;

  @JsonKey(defaultValue: '')
  final String airdate;

  /// True for 正片 (main episodes) -- the only type the episode grid shows.
  bool get isMain => type == 'MAIN';

  /// Display title -- prefers the Chinese name per the design doc's
  /// Section 2, falling back to the original name when no Chinese name
  /// exists.
  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory SubjectEpisode.fromJson(Map<String, dynamic> json) =>
      _$SubjectEpisodeFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectEpisodeToJson(this);
}

/// Coerces the wire's stringified `sort` into a [num].
///
/// Falls back to `0` rather than throwing: a single malformed `sort` would
/// otherwise take down the whole subject detail response (and with it the
/// title, summary, characters and staff), which is a far worse outcome than
/// one episode sorting to the front.
num _sortFromJson(dynamic raw) {
  if (raw is num) return raw;
  if (raw is String) return num.tryParse(raw) ?? 0;
  return 0;
}

String _sortToJson(num sort) => sort.toString();
