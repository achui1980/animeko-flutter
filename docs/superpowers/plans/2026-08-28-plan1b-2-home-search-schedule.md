# Plan 1b-2: Home + Search + Schedule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Home (trending + recommendations), Search (keyword + tags + sort), and Schedule (weekly airing) screens behind a bottom-nav shell, gated by auth, and fix Plan 1b-1 follow-ups I-A (interceptor can't sign the user out on a dead session) and I-B (`SessionRefresher` swallows the specific `AppError` on failure).

**Architecture:** Each of Home/Search/Schedule gets its own thin hand-written Dio API wrapper class + `json_serializable` models (first real consumer of the Plan 1b-1 toolchain) + a Riverpod controller exposing `AsyncValue`. All four Ani API endpoint groups return incompatible lightweight "subject card" shapes, so a single internal `SubjectCard` domain model is introduced with one factory mapper per source. Navigation moves from a single static route to a `go_router` `StatefulShellRoute.indexedStack` (bottom nav) with a top-level `redirect:` callback gating on `AuthController`'s state, refreshed via `refreshListenable` so a successful login automatically navigates away from `/login`.

**Tech Stack:** Riverpod (`@riverpod` codegen), `json_serializable`/`json_annotation` (already added in Plan 1b-1), `dio` (shared `dioProvider`), `go_router` 17.5.0 (`StatefulShellRoute.indexedStack`, `redirect:`, `refreshListenable`), `mocktail` for tests.

**Reference docs:**
- Design: `docs/superpowers/specs/2026-08-28-plan1b-2-home-search-schedule-design.md`
- Plan 1b-1 follow-ups being fixed here (I-A, I-B): `docs/superpowers/plans/2026-08-28-plan1b-1-followups.md`

**Out of scope for this plan (per the design doc):** subject detail pages, rating, collection status, cloud sync, Drift caching, season browsing in search, rating-range search filters, "continue watching" home section. All deferred to Plan 1b-3/1b-4.

---

## File Structure

New files:
- `lib/domain/subject_card.dart` — unified card model + 4 factory mappers (added incrementally per task)
- `lib/data/home/trends_models.dart`, `lib/data/home/trends_api.dart`
- `lib/data/home/home_recommendations_models.dart`, `lib/data/home/home_recommendations_api.dart`
- `lib/domain/home/home_controller.dart`
- `lib/data/search/search_models.dart`, `lib/data/search/search_sort_by.dart`, `lib/data/search/search_api.dart`
- `lib/domain/search/search_controller.dart`
- `lib/data/schedule/schedule_models.dart`, `lib/data/schedule/schedule_api.dart`
- `lib/domain/schedule/schedule_controller.dart`
- `lib/data/auth/refresh_result.dart`
- `lib/ui/shell/main_shell.dart`, `lib/ui/home/home_screen.dart`, `lib/ui/search/search_screen.dart`, `lib/ui/schedule/schedule_screen.dart`

Modified files:
- `lib/data/auth/session_refresher.dart` (I-B: return `RefreshResult` instead of `StoredSession?`)
- `lib/domain/auth/auth_controller.dart` (I-B: consume `RefreshResult`; I-A: add `signOut()` + `refreshSessionForInterceptor()`)
- `lib/data/api_client.dart` (I-A: delegate interceptor refresh to `AuthController`)
- `lib/app/router.dart` (rewrite as Riverpod provider with redirect + shell)
- `lib/app/main.dart` (consume `appRouterProvider` reactively)

---

### Task 1: `SubjectCard` domain model

**Files:**
- Create: `lib/domain/subject_card.dart`
- Test: `test/domain/subject_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/subject_card_test.dart
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SubjectCard stores required and optional fields', () {
    const card = SubjectCard(id: 1, name: 'Test Anime');
    expect(card.id, 1);
    expect(card.name, 'Test Anime');
    expect(card.nameCn, isNull);
    expect(card.imageUrl, isNull);
    expect(card.score, isNull);
    expect(card.tags, isNull);
    expect(card.airDate, isNull);
  });

  test('SubjectCard stores all fields when provided', () {
    const card = SubjectCard(
      id: 2,
      name: 'Full Anime',
      nameCn: '完整动漫',
      imageUrl: 'https://example.com/img.jpg',
      score: '8.5',
      tags: ['Comedy', 'Drama'],
      airDate: '2024-01-01',
    );
    expect(card.nameCn, '完整动漫');
    expect(card.imageUrl, 'https://example.com/img.jpg');
    expect(card.score, '8.5');
    expect(card.tags, ['Comedy', 'Drama']);
    expect(card.airDate, '2024-01-01');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/subject_card_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/domain/subject_card.dart'" or similar "No such file" error.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/subject_card.dart
/// Unified internal representation of an anime "card" shown in Home,
/// Search, and Schedule lists. None of the four Ani API endpoint groups
/// (trends, home recommendations, search, schedule) return a shared wire
/// model -- each has its own incompatible field set (different names for
/// id/image, inconsistent presence of nameCn/score/tags). Rather than
/// have the UI branch on four different types, every API-specific model
/// is mapped into this one type via a factory constructor added in the
/// task that introduces that API (see SubjectCard.fromTrending,
/// .fromRecommendation, .fromSearchResult, .fromScheduledSubject).
class SubjectCard {
  const SubjectCard({
    required this.id,
    required this.name,
    this.nameCn,
    this.imageUrl,
    this.score,
    this.tags,
    this.airDate,
  });

  final int? id;
  final String name;
  final String? nameCn;
  final String? imageUrl;
  final String? score;
  final List<String>? tags;
  final String? airDate;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/subject_card_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/domain/subject_card.dart test/domain/subject_card_test.dart
git commit -m "feat: add unified SubjectCard domain model"
```

---

### Task 2: `TrendsApi` + models + `SubjectCard.fromTrending`

**Files:**
- Create: `lib/data/home/trends_models.dart`
- Create: `lib/data/home/trends_api.dart`
- Modify: `lib/domain/subject_card.dart`
- Test: `test/data/home/trends_api_test.dart`

