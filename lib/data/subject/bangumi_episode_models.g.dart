// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_episode_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiEpisode _$BangumiEpisodeFromJson(Map<String, dynamic> json) =>
    BangumiEpisode(
      id: (json['id'] as num).toInt(),
      sort: json['sort'] as num,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      airdate: json['airdate'] as String,
      type: (json['type'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiEpisodeToJson(BangumiEpisode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sort': instance.sort,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'airdate': instance.airdate,
      'type': instance.type,
    };

BangumiEpisodesResponse _$BangumiEpisodesResponseFromJson(
  Map<String, dynamic> json,
) => BangumiEpisodesResponse(
  data: (json['data'] as List<dynamic>)
      .map((e) => BangumiEpisode.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  offset: (json['offset'] as num).toInt(),
);

Map<String, dynamic> _$BangumiEpisodesResponseToJson(
  BangumiEpisodesResponse instance,
) => <String, dynamic>{
  'data': instance.data,
  'total': instance.total,
  'limit': instance.limit,
  'offset': instance.offset,
};
