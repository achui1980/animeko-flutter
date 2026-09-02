# Plan 1b-3: Subject Detail (Info, Cast/Staff, Collection & Rating) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing minimal `SubjectDetailScreen` (cover image + merged episode list only) with real Bangumi/Ani server subject data — summary, tags, official score/rank, cast (characters + voice actors) and staff avatar rows, collection-status management (5 states + remove), self-rating (1-10 + comment + privacy toggle) — and add a new "我的收藏" (My Collection) library screen filterable by the 5 collection states.

**Architecture:** New `lib/data/subject/` (models + `SubjectApi`, calling the real `https://api.animeko.org` server directly via the existing `dioProvider`, no local caching this round) and `lib/domain/subject/` (three `@riverpod` controllers: detail fetch, collection/rating mutations with optimistic-update+rollback, and paginated my-collections list) layers, following the exact conventions already established elsewhere in this codebase (json_serializable models, bare `@riverpod class` controllers with family params, direct `dio` calls, no repository/cache layer). The existing `SubjectDetailScreen` is *extended* (not rewritten) to add the new sections above the untouched merged-episode-list; a new `MyCollectionScreen` and `/collection` route are added, entered via a bookmark icon next to the existing Settings gear icon on each tab.

**Tech Stack:** Riverpod 3.3.1 (`@riverpod` codegen), `json_annotation`/`json_serializable`, `dio` (via the existing `dioProvider`, which already carries the Plan-1b-1 `AuthInterceptor`), `go_router` 17.5.0, `mocktail` for tests.