**Endpoint (verified against Kotlin generated client `TrendsAniApi.getTrends()`):** `GET /v1/trends`, public (no auth), no params. Response: `{"trendingSubjects": [{"bangumiId": 1, "nameCn": "...", "imageLarge": "..."}]}`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/home/trends_api_test.dart
import 'package:animeko_flutter/data/home/trends_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late TrendsApi api;

  setUp(() {
    dio = MockDio();
    api = TrendsApi(dio);
  });

  test('getTrends GETs /v1/trends and parses the response', () async {
    when(() => dio.get<Map<String, dynamic>>('/v1/trends')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/v1/trends'),
        statusCode: 200,
        data: {
          'trendingSubjects': [
            {'bangumiId': 42, 'nameCn': '测试动漫', 'imageLarge': 'https://x/img.jpg'},
          ],
        },
      ),
    );

    final result = await api.getTrends();

    expect(result.trendingSubjects, hasLength(1));
    expect(result.trendingSubjects.single.bangumiId, 42);
    expect(result.trendingSubjects.single.nameCn, '测试动漫');
    expect(result.trendingSubjects.single.imageLarge, 'https://x/img.jpg');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/home/trends_api_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/data/home/trends_api.dart'".

- [ ] **Step 3: Write the models**

```dart
// lib/data/home/trends_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'trends_models.g.dart';

/// Verified against the Kotlin generated client's AniTrendingSubject
/// model (GET /v1/trends). Deliberately minimal -- the wire response
/// only has these 3 fields, no score/tags/air-date.
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

/// Response body of GET /v1/trends (AniTrends in the Kotlin client).
@JsonSerializable()
class TrendsResponse {
  const TrendsResponse({required this.trendingSubjects});

  final List<TrendingSubject> trendingSubjects;

  factory TrendsResponse.fromJson(Map<String, dynamic> json) =>
      _$TrendsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TrendsResponseToJson(this);
}
```

- [ ] **Step 4: Write the API class**

```dart
// lib/data/home/trends_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'trends_models.dart';

part 'trends_api.g.dart';

/// GET /v1/trends -- public endpoint, no auth required.
class TrendsApi {
  TrendsApi(this._dio);
  final Dio _dio;

  Future<TrendsResponse> getTrends() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/trends');
    return TrendsResponse.fromJson(response.data!);
  }
}

@riverpod
TrendsApi trendsApi(Ref ref) => TrendsApi(ref.watch(dioProvider));
```

- [ ] **Step 5: Add the mapper to `SubjectCard`**

Modify `lib/domain/subject_card.dart`: add this factory constructor inside the `SubjectCard` class, and add `import 'data/home/trends_models.dart';` — wait, `subject_card.dart` lives at `lib/domain/`, so the import path is `../data/home/trends_models.dart`.

```dart
// lib/domain/subject_card.dart
import '../data/home/trends_models.dart';

class SubjectCard {
  const SubjectCard({
    required this.id,
    required this.name,
    this.nameCn,
    this.imageUrl,
    this.score,
    this.tags,
    this.airDate,
  });

  final int? id;
  final String name;
  final String? nameCn;
  final String? imageUrl;
  final String? score;
  final List<String>? tags;
  final String? airDate;

  factory SubjectCard.fromTrending(TrendingSubject t) => SubjectCard(
    id: t.bangumiId,
    name: t.nameCn,
    nameCn: t.nameCn,
    imageUrl: t.imageLarge,
  );
}
```

- [ ] **Step 6: Generate code and run tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/data/home/trends_api_test.dart`
Expected: build_runner generates `lib/data/home/trends_models.g.dart` and `lib/data/home/trends_api.g.dart`; test PASSES.

- [ ] **Step 7: Run full suite and analyze**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: analyze clean modulo the 3 known pre-existing info lints; all tests pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/home/trends_models.dart lib/data/home/trends_models.g.dart lib/data/home/trends_api.dart lib/data/home/trends_api.g.dart lib/domain/subject_card.dart test/data/home/trends_api_test.dart
git commit -m "feat: add TrendsApi and SubjectCard.fromTrending mapper"
```

---

### Task 3: `HomeRecommendationsApi` + models + `SubjectCard.fromRecommendation`

**Files:**
- Create: `lib/data/home/home_recommendations_models.dart`
- Create: `lib/data/home/home_recommendations_api.dart`
- Modify: `lib/domain/subject_card.dart`
- Test: `test/data/home/home_recommendations_api_test.dart`

**Endpoint (verified against Kotlin `HomeAniApi.getHomeRecommendations`):** `GET /v2/home/recommendations`, declared `auth-jwt` in the OpenAPI spec (Authorization header attached automatically by the existing `AuthInterceptor` via the shared `dioProvider` this class uses — no special handling needed here). Params: `offset?:int`, `limit?:int`. Response: `{"total": 10, "items": [{"subjectName": "...", "subjectNameCn": "...", "imageUrl": "...", "desc1": "...", "desc2": "...", "subjectId": 1, "uri": "..."}]}` (`subjectId`/`uri` nullable).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/home/home_recommendations_api_test.dart
import 'package:animeko_flutter/data/home/home_recommendations_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late HomeRecommendationsApi api;

  setUp(() {
    dio = MockDio();
    api = HomeRecommendationsApi(dio);
  });

  Response<Map<String, dynamic>> fixtureResponse() => Response(
    requestOptions: RequestOptions(path: '/v2/home/recommendations'),
    statusCode: 200,
    data: {
      'total': 1,
      'items': [
        {
          'subjectName': 'Test',
          'subjectNameCn': '测试',
          'imageUrl': 'https://x/img.jpg',
          'desc1': 'a',
          'desc2': 'b',
          'subjectId': 7,
          'uri': 'ani://subject/7',
        },
      ],
    },
  );

  test('getRecommendations omits offset/limit query params when not given', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/v2/home/recommendations',
        queryParameters: {},
      ),
    ).thenAnswer((_) async => fixtureResponse());

    final result = await api.getRecommendations();

    expect(result.total, 1);
    expect(result.items.single.subjectId, 7);
    expect(result.items.single.subjectName, 'Test');
    expect(result.items.single.subjectNameCn, '测试');
  });

  test('getRecommendations includes offset/limit when provided', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/v2/home/recommendations',
        queryParameters: {'offset': 5, 'limit': 20},
      ),
    ).thenAnswer((_) async => fixtureResponse());

    await api.getRecommendations(offset: 5, limit: 20);

    verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/home/recommendations',
        queryParameters: {'offset': 5, 'limit': 20},
      ),
    ).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/home/home_recommendations_api_test.dart`
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Write the models**

```dart
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

/// Response body of GET /v2/home/recommendations (AniHomeRecommendationsResponse).
@JsonSerializable()
class HomeRecommendationsResponse {
  const HomeRecommendationsResponse({required this.total, required this.items});

  final int total;
  final List<SubjectRecommendation> items;

  factory HomeRecommendationsResponse.fromJson(Map<String, dynamic> json) =>
      _$HomeRecommendationsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$HomeRecommendationsResponseToJson(this);
}
```

- [ ] **Step 4: Write the API class**

```dart
// lib/data/home/home_recommendations_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'home_recommendations_models.dart';

part 'home_recommendations_api.g.dart';

/// GET /v2/home/recommendations -- declared auth-jwt in the OpenAPI spec.
/// The shared `dioProvider` already attaches the Authorization header via
/// AuthInterceptor, so this class does not need to handle auth itself.
class HomeRecommendationsApi {
  HomeRecommendationsApi(this._dio);
  final Dio _dio;

  Future<HomeRecommendationsResponse> getRecommendations({
    int? offset,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/home/recommendations',
      queryParameters: {
        if (offset != null) 'offset': offset,
        if (limit != null) 'limit': limit,
      },
    );
    return HomeRecommendationsResponse.fromJson(response.data!);
  }
}

@riverpod
HomeRecommendationsApi homeRecommendationsApi(Ref ref) =>
    HomeRecommendationsApi(ref.watch(dioProvider));
```

- [ ] **Step 5: Add the mapper to `SubjectCard`**

Modify `lib/domain/subject_card.dart`: add `import '../data/home/home_recommendations_models.dart';` and this factory:

```dart
  factory SubjectCard.fromRecommendation(SubjectRecommendation r) => SubjectCard(
    id: r.subjectId,
    name: r.subjectName,
    nameCn: r.subjectNameCn,
    imageUrl: r.imageUrl,
  );
```

- [ ] **Step 6: Generate code and run tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/data/home/home_recommendations_api_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 7: Run full suite and analyze**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/home/home_recommendations_models.dart lib/data/home/home_recommendations_models.g.dart lib/data/home/home_recommendations_api.dart lib/data/home/home_recommendations_api.g.dart lib/domain/subject_card.dart test/data/home/home_recommendations_api_test.dart
git commit -m "feat: add HomeRecommendationsApi and SubjectCard.fromRecommendation mapper"
```

---

### Task 4: `HomeController`

**Files:**
- Create: `lib/domain/home/home_controller.dart`
- Test: `test/domain/home/home_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/home/home_controller_test.dart
import 'package:animeko_flutter/data/home/home_recommendations_api.dart';
import 'package:animeko_flutter/data/home/home_recommendations_models.dart';
import 'package:animeko_flutter/data/home/trends_api.dart';
import 'package:animeko_flutter/data/home/trends_models.dart';
import 'package:animeko_flutter/domain/home/home_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockTrendsApi extends Mock implements TrendsApi {}

class MockHomeRecommendationsApi extends Mock implements HomeRecommendationsApi {}

void main() {
  late MockTrendsApi trendsApi;
  late MockHomeRecommendationsApi recommendationsApi;
  late ProviderContainer container;

  setUp(() {
    trendsApi = MockTrendsApi();
    recommendationsApi = MockHomeRecommendationsApi();
    container = ProviderContainer(
      overrides: [
        trendsApiProvider.overrideWithValue(trendsApi),
        homeRecommendationsApiProvider.overrideWithValue(recommendationsApi),
      ],
    );
    addTearDown(container.dispose);
  });

  test('loads trending and recommendations in parallel and maps to SubjectCard', () async {
    when(() => trendsApi.getTrends()).thenAnswer(
      (_) async => const TrendsResponse(
        trendingSubjects: [
          TrendingSubject(bangumiId: 1, nameCn: 'A', imageLarge: 'a.jpg'),
        ],
      ),
    );
    when(() => recommendationsApi.getRecommendations()).thenAnswer(
      (_) async => const HomeRecommendationsResponse(
        total: 1,
        items: [
          SubjectRecommendation(
            subjectName: 'B',
            subjectNameCn: 'B-cn',
            imageUrl: 'b.jpg',
            desc1: 'd1',
            desc2: 'd2',
            subjectId: 2,
          ),
        ],
      ),
    );

    final data = await container.read(homeControllerProvider.future);

    expect(data.trending, hasLength(1));
    expect(data.trending.single.name, 'A');
    expect(data.recommendations, hasLength(1));
    expect(data.recommendations.single.name, 'B');
  });

  test('surfaces an error if either API call fails', () async {
    when(() => trendsApi.getTrends()).thenThrow(Exception('boom'));
    when(() => recommendationsApi.getRecommendations()).thenAnswer(
      (_) async => const HomeRecommendationsResponse(total: 0, items: []),
    );

    await expectLater(
      container.read(homeControllerProvider.future),
      throwsA(isA<Exception>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/home/home_controller_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/domain/home/home_controller.dart'".

- [ ] **Step 3: Write the implementation**

```dart
// lib/domain/home/home_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home/home_recommendations_api.dart';
import '../../data/home/home_recommendations_models.dart';
import '../../data/home/trends_api.dart';
import '../../data/home/trends_models.dart';
import '../subject_card.dart';

