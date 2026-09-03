# Home Page Redesign: Hero Carousel + Infinite-Scroll Recommendations

## 1. Goal

The home page currently feels sparse: two thin, English-labeled horizontal
rows ("Trending"/"Recommended") each showing a handful of small cards, with
no way to see more than what the server returns in one shot. This redesign:

- Turns the "Trending" row into an auto-advancing hero carousel (Material 3
  `CarouselView.weighted`), matching the reference Animeko app's
  `TrendingSubjectsCarousel` (which uses Compose's
  `HorizontalCenteredHeroCarousel`) -- this was explicitly excluded scope in
  the original Plan 1e design doc ("首页M3 Carousel轮播(改用普通横向列表)")
  but is now in scope per the user's explicit request.
- Turns "Recommended" into a true infinite-scroll vertical grid, backed by
  the already-paginated `GET /v2/home/recommendations` endpoint (`offset`/
  `limit`/`total` -- confirmed against the real Kotlin client model when this
  endpoint was first implemented; this plan does not change the API
  contract, only starts actually using its pagination parameters).
- Merges both sections into a single continuously-scrolling page (one
  `CustomScrollView`), matching the reference app's `LazyVerticalGrid` with
  the carousel as its header item, rather than two independently-scrolling
  regions.
- Translates the two section titles from English ("Trending"/"Recommended")
  to Chinese ("最近热门"/"为你推荐"), consistent with the rest of the app.

## 2. Architecture

### 2.1 Data layer

**`trendingProvider`** (new, replaces the `trending` half of the deleted
`HomeController`): a bare function provider, not paginated (the `GET
/v1/trends` endpoint itself has no `offset`/`limit` params -- it returns a
small, fixed, curated list meant for a carousel, not a scrollable feed).

```dart
// lib/domain/home/trending_controller.dart
@riverpod
Future<List<SubjectCard>> trending(Ref ref) async {
  final api = ref.watch(trendsApiProvider);
  final response = await api.getTrends();
  return response.trendingSubjects.map(SubjectCard.fromTrending).toList();
}
```

**`HomeRecommendationsController`** (new, replaces the `recommendations`
half of the deleted `HomeController`): an `AsyncNotifier` with the same
"page + hasMore, load more appends" shape as the already-shipped
`MyCollectionsController` (`lib/domain/subject/my_collections_controller.dart`),
reusing that proven pattern rather than inventing a new one.

