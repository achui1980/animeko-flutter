// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SelfRating _$SelfRatingFromJson(Map<String, dynamic> json) => SelfRating(
  score: (json['score'] as num).toInt(),
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  isPrivate: json['isPrivate'] as bool,
  comment: json['comment'] as String?,
);

Map<String, dynamic> _$SelfRatingToJson(SelfRating instance) =>
    <String, dynamic>{
      'score': instance.score,
      'tags': instance.tags,
      'isPrivate': instance.isPrivate,
      'comment': instance.comment,
    };

SubjectDetail _$SubjectDetailFromJson(Map<String, dynamic> json) =>
    SubjectDetail(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      nameCn: json['nameCn'] as String,
      summary: json['summary'] as String,
      airDate: json['airDate'] as String,
      tags: (json['tags'] as List<dynamic>)
          .map((e) => SubjectTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: json['score'] as String?,
      rank: (json['rank'] as num?)?.toInt(),
      collectionType: collectionTypeFromWireNullable(
        json['collectionType'] as String?,
      ),
      selfRating: SelfRating.fromJson(
        json['selfRating'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$SubjectDetailToJson(SubjectDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nameCn': instance.nameCn,
      'summary': instance.summary,
      'airDate': instance.airDate,
      'tags': instance.tags,
      'score': instance.score,
      'rank': instance.rank,
      'collectionType': collectionTypeToWireNullable(instance.collectionType),
      'selfRating': instance.selfRating,
    };

CharacterInfo _$CharacterInfoFromJson(Map<String, dynamic> json) =>
    CharacterInfo(
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$CharacterInfoToJson(CharacterInfo instance) =>
    <String, dynamic>{'name': instance.name, 'imageUrl': instance.imageUrl};

RelatedCharacter _$RelatedCharacterFromJson(Map<String, dynamic> json) =>
    RelatedCharacter(
      index: (json['index'] as num).toInt(),
      character: CharacterInfo.fromJson(
        json['character'] as Map<String, dynamic>,
      ),
      role: (json['role'] as num).toInt(),
    );

Map<String, dynamic> _$RelatedCharacterToJson(RelatedCharacter instance) =>
    <String, dynamic>{
      'index': instance.index,
      'character': instance.character,
      'role': instance.role,
    };

StaffMember _$StaffMemberFromJson(Map<String, dynamic> json) => StaffMember(
  name: json['name'] as String,
  imageUrl: json['imageUrl'] as String?,
  role: json['role'] as String?,
);

Map<String, dynamic> _$StaffMemberToJson(StaffMember instance) =>
    <String, dynamic>{
      'name': instance.name,
      'imageUrl': instance.imageUrl,
      'role': instance.role,
    };

Map<String, dynamic> _$MyCollectionSubjectToJson(
  MyCollectionSubject instance,
) => <String, dynamic>{
  'subjectId': instance.subjectId,
  'name': instance.name,
  'nameCn': instance.nameCn,
  'collectionType': collectionTypeToWireNullable(instance.collectionType),
};

PaginatedCollections _$PaginatedCollectionsFromJson(
  Map<String, dynamic> json,
) => PaginatedCollections(
  items: (json['items'] as List<dynamic>)
      .map((e) => MyCollectionSubject.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num?)?.toInt(),
);

Map<String, dynamic> _$PaginatedCollectionsToJson(
  PaginatedCollections instance,
) => <String, dynamic>{'items': instance.items, 'total': instance.total};