part 'home_controller.g.dart';

class HomeData {
  const HomeData({required this.trending, required this.recommendations});

  final List<SubjectCard> trending;
  final List<SubjectCard> recommendations;
}

@riverpod
class HomeController extends _$HomeController {
  @override
  Future<HomeData> build() async {
    final trendsApi = ref.watch(trendsApiProvider);
    final recommendationsApi = ref.watch(homeRecommendationsApiProvider);

    final results = await Future.wait([
      trendsApi.getTrends(),
      recommendationsApi.getRecommendations(),
    ]);

    final trends = results[0] as TrendsResponse;
    final recommendations = results[1] as HomeRecommendationsResponse;

    return HomeData(
      trending: trends.trendingSubjects.map(SubjectCard.fromTrending).toList(),
      recommendations: recommendations.items
          .map(SubjectCard.fromRecommendation)
          .toList(),
    );
  }
}
```

- [ ] **Step 4: Generate code and run tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/domain/home/home_controller_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Run full suite and analyze**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/domain/home/home_controller.dart lib/domain/home/home_controller.g.dart test/domain/home/home_controller_test.dart
git commit -m "feat: add HomeController loading trends and recommendations in parallel"
```

---

### Task 5: `SearchApi` + models + `SearchSortBy` enum + `SubjectCard.fromSearchResult`

**Files:**
- Create: `lib/data/search/search_models.dart`
- Create: `lib/data/search/search_sort_by.dart`
- Create: `lib/data/search/search_api.dart`
- Modify: `lib/domain/subject_card.dart` (add `fromSearchResult` factory)
- Test: `test/data/search/search_api_test.dart`

Scope note: per the approved design doc, Search implements ONLY keyword + tags + sort. No season filter, no rating-range filter, no `includeNsfw` param — these were explicitly dropped as out of scope.

- [ ] **Step 1: Write the failing test**

Create `test/data/search/search_api_test.dart`:

```dart
import 'package:animeko_flutter/data/api_client.dart';
import 'package:animeko_flutter/data/search/search_api.dart';
import 'package:animeko_flutter/data/search/search_sort_by.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late SearchApi api;

  setUp(() {
    dio = MockDio();
    api = SearchApi(dio);
  });

  Response<Map<String, dynamic>> jsonResponse(Map<String, dynamic> data) {
    return Response(
      data: data,
      requestOptions: RequestOptions(path: '/v2/subjects/search'),
      statusCode: 200,
    );
  }

  test('search always sends q, omits tags/sortBy when not provided', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'items': <dynamic>[]}));

    await api.search(keywords: 'frieren');

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/subjects/search',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured['q'], 'frieren');
    expect(captured.containsKey('tags'), isFalse);
    expect(captured.containsKey('sortBy'), isFalse);
  });

  test('search joins tags as CSV and sends sortBy wire value', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'items': <dynamic>[]}));

    await api.search(
      keywords: 'frieren',
      tags: const ['Fantasy', 'Drama'],
      sortBy: SearchSortBy.rankAsc,
    );

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/subjects/search',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured['tags'], 'Fantasy,Drama');
    expect(captured['sortBy'], 'rankAsc');
  });

  test('search omits tags param when list is empty', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'items': <dynamic>[]}));

    await api.search(keywords: 'frieren', tags: const []);

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        '/v2/subjects/search',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured.containsKey('tags'), isFalse);
  });

  test('search parses response ignoring unknown JSON keys', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => jsonResponse({
        'items': [
          {
            'id': 42,
            'name': 'Sousou no Frieren',
            'nameCn': '葬送的芙莉莲',
            'summary': 'ignored field not in our model',
            'imageLarge': 'https://example.com/frieren.jpg',
            'nsfw': false,
            'airDate': '2023-09-29',
            'ratingTotal': 12345,
            'favorite': {
              'wish': 1,
              'done': 2,
              'doing': 3,
              'onHold': 4,
              'dropped': 5,
            },
            'tags': [
              {'name': 'Fantasy', 'count': 100},
            ],
            'mainEpisodeCount': 28,
            'lightRelatedPersonInfoList': <dynamic>[],
            'score': '9.1',
            'rank': 3,
          },
        ],
      }),
    );

    final response = await api.search(keywords: 'frieren');

    expect(response.items, hasLength(1));
    expect(response.items.single.id, 42);
    expect(response.items.single.name, 'Sousou no Frieren');
    expect(response.items.single.nameCn, '葬送的芙莉莲');
    expect(response.items.single.imageLarge, 'https://example.com/frieren.jpg');
    expect(response.items.single.airDate, '2023-09-29');
    expect(response.items.single.tags.single.name, 'Fantasy');
    expect(response.items.single.tags.single.count, 100);
    expect(response.items.single.score, '9.1');
  });

  test('searchApiProvider builds a SearchApi backed by dioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(searchApiProvider);
    expect(api, isA<SearchApi>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/search/search_api_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/data/search/search_api.dart'".

- [ ] **Step 3: Write the models**

Create `lib/data/search/search_models.dart`:

```dart
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
```

- [ ] **Step 4: Write the sort enum**

Create `lib/data/search/search_sort_by.dart`:

```dart
// lib/data/search/search_sort_by.dart

/// Mirrors the Kotlin-generated `AniSubjectSearchSortBy` enum's wire
/// values exactly (verified against the real client code -- these do NOT
/// match a naive guess like MATCH/RANK/COLLECTION/DATE).
enum SearchSortBy {
  relevance,
  airDateAsc,
  airDateDesc,
  ratingAsc,
  ratingDesc,
  rankAsc,
  rankDesc,
  collectionDesc,
}

extension SearchSortByWireValue on SearchSortBy {
  String get wireValue => switch (this) {
    SearchSortBy.relevance => 'relevance',
    SearchSortBy.airDateAsc => 'airDateAsc',
    SearchSortBy.airDateDesc => 'airDateDesc',
    SearchSortBy.ratingAsc => 'ratingAsc',
    SearchSortBy.ratingDesc => 'ratingDesc',
    SearchSortBy.rankAsc => 'rankAsc',
    SearchSortBy.rankDesc => 'rankDesc',
    SearchSortBy.collectionDesc => 'collectionDesc',
  };
}
```

- [ ] **Step 5: Write the API class**

Create `lib/data/search/search_api.dart`:

```dart
// lib/data/search/search_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'search_models.dart';
import 'search_sort_by.dart';

part 'search_api.g.dart';

/// GET /v2/subjects/search -- keyword + tags + sort only (season and
/// rating-range filters are out of scope per the approved design doc).
class SearchApi {
  SearchApi(this._dio);
  final Dio _dio;

  Future<SearchResponse> search({
    required String keywords,
    List<String>? tags,
    SearchSortBy? sortBy,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/search',
      queryParameters: {
        'q': keywords,
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
        if (sortBy != null) 'sortBy': sortBy.wireValue,
      },
    );
    return SearchResponse.fromJson(response.data!);
  }
}

@riverpod
SearchApi searchApi(Ref ref) => SearchApi(ref.watch(dioProvider));
```

- [ ] **Step 6: Add the `fromSearchResult` mapper to `SubjectCard`**

Modify `lib/domain/subject_card.dart` -- add this import at the top (alongside the existing `trends_models.dart`/`home_recommendations_models.dart` imports):

```dart
import '../data/search/search_models.dart';
```

Add this factory constructor inside the `SubjectCard` class, alongside `fromTrending`/`fromRecommendation`:

```dart
  factory SubjectCard.fromSearchResult(SubjectSearchResult s) => SubjectCard(
    id: s.id,
    name: s.name,
    nameCn: s.nameCn,
    imageUrl: s.imageLarge,
    score: s.score,
    tags: s.tags.map((t) => t.name).toList(),
    airDate: s.airDate,
  );
```

- [ ] **Step 7: Generate code and run tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/data/search/search_api_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 8: Run full suite and analyze**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 9: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/search/search_models.dart lib/data/search/search_models.g.dart lib/data/search/search_sort_by.dart lib/data/search/search_api.dart lib/data/search/search_api.g.dart lib/domain/subject_card.dart test/data/search/search_api_test.dart
git commit -m "feat: add SearchApi, SearchSortBy, and SubjectCard.fromSearchResult mapper"
```

---

### Task 6: `SearchController` (debounced keyword + tags + sort)

**Files:**
- Create: `lib/domain/search/search_controller.dart`
- Test: `test/domain/search/search_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/search/search_controller_test.dart`:

