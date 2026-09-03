# Home Page Carousel + Infinite Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home page's two thin horizontal rows with an auto-advancing hero carousel for "Trending" and a true infinite-scroll grid for "Recommended", merged into one continuously-scrolling page, with Chinese section titles.

**Architecture:** Split the old combined `HomeController`/`HomeData` into two independent providers -- a bare `trendingProvider` (unpaginated, small curated list) and a paginated `HomeRecommendationsController` (mirrors the existing `MyCollectionsController` "page + hasMore, loadMore appends" shape). The UI becomes a single `CustomScrollView` with slivers: a `TrendingCarousel` (new, dependency-free `StatefulWidget` built on Flutter's native Material 3 `CarouselView.weighted`) followed by a `SliverGrid` of `AnimeCoverCard`s, with scroll-to-bottom triggering `loadMore()` (same `NotificationListener<ScrollEndNotification>` pattern already used by `MyCollectionScreen`).

**Tech Stack:** Flutter's built-in `CarouselView`/`CarouselController` (`package:flutter/material.dart`, no new package), `flutter_riverpod` 3.3.1 / `riverpod_annotation` 4.0.2, `mocktail` for test mocks, `dio`.

**Design doc:** `docs/superpowers/specs/2026-09-03-home-carousel-infinite-scroll-design.md`

---

## Global Constraints (apply to every task below)

- Run `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:/Users/portz/soft/dart-sdk/flutter/bin/cache/dart-sdk/bin:$PATH"` before any `flutter`/`dart` command.
- `AsyncValue` in this project's riverpod (3.2.1) has **no `.valueOrNull` getter** -- always use the nullable `.value` getter instead.
- After any `dart run build_runner build`, run `git status` and `git checkout --` any incidentally-modified `pubspec.lock`/`macos/Podfile.lock` before committing, so each task's commit diff stays clean.
- Current baseline before this plan: `flutter test` **301/301 passing**; `flutter analyze` **21 known issues** in 3 categories (2 `use_null_aware_elements` in `lib/data/home/home_recommendations_api.dart:24-25`; 18 `depend_on_referenced_packages` for test files importing plain `package:riverpod`; 1 `library_private_types_in_public_api` in `test/ui/auth/login_screen_test.dart:26`). Only test files importing plain `package:riverpod` (not `package:flutter_riverpod`) add to the `depend_on_referenced_packages` count.

---

### Task 1: `trendingProvider` (replaces the trending half of `HomeController`)

**Files:**
- Create: `lib/domain/home/trending_controller.dart`
- Create: `test/domain/home/trending_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/home/trending_controller_test.dart`:

```dart
import 'package:animeko_flutter/data/home/trends_api.dart';
import 'package:animeko_flutter/data/home/trends_models.dart';
import 'package:animeko_flutter/domain/home/trending_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockTrendsApi extends Mock implements TrendsApi {}

void main() {
  late MockTrendsApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockTrendsApi();
    container = ProviderContainer(overrides: [trendsApiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
  });

  test('maps TrendsResponse.trendingSubjects to SubjectCard', () async {
    when(() => api.getTrends()).thenAnswer(
      (_) async => const TrendsResponse(
        trendingSubjects: [
          TrendingSubject(bangumiId: 1, nameCn: 'A', imageLarge: 'a.jpg'),
          TrendingSubject(bangumiId: 2, nameCn: 'B', imageLarge: 'b.jpg'),
        ],
      ),
    );

    final result = await container.read(trendingProvider.future);

    expect(result, hasLength(2));
    expect(result[0].id, 1);
    expect(result[0].name, 'A');
    expect(result[0].imageUrl, 'a.jpg');
    expect(result[1].id, 2);
  });

  test('returns an empty list when there are no trending subjects', () async {
    when(() => api.getTrends()).thenAnswer(
      (_) async => const TrendsResponse(trendingSubjects: []),
    );

    final result = await container.read(trendingProvider.future);

    expect(result, isEmpty);
  });
}
```

- [ ] **Step 2: Run test, confirm it fails**

Run: `flutter test test/domain/home/trending_controller_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:animeko_flutter/domain/home/trending_controller.dart'.`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/home/trending_controller.dart`:

```dart
// lib/domain/home/trending_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home/trends_api.dart';
import '../subject_card.dart';

part 'trending_controller.g.dart';

/// The home page's "trending" carousel data. `GET /v1/trends` has no
/// pagination params -- it's a small, curated, fixed-size list meant for
/// a carousel, not a scrollable feed (see the design doc).
@riverpod
Future<List<SubjectCard>> trending(Ref ref) async {
  final api = ref.watch(trendsApiProvider);
  final response = await api.getTrends();
  return response.trendingSubjects.map(SubjectCard.fromTrending).toList();
}
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then check `git status` for incidental `pubspec.lock` changes and `git checkout -- pubspec.lock` if present.

- [ ] **Step 5: Run test, confirm it passes**

Run: `flutter test test/domain/home/trending_controller_test.dart`
Expected: PASS -- 2/2 tests pass.

- [ ] **Step 6: Full regression**

Run: `flutter test` -- expect **303/303** passing (301 baseline + 2 new).
Run: `flutter analyze` -- expect **21 issues, unchanged** (this test file imports plain `package:riverpod`, so it DOES add 1 to the `depend_on_referenced_packages` count -- but that count is already included in "21" as the ongoing baseline convention; verify the exact number stays at the same *category counts*, i.e. confirm no new issue *category* appears, and that the `depend_on_referenced_packages` count is exactly one higher than before this task).

- [ ] **Step 7: Commit**

```bash
git add lib/domain/home/trending_controller.dart lib/domain/home/trending_controller.g.dart test/domain/home/trending_controller_test.dart
git commit -m "feat(home): add trendingProvider"
```

---

### Task 2: `HomeRecommendationsController` (replaces the recommendations half of `HomeController`)

**Files:**
- Create: `lib/domain/home/home_recommendations_controller.dart`
- Create: `test/domain/home/home_recommendations_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/home/home_recommendations_controller_test.dart`:

```dart
import 'package:animeko_flutter/data/home/home_recommendations_api.dart';
import 'package:animeko_flutter/data/home/home_recommendations_models.dart';
import 'package:animeko_flutter/domain/home/home_recommendations_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockHomeRecommendationsApi extends Mock implements HomeRecommendationsApi {}

void main() {
  late MockHomeRecommendationsApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockHomeRecommendationsApi();
    container = ProviderContainer(
      overrides: [homeRecommendationsApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  group('build', () {
    test('fetches the first page at offset 0 and maps to SubjectCard', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
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

      final result = await container.read(homeRecommendationsControllerProvider.future);

      expect(result.items, hasLength(1));
      expect(result.items.single.name, 'B');
      expect(result.hasMore, isFalse);
    });

    test('hasMore is true when items.length < total', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
        (_) async => HomeRecommendationsResponse(
          total: 30,
          items: List.generate(
            20,
            (i) => SubjectRecommendation(
              subjectName: 'S$i',
              subjectNameCn: 'S$i-cn',
              imageUrl: 's$i.jpg',
              desc1: '',
              desc2: '',
              subjectId: i,
            ),
          ),
        ),
      );

      final result = await container.read(homeRecommendationsControllerProvider.future);

      expect(result.hasMore, isTrue);
    });

    test('surfaces an error from the API', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenThrow(Exception('boom'));

      // With riverpod 3.2.1 (pinned by this repo), an autoDispose
      // AsyncNotifier whose build() rejects, when read via `.future` with
      // no persistent listener, races the auto-dispose scheduler and
      // never settles with the real error under `package:test` -- it
      // hangs until timeout. Keep a listener alive + `container.pump()` +
      // a synchronous `container.read()` (returns AsyncValue) instead,
      // matching riverpod's own test suite and this repo's precedent
      // (the deleted `home_controller_test.dart`'s error-path test).
      final sub = container.listen(homeRecommendationsControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.pump();

      final value = container.read(homeRecommendationsControllerProvider);
      expect(value.hasError, isTrue);
      expect(value.error, isA<Exception>());
    });
  });

  group('loadMore', () {
    test('fetches the next page using the current length as offset and appends it', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
        (_) async => HomeRecommendationsResponse(
          total: 21,
          items: List.generate(
            20,
            (i) => SubjectRecommendation(
              subjectName: 'S$i',
              subjectNameCn: 'S$i-cn',
              imageUrl: 's$i.jpg',
              desc1: '',
              desc2: '',
              subjectId: i,
            ),
          ),
        ),
      );
      await container.read(homeRecommendationsControllerProvider.future);

      when(() => api.getRecommendations(offset: 20, limit: 20)).thenAnswer(
        (_) async => const HomeRecommendationsResponse(
          total: 21,
          items: [
            SubjectRecommendation(
              subjectName: 'Last',
              subjectNameCn: 'Last-cn',
              imageUrl: 'last.jpg',
              desc1: '',
              desc2: '',
              subjectId: 20,
            ),
          ],
        ),
      );

      await container.read(homeRecommendationsControllerProvider.notifier).loadMore();

      final result = container.read(homeRecommendationsControllerProvider).value!;
      expect(result.items, hasLength(21));
      expect(result.items.last.id, 20);
      expect(result.hasMore, isFalse);
    });

    test('does nothing when hasMore is already false', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
        (_) async => const HomeRecommendationsResponse(
          total: 1,
          items: [
            SubjectRecommendation(
              subjectName: 'Only',
              subjectNameCn: 'Only-cn',
              imageUrl: 'only.jpg',
              desc1: '',
              desc2: '',
              subjectId: 1,
            ),
          ],
        ),
      );
      await container.read(homeRecommendationsControllerProvider.future);

      await container.read(homeRecommendationsControllerProvider.notifier).loadMore();

      verifyNever(() => api.getRecommendations(offset: 1, limit: 20));
    });
  });
}
```

- [ ] **Step 2: Run test, confirm it fails**

Run: `flutter test test/domain/home/home_recommendations_controller_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:animeko_flutter/domain/home/home_recommendations_controller.dart'.`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/home/home_recommendations_controller.dart`:

```dart
// lib/domain/home/home_recommendations_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home/home_recommendations_api.dart';
import '../subject_card.dart';

part 'home_recommendations_controller.g.dart';

const _pageSize = 20;

/// The loaded slice of the home page's "recommendations" grid plus
/// whether another page is available, using the server's real `total`
/// field (unlike `MyCollectionsController`'s "short page = last page"
/// heuristic, which exists there specifically because
/// `PaginatedCollections.total` was found unreliable on that different
/// endpoint -- no such issue here, see the design doc).
class HomeRecommendationsPage {
  const HomeRecommendationsPage({required this.items, required this.hasMore});

  final List<SubjectCard> items;
  final bool hasMore;
}

@riverpod
class HomeRecommendationsController extends _$HomeRecommendationsController {
  @override
  Future<HomeRecommendationsPage> build() async {
    final api = ref.watch(homeRecommendationsApiProvider);
    final response = await api.getRecommendations(offset: 0, limit: _pageSize);
    return HomeRecommendationsPage(
      items: response.items.map(SubjectCard.fromRecommendation).toList(),
      hasMore: response.items.length < response.total,
    );
  }

  /// Fetches the next page (offset = current list length) and appends
  /// it. No pull-to-refresh (design doc, YAGNI) -- leaving and
  /// re-entering the page re-runs [build] instead.
  Future<void> loadMore() async {
    final current = await future;
    if (!current.hasMore) return;
    final api = ref.read(homeRecommendationsApiProvider);
    final response = await api.getRecommendations(
      offset: current.items.length,
      limit: _pageSize,
    );
    final newItems = response.items.map(SubjectCard.fromRecommendation).toList();
    state = AsyncData(
      HomeRecommendationsPage(
        items: [...current.items, ...newItems],
        hasMore: current.items.length + newItems.length < response.total,
      ),
    );
  }
}
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then check `git status` for incidental `pubspec.lock` changes and `git checkout -- pubspec.lock` if present.

- [ ] **Step 5: Run test, confirm it passes**

Run: `flutter test test/domain/home/home_recommendations_controller_test.dart`
Expected: PASS -- 5/5 tests pass.

- [ ] **Step 6: Full regression**

Run: `flutter test` -- expect **308/308** passing (303 + 5 new).
Run: `flutter analyze` -- expect the same 3 known categories, `depend_on_referenced_packages` one higher than after Task 1 (this test file also imports plain `package:riverpod`).

- [ ] **Step 7: Commit**

```bash
git add lib/domain/home/home_recommendations_controller.dart lib/domain/home/home_recommendations_controller.g.dart test/domain/home/home_recommendations_controller_test.dart
git commit -m "feat(home): add HomeRecommendationsController"
```

---

### Task 3: `TrendingCarousel` widget

**Files:**
- Create: `lib/ui/home/trending_carousel.dart`
- Create: `test/ui/home/trending_carousel_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ui/home/trending_carousel_test.dart`:

```dart
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/home/trending_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cards = [
  SubjectCard(id: 1, name: 'Foo', nameCn: 'Foo', imageUrl: 'https://example.com/1.png'),
  SubjectCard(id: 2, name: 'Bar', nameCn: 'Bar', imageUrl: 'https://example.com/2.png'),
  SubjectCard(id: 3, name: 'Baz', nameCn: 'Baz', imageUrl: 'https://example.com/3.png'),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(height: 200, child: child)),
  );
}

void main() {
  testWidgets("renders a CarouselView with each card's title", (tester) async {
    await tester.pumpWidget(_wrap(const TrendingCarousel(cards: _cards, onTap: _noop)));
    await tester.pump();

    expect(find.byType(CarouselView), findsOneWidget);
    expect(find.text('Foo'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
    expect(find.text('Baz'), findsOneWidget);
  });

  testWidgets('tapping an item calls onTap with that card', (tester) async {
    SubjectCard? tapped;
    await tester.pumpWidget(
      _wrap(TrendingCarousel(cards: _cards, onTap: (card) => tapped = card)),
    );
    await tester.pump();

    await tester.tap(find.text('Foo'));
    await tester.pump();

    expect(tapped?.id, 1);
  });

  testWidgets('renders nothing when there are no cards', (tester) async {
    await tester.pumpWidget(_wrap(const TrendingCarousel(cards: [], onTap: _noop)));
    await tester.pump();

    expect(find.byType(CarouselView), findsNothing);
  });

  testWidgets('auto-advances to the next item after 5 seconds', (tester) async {
    final controller = CarouselController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(TrendingCarousel(cards: _cards, onTap: _noop, controller: controller)),
    );
    await tester.pump();

    expect(controller.offset, 0.0);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 350));

    expect(controller.offset, greaterThan(0.0));
  });
}

void _noop(SubjectCard card) {}
```

- [ ] **Step 2: Run test, confirm it fails**

Run: `flutter test test/ui/home/trending_carousel_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:animeko_flutter/ui/home/trending_carousel.dart'.`

- [ ] **Step 3: Write the implementation**

Create `lib/ui/home/trending_carousel.dart`:

```dart
// lib/ui/home/trending_carousel.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/subject_card.dart';

/// An auto-advancing hero carousel for the home page's "trending"
/// section, built on Flutter's Material 3 `CarouselView.weighted`
/// (matching the reference Animeko app's `HorizontalCenteredHeroCarousel`).
/// Owns its own [CarouselController] and auto-advance [Timer] -- no
/// Riverpod dependency, so it's independently testable (same pattern as
/// Phase D's `SubjectBlurredHeader`/`SubjectTagsRow`).
class TrendingCarousel extends StatefulWidget {
  const TrendingCarousel({super.key, required this.cards, required this.onTap, this.controller});

  final List<SubjectCard> cards;
  final void Function(SubjectCard card) onTap;

  /// Exposed so tests can inspect [CarouselController.offset] after the
  /// auto-advance timer fires. When omitted, the widget creates and owns
  /// its own controller.
  final CarouselController? controller;

  @override
  State<TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends State<TrendingCarousel> {
  late final CarouselController _controller;
  late final bool _ownsController;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? CarouselController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.cards.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _currentIndex = (_currentIndex + 1) % widget.cards.length;
      _controller.animateToItem(_currentIndex);
    });
  }

  void _pauseTimer() => _timer?.cancel();

  @override
  void dispose() {
    _timer?.cancel();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _pauseTimer();
        } else if (notification is ScrollEndNotification) {
          _startTimer();
        }
        return false;
      },
      child: CarouselView.weighted(
        controller: _controller,
        flexWeights: const [1, 7, 1],
        itemSnapping: true,
        onTap: (index) => widget.onTap(widget.cards[index]),
        children: widget.cards.map(_buildItem).toList(),
      ),
    );
  }

  Widget _buildItem(SubjectCard card) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            card.imageUrl ?? '',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Text(
                card.nameCn ?? card.name,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test, confirm it passes**

Run: `flutter test test/ui/home/trending_carousel_test.dart`
Expected: PASS -- 4/4 tests pass. (If the auto-advance test is flaky because the animation hasn't finished within 350ms, increase that pump's duration -- `CarouselController.animateToItem`'s default duration is 300ms, so 350ms should be enough headroom, but adjust if needed.)

- [ ] **Step 5: Full regression**

Run: `flutter test` -- expect **312/312** passing (308 + 4 new).
Run: `flutter analyze` -- expect the same 3 known categories; this test file imports `flutter/material.dart`/`flutter_test.dart` only (no plain `package:riverpod`), so `depend_on_referenced_packages` should NOT increase from this task.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/home/trending_carousel.dart test/ui/home/trending_carousel_test.dart
git commit -m "feat(home): add TrendingCarousel"
```

---

### Task 4: Rewrite `HomeScreen`, delete `HomeController`, fix `router_test.dart`

**Files:**
- Delete: `lib/domain/home/home_controller.dart`
- Delete: `lib/domain/home/home_controller.g.dart`
- Delete: `test/domain/home/home_controller_test.dart`
- Modify: `lib/ui/home/home_screen.dart`
- Modify: `test/ui/home/home_screen_test.dart`
- Modify: `test/app/router_test.dart`

- [ ] **Step 1: Delete the old controller and its test**

```bash
rm lib/domain/home/home_controller.dart lib/domain/home/home_controller.g.dart test/domain/home/home_controller_test.dart
```

- [ ] **Step 2: Write the new (failing) `HomeScreen` test**

Overwrite `test/ui/home/home_screen_test.dart`:

```dart
import 'package:animeko_flutter/domain/home/home_recommendations_controller.dart';
import 'package:animeko_flutter/domain/home/trending_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_cover_card.dart';
import 'package:animeko_flutter/ui/home/home_screen.dart';
import 'package:animeko_flutter/ui/home/trending_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHomeRecommendationsController extends HomeRecommendationsController {
  @override
  Future<HomeRecommendationsPage> build() async {
    return const HomeRecommendationsPage(
      items: [
        SubjectCard(id: 2, name: 'Bar', nameCn: 'Bar', imageUrl: 'https://example.com/2.png'),
      ],
      hasMore: false,
    );
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      trendingProvider.overrideWith(
        (ref) async => const [
          SubjectCard(id: 1, name: 'Foo', nameCn: 'Foo', imageUrl: 'https://example.com/1.png'),
        ],
      ),
      homeRecommendationsControllerProvider.overrideWith(
        () => _FakeHomeRecommendationsController(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  // Bounded pumps, not pumpAndSettle(): TrendingCarousel owns a
  // Timer.periodic that keeps scheduling frames every simulated 5
  // seconds for as long as the widget stays mounted, so pumpAndSettle()
  // would never see "no more frames scheduled".
  testWidgets('shows the trending carousel and recommendations grid with Chinese titles', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('最近热门'), findsOneWidget);
    expect(find.text('为你推荐'), findsOneWidget);
    expect(find.byType(TrendingCarousel), findsOneWidget);
    expect(find.text('Foo'), findsOneWidget);
    expect(find.byType(AnimeCoverCard), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
  });

  testWidgets('AppBar shows the unified account/collection/settings actions', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test, confirm it fails**

Run: `flutter test test/ui/home/home_screen_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:animeko_flutter/domain/home/home_recommendations_controller.dart'.` (imported by the test but `lib/ui/home/home_screen.dart` still references the just-deleted `home_controller.dart`, so this will also show as a broken import in the production file -- both are expected at this point since the implementation hasn't been rewritten yet.)