**Global constraints (apply to every task):**
- Flutter SDK is not on default `PATH`. Before any `flutter`/`dart` command: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:/Users/portz/soft/dart-sdk/flutter/bin/cache/dart-sdk/bin:$PATH"`.
- Baseline before Task 1: `flutter test` = 192 passing, 0 failing. `flutter analyze` = 16 issues across exactly 3 categories (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`). Every task must end with these same 3 categories — new *instances* of an existing category are fine (e.g. a new test file importing `riverpod` directly adds one more `depend_on_referenced_packages` hit, matching 10+ other test files already doing this), but a *new category* is a task failure that must be fixed before committing.
- `flutter pub get` / `dart run build_runner build --delete-conflicting-outputs` sometimes touches unrelated files as a side effect: `macos/Flutter/GeneratedPluginRegistrant.swift`, `macos/Podfile.lock`, `pubspec.lock` (transitive version churn), or other `.g.dart` files whose *source* wasn't touched by this task (their generator content-hash constant can shift for unrelated reasons). Before committing, run `git status` and `git checkout --` any such file that isn't part of *this* task's actual change.
- No local Drift/cache layer this round. The pre-existing `Subjects`/`Episodes`/`SubjectCollections`/`SearchHistory` Drift tables (built in Plan 1b-1, anticipating this exact feature) remain unused — do not wire them up. This is explicitly deferred to Plan 1b-4 (cloud sync).
- No widget tests for any UI task (Tasks 10-11) — this repo has zero widget tests anywhere (`HomeScreen`/`SearchScreen`/`ScheduleScreen`/`SubjectDetailScreen`/`PlayerScreen`/`SettingsScreen` all have none), and the user explicitly confirmed staying consistent with that during this plan's design phase. Core logic is covered by the controller-level unit tests in Tasks 7-9 instead.
- Two known open items, inherited from the design doc (`docs/superpowers/specs/2026-09-02-plan1b-3-subject-detail-design.md`) and NOT resolved by this plan: (1) the real `StaffMember` wire shape was never confirmed against a live API probe or the Kotlin model file — Task 5 uses a best-guess shape (`name`/`imageUrl`/`role`) with an explicit doc-comment flag; (2) `CharacterInfo`'s `imageUrl`-equivalent field name was inferred, not confirmed against the real `AniCharacter` Kotlin model — Task 5 flags this the same way. Both are honest, pre-existing assumptions to be verified against the live server manually after this plan ships (see Definition of Done) — do not "discover" and silently fix them differently mid-plan; if a task's own research turns up the real shape, note it in that task's commit message and keep going.

---
### Task 1: `CollectionType` enum + wire-value mapping

**Files:**
- Create: `lib/data/subject/collection_type.dart`
- Test: `test/data/subject/collection_type_test.dart`

The real Bangumi/Ani server's `AniCollectionType` wire values are `SCREAMING_SNAKE_CASE` (verified against the Kotlin-generated client code), not json_serializable's default camelCase mapping, so a hand-written converter is needed — this follows the exact same pattern already used for `SearchSortBy` in `lib/data/search/search_sort_by.dart` (extension `wireValue` getter + explicit mapping, no `@JsonSerializable` on the enum itself).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/subject/collection_type_test.dart
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionType wire mapping', () {
    test('wireValue maps every enum value to its SCREAMING_SNAKE_CASE wire string', () {
      expect(CollectionType.wish.wireValue, 'WISH');
      expect(CollectionType.doing.wireValue, 'DOING');
      expect(CollectionType.done.wireValue, 'DONE');
      expect(CollectionType.onHold.wireValue, 'ON_HOLD');
      expect(CollectionType.dropped.wireValue, 'DROPPED');
    });

    test('collectionTypeFromWire parses every valid wire value', () {
      expect(collectionTypeFromWire('WISH'), CollectionType.wish);
      expect(collectionTypeFromWire('DOING'), CollectionType.doing);
      expect(collectionTypeFromWire('DONE'), CollectionType.done);
      expect(collectionTypeFromWire('ON_HOLD'), CollectionType.onHold);
      expect(collectionTypeFromWire('DROPPED'), CollectionType.dropped);
    });

    test('collectionTypeFromWire throws FormatException for an unknown value', () {
      expect(() => collectionTypeFromWire('BOGUS'), throwsFormatException);
    });

    test('collectionTypeFromWireNullable returns null for null input', () {
      expect(collectionTypeFromWireNullable(null), isNull);
    });

    test('collectionTypeFromWireNullable parses a non-null value', () {
      expect(collectionTypeFromWireNullable('DOING'), CollectionType.doing);
    });

    test('collectionTypeToWireNullable returns null for null input', () {
      expect(collectionTypeToWireNullable(null), isNull);
    });

    test('collectionTypeToWireNullable serializes a non-null value', () {
      expect(collectionTypeToWireNullable(CollectionType.dropped), 'DROPPED');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/collection_type_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/data/subject/collection_type.dart'` (or similar "file not found").

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/data/subject/collection_type.dart

/// A subject's collection status in the current user's library. Mirrors
/// the Kotlin-generated `AniCollectionType` enum's wire values exactly
/// (verified against the real client code) -- these are
/// SCREAMING_SNAKE_CASE, not json_serializable's default camelCase
/// mapping, so a custom converter is required wherever this type appears
/// on the wire (see [collectionTypeFromWireNullable]/
/// [collectionTypeToWireNullable]).
enum CollectionType { wish, doing, done, onHold, dropped }

extension CollectionTypeWireValue on CollectionType {
  String get wireValue => switch (this) {
    CollectionType.wish => 'WISH',
    CollectionType.doing => 'DOING',
    CollectionType.done => 'DONE',
    CollectionType.onHold => 'ON_HOLD',
    CollectionType.dropped => 'DROPPED',
  };
}

CollectionType collectionTypeFromWire(String wire) => switch (wire) {
  'WISH' => CollectionType.wish,
  'DOING' => CollectionType.doing,
  'DONE' => CollectionType.done,
  'ON_HOLD' => CollectionType.onHold,
  'DROPPED' => CollectionType.dropped,
  _ => throw FormatException('Unknown CollectionType wire value: $wire'),
};

/// json_serializable `@JsonKey(fromJson: ...)` converter for a *nullable*
/// [CollectionType] field (null means "not in the user's collection").
CollectionType? collectionTypeFromWireNullable(String? wire) =>
    wire == null ? null : collectionTypeFromWire(wire);

/// json_serializable `@JsonKey(toJson: ...)` converter for a *nullable*
/// [CollectionType] field.
String? collectionTypeToWireNullable(CollectionType? type) => type?.wireValue;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/subject/collection_type_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (199 tests — 192 baseline + 7 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 6: Commit**

```bash
git add lib/data/subject/collection_type.dart test/data/subject/collection_type_test.dart
git commit -m "feat: add CollectionType enum with SCREAMING_SNAKE_CASE wire mapping"
```

---
### Task 2: Subject detail models (`subject_models.dart`)

**Files:**
- Create: `lib/data/subject/subject_models.dart`
- Create (generated): `lib/data/subject/subject_models.g.dart`
- Test: `test/data/subject/subject_models_test.dart`

Field names are copied verbatim from the real Kotlin client models at `/Users/portz/js/animeko/client/src/commonMain/gen/me/him188/ani/client/apis/SubjectsAniApi.kt` and its related model files, confirmed during this plan's design phase. `SubjectTag` (`{name, count}`) already exists in `lib/data/search/search_models.dart` — reuse it rather than redefining a duplicate. `CharacterInfo.imageUrl` and every field on `StaffMember` are **unconfirmed best guesses** (see the plan's Global Constraints) — flagged with doc comments, not silently presented as verified.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/subject/subject_models_test.dart
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelfRating', () {
    test('parses a rated self-rating', () {
      final rating = SelfRating.fromJson({
        'score': 8,
        'tags': ['神作', '泪目'],
        'isPrivate': false,
        'comment': '很好看',
      });
      expect(rating.score, 8);
      expect(rating.tags, ['神作', '泪目']);
      expect(rating.isPrivate, false);
      expect(rating.comment, '很好看');
    });

    test('parses an unrated self-rating with score 0 and null comment', () {
      final rating = SelfRating.fromJson({
        'score': 0,
        'tags': <String>[],
        'isPrivate': false,
        'comment': null,
      });
      expect(rating.score, 0);
      expect(rating.comment, isNull);
    });

    test('round-trips through toJson', () {
      const rating = SelfRating(score: 7, tags: ['a'], isPrivate: true, comment: 'x');
      final json = rating.toJson();
      expect(SelfRating.fromJson(json).score, 7);
      expect(json['isPrivate'], true);
    });
  });

  group('SubjectDetail', () {
    Map<String, dynamic> baseJson({String? collectionType}) => {
      'id': 400602,
      'name': 'Sousou no Frieren',
      'nameCn': '葬送的芙莉莲',
      'summary': '勇者一行人击败魔王后……',
      'airDate': '2023-09-29',
      'tags': [
        {'name': '奇幻', 'count': 120},
        {'name': '冒险', 'count': 80},
      ],
      'score': '8.4',
      'rank': 12,
      'collectionType': collectionType,
      'selfRating': {
        'score': 0,
        'tags': <String>[],
        'isPrivate': false,
        'comment': null,
      },
    };

    test('parses a subject with no collection (null collectionType)', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.id, 400602);
      expect(detail.nameCn, '葬送的芙莉莲');
      expect(detail.tags, hasLength(2));
      expect(detail.tags.first.name, '奇幻');
      expect(detail.score, '8.4');
      expect(detail.rank, 12);
      expect(detail.collectionType, isNull);
      expect(detail.selfRating.score, 0);
    });

    test('parses a subject with a non-null collectionType', () {
      final detail = SubjectDetail.fromJson(baseJson(collectionType: 'DOING'));
      expect(detail.collectionType, CollectionType.doing);
    });

    test('parses a subject with null score and rank', () {
      final json = baseJson()..['score'] = null..['rank'] = null;
      final detail = SubjectDetail.fromJson(json);
      expect(detail.score, isNull);
      expect(detail.rank, isNull);
    });

    test('round-trips collectionType through toJson', () {
      final detail = SubjectDetail.fromJson(baseJson(collectionType: 'ON_HOLD'));
      expect(detail.toJson()['collectionType'], 'ON_HOLD');
    });
  });

  group('CharacterInfo / RelatedCharacter', () {
    test('parses a related character with a voice actor image', () {
      final related = RelatedCharacter.fromJson({
        'index': 0,
        'character': {'name': '芙莉莲', 'imageUrl': 'https://example.com/f.jpg'},
        'role': 1,
      });
      expect(related.index, 0);
      expect(related.character.name, '芙莉莲');
      expect(related.character.imageUrl, 'https://example.com/f.jpg');
      expect(related.role, 1);
    });

    test('parses a character with a null image', () {
      final related = RelatedCharacter.fromJson({
        'index': 1,
        'character': {'name': '费伦', 'imageUrl': null},
        'role': 2,
      });
      expect(related.character.imageUrl, isNull);
    });
  });

  group('StaffMember', () {
    test('parses a staff member with a role and image', () {
      final staff = StaffMember.fromJson({
        'name': '渡边步',
        'imageUrl': 'https://example.com/s.jpg',
        'role': '导演',
      });
      expect(staff.name, '渡边步');
      expect(staff.imageUrl, 'https://example.com/s.jpg');
      expect(staff.role, '导演');
    });

    test('parses a staff member with null role and image', () {
      final staff = StaffMember.fromJson({'name': '某人', 'imageUrl': null, 'role': null});
      expect(staff.imageUrl, isNull);
      expect(staff.role, isNull);
    });
  });

  group('MyCollectionSubject / PaginatedCollections', () {
    test('parses a collection-list item with a collectionType', () {
      final item = MyCollectionSubject.fromJson({
        'subjectId': 400602,
        'name': 'Sousou no Frieren',
        'nameCn': '葬送的芙莉莲',
        'collectionType': 'WISH',
      });
      expect(item.subjectId, 400602);
      expect(item.collectionType, CollectionType.wish);
    });

    test('parses a paginated response with items and total', () {
      final page = PaginatedCollections.fromJson({
        'items': [
          {'subjectId': 1, 'name': 'A', 'nameCn': 'A-cn', 'collectionType': 'DOING'},
          {'subjectId': 2, 'name': 'B', 'nameCn': 'B-cn', 'collectionType': null},
        ],
        'total': 2,
      });
      expect(page.items, hasLength(2));
      expect(page.total, 2);
      expect(page.items.last.collectionType, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/data/subject/subject_models.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
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
/// own, so this list has no cover image either (the UI shows a grey
/// placeholder, matching the existing `SubjectCard` convention).
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
/// NOTE: the exact wire shape (`items`+`total` vs. something else) is an
/// **unverified assumption** -- modeled after the sibling paginated Ani
/// endpoints that *do* have a `total` field (see the comment on
/// `SearchResponse` in `lib/data/search/search_models.dart`, which
/// notes search is the one endpoint *without* `total`). Adjust if the
/// live server disagrees.
@JsonSerializable()
class PaginatedCollections {
  const PaginatedCollections({required this.items, required this.total});

  final List<MyCollectionSubject> items;
  final int total;

  factory PaginatedCollections.fromJson(Map<String, dynamic> json) =>
      _$PaginatedCollectionsFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedCollectionsToJson(this);
}
```

- [ ] **Step 4: Generate the `.g.dart` file**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `[INFO] Succeeded after ...` with `lib/data/subject/subject_models.g.dart` created. Check `git status` afterward — revert any *other* file it touched (e.g. `macos/Flutter/GeneratedPluginRegistrant.swift`, unrelated `.g.dart` hash churn) via `git checkout --`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: PASS (13 tests)

- [ ] **Step 6: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (212 tests — 199 baseline + 13 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 7: Commit**

```bash
git add lib/data/subject/subject_models.dart lib/data/subject/subject_models.g.dart test/data/subject/subject_models_test.dart
git commit -m "feat: add subject detail models (SelfRating, SubjectDetail, cast/staff, my-collections page)"
```

---
### Task 3: `SubjectApi.getSubject` + provider

**Files:**
- Create: `lib/data/subject/subject_api.dart`
- Create (generated): `lib/data/subject/subject_api.g.dart`
- Test: `test/data/subject/subject_api_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/subject/subject_api_test.dart
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> jsonResponse(
  Map<String, dynamic> body, {
  String path = '/',
}) {
  return Response(
    data: body,
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
  );
}

void main() {
  late MockDio dio;
  late SubjectApi api;

  setUp(() {
    dio = MockDio();
    api = SubjectApi(dio);
  });

  group('getSubject', () {
    final detailJson = {
      'id': 400602,
      'name': 'Sousou no Frieren',
      'nameCn': '葬送的芙莉莲',
      'summary': '勇者一行人击败魔王后……',
      'airDate': '2023-09-29',
      'tags': [
        {'name': '奇幻', 'count': 120},
      ],
      'score': '8.4',
      'rank': 12,
      'collectionType': 'DOING',
      'selfRating': {'score': 0, 'tags': <String>[], 'isPrivate': false, 'comment': null},
    };

    test('GETs the exact subject-detail path', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse(detailJson));

      await api.getSubject(400602);

      verify(() => dio.get<Map<String, dynamic>>('/v2/subjects/400602')).called(1);
    });

    test('parses the response into a SubjectDetail', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse(detailJson));

      final detail = await api.getSubject(400602);

      expect(detail.id, 400602);
      expect(detail.nameCn, '葬送的芙莉莲');
      expect(detail.collectionType?.wireValue, 'DOING');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/data/subject/subject_api.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/data/subject/subject_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'subject_models.dart';

part 'subject_api.g.dart';

/// Direct calls against the real `https://api.animeko.org` server (via
/// the shared [dioProvider], which already carries the Plan-1b-1
/// `AuthInterceptor`). No local caching/Drift layer this round -- see
/// the plan's Global Constraints.
class SubjectApi {
  SubjectApi(this._dio);
  final Dio _dio;

  /// GET /v2/subjects/{subjectId} -- also returns the current user's own
  /// collectionType/selfRating if authenticated (null-valued if not
  /// collected/rated).
  Future<SubjectDetail> getSubject(int subjectId) async {
    final response = await _dio.get<Map<String, dynamic>>('/v2/subjects/$subjectId');
    return SubjectDetail.fromJson(response.data!);
  }
}

@riverpod
SubjectApi subjectApi(Ref ref) => SubjectApi(ref.watch(dioProvider));
```

- [ ] **Step 4: Generate the `.g.dart` file**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds, `lib/data/subject/subject_api.g.dart` created. Revert any unrelated file `build_runner` touches via `git checkout --`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (214 tests — 212 baseline + 2 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 7: Commit**

```bash
git add lib/data/subject/subject_api.dart lib/data/subject/subject_api.g.dart test/data/subject/subject_api_test.dart
git commit -m "feat: add SubjectApi.getSubject"
```

---
### Task 4: `SubjectApi.updateCollection` + `SubjectApi.deleteCollection`

**Files:**
- Modify: `lib/data/subject/subject_api.dart` (from Task 3)
- Test: `test/data/subject/subject_api_test.dart` (from Task 3)

Both `collectionType` and `selfRating` are updated through the *same* `PATCH` endpoint (verified against the real `AniUpdateSubjectCollectionRequest{collectionType?, selfRating?}` model) -- either or both may be sent in one call. No dedicated request-model class is needed; the body is built as a plain `Map` directly, matching the existing precedent of `ScheduleApi`/`SearchApi` passing plain maps for query params.

- [ ] **Step 1: Add the failing tests**

Add to `test/data/subject/subject_api_test.dart`, inside `void main() { ... }`, after the `getSubject` group:

```dart
  group('updateCollection', () {
    test('PATCHes only collectionType when selfRating is omitted', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      await api.updateCollection(400602, collectionType: CollectionType.doing);

      verify(() => dio.patch<void>(
            '/v2/subjects/400602',
            data: {'collectionType': 'DOING'},
          )).called(1);
    });

    test('PATCHes only selfRating when collectionType is omitted', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      const rating = SelfRating(score: 8, tags: [], isPrivate: false, comment: '好看');

      await api.updateCollection(400602, selfRating: rating);

      verify(() => dio.patch<void>(
            '/v2/subjects/400602',
            data: {'selfRating': rating.toJson()},
          )).called(1);
    });

    test('PATCHes both fields together when both are given', () async {
      when(() => dio.patch<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      const rating = SelfRating(score: 9, tags: [], isPrivate: true, comment: null);

      await api.updateCollection(400602, collectionType: CollectionType.done, selfRating: rating);

      verify(() => dio.patch<void>(
            '/v2/subjects/400602',
            data: {'collectionType': 'DONE', 'selfRating': rating.toJson()},
          )).called(1);
    });
  });

  group('deleteCollection', () {
    test('DELETEs the exact subject path', () async {
      when(() => dio.delete<void>(any()))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/'), statusCode: 200));

      await api.deleteCollection(400602);

      verify(() => dio.delete<void>('/v2/subjects/400602')).called(1);
    });
  });
```

Also add these two imports at the top of `test/data/subject/subject_api_test.dart`:

```dart
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: FAIL — `The method 'updateCollection' isn't defined for the type 'SubjectApi'` (and similarly for `deleteCollection`).

- [ ] **Step 3: Add the implementation**

In `lib/data/subject/subject_api.dart`, add two imports and two methods to the `SubjectApi` class (after `getSubject`):

```dart
import 'collection_type.dart';
```

```dart
  /// PATCH /v2/subjects/{subjectId} -- edits (or creates) the current
  /// user's collection status and/or self-rating in one call. Passing
  /// only one of the two named params sends only that field.
  Future<void> updateCollection(
    int subjectId, {
    CollectionType? collectionType,
    SelfRating? selfRating,
  }) async {
    final body = <String, dynamic>{
      if (collectionType != null) 'collectionType': collectionType.wireValue,
      if (selfRating != null) 'selfRating': selfRating.toJson(),
    };
    await _dio.patch<void>('/v2/subjects/$subjectId', data: body);
  }

  /// DELETE /v2/subjects/{subjectId} -- removes the subject from the
  /// current user's collection entirely (this also discards any
  /// self-rating -- there is no partial-removal endpoint).
  Future<void> deleteCollection(int subjectId) async {
    await _dio.delete<void>('/v2/subjects/$subjectId');
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: PASS (6 tests — 2 from Task 3 + 4 new)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (218 tests — 214 baseline + 4 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 6: Commit**

```bash
git add lib/data/subject/subject_api.dart test/data/subject/subject_api_test.dart
git commit -m "feat: add SubjectApi.updateCollection and deleteCollection"
```

---
### Task 5: `SubjectApi.getCharacters` + `SubjectApi.getStaff`

**Files:**
- Modify: `lib/data/subject/subject_api.dart` (from Task 3/4)
- Test: `test/data/subject/subject_api_test.dart` (from Task 3/4)

Per the plan's Global Constraints, `getStaff`'s response shape is an **unconfirmed best guess** (`StaffMember{name, imageUrl, role}` from Task 2) -- this task ships that guess with an explicit doc comment, it does not attempt to verify it live.

- [ ] **Step 1: Add the failing tests**

Add to `test/data/subject/subject_api_test.dart`, after the `deleteCollection` group:

```dart
  group('getCharacters', () {
    test('GETs with withActors=true query param', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[]}));

      await api.getCharacters(400602);

      verify(() => dio.get<Map<String, dynamic>>(
            '/v2/subjects/400602/characters',
            queryParameters: {'withActors': true},
          )).called(1);
    });

    test('parses a list of related characters', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({
                'items': [
                  {'index': 0, 'character': {'name': '芙莉莲', 'imageUrl': 'https://example.com/f.jpg'}, 'role': 1},
                  {'index': 1, 'character': {'name': '费伦', 'imageUrl': null}, 'role': 2},
                ],
              }));

      final characters = await api.getCharacters(400602);

      expect(characters, hasLength(2));
      expect(characters.first.character.name, '芙莉莲');
      expect(characters.last.character.imageUrl, isNull);
    });

    test('returns an empty list when the response has no items', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[]}));

      expect(await api.getCharacters(400602), isEmpty);
    });
  });

  group('getStaff', () {
    test('GETs the exact staff path', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[]}));

      await api.getStaff(400602);

      verify(() => dio.get<Map<String, dynamic>>('/v2/subjects/400602/staff')).called(1);
    });

    test('parses a list of staff members', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => jsonResponse({
                'items': [
                  {'name': '渡边步', 'imageUrl': 'https://example.com/s.jpg', 'role': '导演'},
                ],
              }));

      final staff = await api.getStaff(400602);

      expect(staff, hasLength(1));
      expect(staff.single.name, '渡边步');
      expect(staff.single.role, '导演');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: FAIL — `The method 'getCharacters' isn't defined for the type 'SubjectApi'` (and similarly for `getStaff`).