```dart
import 'package:animeko_flutter/data/search/search_api.dart';
import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/data/search/search_sort_by.dart';
import 'package:animeko_flutter/domain/search/search_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSearchApi extends Mock implements SearchApi {}

void main() {
  late MockSearchApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSearchApi();
    container = ProviderContainer(
      overrides: [
        searchApiProvider.overrideWithValue(api),
        // Zero debounce so tests don't need to wait on a real timer.
        searchDebounceDurationProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
  });

  test('initial state is an empty list', () async {
    final result = await container.read(searchControllerProvider.future);
    expect(result, isEmpty);
  });

  test('empty keywords resets to an empty list without calling the API', () async {
    await container.read(searchControllerProvider.future);
    container.read(searchControllerProvider.notifier).search(keywords: '   ');
    // No debounce wait needed -- empty-keyword path is synchronous.
    final state = container.read(searchControllerProvider);
    expect(state.value, isEmpty);
    verifyNever(() => api.search(keywords: any(named: 'keywords')));
  });

  test('non-empty keywords call the API after the debounce and map results', () async {
    when(
      () => api.search(
        keywords: any(named: 'keywords'),
        tags: any(named: 'tags'),
        sortBy: any(named: 'sortBy'),
      ),
    ).thenAnswer(
      (_) async => const SearchResponse(
        items: [
          SubjectSearchResult(
            id: 1,
            name: 'Frieren',
            nameCn: '芙莉莲',
            imageLarge: 'https://example.com/f.jpg',
            airDate: '2023-09-29',
            tags: [],
          ),
        ],
      ),
    );

    await container.read(searchControllerProvider.future);
    container.read(searchControllerProvider.notifier).search(keywords: 'frieren');

    // Debounce is zero, but the timer callback still runs as a
    // microtask/event -- pump the event loop once.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(searchControllerProvider);
    expect(state.value, isNotNull);
    expect(state.value!.single.name, 'Frieren');
    expect(state.value!.single.id, 1);
  });

  test('a thrown API error surfaces as AsyncError', () async {
    when(
      () => api.search(
        keywords: any(named: 'keywords'),
        tags: any(named: 'tags'),
        sortBy: any(named: 'sortBy'),
      ),
    ).thenThrow(Exception('network down'));

    await container.read(searchControllerProvider.future);
    container.read(searchControllerProvider.notifier).search(keywords: 'frieren');

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(searchControllerProvider);
    expect(state.hasError, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/search/search_controller_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/domain/search/search_controller.dart'".

- [ ] **Step 3: Write the implementation**

Create `lib/domain/search/search_controller.dart`:

```dart
// lib/domain/search/search_controller.dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/search/search_api.dart';
import '../../data/search/search_sort_by.dart';
import '../subject_card.dart';

part 'search_controller.g.dart';

/// Delay before firing a search after the last keystroke. Overridden to
/// [Duration.zero] in tests so debounced searches run instantly.
@riverpod
Duration searchDebounceDuration(Ref ref) =>
    const Duration(milliseconds: 400);

@riverpod
class SearchController extends _$SearchController {
  Timer? _debounce;

  @override
  Future<List<SubjectCard>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return const [];
  }

  void search({
    required String keywords,
    List<String>? tags,
    SearchSortBy? sortBy,
  }) {
    _debounce?.cancel();

    if (keywords.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }

    _debounce = Timer(ref.read(searchDebounceDurationProvider), () async {
      state = const AsyncLoading();
      try {
        final api = ref.read(searchApiProvider);
        final response = await api.search(
          keywords: keywords,
          tags: tags,
          sortBy: sortBy,
        );
        state = AsyncData(
          response.items.map(SubjectCard.fromSearchResult).toList(),
        );
      } catch (e, st) {
        state = AsyncError(e, st);
      }
    });
  }
}
```

- [ ] **Step 4: Generate code and run tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/domain/search/search_controller_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Run full suite and analyze**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/domain/search/search_controller.dart lib/domain/search/search_controller.g.dart test/domain/search/search_controller_test.dart
git commit -m "feat: add SearchController with debounced keyword/tags/sort search"
```

---

### Task 7: `ScheduleApi` + models + `SubjectCard.fromScheduledSubject`

**Files:**
- Create: `lib/data/schedule/schedule_models.dart`
- Create: `lib/data/schedule/schedule_api.dart`
- Modify: `lib/domain/subject_card.dart` (add `fromScheduledSubject` factory)
- Test: `test/data/schedule/schedule_api_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/schedule/schedule_api_test.dart`:

```dart
import 'package:animeko_flutter/data/api_client.dart';
import 'package:animeko_flutter/data/schedule/schedule_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ScheduleApi api;

  setUp(() {
    dio = MockDio();
    api = ScheduleApi(dio);
  });

  Response<Map<String, dynamic>> jsonResponse(Map<String, dynamic> data) {
    return Response(
      data: data,
      requestOptions: RequestOptions(path: '/v1/schedule/airing'),
      statusCode: 200,
    );
  }

  test('getLatestAiringSchedule sends today and timeZone as query params', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => jsonResponse({'list': <dynamic>[]}));

    await api.getLatestAiringSchedule(today: '2026-08-28', timeZone: '+08:00');

    verify(
      () => dio.get<Map<String, dynamic>>(
        '/v1/schedule/airing',
        queryParameters: {'today': '2026-08-28', 'timeZone': '+08:00'},
      ),
    ).called(1);
  });

  test('parses a date-grouped schedule with nested subject/episode', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => jsonResponse({
        'list': [
          {
            'date': '2026-08-28',
            'list': [
              {
                'subject': {
                  'subjectId': 100,
                  'name': 'Frieren',
                  'nameCn': '芙莉莲',
                  'imageLarge': 'https://example.com/f.jpg',
                },
                'episode': {
                  'episodeId': 1000,
                  'name': 'Ep 1',
                  'nameCn': '第1话',
                  'airDate': '2026-08-28',
                  'sort': '1',
                },
                'airingTime': '2026-08-28T22:00:00Z',
              },
            ],
          },
        ],
      }),
    );

    final result = await api.getLatestAiringSchedule(
      today: '2026-08-28',
      timeZone: '+08:00',
    );

    expect(result.list, hasLength(1));
    expect(result.list.single.date, '2026-08-28');
    expect(result.list.single.list.single.subject.subjectId, 100);
    expect(result.list.single.list.single.subject.nameCn, '芙莉莲');
    expect(result.list.single.list.single.episode.sort, '1');
    expect(result.list.single.list.single.airingTime, '2026-08-28T22:00:00Z');
  });

  test('scheduleApiProvider builds a ScheduleApi backed by dioProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(scheduleApiProvider);
    expect(api, isA<ScheduleApi>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/schedule/schedule_api_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/data/schedule/schedule_api.dart'".

- [ ] **Step 3: Write the models**

Create `lib/data/schedule/schedule_models.dart`:

```dart
// lib/data/schedule/schedule_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'schedule_models.g.dart';

/// Verified against the Kotlin-generated `AniScheduledAnimeSubject` model.
@JsonSerializable()
class ScheduledAnimeSubject {
  const ScheduledAnimeSubject({
    required this.subjectId,
    required this.name,
    required this.nameCn,
    required this.imageLarge,
  });

  final int subjectId;
  final String name;
  final String nameCn;
  final String imageLarge;

  factory ScheduledAnimeSubject.fromJson(Map<String, dynamic> json) =>
      _$ScheduledAnimeSubjectFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduledAnimeSubjectToJson(this);
}

/// Verified against the Kotlin-generated `AniScheduledAnimeEpisodeInfo`
/// model. Deliberately omits the wire's required `type` field, which the
/// UI doesn't need.
@JsonSerializable()
class ScheduledAnimeEpisodeInfo {
  const ScheduledAnimeEpisodeInfo({
    required this.episodeId,
    required this.name,
    required this.nameCn,
    required this.airDate,
    required this.sort,
  });

  final int episodeId;
  final String name;
  final String nameCn;
  final String airDate;
  final String sort;

  factory ScheduledAnimeEpisodeInfo.fromJson(Map<String, dynamic> json) =>
      _$ScheduledAnimeEpisodeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduledAnimeEpisodeInfoToJson(this);
}

@JsonSerializable()
class ScheduledAnimeEpisode {
  const ScheduledAnimeEpisode({
    required this.subject,
    required this.episode,
    required this.airingTime,
  });

  final ScheduledAnimeSubject subject;
  final ScheduledAnimeEpisodeInfo episode;
  final String airingTime;

  factory ScheduledAnimeEpisode.fromJson(Map<String, dynamic> json) =>
      _$ScheduledAnimeEpisodeFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduledAnimeEpisodeToJson(this);
}

@JsonSerializable()
class AiringScheduleForDate {
  const AiringScheduleForDate({required this.date, required this.list});

  final String date;
  final List<ScheduledAnimeEpisode> list;

  factory AiringScheduleForDate.fromJson(Map<String, dynamic> json) =>
      _$AiringScheduleForDateFromJson(json);

  Map<String, dynamic> toJson() => _$AiringScheduleForDateToJson(this);
}

/// Response of `GET /v1/schedule/airing`.
@JsonSerializable()
class LatestAiringSchedule {
  const LatestAiringSchedule({required this.list});

  final List<AiringScheduleForDate> list;

