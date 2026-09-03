# Plan 1e Phase C: Home / Search / Schedule Adopt the Shared Component Library

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the three top-level tab screens (Home, Search, Schedule) to use the shared component library built in Phase A (`AnimeCoverCard`, `AnimeListItem`, `EmptyView`, `pagePadding()`) instead of their current ad-hoc `Image.network`/`ListTile` layouts, and unify their AppBar actions via `buildStandardActions()` so all three tabs expose the same account/collection/settings icons (today only 2 of 3 are duplicated by hand per screen, and the account icon added in Phase A/B was never actually wired into these three AppBars).

**Architecture:** No new data flow, no new providers, no codegen. Each screen keeps its existing controller (`homeControllerProvider` / `searchControllerProvider` / `scheduleControllerProvider`) and existing `SubjectCard` model untouched — this phase is purely a presentation-layer swap: replace inline card/list-item widgets with `AnimeCoverCard`/`AnimeListItem`, replace the loading/error boilerplate's empty-state with `EmptyView` where applicable, and replace each screen's own `IconButton` actions list with a call to `buildStandardActions(context)`. `pagePadding(context)` (Phase A, `lib/app/theme/app_spacing.dart`) replaces the hardcoded padding in Home's section headers/list.

**Tech Stack:** No new dependencies. Reuses Phase A's `lib/ui/common/anime_cover_card.dart`, `lib/ui/common/anime_list_item.dart`, `lib/ui/common/empty_view.dart`, `lib/ui/common/app_action_bar.dart`, `lib/app/theme/app_spacing.dart` (all already implemented and tested).

**Design doc:** `docs/superpowers/specs/2026-09-02-plan1e-ui-redesign-design.md` (Phase C section).

---

### Task 1: Home screen adopts `AnimeCoverCard` and `buildStandardActions`

**Files:**
- Modify: `lib/ui/home/home_screen.dart`
- Create: `test/ui/home/home_screen_test.dart`

- [ ] **Step 1: Write the failing test.**

Create `test/ui/home/home_screen_test.dart`:

