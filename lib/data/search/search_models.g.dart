// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubjectTag _$SubjectTagFromJson(Map<String, dynamic> json) => SubjectTag(
  name: json['name'] as String,
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$SubjectTagToJson(SubjectTag instance) =>
    <String, dynamic>{'name': instance.name, 'count': instance.count};

SubjectSearchResult _$SubjectSearchResultFromJson(Map<String, dynamic> json) =>
    SubjectSearchResult(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      nameCn: json['nameCn'] as String,
      imageLarge: json['imageLarge'] as String,
      airDate: json['airDate'] as String,
      tags: (json['tags'] as List<dynamic>)
          .map((e) => SubjectTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: json['score'] as String?,
    );

Map<String, dynamic> _$SubjectSearchResultToJson(
  SubjectSearchResult instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'nameCn': instance.nameCn,
  'imageLarge': instance.imageLarge,
  'airDate': instance.airDate,
  'tags': instance.tags,
  'score': instance.score,
};

SearchResponse _$SearchResponseFromJson(Map<String, dynamic> json) =>
    SearchResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => SubjectSearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SearchResponseToJson(SearchResponse instance) =>
    <String, dynamic>{'items': instance.items};