  factory LatestAiringSchedule.fromJson(Map<String, dynamic> json) =>
      _$LatestAiringScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$LatestAiringScheduleToJson(this);
}
```

- [ ] **Step 4: Write the API class**

Create `lib/data/schedule/schedule_api.dart`:

```dart
// lib/data/schedule/schedule_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'schedule_models.dart';

part 'schedule_api.g.dart';

/// GET /v1/schedule/airing -- public endpoint, no auth required.
class ScheduleApi {
  ScheduleApi(this._dio);
  final Dio _dio;

  Future<LatestAiringSchedule> getLatestAiringSchedule({
    required String today,
    required String timeZone,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/schedule/airing',
      queryParameters: {'today': today, 'timeZone': timeZone},
    );
    return LatestAiringSchedule.fromJson(response.data!);
  }
}

@riverpod
ScheduleApi scheduleApi(Ref ref) => ScheduleApi(ref.watch(dioProvider));
```

- [ ] **Step 5: Add the `fromScheduledSubject` mapper to `SubjectCard`**

Modify `lib/domain/subject_card.dart` -- add this import at the top:

```dart
import '../data/schedule/schedule_models.dart';
```

Add this factory constructor inside the `SubjectCard` class:

```dart
  factory SubjectCard.fromScheduledSubject(ScheduledAnimeSubject s) =>
      SubjectCard(
        id: s.subjectId,
        name: s.name,
        nameCn: s.nameCn,
        imageUrl: s.imageLarge,
      );
```

- [ ] **Step 6: Generate code and run tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/data/schedule/schedule_api_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 7: Run full suite and analyze**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/schedule/schedule_models.dart lib/data/schedule/schedule_models.g.dart lib/data/schedule/schedule_api.dart lib/data/schedule/schedule_api.g.dart lib/domain/subject_card.dart test/data/schedule/schedule_api_test.dart
git commit -m "feat: add ScheduleApi and SubjectCard.fromScheduledSubject mapper"
```

---

### Task 8: `ScheduleController`

**Files:**
- Create: `lib/domain/schedule/schedule_controller.dart`
- Test: `test/domain/schedule/schedule_controller_test.dart`

Note: the exact string format the server expects for `today`/`timeZone` (e.g. whether `timeZone` should be `+08:00` vs `+0800` vs a named zone like `Asia/Shanghai`) could not be verified from the generated client alone -- it's a plain `String` parameter with no further documentation. The ISO-8601-style format below (`YYYY-MM-DD` and `±HH:MM`) is this plan's best-effort assumption, to be empirically confirmed against the real server during Definition-of-Done manual verification (same caveat pattern used for previously-uncertain API behaviors in Plan 1a/1b-1).

- [ ] **Step 1: Write the failing test**

Create `test/domain/schedule/schedule_controller_test.dart`:

```dart
import 'package:animeko_flutter/data/schedule/schedule_api.dart';
import 'package:animeko_flutter/data/schedule/schedule_models.dart';
import 'package:animeko_flutter/domain/schedule/schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockScheduleApi extends Mock implements ScheduleApi {}

void main() {
  group('todayDateString', () {
    test('pads month and day to 2 digits', () {
      expect(todayDateString(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('handles double-digit month and day', () {
      expect(todayDateString(DateTime(2026, 12, 28)), '2026-12-28');
    });
  });

  group('timeZoneOffsetString', () {
    test('formats a positive whole-hour offset', () {
      expect(timeZoneOffsetString(const Duration(hours: 8)), '+08:00');
    });

    test('formats a negative offset', () {
      expect(timeZoneOffsetString(const Duration(hours: -5)), '-05:00');
    });

    test('formats a half-hour offset', () {
      expect(
        timeZoneOffsetString(const Duration(hours: 5, minutes: 30)),
        '+05:30',
      );
    });

    test('formats a zero offset as positive', () {
      expect(timeZoneOffsetString(Duration.zero), '+00:00');
    });
  });

  group('ScheduleController', () {
    late MockScheduleApi api;
    late ProviderContainer container;

    setUp(() {
      api = MockScheduleApi();
      container = ProviderContainer(
        overrides: [scheduleApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
    });

    test('groups subjects by date', () async {
      when(
        () => api.getLatestAiringSchedule(
          today: any(named: 'today'),
          timeZone: any(named: 'timeZone'),
        ),
      ).thenAnswer(
        (_) async => const LatestAiringSchedule(
          list: [
            AiringScheduleForDate(
              date: '2026-08-28',
              list: [
                ScheduledAnimeEpisode(
                  subject: ScheduledAnimeSubject(
                    subjectId: 100,
                    name: 'Frieren',
                    nameCn: '芙莉莲',
                    imageLarge: 'https://example.com/f.jpg',
                  ),
                  episode: ScheduledAnimeEpisodeInfo(
                    episodeId: 1000,
                    name: 'Ep 1',
                    nameCn: '第1话',
                    airDate: '2026-08-28',
                    sort: '1',
                  ),
                  airingTime: '2026-08-28T22:00:00Z',
                ),
              ],
            ),
          ],
        ),
      );

      final result = await container.read(scheduleControllerProvider.future);

      expect(result, hasLength(1));
      expect(result.single.date, '2026-08-28');
      expect(result.single.subjects.single.nameCn, '芙莉莲');
      expect(result.single.subjects.single.id, 100);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/schedule/schedule_controller_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/domain/schedule/schedule_controller.dart'".

- [ ] **Step 3: Write the implementation**

Create `lib/domain/schedule/schedule_controller.dart`:

```dart
// lib/domain/schedule/schedule_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/schedule/schedule_api.dart';
import '../subject_card.dart';

part 'schedule_controller.g.dart';

class ScheduleDay {
  const ScheduleDay({required this.date, required this.subjects});

  final String date;
  final List<SubjectCard> subjects;
}