- [ ] **Step 4: Rewrite the implementation**

Overwrite `lib/ui/home/home_screen.dart`:

```dart
// lib/ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/home/home_recommendations_controller.dart';
import '../../domain/home/trending_controller.dart';
import '../../domain/subject_card.dart';
import '../common/anime_cover_card.dart';
import '../common/app_action_bar.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';
import 'trending_carousel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      await ref.read(homeRecommendationsControllerProvider.notifier).loadMore();
    } catch (_) {
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trending = ref.watch(trendingProvider);
    final recommendations = ref.watch(homeRecommendationsControllerProvider);
    final padding = pagePadding(context);
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Animeko'), actions: buildStandardActions(context)),
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          final page = recommendations.value;
          final metrics = notification.metrics;
          if (page != null &&
              page.hasMore &&
              !_loadingMore &&
              metrics.pixels >= metrics.maxScrollExtent - 40) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _TrendingSection(
                trending: trending,
                onRetry: () => ref.invalidate(trendingProvider),
              ),
            ),
            const SliverToBoxAdapter(child: _SectionTitle('为你推荐')),
            ...recommendations.when(
              loading: () => const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (error, stack) => [
                SliverToBoxAdapter(
                  child: ErrorRetryView(
                    message: 'Failed to load recommendations: $error',
                    onRetry: () => ref.invalidate(homeRecommendationsControllerProvider),
                  ),
                ),
              ],
              data: (recPage) => [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns(width),
                      childAspectRatio: 0.55,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final card = recPage.items[index];
                        return AnimeCoverCard(
                          imageUrl: card.imageUrl ?? '',
                          title: card.nameCn ?? card.name,
                          onTap: () => openSubjectDetail(context, card),
                        );
                      },
                      childCount: recPage.items.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RecommendationsFooter(
                    hasMore: recPage.hasMore,
                    loading: _loadingMore,
                    failed: _loadMoreFailed,
                    onRetry: _loadMore,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// At least 3 columns even on narrow phones; scales up on wider screens
/// (design doc: 固定3列，宽屏自适应). Target column width ~130dp.
int _gridColumns(double width) => (width / 130).floor().clamp(3, 8);

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final padding = pagePadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 16, padding, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.trending, required this.onRetry});

  final AsyncValue<List<SubjectCard>> trending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return trending.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) =>
          ErrorRetryView(message: 'Failed to load trending: $error', onRetry: onRetry),
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('最近热门'),
            SizedBox(
              height: 220,
              child: TrendingCarousel(
                cards: cards,
                onTap: (card) => openSubjectDetail(context, card),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecommendationsFooter extends StatelessWidget {
  const _RecommendationsFooter({
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final bool hasMore;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Center(child: TextButton(onPressed: onRetry, child: const Text('加载失败，点击重试')));
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }
}
```

