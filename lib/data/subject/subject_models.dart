// lib/data/subject/subject_models.dart
import 'package:json_annotation/json_annotation.dart';

import '../search/search_models.dart' show SubjectTag;
import 'collection_type.dart';
import 'subject_episode_models.dart';

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

/// Aggregate collection counters for a subject, from `SubjectDetail`'s
/// `favorite` object. Live-verified shape (subject 302286):
/// `{"wish":2138,"done":7420,"doing":1102,"onHold":360,"dropped":177}`.
///
/// Note the backend uses camelCase `onHold` (not Bangumi's official
/// snake_case `on_hold`) and `done` (not Bangumi's `collect`). Every
/// counter defaults to 0 so a partial object still parses -- the UI
/// only shows `done`/`doing`/`wish`.
///
/// Collapsing "counter absent" into "counter is 0" here is deliberate,
/// and the opposite of what [SubjectDetail.episodes] and
/// [SubjectDetail.scoreDetails] do: those keep null distinct from
/// zero/empty because the UI must omit a line it has no data for,
/// whereas for a display counter an unreported count and a count of zero
/// mean the same thing to the reader.
@JsonSerializable()
class SubjectFavorite {
  const SubjectFavorite({
    required this.wish,
    required this.done,
    required this.doing,
    required this.onHold,
    required this.dropped,
  });

  @JsonKey(defaultValue: 0)
  final int wish;
  @JsonKey(defaultValue: 0)
  final int done;
  @JsonKey(defaultValue: 0)
  final int doing;
  @JsonKey(defaultValue: 0)
  final int onHold;
  @JsonKey(defaultValue: 0)
  final int dropped;

  factory SubjectFavorite.fromJson(Map<String, dynamic> json) =>
      _$SubjectFavoriteFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectFavoriteToJson(this);
}

/// One value of an infobox field. Bangumi's infobox format allows an
/// optional sub-key (`k`), so it is modeled as nullable -- but every
/// value observed on this backend so far carries only `v`. Do not assume
/// `k` is ever populated in production until it is seen live.
///
/// [v] defaults to `''` rather than being a hard requirement: a single
/// malformed value object would otherwise throw out of
/// `SubjectDetail.fromJson` and blank the entire subject page over one
/// unrenderable infobox row (the same class of crash that earned
/// [MyCollectionSubject] its hand-written factory).
@JsonSerializable()
class InfoboxValue {
  const InfoboxValue({this.k, required this.v});

  final String? k;
  @JsonKey(defaultValue: '')
  final String v;

  factory InfoboxValue.fromJson(Map<String, dynamic> json) =>
      _$InfoboxValueFromJson(json);

  Map<String, dynamic> toJson() => _$InfoboxValueToJson(this);
}

/// One infobox row: a Chinese label (`key`) plus one or more values.
@JsonSerializable()
class InfoboxField {
  const InfoboxField({required this.key, this.values = const []});

  final String key;
  @JsonKey(defaultValue: <InfoboxValue>[])
  final List<InfoboxValue> values;

  factory InfoboxField.fromJson(Map<String, dynamic> json) =>
      _$InfoboxFieldFromJson(json);

  Map<String, dynamic> toJson() => _$InfoboxFieldToJson(this);
}

/// The `infobox` object on `GET /v2/subjects/{id}`. This is the ONLY
/// source of human-readable Chinese staff role names -- the
/// `/v2/subjects/{id}/staff` endpoint returns integer `position` codes
/// (52 distinct codes observed on a single subject) with no label, and
/// we deliberately do not maintain a code->label mapping table.
@JsonSerializable()
class SubjectInfobox {
  const SubjectInfobox({this.template, this.fields = const []});

  final String? template;
  @JsonKey(defaultValue: <InfoboxField>[])
  final List<InfoboxField> fields;

  factory SubjectInfobox.fromJson(Map<String, dynamic> json) =>
      _$SubjectInfoboxFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectInfoboxToJson(this);
}

/// Infobox keys that are subject metadata, not staff credits. Used by
/// [SubjectDetail.staffFields].
///
/// This is a BLOCKLIST, not an allowlist, on purpose: staff role keys
/// are free text and 40+ distinct ones have been observed across
/// subjects. An allowlist would silently drop any role we hadn't seen
/// yet, which is worse than occasionally showing one metadata row we
/// forgot to exclude.
const subjectInfoboxNonStaffKeys = <String>{
  '中文名',
  '别名',
  '话数',
  '放送开始',
  '放送星期',
  '放送结束',
  '官方网站',
  '在线播放平台',
  '播放电视台',
  '其他电视台',
  '链接',
  '其他',
  'Copyright',
};

