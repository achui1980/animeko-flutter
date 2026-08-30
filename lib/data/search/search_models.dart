// lib/data/search/search_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'search_models.g.dart';

/// A single tag with the number of subjects it's attached to. Verified
/// against the Kotlin-generated `AniTag` model.
@JsonSerializable()
class SubjectTag {
  const SubjectTag({required this.name, required this.count});

  final String name;
  final int count;

  factory SubjectTag.fromJson(Map<String, dynamic> json) =>
      _$SubjectTagFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectTagToJson(this);
}

/// A single search result. This is a deliberately lean subset of the full
/// wire shape (`AniSubjectSearch` in the Kotlin client has more fields --
/// summary/nsfw/ratingTotal/favorite/mainEpisodeCount/
/// lightRelatedPersonInfoList/rank) -- json_serializable's generated
/// `fromJson` simply ignores any JSON keys not declared as Dart fields, so
/// omitting fields the UI doesn't need is safe.
@JsonSerializable()
class SubjectSearchResult {
  const SubjectSearchResult({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.imageLarge,
    required this.airDate,
    required this.tags,
    this.score,
  });

  final int id;
  final String name;
  final String nameCn;
  final String imageLarge;
  final String airDate;
  final List<SubjectTag> tags;
  final String? score;

  factory SubjectSearchResult.fromJson(Map<String, dynamic> json) =>
      _$SubjectSearchResultFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectSearchResultToJson(this);
}

/// Response of `GET /v2/subjects/search`. Unlike other paginated Ani
/// endpoints, this one has no `total` field -- only `items`.
@JsonSerializable()
class SearchResponse {
  const SearchResponse({required this.items});

  final List<SubjectSearchResult> items;

  factory SearchResponse.fromJson(Map<String, dynamic> json) =>
      _$SearchResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SearchResponseToJson(this);
}
