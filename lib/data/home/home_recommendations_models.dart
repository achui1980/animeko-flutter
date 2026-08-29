// lib/data/home/home_recommendations_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'home_recommendations_models.g.dart';

/// Verified against Kotlin's AniSubjectRecommendation (GET
/// /v2/home/recommendations). subjectId/uri are nullable on the wire.
@JsonSerializable()
class SubjectRecommendation {
  const SubjectRecommendation({
    required this.subjectName,
    required this.subjectNameCn,
    required this.imageUrl,
    required this.desc1,
    required this.desc2,
    this.subjectId,
    this.uri,
  });

  final String subjectName;
  final String subjectNameCn;
  final String imageUrl;
  final String desc1;
  final String desc2;
  final int? subjectId;
  final String? uri;

  factory SubjectRecommendation.fromJson(Map<String, dynamic> json) =>
      _$SubjectRecommendationFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectRecommendationToJson(this);
}

/// Response body of GET /v2/home/recommendations
/// (AniHomeRecommendationsResponse in the Kotlin client).
@JsonSerializable()
class HomeRecommendationsResponse {
  const HomeRecommendationsResponse({
    required this.total,
    required this.items,
  });

  final int total;
  final List<SubjectRecommendation> items;

  factory HomeRecommendationsResponse.fromJson(Map<String, dynamic> json) =>
      _$HomeRecommendationsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$HomeRecommendationsResponseToJson(this);
}