/// Formats a [DateTime] as `YYYY-MM-DD`. Pure function, directly testable
/// with no mocking. See this file's Task 8 note in the plan doc regarding
/// the unverified server-expected format for this string.
String todayDateString(DateTime now) {
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Formats a UTC offset [Duration] as `+HH:MM` / `-HH:MM`. Pure function,
/// directly testable with no mocking.
String timeZoneOffsetString(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hours = abs.inHours.toString().padLeft(2, '0');
  final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}

@riverpod
class ScheduleController extends _$ScheduleController {
  @override
  Future<List<ScheduleDay>> build() async {
    final api = ref.watch(scheduleApiProvider);
    final now = DateTime.now();
    final schedule = await api.getLatestAiringSchedule(
      today: todayDateString(now),
      timeZone: timeZoneOffsetString(now.timeZoneOffset),
    );

    return schedule.list
        .map(
          (day) => ScheduleDay(
            date: day.date,
            subjects: day.list
                .map((e) => SubjectCard.fromScheduledSubject(e.subject))
                .toList(),
          ),
        )
        .toList();
  }
}
```

- [ ] **Step 4: Generate code and run tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/domain/schedule/schedule_controller_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run full suite and analyze**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/domain/schedule/schedule_controller.dart lib/domain/schedule/schedule_controller.g.dart test/domain/schedule/schedule_controller_test.dart
git commit -m "feat: add ScheduleController grouping the current week by date"
```

---

### Task 9: `RefreshResult` sealed class + `SessionRefresher.refresh()` refactor (Plan 1b-1 follow-up I-B)

**Context:** `SessionRefresher.refresh()` currently returns a bare `Future<StoredSession?>`. When it returns `null`, callers have no way to distinguish "the refresh token was rejected by the server (session is truly dead)" from "a transient network error occurred (the old session may still be valid)". This task introduces a `RefreshResult` sealed class that preserves the `AppError` behind a failed refresh, closing follow-up item I-B from `docs/superpowers/plans/2026-08-28-plan1b-1-followups.md`.

**Files:**
- Create: `lib/data/auth/refresh_result.dart`
- Modify: `lib/data/auth/session_refresher.dart` (change `refresh()`'s return type)
- Modify: `lib/domain/auth/auth_controller.dart` (`restoreSession()`'s handling of the refresh outcome)
- Test: `test/data/auth/session_refresher_test.dart` (rewrite existing cases)
- Test: `test/domain/auth/auth_controller_test.dart` (update `restoreSession` mock setups)

- [ ] **Step 1: Write the failing test for `RefreshResult`'s shape**

Create `test/data/auth/refresh_result_test.dart`:

```dart
// test/data/auth/refresh_result_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/refresh_result.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final session = const StoredSession(
    userId: 'user-1',
    tokens: AniTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAtMillis: 1,
    ),
  );

  test('RefreshSuccess carries the new session', () {
    final result = RefreshSuccess(session);
    expect(result.session, session);
  });

  test('RefreshFailure carries the AppError', () {
    const error = NetworkError();
    final result = RefreshFailure(error);
    expect(result.error, error);
  });

  test('switch exhaustiveness compiles for both variants', () {
    String describe(RefreshResult r) => switch (r) {
      RefreshSuccess(session: final s) => 'success:${s.userId}',
      RefreshFailure(error: final e) => 'failure:${e.message}',
    };
    expect(describe(RefreshSuccess(session)), 'success:user-1');
    expect(
      describe(const RefreshFailure(NetworkError())),
      contains('failure:'),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/refresh_result_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:animeko_flutter/data/auth/refresh_result.dart'".

- [ ] **Step 3: Create `RefreshResult`**

Create `lib/data/auth/refresh_result.dart`:

```dart
// lib/data/auth/refresh_result.dart
import '../../domain/app_error.dart';
import 'secure_token_storage.dart';

/// Outcome of [SessionRefresher.refresh]. Unlike the previous bare
/// `StoredSession?` return type, this preserves *why* a refresh failed
/// (Plan 1a/1b-1 follow-up I-B): a [RefreshFailure] carrying a
/// [NetworkError] means the old session may still be valid (the server
/// was just unreachable), whereas one carrying an [AuthExpiredError]
/// means the refresh token itself was rejected and the session is
/// definitively dead. Callers (see `AuthController.restoreSession()` and
/// `AuthController.refreshSessionForInterceptor()`) use this distinction
/// to decide whether to sign the user out.
sealed class RefreshResult {
  const RefreshResult();
}

class RefreshSuccess extends RefreshResult {
  const RefreshSuccess(this.session);
  final StoredSession session;
}

class RefreshFailure extends RefreshResult {
  const RefreshFailure(this.error);
  final AppError error;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/refresh_result_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Rewrite `session_refresher_test.dart` for the new return type**

Replace the full content of `test/data/auth/session_refresher_test.dart`:

```dart
// test/data/auth/session_refresher_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/refresh_result.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth/session_api.dart';
import 'package:animeko_flutter/data/auth/session_refresher.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionApi extends Mock implements SessionApi {}

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late MockSessionApi api;
  late MockSecureTokenStorage storage;
  late SessionRefresher refresher;

  setUpAll(() {
    registerFallbackValue(
      const StoredSession(
        userId: '',
        tokens: AniTokens(
          accessToken: '',
          refreshToken: '',
          expiresAtMillis: 0,
        ),
      ),
    );
  });

  setUp(() {
    api = MockSessionApi();
    storage = MockSecureTokenStorage();
    refresher = SessionRefresher(api, storage);
  });

  test('a successful refresh persists and returns RefreshSuccess', () async {
    const response = UserAuthRoutingLoginResponse(
      userId: 'user-1',
      tokens: AniTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresAtMillis: 999,
      ),
    );
    when(() => api.refreshToken('old-refresh')).thenAnswer(
      (_) async => response,
    );
    when(() => storage.saveSession(any())).thenAnswer((_) async {});

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshSuccess>());
    final session = (result as RefreshSuccess).session;
    expect(session.userId, 'user-1');
    expect(session.tokens.accessToken, 'new-access');
    verify(() => storage.saveSession(any())).called(1);
  });

  test('a failed API refresh clears storage and returns RefreshFailure', () async {
    when(() => api.refreshToken('old-refresh')).thenThrow(
      Exception('refresh token rejected'),
    );
    when(() => storage.clear()).thenAnswer((_) async {});

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshFailure>());
    expect((result as RefreshFailure).error, isA<UnknownAppError>());
    verify(() => storage.clear()).called(1);
  });

  test('a successful API refresh but a failed local save does NOT clear storage', () async {
    const response = UserAuthRoutingLoginResponse(
      userId: 'user-1',
      tokens: AniTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresAtMillis: 999,
      ),
    );
    when(() => api.refreshToken('old-refresh')).thenAnswer(
      (_) async => response,
    );
    when(() => storage.saveSession(any())).thenThrow(
      Exception('keychain unavailable'),
    );

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshFailure>());
    verifyNever(() => storage.clear());
  });

  test('refresh() never throws even if clearing storage itself fails', () async {
    when(() => api.refreshToken('old-refresh')).thenThrow(
      Exception('refresh token rejected'),
    );
    when(() => storage.clear()).thenThrow(Exception('keychain unavailable'));

    final result = await refresher.refresh('old-refresh');

    expect(result, isA<RefreshFailure>());
  });
}
```

- [ ] **Step 6: Modify `SessionRefresher.refresh()` to return `RefreshResult`**

In `lib/data/auth/session_refresher.dart`, add the import `import '../dio_error_mapper.dart';` and `import 'refresh_result.dart';`, then replace `refresh()`'s body so its signature becomes `Future<RefreshResult> refresh(String refreshToken) async`, its API-failure branch becomes:

```dart
    } catch (e) {
      await _clearSafely();
      return RefreshFailure(mapToAppError(e));
    }
```

and its local-save-failure branch becomes:

```dart
    try {
      await _storage.saveSession(session);
      return RefreshSuccess(session);
    } catch (e) {
      return RefreshFailure(mapToAppError(e));
    }
```

(The `_clearSafely()` helper and the two-separate-try-blocks structure from the Plan 1b-1 Task 4 follow-up fix are otherwise unchanged — only the return values change from `null`/`session` to `RefreshFailure(...)`/`RefreshSuccess(session)`.)

- [ ] **Step 7: Run the session_refresher tests**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/session_refresher_test.dart test/data/auth/refresh_result_test.dart`
Expected: PASS, 4 + 3 tests. (This will still show compile errors from `auth_controller.dart` referencing the old `StoredSession?` return type — those are fixed in the next step.)

- [ ] **Step 8: Update `AuthController.restoreSession()` to switch on `RefreshResult`**

In `lib/domain/auth/auth_controller.dart`, add `import '../../data/auth/refresh_result.dart';`. Replace the `refreshed != null ? ... : ...` block inside `restoreSession()` with:

```dart
      final result = await refresher
          .refresh(session.tokens.refreshToken)
          .timeout(_restoreSessionRefreshTimeout);
      switch (result) {
        case RefreshSuccess(session: final refreshed):
          state = AuthAuthenticated(refreshed.userId);
        case RefreshFailure():
          // Storage handling on failure is `SessionRefresher`'s
          // responsibility (see RefreshResult's doc comment): a
          // definitively-dead refresh token has already been cleared;
          // a transient local-save failure leaves the old (now expired)
          // session untouched. Either way we fall back to whatever
          // build() set -- AuthUnauthenticated.
          break;
      }
```

(the surrounding `try { ... } on TimeoutException { ... }` structure from the Plan 1b-1 C1 fix is unchanged; on a `TimeoutException`, treat it the same as a `RefreshFailure` by simply not entering the `RefreshSuccess` branch — i.e. leave `state` as `AuthUnauthenticated`.)

- [ ] **Step 9: Update `auth_controller_test.dart`'s `restoreSession` mocks**

In `test/domain/auth/auth_controller_test.dart`, add `import 'package:animeko_flutter/data/auth/refresh_result.dart';`. Find every `when(() => refresher.refresh(any())).thenAnswer((_) async => <expr>);` in the `restoreSession` test group and update `<expr>`:
- Where it previously returned a `StoredSession` directly, wrap it: `RefreshSuccess(<thatSession>)`.
- Where it previously returned `null`, replace with `const RefreshFailure(NetworkError())` (add `import 'package:animeko_flutter/domain/app_error.dart';` if not already present).

All other assertions in these tests (on `AuthController.state` after `restoreSession()` completes) remain unchanged — only the mock's return type changes, not the expected external behavior.

- [ ] **Step 10: Generate code and run the full suite**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 11: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/auth/refresh_result.dart lib/data/auth/session_refresher.dart lib/domain/auth/auth_controller.dart lib/domain/auth/auth_controller.g.dart test/data/auth/refresh_result_test.dart test/data/auth/session_refresher_test.dart test/domain/auth/auth_controller_test.dart
git commit -m "feat: introduce RefreshResult so SessionRefresher no longer swallows the failure reason (Plan 1b-1 follow-up I-B)"
```

---

### Task 10: `AuthController.signOut()` + `refreshSessionForInterceptor()` (Plan 1b-1 follow-up I-A)

**Context:** Today, when `AuthInterceptor` hits a 401 and its injected refresh callback fails, the interceptor just gives up on the current request -- nothing tells `AuthController` the session is dead, so the UI keeps reporting `AuthAuthenticated` forever even though every subsequent request will also 401. This closes follow-up item I-A from `docs/superpowers/plans/2026-08-28-plan1b-1-followups.md` by adding a `signOut()` method plus a `refreshSessionForInterceptor()` method (both directly unit-testable on `AuthController`, reusing the mocktail patterns already established for `restoreSession()`), and delegating `api_client.dart`'s interceptor closure to it.

**Files:**
- Modify: `lib/domain/auth/auth_controller.dart` (add `signOut()` and `refreshSessionForInterceptor()`)
- Modify: `lib/data/api_client.dart` (delegate the interceptor's refresh closure)
- Test: `test/domain/auth/auth_controller_test.dart` (add tests for both new methods)

- [ ] **Step 1: Write the failing tests**

Append to the `AuthController` test group in `test/domain/auth/auth_controller_test.dart` (ensure `import 'package:animeko_flutter/domain/app_error.dart';` is present):

```dart
  group('signOut', () {
    test('clears storage and resets state to AuthUnauthenticated', () async {
      final container = ProviderContainer(overrides: [/* ...existing overrides from this file, plus... */]);
      addTearDown(container.dispose);
      when(() => storage.clear()).thenAnswer((_) async {});

      final controller = container.read(authControllerProvider.notifier);
      await controller.signOut();

      verify(() => storage.clear()).called(1);
      expect(container.read(authControllerProvider), const AuthUnauthenticated());
    });
  });

  group('refreshSessionForInterceptor', () {
    test('returns true on RefreshSuccess without signing out', () async {
      final container = ProviderContainer(overrides: [/* existing overrides */]);
      addTearDown(container.dispose);
      final session = const StoredSession(
        userId: 'user-1',
        tokens: AniTokens(accessToken: 'a', refreshToken: 'r', expiresAtMillis: 1),
      );
      when(() => storage.readSession()).thenAnswer((_) async => session);
      when(() => refresher.refresh('r')).thenAnswer(
        (_) async => RefreshSuccess(session),
      );

      final result = await container
          .read(authControllerProvider.notifier)
          .refreshSessionForInterceptor();

      expect(result, isTrue);
      verifyNever(() => storage.clear());
    });

    test('signs out and returns false on RefreshFailure(AuthExpiredError)', () async {
      final container = ProviderContainer(overrides: [/* existing overrides */]);
      addTearDown(container.dispose);
      final session = const StoredSession(
        userId: 'user-1',
        tokens: AniTokens(accessToken: 'a', refreshToken: 'r', expiresAtMillis: 1),
      );
      when(() => storage.readSession()).thenAnswer((_) async => session);
      when(() => refresher.refresh('r')).thenAnswer(
        (_) async => const RefreshFailure(AuthExpiredError()),
      );
      when(() => storage.clear()).thenAnswer((_) async {});

      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.refreshSessionForInterceptor();

      expect(result, isFalse);
      verify(() => storage.clear()).called(1);
      expect(container.read(authControllerProvider), const AuthUnauthenticated());
    });

    test('returns false without signing out on RefreshFailure(NetworkError)', () async {
      final container = ProviderContainer(overrides: [/* existing overrides */]);
      addTearDown(container.dispose);
      final session = const StoredSession(
        userId: 'user-1',
        tokens: AniTokens(accessToken: 'a', refreshToken: 'r', expiresAtMillis: 1),
      );
      when(() => storage.readSession()).thenAnswer((_) async => session);
      when(() => refresher.refresh('r')).thenAnswer(
        (_) async => const RefreshFailure(NetworkError()),
      );

      final result = await container
          .read(authControllerProvider.notifier)
          .refreshSessionForInterceptor();

      expect(result, isFalse);
      verifyNever(() => storage.clear());
    });

    test('returns false immediately when nothing is stored', () async {
      final container = ProviderContainer(overrides: [/* existing overrides */]);
      addTearDown(container.dispose);
      when(() => storage.readSession()).thenAnswer((_) async => null);

      final result = await container
          .read(authControllerProvider.notifier)
          .refreshSessionForInterceptor();

      expect(result, isFalse);
      verifyNever(() => refresher.refresh(any()));
    });
  });
```

(Use this file's existing `overrides:` list, `storage`/`refresher` mock variable names, and `setUp()` structure exactly as already established earlier in the file for the `restoreSession` tests -- do not introduce new mock instances.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/auth/auth_controller_test.dart`
Expected: FAIL with "The method 'signOut' isn't defined" / "The method 'refreshSessionForInterceptor' isn't defined".

- [ ] **Step 3: Implement `signOut()` and `refreshSessionForInterceptor()`**

In `lib/domain/auth/auth_controller.dart`, inside the `AuthController` class (after `restoreSession()`), add:

```dart
  /// Clears the persisted session and resets [state] to
  /// [AuthUnauthenticated]. Called directly by the UI's "log out" action,
  /// and by [refreshSessionForInterceptor] when a background token
  /// refresh definitively fails (Plan 1a/1b-1 follow-up I-A).
  Future<void> signOut() async {
    final storage = ref.read(secureTokenStorageProvider);
    await storage.clear();
    state = const AuthUnauthenticated();
  }

  /// Called by [AuthInterceptor] when a request gets a 401: attempts a
  /// single token refresh and reports back whether the retry should
  /// proceed. On [AuthExpiredError] the refresh token itself was
  /// rejected by the server -- there is no path back to a valid session,
  /// so this signs the user out (routing the UI back to login) rather
  /// than leaving [state] stuck at a stale [AuthAuthenticated] forever.
  /// Any other failure (e.g. [NetworkError]) is treated as transient and
  /// does not sign the user out.
  Future<bool> refreshSessionForInterceptor() async {
    final storage = ref.read(secureTokenStorageProvider);
    final session = await storage.readSession();
    if (session == null) return false;

    final refresher = ref.read(sessionRefresherProvider);
    final result = await refresher.refresh(session.tokens.refreshToken);
    switch (result) {
      case RefreshSuccess():
        return true;
      case RefreshFailure(error: AuthExpiredError()):
        await signOut();
        return false;
      case RefreshFailure():
        return false;
    }
  }
```

Add `import '../app_error.dart';` to the top of the file if `AuthExpiredError`/`NetworkError` aren't already resolvable (they are transitively imported via `dio_error_mapper.dart`'s import, but importing `app_error.dart` directly here makes the pattern-match on `AuthExpiredError()` clearer to a reader).

- [ ] **Step 4: Run tests to verify they pass**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/auth/auth_controller_test.dart`
Expected: PASS, all tests including the 5 new ones (1 signOut + 4 refreshSessionForInterceptor).

- [ ] **Step 5: Delegate `api_client.dart`'s interceptor closure to `AuthController`**

In `lib/data/api_client.dart`, add `import '../domain/auth/auth_controller.dart';`. In the `dio()` provider, replace the inline refresh closure (the one currently doing `final session = await storage.readSession(); if (session == null) return false; final refreshed = await refresher.refresh(...); return refreshed != null;`) with:

```dart
  dio.interceptors.add(
    AuthInterceptor(
      dio,
      storage,
      () => ref.read(authControllerProvider.notifier).refreshSessionForInterceptor(),
    ),
  );
```

Remove the now-unused `refresher = ref.watch(sessionRefresherProvider);` line from `dio()` if it is no longer referenced elsewhere in that function body (the refresh logic now lives entirely inside `AuthController.refreshSessionForInterceptor()`, which reads `sessionRefresherProvider` itself).

**Note on the resulting import graph:** this creates `api_client.dart` -> `auth_controller.dart` -> `bangumi_oauth_api.dart` -> `api_client.dart`, a cycle across three files. Dart's compiler and analyzer fully support this (unlike some stricter module systems) and it will not cause a build or analysis error -- confirmed acceptable as a deliberate, small exception to the general data-depends-on-domain direction, justified by the approved design doc's explicit intent for the interceptor to reach `AuthController.signOut()` on a definitive auth failure.

- [ ] **Step 6: Generate code and run the full suite**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass. (No new test needed for `dio()`'s wiring itself -- consistent with the project's existing convention that this provider's thin wiring-only body doesn't need its own dedicated unit test.)

- [ ] **Step 7: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/domain/auth/auth_controller.dart lib/domain/auth/auth_controller.g.dart lib/data/api_client.dart lib/data/api_client.g.dart test/domain/auth/auth_controller_test.dart
git commit -m "feat: add AuthController.signOut() so a dead session routes back to login (Plan 1b-1 follow-up I-A)"
```

### Task 11: UI screens, bottom-nav shell, and auth-gated router

**Files:**
- Create: `lib/ui/home/home_screen.dart`
- Create: `lib/ui/search/search_screen.dart`
- Create: `lib/ui/schedule/schedule_screen.dart`
- Create: `lib/ui/shell/main_shell.dart`
- Modify: `lib/app/router.dart` (full rewrite)
- Modify: `lib/app/main.dart`
- Test: `test/app/router_test.dart`

This is the final task: it wires everything built in Tasks 1-10 into a real, navigable app. `LoginScreen` (built in Plan 1a) is unchanged. `router.dart` is rewritten from a single static route into a Riverpod-generated `GoRouter` provider with an auth-gated `redirect:` callback and a bottom-navigation `StatefulShellRoute` wrapping Home/Search/Schedule.

- [ ] **Step 1: Write `HomeScreen`**

Create `lib/ui/home/home_screen.dart`:

```dart
// lib/ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/home/home_controller.dart';
import '../../domain/subject_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeData = ref.watch(homeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Animeko')),
      body: homeData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load home: $error')),
        data: (data) => ListView(
          children: [
            _SubjectCardSection(title: 'Trending', cards: data.trending),
            _SubjectCardSection(title: 'Recommended', cards: data.recommendations),
          ],
        ),
      ),
    );
  }
}

class _SubjectCardSection extends StatelessWidget {
  const _SubjectCardSection({required this.title, required this.cards});

  final String title;
  final List<SubjectCard> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Expanded(
                        child: card.imageUrl != null
                            ? Image.network(card.imageUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.grey.shade300),
                      ),
                      Text(
                        card.nameCn ?? card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

No dedicated unit test for `HomeScreen` in this task -- it is exercised indirectly by Step 6's router integration test, which asserts its `AppBar` title renders after a successful login. This mirrors Plan 1a's `LoginScreen`, which also got its coverage from a router-level test plus its own dedicated widget test; a dedicated `HomeScreen` widget test with mocked `homeControllerProvider` states is a reasonable fast-follow but not required for this plan's Definition of Done.

- [ ] **Step 2: Write `SearchScreen`**

Create `lib/ui/search/search_screen.dart`:

```dart
// lib/ui/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/search/search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Search subjects...'),
          onChanged: (value) => ref
              .read(searchControllerProvider.notifier)
              .search(keywords: value),
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Search failed: $error')),
        data: (cards) => ListView.builder(
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return ListTile(
              leading: card.imageUrl != null
                  ? Image.network(card.imageUrl!, width: 48, fit: BoxFit.cover)
                  : const SizedBox(width: 48),
              title: Text(card.nameCn ?? card.name),
              subtitle: card.tags != null && card.tags!.isNotEmpty
                  ? Text(card.tags!.join(', '))
                  : null,
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write `ScheduleScreen`**

Create `lib/ui/schedule/schedule_screen.dart`:

```dart
// lib/ui/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/schedule/schedule_controller.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(scheduleControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load schedule: $error')),
        data: (schedule) => ListView.builder(
          itemCount: schedule.length,
          itemBuilder: (context, index) {
            final day = schedule[index];
            return ExpansionTile(
              title: Text(day.date),
              children: day.subjects
                  .map(
                    (card) => ListTile(
                      leading: card.imageUrl != null
                          ? Image.network(card.imageUrl!, width: 40, fit: BoxFit.cover)
                          : const SizedBox(width: 40),
                      title: Text(card.nameCn ?? card.name),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write `MainShell` (bottom-nav)**

Create `lib/ui/shell/main_shell.dart`:

```dart
// lib/ui/shell/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Schedule'),
        ],
      ),
    );
  }
}
```

(`StatefulNavigationShell`/`goBranch` are the go_router 17.5.0 APIs verified directly against the installed package source, per the design research for this plan.)

- [ ] **Step 5: Rewrite `router.dart` with an auth-gated `redirect:` and a bottom-nav shell**

Replace the full contents of `lib/app/router.dart`:

```dart
// lib/app/router.dart
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth/auth_controller.dart';
import '../domain/auth/auth_state.dart';
import '../ui/auth/login_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/schedule/schedule_screen.dart';
import '../ui/search/search_screen.dart';
import '../ui/shell/main_shell.dart';

part 'router.g.dart';

/// Bridges Riverpod's [authControllerProvider] state changes into
/// go_router's `refreshListenable`, which is what triggers the `redirect:`
/// callback to be re-evaluated on an *external* state change (e.g. login
/// succeeding while the user is still sitting on the `/login` route).
/// Without this, go_router only re-runs `redirect:` on navigation events,
/// so a successful login would never automatically navigate the user away
/// from the login screen.
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

@riverpod
GoRouter appRouter(Ref ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, __) => notifier.notify());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/search', builder: (context, state) => const SearchScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/schedule', builder: (context, state) => const ScheduleScreen())],
          ),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 6: Update `main.dart` to watch the new router provider**