```dart
// lib/domain/home/home_recommendations_controller.dart
const _pageSize = 20;

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

Note this uses the server's real `total` field for `hasMore` (unlike
`MyCollectionsController`'s "short page = last page" heuristic, which was
adopted there specifically because `PaginatedCollections.total` was found to
be unreliable/absent on the wire -- see that class's own doc comment). The
recommendations endpoint's `total` field has no such known issue, so the
more precise `items.length < total` check is used here instead.

**`HomeController`/`HomeData`** (`lib/domain/home/home_controller.dart` and
its `.g.dart`) are deleted outright, along with their test file
(`test/domain/home/home_controller_test.dart`) -- replaced by the two
providers above with their own new test files. No other file references
`homeControllerProvider`/`HomeData` (confirmed by grep before implementation).

### 2.2 UI layer

**`HomeScreen`** (`lib/ui/home/home_screen.dart`) is rewritten from a plain
`ListView` of two sections into a `CustomScrollView` with slivers, so the
carousel and the recommendations grid scroll together as one continuous
page:

```dart
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(child: _TrendingSection(cards: trending)),   // title + TrendingCarousel
    SliverToBoxAdapter(child: _SectionTitle('为你推荐')),
    SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: pagePadding(context)),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, ...),
        delegate: SliverChildBuilderDelegate(...), // AnimeCoverCard per item
      ),
    ),
    SliverToBoxAdapter(child: _RecommendationsFooter(...)), // loading/retry, same shape as _CollectionList's footer
  ],
)
```

Wrapped in a `NotificationListener<ScrollNotification>` (the whole
`CustomScrollView`, same "near the bottom -> call loadMore()" trigger
already used by `MyCollectionScreen`'s `_CollectionList`, adapted from
`ScrollEndNotification` to a plain `ScrollUpdateNotification`/`ScrollEndNotification`
check on `notification.metrics`).

Column count for the recommendations grid: a deterministic `int
_gridColumns(double width) => (width / 130).floor().clamp(3, 8)` helper
(local to `home_screen.dart`, not a new shared `app_spacing.dart` export --
it's specific to this one grid's target item width of ~130dp) drives a
`SliverGridDelegateWithFixedCrossAxisCount`. The `clamp(3, ...)` lower bound
guarantees at least 3 columns even on narrow phones (e.g. a 360dp-wide phone
computes `(360/130).floor()=2`, clamped up to 3), and typical/larger phone
widths (390dp+) already compute to 3 or more on their own; wider screens
scale up automatically, matching the user's explicit choice
("固定3列，宽屏自适应"). This uses `AnimeCoverCard` unchanged (already
849:1200 cover + title, no new component needed for grid items).

**`TrendingCarousel`** (new, `lib/ui/home/trending_carousel.dart`): a small,
dependency-free `StatefulWidget` (owns its own `CarouselController` and
auto-advance `Timer`, no Riverpod dependency at all -- same "extract a
public, independently-testable component" pattern already used for
`SubjectBlurredHeader`/`SubjectTagsRow` in Phase D), taking a plain
`List<SubjectCard>` and an `onTap` callback:

```dart
class TrendingCarousel extends StatefulWidget {
  const TrendingCarousel({super.key, required this.cards, required this.onTap});
  final List<SubjectCard> cards;
  final void Function(SubjectCard card) onTap;
}
```

Internals:
- `CarouselView.weighted(flexWeights: [1, 7, 1], itemSnapping: true, controller: _controller, children: cards.map(_buildItem).toList())`.
- Each item: `ClipRRect` + `Stack` with `Image.network(card.imageUrl ?? '', fit: BoxFit.cover, errorBuilder: ...)` (same defensive `errorBuilder` pattern as `AnimeCoverCard`/`AnimeListItem`) + a bottom-aligned gradient (`Colors.transparent` -> `Colors.black54`) + a `Text(card.nameCn ?? card.name)` overlay in the gradient area (white text, matching the reference app's `CarouselItemDefaults.Text` label-over-image look).
- Auto-advance: a `Timer.periodic(const Duration(seconds: 5), ...)` calls
  `_controller.animateToItem((current + 1) % cards.length, duration: ..., curve: ...)`.
  Paused while the user is actively dragging the carousel (tracked via
  `NotificationListener<ScrollStartNotification>`/`ScrollEndNotification`
  wrapping the `CarouselView`, cancelling the timer on drag-start and
  restarting it a couple seconds after drag-end) so auto-advance doesn't
  fight the user's own swipe.
- `initState`/`dispose` start/cancel the timer; guards against `cards.isEmpty`
  (returns `SizedBox.shrink()`, same convention as `_SubjectCardSection`'s
  existing empty-list guard).
- Tapping an item calls `onTap(card)`; `HomeScreen` passes `(card) =>
  openSubjectDetail(context, card)`, unchanged navigation target.

**`_SubjectCardSection`** (the private class currently used for both rows) is
deleted -- the carousel section and the grid section have different enough
shapes (carousel vs. sliver grid) that keeping one shared private widget for
both no longer makes sense; each gets its own small private widget local to
`home_screen.dart` instead.

## 3. Data Flow

1. `HomeScreen.build()` watches both `trendingProvider` and
   `homeRecommendationsControllerProvider` independently (two separate
   `AsyncValue`s, each with their own `.when(loading/error/data)` -- the
   carousel section and the grid section can independently show
   loading/error/data states rather than one combined all-or-nothing state
   like the old `HomeData` had).
2. Scrolling the `CustomScrollView` near its bottom edge calls
   `ref.read(homeRecommendationsControllerProvider.notifier).loadMore()`,
   which appends a page and updates `state` -- the grid's `SliverGrid`
   rebuilds with the longer `items` list. `trendingProvider` is never
   paginated; it only ever refetches on `ref.invalidate()` (pull-to-refresh
   is not part of this design, matching the existing lack of pull-to-refresh
   elsewhere in the app apart from `MyCollectionScreen`... actually
   `MyCollectionScreen` also has no pull-to-refresh per its own design doc's
   YAGNI note -- consistent).
3. Tapping any carousel item or grid item navigates via the existing
   `openSubjectDetail(context, card)` helper, unchanged.

## 4. Error Handling

- Trending load failure: the carousel section shows the existing
  `ErrorRetryView` pattern (message + retry button invalidating
  `trendingProvider`) in place of the carousel.
- Recommendations *first-page* load failure: same `ErrorRetryView` pattern
  in place of the grid, retry invalidates `homeRecommendationsControllerProvider`.
- Recommendations *load-more* failure (i.e. first page already showing,
  scrolling further triggers a failing `loadMore()`): same UX as
  `_CollectionList`'s existing "加载失败，点击重试" text-button footer, not a
  full-screen error -- the already-loaded grid items stay visible.

## 5. Testing Strategy

- `test/domain/home/trending_controller_test.dart` (new): mocks
  `TrendsApi`, verifies mapping to `SubjectCard`. Mirrors the deleted
  `home_controller_test.dart`'s trending-half assertions.
- `test/domain/home/home_recommendations_controller_test.dart` (new): mocks
  `HomeRecommendationsApi`, verifies first-page load, `loadMore()` appending
  and `hasMore` becoming `false` once `items.length >= total`, and the
  riverpod-3.2.1 "keep a listener + `container.pump()`" pattern (documented
  in the deleted test's comment) for the error-path test.
- `test/ui/home/trending_carousel_test.dart` (new): pumps `TrendingCarousel`
  standalone (no Riverpod), verifies it renders a `CarouselView`, renders
  each card's title text, calls `onTap` with the right card on tap, and
  (using `tester.pump(const Duration(seconds: 5))`) that it auto-advances to
  the next item. No test for the drag-pauses-autoadvance behavior specifically
  (hard to simulate a real streak drag deterministically in a widget test;
  this is verified manually per the Definition of Done instead).
- `test/ui/home/home_screen_test.dart` (rewritten): fakes both
  `trendingProvider`/`homeRecommendationsControllerProvider`, asserts the
  Chinese titles ("最近热门"/"为你推荐") render, `TrendingCarousel` and grid
  items render, and the unified AppBar actions still render (unchanged from
  the existing test's second case).
- `test/data/home/trends_api_test.dart`/`home_recommendations_api_test.dart`
  are untouched -- the API classes' signatures don't change, only how the
  domain layer calls them.

## 6. Explicitly Out of Scope

- Pull-to-refresh (neither section gets one, matching the rest of the app).
- Hover-to-pause (desktop-only concept in the reference app; this app's
  primary target is touch, so only drag-pause is implemented).
- Any change to the recommendation/trending server-side algorithms or the
  `SubjectRecommendation`/`TrendingSubject` wire models.
- Any change to Search/Schedule/other pages.
