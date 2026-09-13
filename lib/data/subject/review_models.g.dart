// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewAuthor _$ReviewAuthorFromJson(Map<String, dynamic> json) => ReviewAuthor(
  id: json['id'] as String,
  nickname: json['nickname'] as String,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$ReviewAuthorToJson(ReviewAuthor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nickname': instance.nickname,
      'avatarUrl': instance.avatarUrl,
    };

SubjectReview _$SubjectReviewFromJson(Map<String, dynamic> json) =>
    SubjectReview(
      id: json['id'] as String,
      subjectId: (json['subjectId'] as num).toInt(),
      source: json['source'] as String,
      author: ReviewAuthor.fromJson(json['author'] as Map<String, dynamic>),
      contentBbcode: json['contentBbcode'] as String?,
      updatedAt: json['updatedAt'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SubjectReviewToJson(SubjectReview instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subjectId': instance.subjectId,
      'source': instance.source,
      'author': instance.author,
      'contentBbcode': instance.contentBbcode,
      'updatedAt': instance.updatedAt,
      'rating': instance.rating,
      'likeCount': instance.likeCount,
    };

PaginatedReviews _$PaginatedReviewsFromJson(Map<String, dynamic> json) =>
    PaginatedReviews(
      total: (json['total'] as num).toInt(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => SubjectReview.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$PaginatedReviewsToJson(PaginatedReviews instance) =>
    <String, dynamic>{'total': instance.total, 'items': instance.items};
