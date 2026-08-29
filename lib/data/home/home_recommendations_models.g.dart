// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_recommendations_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubjectRecommendation _$SubjectRecommendationFromJson(
  Map<String, dynamic> json,
) => SubjectRecommendation(
  subjectName: json['subjectName'] as String,
  subjectNameCn: json['subjectNameCn'] as String,
  imageUrl: json['imageUrl'] as String,
  desc1: json['desc1'] as String,
  desc2: json['desc2'] as String,
  subjectId: (json['subjectId'] as num?)?.toInt(),
  uri: json['uri'] as String?,
);

Map<String, dynamic> _$SubjectRecommendationToJson(
  SubjectRecommendation instance,
) => <String, dynamic>{
  'subjectName': instance.subjectName,
  'subjectNameCn': instance.subjectNameCn,
  'imageUrl': instance.imageUrl,
  'desc1': instance.desc1,
  'desc2': instance.desc2,
  'subjectId': instance.subjectId,
  'uri': instance.uri,
};

HomeRecommendationsResponse _$HomeRecommendationsResponseFromJson(
  Map<String, dynamic> json,
) => HomeRecommendationsResponse(
  total: (json['total'] as num).toInt(),
  items: (json['items'] as List<dynamic>)
      .map((e) => SubjectRecommendation.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$HomeRecommendationsResponseToJson(
  HomeRecommendationsResponse instance,
) => <String, dynamic>{'total': instance.total, 'items': instance.items};