- [ ] **Step 5: Run test, confirm it passes**

Run: `flutter test test/ui/home/home_screen_test.dart`
Expected: PASS -- 2/2 tests pass.

- [ ] **Step 6: Fix `router_test.dart`**

`router_test.dart` has three places that reference the now-deleted `homeControllerProvider` or that will break because `HomeScreen` now contains `TrendingCarousel`'s live `Timer.periodic` (which keeps scheduling frames for as long as `HomeScreen` stays mounted -- including when it's still mounted-but-obscured beneath a pushed route, since `Navigator.push` does not dispose the page underneath). Read the current file first:

Run: `cat test/app/router_test.dart` (or use the Read tool) to confirm line numbers before editing, since exact line numbers may have shifted since this plan was written.

Make these 3 edits to `test/app/router_test.dart`:

**Edit A** -- update the comment above the first bounded-pump pair (originally around line 50-55) from:

```dart
    fake.state = const AuthAuthenticated('user-1');
    // Not pumpAndSettle(): HomeScreen's homeControllerProvider makes a real
    // (un-mocked) network call and stays in AsyncLoading, whose
    // CircularProgressIndicator animates indefinitely -- pumpAndSettle()
    // never sees "no more frames scheduled" and times out. A couple of
    // bounded pumps is enough for the refreshListenable-triggered redirect
    // and the route transition to complete.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
```