- [ ] **Step 3: Add the implementation**

In `lib/data/subject/subject_api.dart`, add two more imports and two methods to the `SubjectApi` class (after `deleteCollection`):

```dart
import 'package:animeko_flutter/data/subject/subject_models.dart';
// (subject_models.dart is already imported from Task 2/3 -- no new import
// needed for CharacterInfo/RelatedCharacter/StaffMember, they live in the
// same file already imported.)
```

```dart
  /// GET /v2/subjects/{subjectId}/characters?withActors=true -- always
  /// requested with voice-actor info included (the UI's cast row shows
  /// both). Response wrapped in an `items` envelope, matching every
  /// other list endpoint in this codebase.
  Future<List<RelatedCharacter>> getCharacters(int subjectId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/$subjectId/characters',
      queryParameters: {'withActors': true},
    );
    final items = response.data!['items'] as List<dynamic>;
    return items
        .map((e) => RelatedCharacter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /v2/subjects/{subjectId}/staff.
  ///
  /// NOTE: `StaffMember`'s wire shape is an unconfirmed best guess (see
  /// the plan's Global Constraints and `StaffMember`'s own doc comment
  /// in `subject_models.dart`).
  Future<List<StaffMember>> getStaff(int subjectId) async {
    final response = await _dio.get<Map<String, dynamic>>('/v2/subjects/$subjectId/staff');
    final items = response.data!['items'] as List<dynamic>;
    return items
        .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: PASS (11 tests — 6 from Task 3/4 + 5 new)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (223 tests — 218 baseline + 5 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 6: Commit**

```bash
git add lib/data/subject/subject_api.dart test/data/subject/subject_api_test.dart
git commit -m "feat: add SubjectApi.getCharacters and getStaff"
```

---
### Task 6: `SubjectApi.getMyCollections` + `SubjectCard.fromMyCollectionSubject`

**Files:**
- Modify: `lib/data/subject/subject_api.dart` (from Task 3-5)
- Modify: `lib/domain/subject_card.dart`
- Test: `test/data/subject/subject_api_test.dart` (from Task 3-5)

`SubjectCard.fromMyCollectionSubject` follows the exact same one-factory-per-source pattern already used for `.fromTrending`/`.fromRecommendation`/`.fromSearchResult`/`.fromScheduledSubject` in `lib/domain/subject_card.dart` -- it is *not* unit-tested directly here (none of the other four factories are either; they're exercised through their owning controller's test, e.g. `schedule_controller_test.dart` asserts on the mapped `SubjectCard` fields). This factory is exercised the same way, by Task 9's `MyCollectionsController` test.

- [ ] **Step 1: Add the failing tests**

Add to `test/data/subject/subject_api_test.dart`, after the `getStaff` group:

```dart
  group('getMyCollections', () {
    test('GETs with type/offset/limit query params when type is given', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[], 'total': 0}));

      await api.getMyCollections(type: CollectionType.doing, offset: 20, limit: 20);

      verify(() => dio.get<Map<String, dynamic>>(
            '/v2/subjects/list',
            queryParameters: {'type': 'DOING', 'offset': 20, 'limit': 20},
          )).called(1);
    });

    test('omits the type query param when type is null', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({'items': <Map<String, dynamic>>[], 'total': 0}));

      await api.getMyCollections(offset: 0, limit: 20);

      verify(() => dio.get<Map<String, dynamic>>(
            '/v2/subjects/list',
            queryParameters: {'offset': 0, 'limit': 20},
          )).called(1);
    });

    test('parses a paginated response', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => jsonResponse({
                'items': [
                  {'subjectId': 1, 'name': 'A', 'nameCn': 'A-cn', 'collectionType': 'DOING'},
                ],
                'total': 1,
              }));

      final page = await api.getMyCollections(offset: 0, limit: 20);

      expect(page.items, hasLength(1));
      expect(page.total, 1);
      expect(page.items.single.nameCn, 'A-cn');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: FAIL — `The method 'getMyCollections' isn't defined for the type 'SubjectApi'`.