/// Response of `GET /v2/subjects/{subjectId}` -- verified against the
/// real `AniSubjectCollection` model. This is a deliberately lean subset
/// -- json_serializable's generated `fromJson` ignores undeclared keys,
/// so omitting fields is safe.
///
/// The real wire shape also has `type`/`nsfw`/`metaTags`/`relations`/
/// `platform`/`airingInfo`/`updatedAt`, none of which the UI needs.
/// `favorite` and `infobox` ARE parsed (see the fields below).
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
    this.aliases = const [],
    this.scoreDetails,
    this.favorite,
    this.infobox,
    this.episodes,
  });

  final int id;
  final String name;
  final String nameCn;
  final String summary;
  final String airDate;
  final List<SubjectTag> tags;

  /// Alternate titles for this subject (e.g. original Japanese title,
  /// English title). Parsed from the `aliases` field already present in
  /// the raw `api.animeko.org` `/v2/subjects/{id}` response but not
  /// previously modeled here. Defaults to an empty list when the key is
  /// absent, so existing test fixtures/responses without this key still
  /// parse cleanly.
  @JsonKey(defaultValue: <String>[])
  final List<String> aliases;

  /// Official rating, string-encoded float (e.g. `"8.4"`) or null if the
  /// subject has too few ratings.
  final String? score;
  final int? rank;

  /// The current user's own collection status. Null means "not in the
  /// user's collection at all" (distinct from any of the 5 real states).
  @JsonKey(
    fromJson: collectionTypeFromWireNullable,
    toJson: collectionTypeToWireNullable,
  )
  final CollectionType? collectionType;

  final SelfRating selfRating;

  /// Per-score-bucket vote counts (score "1" through "10" as string keys,
  /// vote count as int values), e.g. `{"1": 130, "2": 37, ..., "10": 7445}`.
  /// Parsed from the `scoreDetails` field already present in the raw
  /// `api.animeko.org` `/v2/subjects/{id}` response but not previously
  /// modeled here. Verified live to match Bangumi's own official
  /// `GET /v0/subjects/{id}` response's `rating.count` field almost
  /// exactly (negligible caching/sync lag between the two backends).
  /// Null when the response omits this key (or for older cached
  /// responses that predate this field being added).
  final Map<String, int>? scoreDetails;

  /// Aggregate collection counters. Nullable because the field is absent
  /// on some responses; the 收藏统计 block hides itself when null.
  final SubjectFavorite? favorite;

  /// The raw infobox. Nullable; [infoboxValue] returns null and
  /// [staffFields] returns empty when absent.
  ///
  /// Note that a field whose only value degraded to [InfoboxValue.v] ==
  /// `''` still counts as having values, so it survives [staffFields]
  /// and [infoboxValue] returns `''` for it -- absent and blank are not
  /// collapsed here.
  final SubjectInfobox? infobox;

  /// Every episode of this subject, of every type (`MAIN`/`SPECIAL`/`OP`/
  /// `ED`), exactly as embedded in this same `/v2/subjects/{id}` response.
  ///
  /// This array is the app's *only* source of episode data. It used to be
  /// parsed purely to derive [episodeCount] while the episode grid itself
  /// called Bangumi's own `https://api.bgm.tv/v0/episodes`; that endpoint is
  /// DNS-poisoned and SNI-blocked from mainland networks, so the grid was
  /// the one part of this screen that could not load without a proxy. Using
  /// the embedded array instead makes it work proxy-free, and incidentally
  /// removes the old `limit=100` truncation.
  ///
  /// Null when the response omits the `episodes` key (or for older cached
  /// responses that predate this field) -- deliberately distinct from an
  /// empty list, which means "this subject genuinely has no episodes". See
  /// [episodeCount].
  final List<SubjectEpisode>? episodes;

  /// Count of "main" episodes (`type == "MAIN"`) in [episodes], for the
  /// "作品信息" block's 话数 line.
  ///
  /// Null propagates from [episodes] being null so the UI can omit the line
  /// entirely rather than asserting a wrong 话数：0.
  int? get episodeCount => episodes?.where((episode) => episode.isMain).length;

  /// First value of the infobox field named [key], or null when the
  /// field is absent, the whole infobox is absent, or the field is
  /// present with no values. Used for the pre-formatted Chinese
  /// `放送开始` / `话数` / `别名` rows in 作品信息.
  ///
  /// Duplicate keys are realistic on a wiki-sourced infobox: the first
  /// match that actually has a value wins, so an empty duplicate is
  /// skipped rather than shadowing a later populated one.
  String? infoboxValue(String key) {
    final fields = infobox?.fields;
    if (fields == null) return null;
    for (final field in fields) {
      if (field.key == key && field.values.isNotEmpty) {
        return field.values.first.v;
      }
    }
    return null;
  }

  /// Infobox fields that represent staff credits -- everything except
  /// [subjectInfoboxNonStaffKeys]. Drives the 制作人员 card.
  ///
  /// Fields with an empty `values` list are excluded, matching
  /// [infoboxValue]'s treatment of the same shape, so a renderer can
  /// join `field.values` unguarded. A value whose `v` degraded to `''`
  /// is NOT excluded (see [infobox]) -- that path is a malformed payload
  /// we chose to render blank rather than reject.
  List<InfoboxField> get staffFields {
    final fields = infobox?.fields;
    if (fields == null) return const [];
    return fields
        .where((field) => field.values.isNotEmpty)
        .where((field) => !subjectInfoboxNonStaffKeys.contains(field.key))
        .toList();
  }

  factory SubjectDetail.fromJson(Map<String, dynamic> json) =>
      _$SubjectDetailFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectDetailToJson(this);
}