to:

```dart
    fake.state = const AuthAuthenticated('user-1');
    // Not pumpAndSettle(): HomeScreen's trendingProvider and
    // homeRecommendationsControllerProvider make real (un-mocked) network
    // calls and stay in AsyncLoading, and TrendingCarousel's auto-advance
    // Timer keeps scheduling a new animation frame every simulated 5
    // seconds for as long as it's mounted -- pumpAndSettle() never sees
    // "no more frames scheduled" and times out. A couple of bounded pumps
    // is enough for the refreshListenable-triggered redirect and the
    // route transition to complete.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
```

**Edit B** -- in the `'navigating to /account renders AccountScreen with the self profile'` test, change:

```dart
    router!.push('/account');
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
```

to:

```dart
    router!.push('/account');
    // Not pumpAndSettle(): the previous /home route (with its
    // auto-advancing TrendingCarousel Timer) stays mounted beneath the
    // pushed route, so a new frame keeps getting scheduled every
    // simulated 5 seconds and pumpAndSettle() never settles. A couple of
    // bounded pumps is enough for the push transition and
    // selfUserProvider's fake future to resolve.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Alice'), findsOneWidget);
```

**Edit C** -- in the `'navigating to /settings/proxy renders ProxySettingsScreen'` test, change:

```dart
    router!.push('/settings/proxy');
    await tester.pumpAndSettle();

    expect(find.text('代理设置'), findsWidgets);
```