- [ ] **Step 3: Add the implementation**

In `lib/data/subject/subject_api.dart`, add one method to the `SubjectApi` class (after `getStaff`):

```dart
  /// GET /v2/subjects/list -- the "My Collection" library page, filtered
  /// by [type] (null = all 5 states, though the UI always passes a
  /// concrete type -- see `MyCollectionsController`). Pagination is
  /// offset-based (see `MyCollectionsController.loadMore`).
  Future<PaginatedCollections> getMyCollections({
    CollectionType? type,
    required int offset,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/list',
      queryParameters: {
        if (type != null) 'type': type.wireValue,
        'offset': offset,
        'limit': limit,
      },
    );
    return PaginatedCollections.fromJson(response.data!);
  }
```

In `lib/domain/subject_card.dart`, add an import and a fifth factory constructor (after `.fromScheduledSubject`):

```dart
import '../data/subject/subject_models.dart';
```

```dart
  factory SubjectCard.fromMyCollectionSubject(MyCollectionSubject s) =>
      SubjectCard(id: s.subjectId, name: s.name, nameCn: s.nameCn);
```

Also update the file's top doc comment to mention the fifth source, changing:

```dart
/// Unified internal representation of an anime "card" shown in Home,
/// Search, and Schedule lists. None of the four Ani API endpoint groups
```

to:

```dart
/// Unified internal representation of an anime "card" shown in Home,
/// Search, Schedule, and My-Collection lists. None of the five Ani API
/// endpoint groups
```