```dart
import 'package:animeko_flutter/domain/home/home_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_cover_card.dart';
import 'package:animeko_flutter/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHomeController extends HomeController {
  @override
  Future<HomeData> build() async {
    return const HomeData(
      trending: [
        SubjectCard(id: 1, name: 'Foo', nameCn: 'Foo', imageUrl: 'https://example.com/1.png'),
      ],
      recommendations: [
        SubjectCard(id: 2, name: 'Bar', nameCn: 'Bar', imageUrl: 'https://example.com/2.png'),
      ],
    );
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [homeControllerProvider.overrideWith(() => _FakeHomeController())],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows trending and recommended sections using AnimeCoverCard', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Foo'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
    expect(find.byType(AnimeCoverCard), findsNWidgets(2));
  });

  testWidgets('AppBar shows the unified account/collection/settings actions', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test, confirm it fails.**

```bash
flutter test test/ui/home/home_screen_test.dart
```

Expect failure: `AnimeCoverCard` is not found (the screen still renders raw `Image.network`/`Text` pairs instead), so `find.byType(AnimeCoverCard)` returns 0 widgets and the test fails with a "findsNWidgets(2)" mismatch (or similar — the exact assertion that fails may vary, but the test must not pass against the current implementation).

- [ ] **Step 3: Implement.**

Read the current `lib/ui/home/home_screen.dart` first (96 lines) to confirm its exact current content before editing. Rewrite it to:

```dart
// lib/ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/home/home_controller.dart';
import '../../domain/subject_card.dart';
import '../common/anime_cover_card.dart';
import '../common/app_action_bar.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeData = ref.watch(homeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Animeko'), actions: buildStandardActions(context)),
      body: homeData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(
          message: 'Failed to load home: $error',
          onRetry: () => ref.invalidate(homeControllerProvider),
        ),
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

    final padding = pagePadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 120,
                  child: AnimeCoverCard(
                    imageUrl: card.imageUrl ?? '',
                    title: card.nameCn ?? card.name,
                    onTap: () => openSubjectDetail(context, card),
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

Notes:
- `buildStandardActions(context)` replaces the two hand-rolled `IconButton`s, so the `go_router` import is no longer needed directly in this file.
- Horizontal list height raised from 160 to 210 to accommodate `AnimeCoverCard`'s aspect-ratio cover (120px wide → ~170px tall image) plus its title row and container padding.
- If the existing `ErrorRetryView`/loading branches in the current file differ slightly from what's shown above, preserve the existing error/loading widgets as they are — only the `data` branch's card rendering and the `AppBar.actions` need to change.

- [ ] **Step 4: Run the test, confirm it passes.**

```bash
flutter test test/ui/home/home_screen_test.dart
```

Expect: 2/2 tests pass.

- [ ] **Step 5: Full regression.**

```bash
flutter test
flutter analyze
```

Expect: all tests pass (baseline + 2 new); `flutter analyze` reports the same 3 known issue categories with unchanged counts (this test file imports `flutter_riverpod`, not plain `riverpod`, so it does not add to `depend_on_referenced_packages`).

- [ ] **Step 6: Commit.**

```bash
git add lib/ui/home/home_screen.dart test/ui/home/home_screen_test.dart
git commit -m "feat(home): adopt AnimeCoverCard and buildStandardActions"
```

---

### Task 2: Search screen adopts `AnimeListItem`, `EmptyView`, and `buildStandardActions`

**Files:**
- Modify: `lib/ui/search/search_screen.dart`
- Create: `test/ui/search/search_screen_test.dart`

- [ ] **Step 1: Write the failing test.**

Create `test/ui/search/search_screen_test.dart`:

```dart
import 'package:animeko_flutter/domain/search/search_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:animeko_flutter/ui/common/empty_view.dart';
import 'package:animeko_flutter/ui/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSearchController extends SearchController {
  _FakeSearchController(this._results);
  final List<SubjectCard> _results;

  @override
  Future<List<SubjectCard>> build() async => _results;
}

Widget _wrap(Widget child, List<SubjectCard> results) {
  return ProviderScope(
    overrides: [searchControllerProvider.overrideWith(() => _FakeSearchController(results))],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows search results as AnimeListItem', (tester) async {
    const results = [
      SubjectCard(
        id: 1,
        name: 'Foo',
        nameCn: 'Foo CN',
        imageUrl: 'https://example.com/1.png',
        tags: ['Action', 'Comedy'],
      ),
    ];
    await tester.pumpWidget(_wrap(const SearchScreen(), results));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeListItem), findsOneWidget);
    expect(find.text('Foo CN'), findsOneWidget);
    expect(find.text('Action, Comedy'), findsOneWidget);
  });

  testWidgets('shows EmptyView when there are no results', (tester) async {
    await tester.pumpWidget(_wrap(const SearchScreen(), const []));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
  });

  testWidgets('AppBar shows the unified account/collection/settings actions', (tester) async {
    await tester.pumpWidget(_wrap(const SearchScreen(), const []));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test, confirm it fails.**

```bash
flutter test test/ui/search/search_screen_test.dart
```

Expect failure: `AnimeListItem`/`EmptyView` not found (current implementation uses raw `ListTile`s and a bare empty `ListView`), so the first two tests fail.

- [ ] **Step 3: Implement.**

Read the current `lib/ui/search/search_screen.dart` first (70 lines) to confirm its exact current content before editing. Rewrite the body's data branch and AppBar actions:

```dart
// lib/ui/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/search/search_controller.dart';
import '../common/anime_list_item.dart';
import '../common/app_action_bar.dart';
import '../common/empty_view.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';

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
          decoration: const InputDecoration(hintText: 'Search subjects...', border: InputBorder.none),
          onChanged: (value) => ref.read(searchControllerProvider.notifier).search(keywords: value),
        ),
        actions: buildStandardActions(context),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(
          message: 'Search failed: $error',
          onRetry: () => ref.invalidate(searchControllerProvider),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return const EmptyView(
              icon: Icons.search_off,
              message: '没有找到相关番剧，换个关键词试试',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final card = cards[index];
              return AnimeListItem(
                imageUrl: card.imageUrl ?? '',
                title: card.nameCn ?? card.name,
                subtitle: card.tags?.join(', ') ?? '',
                onTap: () => openSubjectDetail(context, card),
              );
            },
          );
        },
      ),
    );
  }
}
```

Notes:
- Preserve whatever the existing `TextField`'s `hintText`/decoration actually is if it differs — the important change is `onChanged` stays wired to the controller and `actions: buildStandardActions(context)` replaces the two hand-rolled icons.
- If the current file's `InputDecoration` differs (e.g. uses `hintText:` directly on a bare `TextField` without `InputDecoration`), keep that structure; only change what's necessary to satisfy the task.

- [ ] **Step 4: Run the test, confirm it passes.**

```bash
flutter test test/ui/search/search_screen_test.dart
```

Expect: 3/3 tests pass.

- [ ] **Step 5: Full regression.**

```bash
flutter test
flutter analyze
```

Expect: all tests pass; `flutter analyze` unchanged (3 known categories, same counts — this test file imports `flutter_riverpod` not plain `riverpod`).

- [ ] **Step 6: Commit.**

```bash
git add lib/ui/search/search_screen.dart test/ui/search/search_screen_test.dart
git commit -m "feat(search): adopt AnimeListItem, EmptyView, and buildStandardActions"
```

---

### Task 3: Schedule screen adopts `AnimeListItem` and `buildStandardActions`

**Files:**
- Modify: `lib/ui/schedule/schedule_screen.dart`
- Create: `test/ui/schedule/schedule_screen_test.dart`

- [ ] **Step 1: Write the failing test.**

Create `test/ui/schedule/schedule_screen_test.dart`:

```dart
import 'package:animeko_flutter/domain/schedule/schedule_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:animeko_flutter/ui/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduleController extends ScheduleController {
  @override
  Future<List<ScheduleDay>> build() async {
    return const [
      ScheduleDay(
        date: '2024-01-01',
        subjects: [
          SubjectCard(id: 1, name: 'Foo', imageUrl: 'https://example.com/1.png'),
        ],
      ),
    ];
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [scheduleControllerProvider.overrideWith(() => _FakeScheduleController())],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('expanding a day shows its subjects as AnimeListItem', (tester) async {
    await tester.pumpWidget(_wrap(const ScheduleScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2024-01-01'));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeListItem), findsOneWidget);
    expect(find.text('Foo'), findsOneWidget);
  });

  testWidgets('AppBar shows the unified account/collection/settings actions', (tester) async {
    await tester.pumpWidget(_wrap(const ScheduleScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test, confirm it fails.**

```bash
flutter test test/ui/schedule/schedule_screen_test.dart
```

Expect failure: `AnimeListItem` not found (current implementation uses a raw `ListTile`).

- [ ] **Step 3: Implement.**

Read the current `lib/ui/schedule/schedule_screen.dart` first (55 lines) to confirm its exact current content before editing. Rewrite the `ExpansionTile.children` mapping and AppBar actions:

```dart
// lib/ui/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/schedule/schedule_controller.dart';
import '../common/anime_list_item.dart';
import '../common/app_action_bar.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(scheduleControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule'), actions: buildStandardActions(context)),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(
          message: 'Failed to load schedule: $error',
          onRetry: () => ref.invalidate(scheduleControllerProvider),
        ),
        data: (days) => ListView.builder(
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            return ExpansionTile(
              title: Text(day.date),
              children: day.subjects
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: AnimeListItem(
                        imageUrl: card.imageUrl ?? '',
                        title: card.nameCn ?? card.name,
                        subtitle: day.date,
                        onTap: () => openSubjectDetail(context, card),
                      ),
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

- [ ] **Step 4: Run the test, confirm it passes.**

```bash
flutter test test/ui/schedule/schedule_screen_test.dart
```

Expect: 2/2 tests pass.

- [ ] **Step 5: Full regression.**

```bash
flutter test
flutter analyze
```

Expect: all tests pass; `flutter analyze` unchanged (3 known categories, same counts).

- [ ] **Step 6: Commit.**

```bash
git add lib/ui/schedule/schedule_screen.dart test/ui/schedule/schedule_screen_test.dart
git commit -m "feat(schedule): adopt AnimeListItem and buildStandardActions"
```

---

## Definition of Done

- `flutter test` passes in full (baseline 288 + ~7 new tests across the 3 tasks).
- `flutter analyze` reports only the same 3 known issue categories (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`) with unchanged counts — none of this phase's 3 new test files import plain `package:riverpod` (only `flutter_riverpod`), so `depend_on_referenced_packages` does not grow.
- All 3 task commits are present in `git log` on `main`.
- Manual/non-blocking verification: run the app (e.g. `flutter run -d macos`) and visually confirm the new `AnimeCoverCard`/`AnimeListItem` cards render correctly with real network images on Home/Search/Schedule, and that the account icon now appears consistently in all three tabs' AppBars (previously only 2 of 3 icons were hand-duplicated per screen, and no screen exposed the account icon at all before Phase A's `buildStandardActions` existed).
- Explicitly out of scope for this phase: subject detail page's immersive header (Phase D), My Collections page adopting `AnimeListItem`/`EmptyView` (Phase E), player screen's forced dark theme wrapper (Phase F).
