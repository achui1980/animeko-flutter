# Plan 1e Phase E: My Collections Page Adopts the Shared Component Library

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lib/ui/collection/my_collection_screen.dart` adopts the Phase A shared component library: the plain `ListTile` rows in `_CollectionList` become `AnimeListItem`, and the plain `Center(child: Text('还没有收藏任何番剧'))` empty state becomes `EmptyView`. The `SegmentedButton` tab switcher, the scroll-to-load-more footer logic, and the `AppBar` are left untouched (design doc: "`SegmentedButton` 视觉保留").

**Architecture:** No new providers, no codegen, no new data flow. `MyCollectionScreen`/`_CollectionList` keep their existing `myCollectionsControllerProvider(type: ...)` family-provider wiring. Unlike Phase D (which extracted dependency-free widgets because `SubjectDetailScreen` depends on 6 separate providers), this screen depends on exactly one family provider, so this plan follows Phase C's pattern instead: test the whole screen directly with a fake controller override (parameterized fake pattern, same as `_FakeHomeController`/`_FakeScheduleController` in Phase C).

Real constraint discovered while researching this phase: `MyCollectionSubject` (`lib/data/subject/subject_models.dart`) has no `imageUrl`/`tags`/`airDate` fields at all — only `subjectId`/`name`/`nameCn`/`collectionType`. `SubjectCard.fromMyCollectionSubject` therefore never populates `imageUrl`, so `AnimeListItem`'s `imageUrl` param will always receive `''` here (same "pass empty string, let the component's `errorBuilder` show a placeholder icon" pattern already used for Search/Schedule in Phase C when a card has no cover). For `AnimeListItem`'s required `subtitle`, there is no per-item data to show, so this plan uses the current tab's Chinese label (e.g. "在看") as the subtitle — the same "fall back to page-level context data" precedent Phase C set for Schedule (which used `day.date` as the subtitle for the same reason).

**Tech Stack:** No new dependencies. Reuses Phase A's `lib/ui/common/anime_list_item.dart` and `lib/ui/common/empty_view.dart` (already implemented and tested).

**Design doc:** `docs/superpowers/specs/2026-09-02-plan1e-ui-redesign-design.md` (Phase E section, "3. 页面级改动" table row for 我的收藏页).

---

### Task 1: `MyCollectionScreen` adopts `AnimeListItem` and `EmptyView`

**Files:**
- Create: `test/ui/collection/my_collection_screen_test.dart`
- Modify: `lib/ui/collection/my_collection_screen.dart`

- [ ] **Step 1: Write the failing test.**

Create `test/ui/collection/my_collection_screen_test.dart`:

```dart
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/my_collections_controller.dart';
import 'package:animeko_flutter/ui/collection/my_collection_screen.dart';
import 'package:animeko_flutter/ui/common/anime_list_item.dart';
import 'package:animeko_flutter/ui/common/empty_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMyCollectionsController extends MyCollectionsController {
  _FakeMyCollectionsController(this._page);

  final MyCollectionsPage _page;

  @override
  Future<MyCollectionsPage> build({required CollectionType? type}) async => _page;
}

Widget _wrap(MyCollectionsPage page) {
  return ProviderScope(
    overrides: [
      myCollectionsControllerProvider.overrideWith(() => _FakeMyCollectionsController(page)),
    ],
    child: const MaterialApp(home: MyCollectionScreen()),
  );
}

void main() {
  group('MyCollectionScreen', () {
    testWidgets('shows collection items as AnimeListItem', (tester) async {
      const page = MyCollectionsPage(
        items: [
          MyCollectionSubject(subjectId: 1, name: 'Foo', nameCn: 'Foo CN'),
          MyCollectionSubject(subjectId: 2, name: 'Bar', nameCn: 'Bar CN'),
        ],
        hasMore: false,
      );

      await tester.pumpWidget(_wrap(page));
      await tester.pump();

      expect(find.byType(AnimeListItem), findsNWidgets(2));
      expect(find.text('Foo CN'), findsOneWidget);
      expect(find.text('Bar CN'), findsOneWidget);
    });

    testWidgets('shows EmptyView when there are no items', (tester) async {
      const page = MyCollectionsPage(items: [], hasMore: false);

      await tester.pumpWidget(_wrap(page));
      await tester.pump();

      expect(find.byType(EmptyView), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test, confirm it fails.**

```bash
flutter test test/ui/collection/my_collection_screen_test.dart
```

Expected failure: `AnimeListItem`/`EmptyView` not found (the current implementation uses plain `ListTile`s and a plain `Center(child: Text(...))`).

- [ ] **Step 3: Implement.**

In `lib/ui/collection/my_collection_screen.dart`:

1. Add imports:

```dart
import '../common/anime_list_item.dart';
import '../common/empty_view.dart';
```

2. Replace the empty-state branch:

```dart
if (widget.subjects.isEmpty) {
  return const Center(child: Text('还没有收藏任何番剧'));
}
```

with:

```dart
if (widget.subjects.isEmpty) {
  return const EmptyView(message: '还没有收藏任何番剧');
}
```

3. Replace the per-item `ListTile`:

```dart
final card = SubjectCard.fromMyCollectionSubject(widget.subjects[index]);
return ListTile(
  leading: card.imageUrl != null
      ? Image.network(card.imageUrl!, width: 40, fit: BoxFit.cover)
      : const SizedBox(width: 40),
  title: Text(card.nameCn ?? card.name),
  onTap: () => openSubjectDetail(context, card),
);
```

with:

```dart
final card = SubjectCard.fromMyCollectionSubject(widget.subjects[index]);
return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  child: AnimeListItem(
    imageUrl: card.imageUrl ?? '',
    title: card.nameCn ?? card.name,
    subtitle: _collectionLabels[widget.type] ?? '',
    onTap: () => openSubjectDetail(context, card),
  ),
);
```

(`_collectionLabels` is the existing top-level map already defined in this file -- no change needed to it.)

- [ ] **Step 4: Run the test, confirm it passes.**

```bash
flutter test test/ui/collection/my_collection_screen_test.dart
```

Expected: 2/2 pass.

- [ ] **Step 5: Full regression.**

```bash
flutter test
flutter analyze
```

Expected: `flutter test` passes in full (baseline + 2 new tests). `flutter analyze` reports the same 3 known issue categories with an unchanged count (this test file imports `flutter_riverpod`, not plain `riverpod`, so `depend_on_referenced_packages` does not increase).

- [ ] **Step 6: Commit.**

```bash
git add lib/ui/collection/my_collection_screen.dart test/ui/collection/my_collection_screen_test.dart
git commit -m "feat(collection): adopt AnimeListItem and EmptyView in MyCollectionScreen"
```

---

## Definition of Done

- `flutter test` passes in full (baseline 299 + 2 new tests = 301, assuming this plan is executed directly after Phase D's bugfix commit).
- `flutter analyze` reports only the same 3 known issue categories established throughout this session, with an unchanged count.
- The task commit is present in `git log` on `main`.
- Manual/non-blocking verification: run the app, open "我的收藏", switch between the 5 tabs, confirm items render as `AnimeListItem` rows (cover thumbnail will show the "image not supported" placeholder icon since `MyCollectionSubject` has no `imageUrl` field -- this is a pre-existing data limitation, not a regression) and that the empty tabs show the unified `EmptyView`.
- Explicitly out of scope for Phase E: the `SegmentedButton` tab switcher, the scroll-to-load-more footer, the `AppBar`. Player screen forced dark theme (Phase F) remains separately out of scope.