and the parenthetical `.fromScheduledSubject).` to `.fromScheduledSubject, .fromMyCollectionSubject).`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/subject/subject_api_test.dart`
Expected: PASS (14 tests — 11 from Task 3-5 + 3 new)

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (226 tests — 223 baseline + 3 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 6: Commit**

```bash
git add lib/data/subject/subject_api.dart lib/domain/subject_card.dart test/data/subject/subject_api_test.dart
git commit -m "feat: add SubjectApi.getMyCollections and SubjectCard.fromMyCollectionSubject"
```

---
### Task 7: `SubjectDetailController` + `SubjectCharacters` + `SubjectStaff`

**Files:**
- Create: `lib/domain/subject/subject_detail_controller.dart`
- Create (generated): `lib/domain/subject/subject_detail_controller.g.dart`
- Test: `test/domain/subject/subject_detail_controller_test.dart`

Three separate bare `@riverpod class` controllers (matching the codebase's exclusive convention for family providers, e.g. `SubjectEpisodesController`/`EpisodePlayController`) -- one for the main detail payload, and two small ones for cast/staff so either can fail independently without affecting the main detail or each other (the design doc's "per-source silent failure" pattern, mirroring how `SubjectEpisodesController` isolates each `MediaSource`'s failure). Uses the `retry: (retryCount, error) => null` `ProviderContainer` workaround (established in Plan 1c and reused throughout this codebase's controller tests) for the two tests that expect a bare `container.read(provider.future)` to propagate an exception under riverpod 3.x's default retry/autoDispose interaction.

- [ ] **Step 1: Write the failing tests**

```dart
// test/domain/subject/subject_detail_controller_test.dart
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/subject_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const _detail = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: [],
  selfRating: SelfRating(score: 0, tags: [], isPrivate: false),
);

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  group('SubjectDetailController', () {
    test('returns the detail from SubjectApi.getSubject', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);

      final result = await container.read(subjectDetailControllerProvider(subjectId: 1).future);

      expect(result.nameCn, 'A-cn');
    });

    test('propagates a getSubject failure', () async {
      when(() => api.getSubject(1)).thenThrow(Exception('network error'));

      await expectLater(
        container.read(subjectDetailControllerProvider(subjectId: 1).future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SubjectCharacters', () {
    test('returns the list from SubjectApi.getCharacters', () async {
      const character = RelatedCharacter(index: 0, character: CharacterInfo(name: 'X'), role: 1);
      when(() => api.getCharacters(1)).thenAnswer((_) async => [character]);

      final result = await container.read(subjectCharactersProvider(subjectId: 1).future);

      expect(result.single.character.name, 'X');
    });

    test('propagates a getCharacters failure independently', () async {
      when(() => api.getCharacters(1)).thenThrow(Exception('cast unavailable'));

      await expectLater(
        container.read(subjectCharactersProvider(subjectId: 1).future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SubjectStaff', () {
    test('returns the list from SubjectApi.getStaff', () async {
      const staff = StaffMember(name: 'Y');
      when(() => api.getStaff(1)).thenAnswer((_) async => [staff]);

      final result = await container.read(subjectStaffProvider(subjectId: 1).future);

      expect(result.single.name, 'Y');
    });

    test('propagates a getStaff failure independently', () async {
      when(() => api.getStaff(1)).thenThrow(Exception('staff unavailable'));

      await expectLater(
        container.read(subjectStaffProvider(subjectId: 1).future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/subject/subject_detail_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/domain/subject/subject_detail_controller.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/subject/subject_detail_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_models.dart';

part 'subject_detail_controller.g.dart';

/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating). Cast ([SubjectCharacters]) and staff
/// ([SubjectStaff]) are fetched via separate providers so either can
/// fail independently without affecting this one or each other -- see
/// the design doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).
@riverpod
class SubjectDetailController extends _$SubjectDetailController {
  @override
  Future<SubjectDetail> build({required int subjectId}) {
    return ref.watch(subjectApiProvider).getSubject(subjectId);
  }
}

/// Cast (characters + voice actors, per `SubjectApi.getCharacters`
/// always requesting `withActors=true`). `SubjectDetailScreen` hides
/// this whole section on error rather than showing a retry button.
@riverpod
class SubjectCharacters extends _$SubjectCharacters {
  @override
  Future<List<RelatedCharacter>> build({required int subjectId}) {
    return ref.watch(subjectApiProvider).getCharacters(subjectId);
  }
}

/// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].
@riverpod
class SubjectStaff extends _$SubjectStaff {
  @override
  Future<List<StaffMember>> build({required int subjectId}) {
    return ref.watch(subjectApiProvider).getStaff(subjectId);
  }
}
```

- [ ] **Step 4: Generate the `.g.dart` file**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds, `lib/domain/subject/subject_detail_controller.g.dart` created. Revert any unrelated file `build_runner` touches via `git checkout --`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/domain/subject/subject_detail_controller_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 6: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (232 tests — 226 baseline + 6 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/subject/subject_detail_controller.dart lib/domain/subject/subject_detail_controller.g.dart test/domain/subject/subject_detail_controller_test.dart
git commit -m "feat: add SubjectDetailController, SubjectCharacters, SubjectStaff"
```

---
### Task 8: `SubjectCollectionController` (optimistic collection updates + non-optimistic rating)

**Files:**
- Create: `lib/domain/subject/subject_collection_controller.dart`
- Create (generated): `lib/domain/subject/subject_collection_controller.g.dart`
- Test: `test/domain/subject/subject_collection_controller_test.dart`

This is the highest-priority test target in the whole plan (design doc: "the optimistic-update+rollback logic is the highest-priority test target"). `setCollectionType`/`removeFromCollection` update local state *before* the network call resolves and roll back on failure (design doc "收藏状态切换"); `submitRating` deliberately does **not** update state until the network call succeeds (design doc "评分提交" -- rating has more content than a rollback UX handles well). Both mutation paths rethrow on failure so the caller (`SubjectDetailScreen`, Task 10) can show a one-off SnackBar.

- [ ] **Step 1: Write the failing tests**

```dart
// test/domain/subject/subject_collection_controller_test.dart
import 'dart:async';

import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/subject_collection_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const _unratedSelfRating = SelfRating(score: 0, tags: [], isPrivate: false);

const _detail = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 's',
  airDate: '2026-01-01',
  tags: [],
  selfRating: _unratedSelfRating,
);

const _detailCollected = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 's',
  airDate: '2026-01-01',
  tags: [],
  collectionType: CollectionType.doing,
  selfRating: _unratedSelfRating,
);

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  final provider = subjectCollectionControllerProvider(subjectId: 1);

  group('build', () {
    test('reads the initial collectionType/selfRating from SubjectDetailController', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detailCollected);

      final result = await container.read(provider.future);

      expect(result.collectionType, CollectionType.doing);
      expect(result.selfRating.score, 0);
    });
  });

  group('setCollectionType', () {
    test('optimistically updates state before the PATCH resolves', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      final completer = Completer<void>();
      when(() => api.updateCollection(1, collectionType: CollectionType.doing))
          .thenAnswer((_) => completer.future);

      final call = container.read(provider.notifier).setCollectionType(CollectionType.doing);
      // The optimistic `state = AsyncData(...)` assignment happens
      // synchronously before the `await api.updateCollection(...)` call --
      // give that a chance to run before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider).value!.collectionType, CollectionType.doing);

      completer.complete();
      await call;
    });

    test('rolls back to the previous state when the PATCH fails', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, collectionType: CollectionType.dropped))
          .thenThrow(Exception('network error'));

      await expectLater(
        container.read(provider.notifier).setCollectionType(CollectionType.dropped),
        throwsA(isA<Exception>()),
      );

      expect(container.read(provider).value!.collectionType, isNull);
    });
  });

  group('removeFromCollection', () {
    test('optimistically clears collectionType and calls deleteCollection', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detailCollected);
      await container.read(provider.future);

      when(() => api.deleteCollection(1)).thenAnswer((_) async {});

      await container.read(provider.notifier).removeFromCollection();

      expect(container.read(provider).value!.collectionType, isNull);
      verify(() => api.deleteCollection(1)).called(1);
    });

    test('rolls back to the previous collectionType when the DELETE fails', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detailCollected);
      await container.read(provider.future);

      when(() => api.deleteCollection(1)).thenThrow(Exception('network error'));

      await expectLater(
        container.read(provider.notifier).removeFromCollection(),
        throwsA(isA<Exception>()),
      );

      expect(container.read(provider).value!.collectionType, CollectionType.doing);
    });
  });

  group('submitRating', () {
    test('rejects a score outside 1-10 without calling the API', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      await expectLater(container.read(provider.notifier).submitRating(0), throwsArgumentError);
      await expectLater(container.read(provider.notifier).submitRating(11), throwsArgumentError);
      verifyNever(() => api.updateCollection(any(), selfRating: any(named: 'selfRating')));
    });

    test('updates state only after the PATCH succeeds', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, selfRating: any(named: 'selfRating')))
          .thenAnswer((_) async {});

      await container.read(provider.notifier).submitRating(8, comment: '好看');

      final result = container.read(provider).value!;
      expect(result.selfRating.score, 8);
      expect(result.selfRating.comment, '好看');
    });

    test('leaves state unchanged when the PATCH fails', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, selfRating: any(named: 'selfRating')))
          .thenThrow(Exception('network error'));

      await expectLater(
        container.read(provider.notifier).submitRating(8),
        throwsA(isA<Exception>()),
      );

      expect(container.read(provider).value!.selfRating.score, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/subject/subject_collection_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/domain/subject/subject_collection_controller.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/subject/subject_collection_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_models.dart';
import 'subject_detail_controller.dart';

part 'subject_collection_controller.g.dart';

/// The mutable slice of subject state this controller owns --
/// `collectionType`/`selfRating` only, read once from
/// [SubjectDetailController]'s already-fetched [SubjectDetail] (avoids a
/// duplicate `getSubject` request) and then mutated locally as the user
/// changes their collection status or rating.
class SubjectCollectionState {
  const SubjectCollectionState({required this.collectionType, required this.selfRating});

  final CollectionType? collectionType;
  final SelfRating selfRating;

  SubjectCollectionState copyWith({CollectionType? collectionType, SelfRating? selfRating}) =>
      SubjectCollectionState(
        collectionType: collectionType ?? this.collectionType,
        selfRating: selfRating ?? this.selfRating,
      );

  /// Distinct from [copyWith] -- passing `collectionType: null` there
  /// means "keep the current value" (a plain named param can't
  /// distinguish "omitted" from "explicitly null"), so clearing needs
  /// its own method.
  SubjectCollectionState clearCollectionType() =>
      SubjectCollectionState(collectionType: null, selfRating: selfRating);
}

@riverpod
class SubjectCollectionController extends _$SubjectCollectionController {
  @override
  Future<SubjectCollectionState> build({required int subjectId}) async {
    final detail = await ref.watch(subjectDetailControllerProvider(subjectId: subjectId).future);
    return SubjectCollectionState(collectionType: detail.collectionType, selfRating: detail.selfRating);
  }

  /// Optimistically updates [state] to [type] before the `PATCH`
  /// resolves, then rolls back to the pre-call state if it fails
  /// (design doc "收藏状态切换"). Rethrows on failure so the caller can
  /// show a one-off error -- see `SubjectDetailScreen` (Task 10).
  Future<void> setCollectionType(CollectionType type) async {
    final previous = state;
    final current = await future;
    state = AsyncData(current.copyWith(collectionType: type));
    try {
      await ref.read(subjectApiProvider).updateCollection(subjectId, collectionType: type);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Same optimistic-update-then-rollback treatment as
  /// [setCollectionType], but clears the collection status entirely via
  /// `DELETE`.
  Future<void> removeFromCollection() async {
    final previous = state;
    final current = await future;
    state = AsyncData(current.clearCollectionType());
    try {
      await ref.read(subjectApiProvider).deleteCollection(subjectId);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// NOT optimistic (design doc "评分提交") -- local state is only
  /// updated after the `PATCH` succeeds; on failure the caller keeps the
  /// user's input in the still-open rating form for retry rather than
  /// this controller attempting a rollback.
  Future<void> submitRating(int score, {String? comment, bool isPrivate = false}) async {
    if (score < 1 || score > 10) {
      throw ArgumentError.value(score, 'score', 'must be between 1 and 10');
    }
    final rating = SelfRating(score: score, tags: const [], isPrivate: isPrivate, comment: comment);
    await ref.read(subjectApiProvider).updateCollection(subjectId, selfRating: rating);
    final current = await future;
    state = AsyncData(current.copyWith(selfRating: rating));
  }
}
```

- [ ] **Step 4: Generate the `.g.dart` file**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds, `lib/domain/subject/subject_collection_controller.g.dart` created. Revert any unrelated file `build_runner` touches via `git checkout --`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/domain/subject/subject_collection_controller_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 6: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (241 tests — 232 baseline + 9 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/subject/subject_collection_controller.dart lib/domain/subject/subject_collection_controller.g.dart test/domain/subject/subject_collection_controller_test.dart
git commit -m "feat: add SubjectCollectionController with optimistic update/rollback"
```

---
### Task 9: `MyCollectionsController` (paginated "My Collection" list)

**Files:**
- Create: `lib/domain/subject/my_collections_controller.dart`
- Create (generated): `lib/domain/subject/my_collections_controller.g.dart`
- Test: `test/domain/subject/my_collections_controller_test.dart`

Pagination is "load more on scroll-to-bottom" only (design doc: no pull-to-refresh, YAGNI). `loadMore` uses the current list's length as the next `offset`, matching `SubjectApi.getMyCollections`'s offset-based signature from Task 6.

- [ ] **Step 1: Write the failing tests**

```dart
// test/domain/subject/my_collections_controller_test.dart
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/my_collections_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  group('build', () {
    test('fetches the first page for the given type at offset 0', () async {
      when(() => api.getMyCollections(type: CollectionType.doing, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 1, name: 'A', nameCn: 'A-cn')],
          total: 1,
        ),
      );

      final result = await container.read(
        myCollectionsControllerProvider(type: CollectionType.doing).future,
      );

      expect(result, hasLength(1));
      expect(result.single.nameCn, 'A-cn');
    });

    test('fetches all types (type: null) at offset 0', () async {
      when(() => api.getMyCollections(type: null, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(items: [], total: 0),
      );

      final result = await container.read(myCollectionsControllerProvider(type: null).future);

      expect(result, isEmpty);
    });
  });

  group('loadMore', () {
    test('fetches the next page using the current length as offset and appends it', () async {
      when(() => api.getMyCollections(type: CollectionType.wish, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 1, name: 'A', nameCn: 'A-cn')],
          total: 2,
        ),
      );
      await container.read(myCollectionsControllerProvider(type: CollectionType.wish).future);

      when(() => api.getMyCollections(type: CollectionType.wish, offset: 1, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 2, name: 'B', nameCn: 'B-cn')],
          total: 2,
        ),
      );

      await container.read(myCollectionsControllerProvider(type: CollectionType.wish).notifier).loadMore();

      final result = container.read(myCollectionsControllerProvider(type: CollectionType.wish)).value!;
      expect(result, hasLength(2));
      expect(result.map((s) => s.subjectId), [1, 2]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/subject/my_collections_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/domain/subject/my_collections_controller.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/subject/my_collections_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_models.dart';

part 'my_collections_controller.g.dart';

const _pageSize = 20;

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.
@riverpod
class MyCollectionsController extends _$MyCollectionsController {
  @override
  Future<List<MyCollectionSubject>> build({required CollectionType? type}) async {
    final page = await ref
        .watch(subjectApiProvider)
        .getMyCollections(type: type, offset: 0, limit: _pageSize);
    return page.items;
  }

  /// Fetches the next page (offset = current list length) and appends
  /// it. No pull-to-refresh (design doc, YAGNI) -- leaving and
  /// re-entering the page re-runs [build] instead.
  Future<void> loadMore() async {
    final current = await future;
    final page = await ref
        .read(subjectApiProvider)
        .getMyCollections(type: type, offset: current.length, limit: _pageSize);
    state = AsyncData([...current, ...page.items]);
  }
}
```

- [ ] **Step 4: Generate the `.g.dart` file**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds, `lib/domain/subject/my_collections_controller.g.dart` created. Revert any unrelated file `build_runner` touches via `git checkout --`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/domain/subject/my_collections_controller_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (244 tests — 241 baseline + 3 new)

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/subject/my_collections_controller.dart lib/domain/subject/my_collections_controller.g.dart test/domain/subject/my_collections_controller_test.dart
git commit -m "feat: add MyCollectionsController with offset-based pagination"
```

---
### Task 10: Extend `SubjectDetailScreen` with real detail data, cast/staff, collection buttons, and rating

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart` (full replacement, in-place -- no test, per Global Constraints)

The existing cover-image block and the episode-list `ListTile` (title/source-badge `Chip`/`onTap`) are preserved byte-identical -- the only *structural* change to the episode section is that its container changes from an independent `ListView.builder` inside its own `Expanded` to a flattened list of widgets inside one outer `ListView` (via `.map(...).toList()` instead of `itemBuilder`), which is required to host the new sections above it without nesting two unbounded vertical scrollables. `SubjectDetailScreen` itself stays a `ConsumerWidget` (no state of its own is needed); the rating-input form's local state lives in a small private `ConsumerStatefulWidget` (`_RatingSection`).

- [ ] **Step 1: Replace the entire file**

Replace the entire contents of `lib/ui/subject/subject_detail_screen.dart` with:

```dart
// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/subject/collection_type.dart';
import '../../domain/media/media_registry.dart';
import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/subject_collection_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../common/error_retry_view.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.imageUrl,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectEpisodesControllerProvider(
      subjectId: subjectId,
      subjectName: subjectName,
    );
    final episodes = ref.watch(provider);
    final sources = ref.watch(mediaSourcesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: ListView(
        children: [
          if (imageUrl != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(imageUrl!, fit: BoxFit.cover),
            ),
          _SubjectInfoSection(subjectId: subjectId),
          _CastStaffSection(subjectId: subjectId),
          const Divider(),
          ...episodes.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, stack) {
              if (error is MediaNotFoundException) {
                return const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('未找到该番剧的播放资源')),
                  ),
                ];
              }
              return [
                ErrorRetryView(
                  message: '加载失败：$error',
                  onRetry: () => ref.invalidate(provider),
                ),
              ];
            },
            data: (episodeList) => episodeList
                .map(
                  (episode) => ListTile(
                    title: Text(episode.title),
                    trailing: Chip(label: Text(_sourceLabel(sources, episode.sourceId))),
                    onTap: () => context.push(
                      '/subject/$subjectId/play',
                      extra: episode,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Summary/tags/score/rank + the collection-status buttons + the rating
/// input -- one section, since collection status and rating both read
/// from the same [SubjectCollectionController].
class _SubjectInfoSection extends ConsumerWidget {
  const _SubjectInfoSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectDetailControllerProvider(subjectId: subjectId);
    final detail = ref.watch(provider);

    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => ErrorRetryView(
        message: '加载详情失败：$error',
        onRetry: () => ref.invalidate(provider),
      ),
      data: (subject) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject.summary),
            const SizedBox(height: 8),
            if (subject.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: subject.tags
                    .map((tag) => Chip(label: Text('${tag.name} ${tag.count}')))
                    .toList(),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (subject.score != null) Text('评分：${subject.score}'),
                if (subject.rank != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('排名：#${subject.rank}'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _CollectionButtons(subjectId: subjectId),
            const SizedBox(height: 16),
            _RatingSection(subjectId: subjectId),
          ],
        ),
      ),
    );
  }
}

/// The 5 collection-status buttons + a "移除" (remove) button, shown
/// only when the subject is already collected. Tapping a button calls
/// [SubjectCollectionController]'s optimistic-update methods and shows a
/// one-off SnackBar on failure (the controller has already rolled back
/// its own state by the time the exception reaches here).
class _CollectionButtons extends ConsumerWidget {
  const _CollectionButtons({required this.subjectId});

  final int subjectId;

  static const _labels = {
    CollectionType.wish: '想看',
    CollectionType.doing: '在看',
    CollectionType.done: '看过',
    CollectionType.onHold: '搁置',
    CollectionType.dropped: '弃番',
  };

  Future<void> _setType(BuildContext context, WidgetRef ref, CollectionType type) async {
    try {
      await ref
          .read(subjectCollectionControllerProvider(subjectId: subjectId).notifier)
          .setCollectionType(type);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新收藏状态失败：$e')));
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(subjectCollectionControllerProvider(subjectId: subjectId).notifier)
          .removeFromCollection();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('取消收藏失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subjectCollectionControllerProvider(subjectId: subjectId));
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (collection) => Wrap(
        spacing: 8,
        children: [
          for (final type in CollectionType.values)
            ChoiceChip(
              label: Text(_labels[type]!),
              selected: collection.collectionType == type,
              onSelected: (_) => _setType(context, ref, type),
            ),
          if (collection.collectionType != null)
            ActionChip(label: const Text('移除'), onPressed: () => _remove(context, ref)),
        ],
      ),
    );
  }
}

/// The rating input -- collapsed to a single button/label showing the
/// current rating (if any) until tapped, then expands into a 1-10
/// slider + optional comment + privacy toggle + submit button. Local
/// UI state (expanded/score/comment/privacy) lives here, not in the
/// controller -- [SubjectCollectionController.submitRating] is
/// deliberately not optimistic (design doc "评分提交"), so on failure
/// this widget keeps the form open with the user's input intact.
class _RatingSection extends ConsumerStatefulWidget {
  const _RatingSection({required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends ConsumerState<_RatingSection> {
  bool _expanded = false;
  int _score = 5;
  bool _isPrivate = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      await ref
          .read(subjectCollectionControllerProvider(subjectId: widget.subjectId).notifier)
          .submitRating(
            _score,
            comment: _commentController.text.isEmpty ? null : _commentController.text,
            isPrivate: _isPrivate,
          );
      if (mounted) setState(() => _expanded = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评分已提交')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交评分失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subjectCollectionControllerProvider(subjectId: widget.subjectId));
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (collection) {
        if (!_expanded) {
          return TextButton(
            onPressed: () => setState(() {
              _score = collection.selfRating.score > 0 ? collection.selfRating.score : 5;
              _expanded = true;
            }),
            child: Text(
              collection.selfRating.score > 0 ? '我的评分：${collection.selfRating.score}' : '评分',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: _score.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_score',
              onChanged: (value) => setState(() => _score = value.round()),
            ),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(hintText: '评论（可选）'),
            ),
            SwitchListTile(
              title: const Text('仅自己可见'),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
            FilledButton(onPressed: _submit, child: const Text('提交')),
          ],
        );
      },
    );
  }
}

/// Two horizontal avatar rows (cast, then staff). Either row fails
/// silently (hides itself entirely) without affecting the other or
/// `_SubjectInfoSection` -- the design doc's "per-source silent
/// failure" pattern.
class _CastStaffSection extends ConsumerWidget {
  const _CastStaffSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(subjectCharactersProvider(subjectId: subjectId));
    final staff = ref.watch(subjectStaffProvider(subjectId: subjectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        characters.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : _AvatarRow(
                  title: '角色',
                  items: list.map((c) => (c.character.name, c.character.imageUrl)).toList(),
                ),
        ),
        staff.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : _AvatarRow(
                  title: '制作人员',
                  items: list.map((s) => (s.name, s.imageUrl)).toList(),
                ),
        ),
      ],
    );
  }
}

/// A titled horizontal-scroll row of circular avatars + names. No
/// tap-through to a person detail page (explicitly excluded, see the
/// design doc).
class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.title, required this.items});

  final String title;
  final List<(String, String?)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final (name, imageUrl) = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null ? const Icon(Icons.person) : null,
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Human-readable label for the merged-episode-list source badge
/// (Decision 6). Looks up the owning [MediaSource]'s [MediaSource.displayName]
/// so this stays in sync with the single source of truth instead of
/// re-deriving it from a hardcoded switch on `sourceId`. Falls back to the
/// raw `sourceId` for any `sourceId` with no matching registered source --
/// never crashes, just looks slightly less polished.
String _sourceLabel(List<MediaSource> sources, String sourceId) {
  for (final source in sources) {
    if (source.id == sourceId) return source.displayName;
  }
  return sourceId;
}
```

- [ ] **Step 2: Run the full suite and analyzer**

Run: `flutter test`
Expected: PASS (244 tests -- unchanged, this task adds no tests per the plan's Global Constraints).

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category. (Watch for `record` pattern-matching or unused-import lints specifically on this file -- fix inline if any appear, without changing behavior, before committing.)

- [ ] **Step 3: Manual sanity check (not a substitute for the tests above)**

Run: `flutter build macos --debug`
Expected: succeeds. This does not exercise the new UI live (no widget tests, no manual server round-trip in this task) -- it only confirms the file compiles under the full app, catching any typo the analyzer/test suite wouldn't (e.g. a missing import surfaced only at the `flutter build` link stage). Revert any macOS build-artifact drift (`macos/Podfile.lock`, `macos/Flutter/GeneratedPluginRegistrant.swift`) via `git checkout --` before committing.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/subject/subject_detail_screen.dart
git commit -m "feat: extend SubjectDetailScreen with summary/tags/score/rank/cast/staff/collection/rating"
```

---
### Task 11: `MyCollectionScreen` + `/collection` route + bookmark icons on Home/Search/Schedule

**Files:**
- Create: `lib/ui/collection/my_collection_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/ui/home/home_screen.dart`
- Modify: `lib/ui/search/search_screen.dart`
- Modify: `lib/ui/schedule/schedule_screen.dart`
- Modify: `lib/ui/subject/subject_navigation.dart` (trivial doc-comment fix, see Step 4)

No test, per the plan's Global Constraints. The `/collection` route is a top-level sibling route (like `/settings`), reachable from any tab, not nested in the bottom-nav shell -- mirroring exactly how Settings was wired in.

- [ ] **Step 1: Create the My Collection screen**

```dart
// lib/ui/collection/my_collection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_models.dart';
import '../../domain/subject/my_collections_controller.dart';
import '../../domain/subject_card.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';

class MyCollectionScreen extends ConsumerStatefulWidget {
  const MyCollectionScreen({super.key});

  @override
  ConsumerState<MyCollectionScreen> createState() => _MyCollectionScreenState();
}

const _collectionLabels = {
  CollectionType.wish: '想看',
  CollectionType.doing: '在看',
  CollectionType.done: '看过',
  CollectionType.onHold: '搁置',
  CollectionType.dropped: '弃番',
};

class _MyCollectionScreenState extends ConsumerState<MyCollectionScreen> {
  CollectionType _selected = CollectionType.doing;

  @override
  Widget build(BuildContext context) {
    final provider = myCollectionsControllerProvider(type: _selected);
    final items = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<CollectionType>(
              segments: CollectionType.values
                  .map((type) => ButtonSegment(value: type, label: Text(_collectionLabels[type]!)))
                  .toList(),
              selected: {_selected},
              onSelectionChanged: (selection) => setState(() => _selected = selection.first),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ErrorRetryView(
                message: '加载失败：$error',
                onRetry: () => ref.invalidate(provider),
              ),
              data: (subjects) => _CollectionList(type: _selected, subjects: subjects),
            ),
          ),
        ],
      ),
    );
  }
}

/// The list itself + a "load more on scroll to bottom" footer row
/// (design doc: no pull-to-refresh, YAGNI). A failed load-more shows a
/// small retry text button without disturbing the already-loaded items.
class _CollectionList extends ConsumerStatefulWidget {
  const _CollectionList({required this.type, required this.subjects});

  final CollectionType type;
  final List<MyCollectionSubject> subjects;

  @override
  ConsumerState<_CollectionList> createState() => _CollectionListState();
}

class _CollectionListState extends ConsumerState<_CollectionList> {
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      await ref.read(myCollectionsControllerProvider(type: widget.type).notifier).loadMore();
    } catch (_) {
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subjects.isEmpty) {
      return const Center(child: Text('还没有收藏任何番剧'));
    }
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (!_loadingMore && metrics.pixels >= metrics.maxScrollExtent - 40) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: widget.subjects.length + 1,
        itemBuilder: (context, index) {
          if (index == widget.subjects.length) {
            if (_loadMoreFailed) {
              return Center(
                child: TextButton(onPressed: _loadMore, child: const Text('加载失败，点击重试')),
              );
            }
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox.shrink();
          }
          final card = SubjectCard.fromMyCollectionSubject(widget.subjects[index]);
          return ListTile(
            leading: card.imageUrl != null
                ? Image.network(card.imageUrl!, width: 40, fit: BoxFit.cover)
                : const SizedBox(width: 40),
            title: Text(card.nameCn ?? card.name),
            onTap: () => openSubjectDetail(context, card),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the `/collection` route into the router**

In `lib/app/router.dart`, add an import (near the other `ui/` imports):

```dart
import '../ui/collection/my_collection_screen.dart';
```

Then add a new top-level `GoRoute`, placed right after the existing `/settings` route (still inside the `routes:` list, still before `StatefulShellRoute.indexedStack(...)`):

```dart
      GoRoute(path: '/collection', builder: (context, state) => const MyCollectionScreen()),
```

- [ ] **Step 3: Add the bookmark icon to Home, Search, and Schedule**

In `lib/ui/home/home_screen.dart`, `lib/ui/search/search_screen.dart`, and `lib/ui/schedule/schedule_screen.dart`, each `AppBar`'s `actions:` list currently has exactly one `IconButton` (the Settings gear). In each of the three files, change:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
```

to:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () => context.push('/collection'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
```

(All three files already import `package:go_router/go_router.dart` for `context.push`, so no new import is needed for this step.)

- [ ] **Step 4: Minor doc-comment consistency fix**

In `lib/ui/subject/subject_navigation.dart`, `openSubjectDetail`'s doc comment currently says "all four `SubjectCard.from*` factories" -- this is now stale since Task 6 added a fifth (`.fromMyCollectionSubject`). Change:

```dart
/// Pushes to the subject detail route for [card]. Does nothing if the
/// card has no [SubjectCard.id] -- all four `SubjectCard.from*` factories
/// set this from a required wire field, so in practice this should not
/// happen for cards rendered by Home/Search/Schedule; guarded defensively
/// so a malformed API response can't crash navigation.
```

to:

```dart
/// Pushes to the subject detail route for [card]. Does nothing if the
/// card has no [SubjectCard.id] -- all five `SubjectCard.from*` factories
/// set this from a required wire field, so in practice this should not
/// happen for cards rendered by Home/Search/Schedule/My-Collection;
/// guarded defensively so a malformed API response can't crash navigation.
```

- [ ] **Step 5: Regenerate the router's `.g.dart` and run the full suite/analyzer**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds. Only `lib/app/router.g.dart`'s content-hash constant should change (the `appRouter` function's source body changed) -- no other `.g.dart` file should change. Revert any unrelated file via `git checkout --`.

Run: `flutter test`
Expected: PASS (244 tests -- unchanged; `test/app/router_test.dart`'s existing auth-redirect coverage is unaffected since the `redirect:`/`refreshListenable`/`_RouterRefreshNotifier` logic is untouched).

Run: `flutter analyze`
Expected: same 3 pre-existing categories, no new category.

- [ ] **Step 6: Full native build check**

Run: `flutter build macos --debug`
Expected: succeeds. Revert any macOS build-artifact drift (`macos/Podfile.lock`, `macos/Flutter/GeneratedPluginRegistrant.swift`) via `git checkout --` before committing.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/collection/my_collection_screen.dart lib/app/router.dart lib/app/router.g.dart lib/ui/home/home_screen.dart lib/ui/search/search_screen.dart lib/ui/schedule/schedule_screen.dart lib/ui/subject/subject_navigation.dart
git commit -m "feat: add MyCollectionScreen, /collection route, and bookmark icon on Home/Search/Schedule"
```

---
### Task 12: Final verification

**Files:** none (verification only, no commit unless a fix is needed)

- [ ] **Step 1: Full test suite**

Run: `flutter test`
Expected: 0 failures. (Exact count depends on the cumulative additions from Tasks 1-9; do not hardcode a number here -- confirm it matches "192 baseline + every task's stated addition" rather than trusting a possibly-stale running total.)

- [ ] **Step 2: Analyzer**

Run: `flutter analyze`
Expected: exactly the same 3 categories as the plan's baseline (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`) -- zero new categories. Individual-count growth within these categories (e.g. from new test files importing `riverpod` directly) is expected and fine.

- [ ] **Step 3: Full native build**

Run: `flutter build macos --debug`
Expected: succeeds.

- [ ] **Step 4: Commit history**

Run: `git log --oneline` and confirm all 11 task commits from Tasks 1-11 are present on `main` in order.

- [ ] **Step 5: Working tree cleanliness**

Run: `git status`
Expected: clean, aside from the same pre-existing, unrelated macOS project files (`macos/Podfile.lock`, `macos/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`) that have been dirty throughout this whole session's prior plans -- these are not part of this plan's scope and should be left untouched.

---

## Definition of Done

- `flutter test`: 0 failures.
- `flutter analyze`: same 3 pre-existing categories, zero new categories.
- `flutter build macos --debug`: succeeds.
- All 11 task commits from this plan are present in `git log` on `main`.

## 手工验证 (non-blocking, does not gate task completion)

The following require a real logged-in session against `https://api.animeko.org` and cannot be automated by an agentic worker -- track as follow-up items, not blockers:

1. Confirm the real `GET /v2/subjects/{id}` response shape matches `SubjectDetail` exactly (especially `collectionType`'s wire values and `score`/`rank` nullability).
2. Confirm the real `GET .../characters?withActors=true` response's character-image field name matches `CharacterInfo.imageUrl` (flagged as an unconfirmed guess in Task 2/5).
3. Confirm the real `GET .../staff` response shape at all -- `StaffMember{name, imageUrl, role}` is an entirely unconfirmed guess (flagged in Task 2/5); the real endpoint may return a completely different shape, in which case Task 5's implementation needs to be revisited.
4. Confirm the real `GET /v2/subjects/list` response's pagination envelope matches `PaginatedCollections{items, total}` (flagged as an unverified assumption in Task 2/6).
5. Confirm collection-status changes and rating submissions round-trip correctly against the live server (tap through all 5 states + remove + submit a rating with a comment, then reload the page and confirm the change persisted).
6. Confirm the "我的收藏" page's pagination (`loadMore` on scroll-to-bottom) works against a real account with more than 20 collected subjects in one state.
