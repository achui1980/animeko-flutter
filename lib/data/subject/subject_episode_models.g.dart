// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_episode_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubjectEpisode _$SubjectEpisodeFromJson(Map<String, dynamic> json) =>
    SubjectEpisode(
      episodeId: (json['episodeId'] as num?)?.toInt() ?? 0,
      sort: _sortFromJson(json['sort']),
      ep: json['ep'] as String?,
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameCn: json['nameCn'] as String? ?? '',
      airdate: json['airdate'] as String? ?? '',
    );

Map<String, dynamic> _$SubjectEpisodeToJson(SubjectEpisode instance) =>
    <String, dynamic>{
      'episodeId': instance.episodeId,
      'sort': _sortToJson(instance.sort),
      'ep': instance.ep,
      'type': instance.type,
      'name': instance.name,
      'nameCn': instance.nameCn,
      'airdate': instance.airdate,
    };
