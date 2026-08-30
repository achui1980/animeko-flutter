// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScheduledAnimeSubject _$ScheduledAnimeSubjectFromJson(
  Map<String, dynamic> json,
) => ScheduledAnimeSubject(
  subjectId: (json['subjectId'] as num).toInt(),
  name: json['name'] as String,
  nameCn: json['nameCn'] as String,
  imageLarge: json['imageLarge'] as String,
);

Map<String, dynamic> _$ScheduledAnimeSubjectToJson(
  ScheduledAnimeSubject instance,
) => <String, dynamic>{
  'subjectId': instance.subjectId,
  'name': instance.name,
  'nameCn': instance.nameCn,
  'imageLarge': instance.imageLarge,
};

ScheduledAnimeEpisodeInfo _$ScheduledAnimeEpisodeInfoFromJson(
  Map<String, dynamic> json,
) => ScheduledAnimeEpisodeInfo(
  episodeId: (json['episodeId'] as num).toInt(),
  name: json['name'] as String,
  nameCn: json['nameCn'] as String,
  airDate: json['airDate'] as String,
  sort: json['sort'] as String,
);

Map<String, dynamic> _$ScheduledAnimeEpisodeInfoToJson(
  ScheduledAnimeEpisodeInfo instance,
) => <String, dynamic>{
  'episodeId': instance.episodeId,
  'name': instance.name,
  'nameCn': instance.nameCn,
  'airDate': instance.airDate,
  'sort': instance.sort,
};

ScheduledAnimeEpisode _$ScheduledAnimeEpisodeFromJson(
  Map<String, dynamic> json,
) => ScheduledAnimeEpisode(
  subject: ScheduledAnimeSubject.fromJson(
    json['subject'] as Map<String, dynamic>,
  ),
  episode: ScheduledAnimeEpisodeInfo.fromJson(
    json['episode'] as Map<String, dynamic>,
  ),
  airingTime: json['airingTime'] as String,
);

Map<String, dynamic> _$ScheduledAnimeEpisodeToJson(
  ScheduledAnimeEpisode instance,
) => <String, dynamic>{
  'subject': instance.subject,
  'episode': instance.episode,
  'airingTime': instance.airingTime,
};

AiringScheduleForDate _$AiringScheduleForDateFromJson(
  Map<String, dynamic> json,
) => AiringScheduleForDate(
  date: json['date'] as String,
  list: (json['list'] as List<dynamic>)
      .map((e) => ScheduledAnimeEpisode.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AiringScheduleForDateToJson(
  AiringScheduleForDate instance,
) => <String, dynamic>{'date': instance.date, 'list': instance.list};

LatestAiringSchedule _$LatestAiringScheduleFromJson(
  Map<String, dynamic> json,
) => LatestAiringSchedule(
  list: (json['list'] as List<dynamic>)
      .map((e) => AiringScheduleForDate.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LatestAiringScheduleToJson(
  LatestAiringSchedule instance,
) => <String, dynamic>{'list': instance.list};