In `lib/app/main.dart`, change `AnimekoFlutterApp` from a `StatelessWidget` to a `ConsumerWidget`:

```dart
class AnimekoFlutterApp extends ConsumerWidget {
  const AnimekoFlutterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(title: 'Animeko', routerConfig: router);
  }
}
```

Add `import 'package:flutter_riverpod/flutter_riverpod.dart';` and `import '../app/router.dart';` (or the correct relative path) if not already present. The rest of `main()` (the `WidgetsFlutterBinding.ensureInitialized()` / `ProviderContainer` / `await ...restoreSession()` / `UncontrolledProviderScope` structure) is unchanged.

- [ ] **Step 7: Write the router integration test**

Create `test/app/router_test.dart`:

```dart
// test/app/router_test.dart
import 'package:animeko_flutter/app/router.dart';
import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal fake that lets the test drive [AuthController]'s state
/// directly, mirroring the `_FakeAuthController` pattern already used in
/// Plan 1a's `login_screen_test.dart`.
class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

void main() {
  testWidgets('unauthenticated user sees the login screen, authenticated user sees Home', (
    tester,
  ) async {
    final fake = _FakeAuthController();
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in with Bangumi'), findsOneWidget);

    fake.state = const AuthAuthenticated('user-1');
    await tester.pumpAndSettle();

    expect(find.text('Animeko'), findsOneWidget);
    expect(find.text('Log in with Bangumi'), findsNothing);
  });
}
```

