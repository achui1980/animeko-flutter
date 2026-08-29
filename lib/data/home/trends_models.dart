// lib/data/home/trends_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'trends_models.g.dart';

@JsonSerializable()
class TrendingSubject {
  const TrendingSubject({
    required this.bangumiId,
    required this.nameCn,
    required this.imageLarge,
  });

  final int bangumiId;
  final String nameCn;
  final String imageLarge;

  factory TrendingSubject.fromJson(Map<String, dynamic> json) =>
      _$TrendingSubjectFromJson(json);

  Map<String, dynamic> toJson() => _$TrendingSubjectToJson(this);
}

@JsonSerializable()
class TrendsResponse {
  const TrendsResponse({required this.trendingSubjects});

  final List<TrendingSubject> trendingSubjects;

  factory TrendsResponse.fromJson(Map<String, dynamic> json) =>
      _$TrendsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TrendsResponseToJson(this);
}