to:

```dart
    router!.push('/settings/proxy');
    // Not pumpAndSettle(): same reason as the /account test above -- the
    // previous /home route's TrendingCarousel Timer keeps the widget
    // tree scheduling frames while it's mounted underneath.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('代理设置'), findsWidgets);
```

- [ ] **Step 7: Run the router test, confirm it still passes**

Run: `flutter test test/app/router_test.dart`
Expected: PASS -- all 4 tests pass.

- [ ] **Step 8: Full regression**

Run: `flutter test` -- expect **314/314** passing (312 + 2 rewritten `home_screen_test.dart` tests; net test count is the same as before this task since 2 old tests were replaced by 2 new ones, and the 2 deleted `home_controller_test.dart` tests were already removed from the baseline by deleting that file -- recompute from the actual `flutter test` summary line rather than trusting this number blindly, since deletions and additions happened in the same task).
Run: `flutter analyze` -- expect the same 3 known categories, with `depend_on_referenced_packages` **decreased by 1** relative to after Task 3 (the deleted `test/domain/home/home_controller_test.dart` imported plain `package:riverpod`, and it's gone now) but the newly rewritten `test/ui/home/home_screen_test.dart` imports `flutter_riverpod` (not plain `riverpod`), so it doesn't add anything back. Confirm no new issue *category* appears.

- [ ] **Step 9: Commit**

```bash
git add lib/ui/home/home_screen.dart test/ui/home/home_screen_test.dart test/app/router_test.dart
git add -u lib/domain/home/home_controller.dart lib/domain/home/home_controller.g.dart test/domain/home/home_controller_test.dart
git commit -m "feat(home): rewrite HomeScreen as a carousel + infinite-scroll grid"
```

(The second `git add -u` line stages the deletions of the three removed files; `git add -u` only stages changes to already-tracked files, which is exactly what's needed here alongside the first line's new/modified files.)

---

## Definition of Done

- `flutter test` passes in full (verify the exact final count via the test run's own summary line; starting from the 301 baseline, net change is +2 (Task 1) +5 (Task 2) +4 (Task 3) +0 (Task 4, since 2 old tests were replaced 1:1 and the 2-test `home_controller_test.dart` was deleted while `home_screen_test.dart` kept its existing 2 tests) = **312 total**, but always trust the actual `flutter test` output over this arithmetic).
- `flutter analyze` reports only the same 3 known issue categories as the baseline, with no new category. The exact `depend_on_referenced_packages` count will differ slightly from 21 (Tasks 1 and 2 each add a plain-`riverpod`-importing test file; Task 4 removes one); confirm via the actual `flutter analyze` output that only that one category's count moved and everything else matches the established baseline.
- All 4 task commits are present in `git log` on `main`.
- `lib/domain/home/home_controller.dart`, its `.g.dart`, and `test/domain/home/home_controller_test.dart` no longer exist.
- Manual/non-blocking verification (run the app, e.g. `flutter run -d macos`): the home page shows an auto-advancing carousel under "最近热门" that responds to taps and drags, and a 3+-column infinite-scroll grid under "为你推荐" that loads more items as you scroll to the bottom.

Explicitly out of scope (per the design doc): pull-to-refresh, hover-to-pause, any change to server-side recommendation/trending models, any change to Search/Schedule/other pages.