/// A person (voice actor, staff member, author). Live-verified against
/// the `actors` array inside a character
/// (`GET /v2/subjects/302286/characters?withActors=true`); the `person`
/// object on `/v2/subjects/{id}/staff` was observed to have this exact
/// field set too, though that endpoint was dropped in favour of
/// `infobox` (its `position` codes are unmappable).
@JsonSerializable()
class PersonInfo {
  const PersonInfo({
    required this.id,
    required this.name,
    this.nameCn,
    this.type,
    this.imageMedium,
    this.imageLarge,
    this.summary,
  });

  final int id;
  final String name;
  final String? nameCn;

  /// Opaque server-side person-category code. The only value observed on
  /// the wire is `1` (every voice actor in the probed payload); there is
  /// no code->label mapping available and none is planned, so nothing
  /// renders this.
  final int? type;
  final String? imageMedium;
  final String? imageLarge;
  final String? summary;

  /// Chinese name when it is present and non-empty, else the original.
  String get displayName =>
      (nameCn != null && nameCn!.isNotEmpty) ? nameCn! : name;

  factory PersonInfo.fromJson(Map<String, dynamic> json) =>
      _$PersonInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PersonInfoToJson(this);
}

/// A single character plus its voice actors.
///
/// Live-verified against `GET /v2/subjects/{id}/characters?withActors=true`
/// (subject 302286). NOTE: an earlier version of this model declared an
/// `imageUrl` field that does not exist on the wire -- the real keys are
/// `imageMedium` / `imageLarge`. `actors` was also being silently
/// dropped even though the request always sends `withActors=true`.
@JsonSerializable()
class CharacterInfo {
  const CharacterInfo({
    required this.id,
    required this.name,
    this.nameCn,
    this.imageMedium,
    this.imageLarge,
    this.actors = const [],
  });

  final int id;
  final String name;
  final String? nameCn;
  final String? imageMedium;
  final String? imageLarge;
  @JsonKey(defaultValue: <PersonInfo>[])
  final List<PersonInfo> actors;

  /// Chinese name when it is present and non-empty, else the original.
  String get displayName =>
      (nameCn != null && nameCn!.isNotEmpty) ? nameCn! : name;

  /// The character's primary voice actor, or null when unknown. The UI
  /// hides the CV line entirely when this is null.
  PersonInfo? get primaryActor => actors.isEmpty ? null : actors.first;

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

/// One item of `GET /v2/subjects/list` (the "My Collection" library
/// page). A deliberately lean subset of `AniSubjectCollection` for list
/// display -- notably, `AniSubjectCollection` has no image field of its
/// own, so this list has no cover image either (the UI leaves a plain
/// empty-space placeholder with no grey fill, unlike the
/// `Colors.grey.shade300`-filled `Container` convention used elsewhere,
/// e.g. `home_screen.dart`).
@JsonSerializable(createFactory: false)
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

  @JsonKey(
    fromJson: collectionTypeFromWireNullable,
    toJson: collectionTypeToWireNullable,
  )
  final CollectionType? collectionType;

  /// Hand-written (not `json_serializable`-generated) because the real
  /// per-item id key was CONFIRMED via live testing (2026-09-02) to be
  /// unreliable: this plan originally guessed `subjectId`, but that key
  /// is entirely absent from at least some real responses, crashing
  /// with "type 'Null' is not a subtype of type 'num'". `AniSubjectCollection`
  /// itself (the full model behind `GET /v2/subjects/{id}`) uses `id`
  /// for the same underlying value, so this reads either key
  /// defensively rather than guessing a single one again.
  factory MyCollectionSubject.fromJson(Map<String, dynamic> json) =>
      MyCollectionSubject(
        subjectId: ((json['subjectId'] ?? json['id']) as num).toInt(),
        name: json['name'] as String,
        nameCn: json['nameCn'] as String,
        collectionType: collectionTypeFromWireNullable(
          json['collectionType'] as String?,
        ),
      );

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