- [ ] **Step 8: Run the test to verify it fails, then passes after Steps 1-6**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/app/router_test.dart`
Expected (before Steps 1-6 exist): FAIL with a "target of URI doesn't exist" style error for the missing screen/shell files. After completing Steps 1-6: PASS, 1 test.

- [ ] **Step 9: Generate code and run the full suite**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
Expected: clean modulo 3 known pre-existing info lints; all tests pass.

- [ ] **Step 10: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/ui/home/home_screen.dart lib/ui/search/search_screen.dart lib/ui/schedule/schedule_screen.dart lib/ui/shell/main_shell.dart lib/app/router.dart lib/app/router.g.dart lib/app/main.dart test/app/router_test.dart
git commit -m "feat: add Home/Search/Schedule screens with bottom-nav shell and auth-gated routing"
```

## Definition of Done

- [ ] `flutter test` passes with zero failures (expected final count: 69 baseline from Plan 1b-1 + all tests added across Tasks 1-11 of this plan).
- [ ] `flutter analyze` is clean modulo the 3 known pre-existing info-level lints (`depend_on_referenced_packages` x2, `library_private_types_in_public_api` x1).
- [ ] `flutter build macos --debug` succeeds.
- [ ] Manual network verification against the real production server (`https://api.animeko.org`), logged in with a real Bangumi account:
  - [ ] Home tab shows a non-empty Trending row and a non-empty Recommended row.
  - [ ] Search tab: typing a keyword (e.g. an anime title fragment) returns matching results after the debounce delay.
  - [ ] Schedule tab shows entries grouped by date for the current week. If this is empty/errors, check whether the `today`/`timeZone` string format guessed in Task 8 (`YYYY-MM-DD` / `+HH:MM`) matches what the real server expects -- this was an explicitly flagged unverified assumption.
  - [ ] Bottom navigation switches between Home/Search/Schedule and preserves each tab's own scroll/state when switching away and back (`StatefulShellRoute.indexedStack`'s default behavior).
  - [ ] Visiting the app while unauthenticated redirects to `/login`.
  - [ ] Completing login while on `/login` automatically navigates to `/home` (proves the `refreshListenable` wiring works against a real, not faked, `AuthController`).
- [ ] Plan 1b-1 follow-up I-A is resolved: a 401 that the `AuthInterceptor` cannot refresh past (real `AuthExpiredError`) results in `AuthController.signOut()` being called, which -- via the redirect above -- routes the user back to `/login`. (Covered by unit tests in Task 10; the manual network check above exercises the happy path but not this specific failure path, which is impractical to trigger against the real server on demand.)
- [ ] Plan 1b-1 follow-up I-B is resolved: `SessionRefresher.refresh()` returns a `RefreshResult` that preserves the specific `AppError` on failure, verified by Task 9's unit tests.
- [ ] All 11 task commits from this plan are present in `git log` on `main`.

## Out of Scope (confirmed unchanged from the approved design doc)

- Subject detail pages, self-rating, and collection management (Plan 1b-3).
- Cloud sync of collection/progress state (Plan 1b-4).
- Wiring the Drift local database built in Plan 1b-1 as a cache for any of this plan's data (deferred to Plan 1b-3, which needs it for collection persistence).
- "Continue watching" home section (needs Plan 1b-3's collection state).
- Season browsing in Search, rating-range Search filtering (per the approved design's explicit scope-narrowing decision).
- Plan 1a/1b-1 follow-ups I1/I2/I3/M2/M4-M10 (remain tracked in `docs/superpowers/plans/2026-08-28-plan1a-followups.md`, untouched by this plan).
