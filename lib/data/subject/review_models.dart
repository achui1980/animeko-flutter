// lib/data/subject/review_models.dart

import 'package:json_annotation/json_annotation.dart';

part 'review_models.g.dart';

/// The author of a review.
///
/// `id` is a STRING on the wire (observed `"1261526"`), matching
/// `SelfUser.id` in `../user/user_models.dart` -- user ids are strings
/// across this API, unlike the int ids on subjects/characters/persons.
@JsonSerializable()
class ReviewAuthor {
  const ReviewAuthor({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) =>
      _$ReviewAuthorFromJson(json);

  Map<String, dynamic> toJson() => _$ReviewAuthorToJson(this);
}

/// One other-user review (热门评价) from
/// `GET /v2/subjects/{id}/reviews`.
///
/// `contentBbcode` is BBCode-formatted; run it through
/// `stripBbcode` (`bbcode.dart`) before rendering.
@JsonSerializable()
class SubjectReview {
  const SubjectReview({
    required this.id,
    required this.subjectId,
    required this.source,
    required this.author,
    this.contentBbcode,
    this.updatedAt,
    this.rating,
    this.likeCount = 0,
  });

  /// Composite key, observed as `"{source}:{subjectId}:{authorId}"` --
  /// treat it as an opaque string, not something to parse.
  final String id;
  final int subjectId;
  final String source;
  final ReviewAuthor author;
  final String? contentBbcode;

  /// ISO-8601 UTC string, e.g. `"2026-09-11T13:56:03Z"`. Left as a raw
  /// String because nothing needs it as a `DateTime` yet.
  final String? updatedAt;

  /// The review author's own score for the subject. The type permits
  /// null, but no null was ever observed -- the one review captured
  /// during API probing carried `rating: 8`. The value range is also
  /// unverified, so do not assume one when formatting.
  final int? rating;

  @JsonKey(defaultValue: 0)
  final int likeCount;

  factory SubjectReview.fromJson(Map<String, dynamic> json) =>
      _$SubjectReviewFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectReviewToJson(this);
}

/// One page of reviews.
///
/// **WARNING: `total` is NOT a real total.** The backend returns
/// `limit + 1` whenever more rows exist (verified by live probe:
/// limit=1 -> total=2, limit=3 -> total=4, limit=10 -> total=11,
/// limit=50 -> total=51). Treat it purely as a has-more sentinel via
/// [hasMore]. NEVER render it as 「共 N 条评价」 -- it would show a
/// wrong number on every subject.
@JsonSerializable()
class PaginatedReviews {
  const PaginatedReviews({required this.total, this.items = const []});

  final int total;
  @JsonKey(defaultValue: <SubjectReview>[])
  final List<SubjectReview> items;

  /// Whether another page exists AFTER the page this object represents.
  /// See the class doc for why this is the only legitimate use of [total].
  ///
  /// Valid ONLY for a page exactly as returned by `SubjectApi.getReviews`.
  /// [total] is a per-request `limit + 1` sentinel while [items] would be
  /// cumulative, so this comparison silently goes false once pages have
  /// been concatenated: page 2 of a 100-review subject read 20 at a time
  /// gives `21 > 40 == false` and load-more stops at 40. A controller
  /// that accumulates pages must carry the LAST page's [hasMore] forward
  /// as a field of its own -- `MyCollectionsController` does exactly that
  /// with `MyCollectionsPage.hasMore` (`hasMore:` at
  /// `lib/domain/subject/my_collections_controller.dart:52,73`, derived
  /// from the freshly fetched page alone) -- not recompute it against the
  /// accumulated list.
  bool get hasMore => total > items.length;

  factory PaginatedReviews.fromJson(Map<String, dynamic> json) =>
      _$PaginatedReviewsFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedReviewsToJson(this);
}
