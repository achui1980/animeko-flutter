// lib/data/subject/subject_models.dart
import 'package:json_annotation/json_annotation.dart';

import '../search/search_models.dart' show SubjectTag;
import 'collection_type.dart';

part 'subject_models.g.dart';

/// The current user's own rating for a subject. Always present on
/// [SubjectDetail] (verified against the real `AniSelfRatingInfo`
/// model) -- `score == 0` means "not rated yet", not a real 0-star
/// rating (the UI never lets a user submit a score below 1, see
/// `SubjectCollectionController.submitRating`).
@JsonSerializable()
class SelfRating {
  const SelfRating({
    required this.score,
    required this.tags,
    required this.isPrivate,
    this.comment,
  });

  final int score;
  final List<String> tags;
  final bool isPrivate;
  final String? comment;

  factory SelfRating.fromJson(Map<String, dynamic> json) =>
      _$SelfRatingFromJson(json);

  Map<String, dynamic> toJson() => _$SelfRatingToJson(this);
}

/// Response of `GET /v2/subjects/{subjectId}` -- verified against the
/// real `AniSubjectCollection` model. This is a deliberately lean subset
/// (the real wire shape also has `type`/`nsfw`/`aliases`/`favorite`/
/// `metaTags`/`scoreDetails`/`episodes`/`relations`/`infobox`/`platform`/
/// `airingInfo`/`updatedAt`, none of which the UI needs) --
/// json_serializable's generated `fromJson` ignores undeclared keys, so
/// omitting fields is safe.
@JsonSerializable()
class SubjectDetail {
  const SubjectDetail({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.tags,
    this.score,
    this.rank,
    this.collectionType,
    required this.selfRating,
  });

  final int id;
  final String name;
  final String nameCn;
  final String summary;
  final String airDate;
  final List<SubjectTag> tags;

  /// Official rating, string-encoded float (e.g. `"8.4"`) or null if the
  /// subject has too few ratings.
  final String? score;
  final int? rank;

  /// The current user's own collection status. Null means "not in the
  /// user's collection at all" (distinct from any of the 5 real states).
  @JsonKey(fromJson: collectionTypeFromWireNullable, toJson: collectionTypeToWireNullable)
  final CollectionType? collectionType;

  final SelfRating selfRating;

  factory SubjectDetail.fromJson(Map<String, dynamic> json) =>
      _$SubjectDetailFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectDetailToJson(this);
}

/// A single character (with its voice actor's info, since
/// `getCharacters` is always called with `withActors=true`).
///
/// NOTE: `imageUrl`'s real field name is *inferred*, not confirmed
/// against the real `AniCharacter` Kotlin model (only the wrapper
/// `AniRelatedCharacter{index,character,role}` shape was actually read
/// during this plan's design phase) -- verify against a live
/// `GET .../characters?withActors=true` response before trusting this.
@JsonSerializable()
class CharacterInfo {
  const CharacterInfo({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  factory CharacterInfo.fromJson(Map<String, dynamic> json) =>
      _$CharacterInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CharacterInfoToJson(this);
}

/// Response item of `GET /v2/subjects/{subjectId}/characters`. Verified
/// against the real `AniRelatedCharacter{index,character,role}` wrapper
/// shape.
@JsonSerializable()
class RelatedCharacter {
  const RelatedCharacter({
    required this.index,
    required this.character,
    required this.role,
  });

  final int index;
  final CharacterInfo character;
  final int role;

  factory RelatedCharacter.fromJson(Map<String, dynamic> json) =>
      _$RelatedCharacterFromJson(json);

  Map<String, dynamic> toJson() => _$RelatedCharacterToJson(this);
}

/// Response item of `GET /v2/subjects/{subjectId}/staff`.
///
/// NOTE: this entire shape is an **unconfirmed best guess** -- the real
/// Kotlin model for this endpoint was never read during this plan's
/// design phase (flagged explicitly rather than silently assumed
/// correct). Verify against a live `GET .../staff` response before
/// trusting `name`/`imageUrl`/`role` as the real field names.
@JsonSerializable()
class StaffMember {
  const StaffMember({required this.name, this.imageUrl, this.role});

  final String name;
  final String? imageUrl;
  final String? role;

  factory StaffMember.fromJson(Map<String, dynamic> json) =>
      _$StaffMemberFromJson(json);

  Map<String, dynamic> toJson() => _$StaffMemberToJson(this);
}

/// One item of `GET /v2/subjects/list` (the "My Collection" library
/// page). A deliberately lean subset of `AniSubjectCollection` for list
/// display -- notably, `AniSubjectCollection` has no image field of its
/// own, so this list has no cover image either (the UI leaves a plain
/// empty-space placeholder with no grey fill, unlike the
/// `Colors.grey.shade300`-filled `Container` convention used elsewhere,
/// e.g. `home_screen.dart`).
@JsonSerializable()
class MyCollectionSubject {
  const MyCollectionSubject({
    required this.subjectId,
    required this.name,
    required this.nameCn,
    this.collectionType,
  });

  final int subjectId;
  final String name;
  final String nameCn;

  @JsonKey(fromJson: collectionTypeFromWireNullable, toJson: collectionTypeToWireNullable)
  final CollectionType? collectionType;

  factory MyCollectionSubject.fromJson(Map<String, dynamic> json) =>
      _$MyCollectionSubjectFromJson(json);

  Map<String, dynamic> toJson() => _$MyCollectionSubjectToJson(this);
}

/// Response of `GET /v2/subjects/list`.
///
/// CONFIRMED via live testing (2026-09-02): the real server response
/// omits `total` entirely, unlike sibling paginated Ani endpoints (see
/// the comment on `SearchResponse` in
/// `lib/data/search/search_models.dart`). Originally modeled as a
/// required `int`, which crashed with "type 'Null' is not a subtype
/// of type 'num'" the first time this endpoint was hit against the
/// real backend -- [total] is now nullable. No production code reads
/// [total] (`MyCollectionsController` uses a short-page heuristic
/// instead, see its doc comment), so this field is effectively
/// vestigial; kept only in case a future server version starts
/// sending it.
@JsonSerializable()
class PaginatedCollections {
  const PaginatedCollections({required this.items, this.total});

  final List<MyCollectionSubject> items;
  final int? total;

  factory PaginatedCollections.fromJson(Map<String, dynamic> json) =>
      _$PaginatedCollectionsFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedCollectionsToJson(this);
}
