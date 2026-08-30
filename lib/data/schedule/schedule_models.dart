// lib/data/schedule/schedule_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'schedule_models.g.dart';

/// Verified against the Kotlin-generated `AniScheduledAnimeSubject` model.
@JsonSerializable()
class ScheduledAnimeSubject {
  const ScheduledAnimeSubject({
    required this.subjectId,
    required this.name,
    required this.nameCn,
    required this.imageLarge,
  });

  final int subjectId;
  final String name;
  final String nameCn;
  final String imageLarge;

  factory ScheduledAnimeSubject.fromJson(Map<String, dynamic> json) =>
      _$ScheduledAnimeSubjectFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduledAnimeSubjectToJson(this);
}

/// Verified against the Kotlin-generated `AniScheduledAnimeEpisodeInfo`
/// model. Deliberately omits the wire's required `type` field, which the
/// UI doesn't need.
@JsonSerializable()
class ScheduledAnimeEpisodeInfo {
  const ScheduledAnimeEpisodeInfo({
    required this.episodeId,
    required this.name,
    required this.nameCn,
    required this.airDate,
    required this.sort,
  });

  final int episodeId;
  final String name;
  final String nameCn;
  final String airDate;
  final String sort;

  factory ScheduledAnimeEpisodeInfo.fromJson(Map<String, dynamic> json) =>
      _$ScheduledAnimeEpisodeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduledAnimeEpisodeInfoToJson(this);
}

@JsonSerializable()
class ScheduledAnimeEpisode {
  const ScheduledAnimeEpisode({
    required this.subject,
    required this.episode,
    required this.airingTime,
  });

  final ScheduledAnimeSubject subject;
  final ScheduledAnimeEpisodeInfo episode;
  final String airingTime;

  factory ScheduledAnimeEpisode.fromJson(Map<String, dynamic> json) =>
      _$ScheduledAnimeEpisodeFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduledAnimeEpisodeToJson(this);
}

@JsonSerializable()
class AiringScheduleForDate {
  const AiringScheduleForDate({required this.date, required this.list});

  final String date;
  final List<ScheduledAnimeEpisode> list;

  factory AiringScheduleForDate.fromJson(Map<String, dynamic> json) =>
      _$AiringScheduleForDateFromJson(json);

  Map<String, dynamic> toJson() => _$AiringScheduleForDateToJson(this);
}

/// Response of `GET /v1/schedule/airing`.
@JsonSerializable()
class LatestAiringSchedule {
  const LatestAiringSchedule({required this.list});

  final List<AiringScheduleForDate> list;

  factory LatestAiringSchedule.fromJson(Map<String, dynamic> json) =>
      _$LatestAiringScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$LatestAiringScheduleToJson(this);
}
