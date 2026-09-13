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

SubjectFavorite _$SubjectFavoriteFromJson(Map<String, dynamic> json) =>
    SubjectFavorite(
      wish: (json['wish'] as num?)?.toInt() ?? 0,
      done: (json['done'] as num?)?.toInt() ?? 0,
      doing: (json['doing'] as num?)?.toInt() ?? 0,
      onHold: (json['onHold'] as num?)?.toInt() ?? 0,
      dropped: (json['dropped'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SubjectFavoriteToJson(SubjectFavorite instance) =>
    <String, dynamic>{
      'wish': instance.wish,
      'done': instance.done,
      'doing': instance.doing,
      'onHold': instance.onHold,
      'dropped': instance.dropped,
    };

InfoboxValue _$InfoboxValueFromJson(Map<String, dynamic> json) =>
    InfoboxValue(k: json['k'] as String?, v: json['v'] as String);

Map<String, dynamic> _$InfoboxValueToJson(InfoboxValue instance) =>
    <String, dynamic>{'k': instance.k, 'v': instance.v};

InfoboxField _$InfoboxFieldFromJson(Map<String, dynamic> json) => InfoboxField(
  key: json['key'] as String,
  values:
      (json['values'] as List<dynamic>?)
          ?.map((e) => InfoboxValue.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$InfoboxFieldToJson(InfoboxField instance) =>
    <String, dynamic>{'key': instance.key, 'values': instance.values};

SubjectInfobox _$SubjectInfoboxFromJson(Map<String, dynamic> json) =>
    SubjectInfobox(
      template: json['template'] as String?,
      fields:
          (json['fields'] as List<dynamic>?)
              ?.map((e) => InfoboxField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$SubjectInfoboxToJson(SubjectInfobox instance) =>
    <String, dynamic>{'template': instance.template, 'fields': instance.fields};

SubjectDetail _$SubjectDetailFromJson(
  Map<String, dynamic> json,
) => SubjectDetail(
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
  selfRating: SelfRating.fromJson(json['selfRating'] as Map<String, dynamic>),
  aliases:
      (json['aliases'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  scoreDetails: (json['scoreDetails'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toInt()),
  ),
  favorite: json['favorite'] == null
      ? null
      : SubjectFavorite.fromJson(json['favorite'] as Map<String, dynamic>),
  infobox: json['infobox'] == null
      ? null
      : SubjectInfobox.fromJson(json['infobox'] as Map<String, dynamic>),
  episodes: (json['episodes'] as List<dynamic>?)
      ?.map((e) => SubjectEpisode.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubjectDetailToJson(SubjectDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nameCn': instance.nameCn,
      'summary': instance.summary,
      'airDate': instance.airDate,
      'tags': instance.tags,
      'aliases': instance.aliases,
      'score': instance.score,
      'rank': instance.rank,
      'collectionType': collectionTypeToWireNullable(instance.collectionType),
      'selfRating': instance.selfRating,
      'scoreDetails': instance.scoreDetails,
      'favorite': instance.favorite,
      'infobox': instance.infobox,
      'episodes': instance.episodes,
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
