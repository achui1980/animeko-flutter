// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trends_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrendingSubject _$TrendingSubjectFromJson(Map<String, dynamic> json) =>
    TrendingSubject(
      bangumiId: (json['bangumiId'] as num).toInt(),
      nameCn: json['nameCn'] as String,
      imageLarge: json['imageLarge'] as String,
    );

Map<String, dynamic> _$TrendingSubjectToJson(TrendingSubject instance) =>
    <String, dynamic>{
      'bangumiId': instance.bangumiId,
      'nameCn': instance.nameCn,
      'imageLarge': instance.imageLarge,
    };

TrendsResponse _$TrendsResponseFromJson(Map<String, dynamic> json) =>
    TrendsResponse(
      trendingSubjects: (json['trendingSubjects'] as List<dynamic>)
          .map((e) => TrendingSubject.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TrendsResponseToJson(TrendsResponse instance) =>
    <String, dynamic>{'trendingSubjects': instance.trendingSubjects};
