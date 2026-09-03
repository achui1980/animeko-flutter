# Plan 1e Phase D: Subject Detail Page Immersive Header

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the subject detail page's plain 160dp `Image.network` header with a simplified immersive header (blurred cover background + top-to-bottom gradient fading into the page background + a sharp, correctly-proportioned cover thumbnail overlaid at the bottom-left), matching a simplified version of the reference app's `SubjectBlurredBackground` (blur radius, not dynamic color theming — that's explicitly excluded scope). Also replace the page's plain `Chip`-based tag list with the Phase A `TagChip` component.

**Architecture:** No new data flow, no new providers, no codegen. `SubjectDetailScreen`'s existing `subjectDetailControllerProvider`/`subjectCollectionControllerProvider`/`subjectEpisodesControllerProvider`/`mediaSourcesProvider`/`subjectCharactersProvider`/`subjectStaffProvider` wiring is untouched. Both changes are extracted into small, dependency-free, independently-testable widgets (following the same "extract a public component + dedicated widget test" pattern established in Phase A/C, rather than testing the whole screen, which would require mocking six separate Riverpod family providers for no benefit):

- `lib/ui/subject/subject_blurred_header.dart` — `SubjectBlurredHeader(imageUrl)`, a `StatelessWidget` that takes a plain `String` cover URL and renders the blurred-background + gradient + sharp-thumbnail stack. No Riverpod dependency at all.
- `lib/ui/subject/subject_tags_row.dart` — `SubjectTagsRow(tags)`, a `StatelessWidget` that takes a plain `List<SubjectTag>` (the existing `data/search/search_models.dart` model already used by `SubjectDetail.tags`) and renders a `Wrap` of `TagChip`s. No Riverpod dependency at all.

`lib/ui/subject/subject_detail_screen.dart` then wires both into the existing `_SubjectInfoSection`/`SubjectDetailScreen` tree with a one-line swap each.

**Tech Stack:** No new dependencies. Uses `dart:ui`'s `ImageFilter.blur` (already available via Flutter, no new package). Reuses Phase A's `lib/ui/common/tag_chip.dart` (already implemented and tested).

**Design doc:** `docs/superpowers/specs/2026-09-02-plan1e-ui-redesign-design.md` (Phase D section, "3. 页面级改动" table row for 番剧详情页).

---

### Task 1: Extract `SubjectBlurredHeader` and wire it into the subject detail page

**Files:**
- Create: `lib/ui/subject/subject_blurred_header.dart`
- Create: `test/ui/subject/subject_blurred_header_test.dart`
- Modify: `lib/ui/subject/subject_detail_screen.dart`

- [ ] **Step 1: Write the failing test.**

Create `test/ui/subject/subject_blurred_header_test.dart`:

```dart
import 'package:animeko_flutter/ui/subject/subject_blurred_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubjectBlurredHeader', () {
    testWidgets('renders a blurred background and a sharp foreground cover', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectBlurredHeader(imageUrl: 'https://example.com/cover.png'),
          ),
        ),
      );

      // The blurred background layer.
      expect(find.byType(ImageFiltered), findsOneWidget);
      // Two Image widgets total: the blurred background + the sharp
      // foreground thumbnail.
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('sizes itself to the fixed header height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectBlurredHeader(imageUrl: 'https://example.com/cover.png'),
          ),
        ),
      );

      final size = tester.getSize(find.byType(SubjectBlurredHeader));
      expect(size.height, SubjectBlurredHeader.height);
    });
  });
}
```

- [ ] **Step 2: Run the test, confirm it fails.**

```bash
flutter test test/ui/subject/subject_blurred_header_test.dart
```

Expected failure: `Target of URI doesn't exist: 'package:animeko_flutter/ui/subject/subject_blurred_header.dart'.`

- [ ] **Step 3: Implement `lib/ui/subject/subject_blurred_header.dart`:**

```dart
// lib/ui/subject/subject_blurred_header.dart
import 'dart:ui';

import 'package:flutter/material.dart';

/// The subject detail page's immersive header: the cover image blurred
/// and stretched to fill the header's full width/height, with a
/// top-to-bottom gradient fading into the page background, and the
/// actual (unblurred) cover thumbnail overlaid at the bottom-left in
/// its native 849:1200 aspect ratio with 16dp rounded corners.
///
/// A simplified version of the reference app's `SubjectBlurredBackground`
/// (blur radius 16dp on compact widths, 32dp on wide widths) --
/// deliberately does NOT extract a dynamic color theme from the cover
/// image (excluded scope, see the design doc's "明确排除范围").
class SubjectBlurredHeader extends StatelessWidget {
  const SubjectBlurredHeader({super.key, required this.imageUrl});

  static const height = 240.0;
  static const coverAspectRatio = 849 / 1200;

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final blurSigma = MediaQuery.of(context).size.width < 600 ? 16.0 : 32.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: colorScheme.surfaceContainerHighest),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, colorScheme.surface],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: SizedBox(
                    width: 120,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test, confirm it passes.**

```bash
flutter test test/ui/subject/subject_blurred_header_test.dart
```

Expected: 2/2 pass.

- [ ] **Step 5: Wire it into `subject_detail_screen.dart`.**

In `lib/ui/subject/subject_detail_screen.dart`:

1. Add the import: `import 'subject_blurred_header.dart';`
2. Replace the existing top-of-`ListView` block:

```dart
if (imageUrl != null)
  SizedBox(
    height: 160,
    width: double.infinity,
    child: Image.network(imageUrl!, fit: BoxFit.cover),
  ),
```

with:

```dart
if (imageUrl != null) SubjectBlurredHeader(imageUrl: imageUrl!),
```

No test is added for this one-line wiring change in `subject_detail_screen.dart` itself — `SubjectDetailScreen` currently has zero widget-test coverage (it depends on 6 separate Riverpod family providers, none of which are mocked anywhere in the test suite today), and adding a full-page test harness for this file is out of scope for this phase. Full regression (Step 6 below) plus `flutter analyze` is the verification for this step; `SubjectBlurredHeader` itself is fully covered by Step 1-4's dedicated test.

- [ ] **Step 6: Full regression.**

```bash
flutter test
flutter analyze
```

Expected: `flutter test` passes in full (baseline + 2 new tests). `flutter analyze` reports the same 3 known issue categories with an unchanged count (this test file imports `flutter_test`/`flutter/material.dart` only, no plain `riverpod`, so `depend_on_referenced_packages` does not increase).

- [ ] **Step 7: Commit.**

```bash
git add lib/ui/subject/subject_blurred_header.dart test/ui/subject/subject_blurred_header_test.dart lib/ui/subject/subject_detail_screen.dart
git commit -m "feat(subject): add immersive blurred header to the subject detail page"
```

---

### Task 2: Extract `SubjectTagsRow` and wire it into the subject detail page

**Files:**
- Create: `lib/ui/subject/subject_tags_row.dart`
- Create: `test/ui/subject/subject_tags_row_test.dart`
- Modify: `lib/ui/subject/subject_detail_screen.dart`

- [ ] **Step 1: Write the failing test.**

Create `test/ui/subject/subject_tags_row_test.dart`:

```dart
import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/ui/common/tag_chip.dart';
import 'package:animeko_flutter/ui/subject/subject_tags_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubjectTagsRow', () {
    testWidgets('renders a TagChip per tag with "name count" labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectTagsRow(
              tags: [
                SubjectTag(name: '战斗', count: 120),
                SubjectTag(name: '奇幻', count: 80),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TagChip), findsNWidgets(2));
      expect(find.text('战斗 120'), findsOneWidget);
      expect(find.text('奇幻 80'), findsOneWidget);
    });

    testWidgets('renders nothing when there are no tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SubjectTagsRow(tags: []))),
      );

      expect(find.byType(TagChip), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run the test, confirm it fails.**

```bash
flutter test test/ui/subject/subject_tags_row_test.dart
```

Expected failure: `Target of URI doesn't exist: 'package:animeko_flutter/ui/subject/subject_tags_row.dart'.`

- [ ] **Step 3: Implement `lib/ui/subject/subject_tags_row.dart`:**

```dart
// lib/ui/subject/subject_tags_row.dart
import 'package:flutter/material.dart';

import '../../data/search/search_models.dart' show SubjectTag;
import '../common/tag_chip.dart';

/// A wrapped row of [TagChip]s for a subject's tags, each showing
/// "name count" (e.g. "战斗 120"). Renders nothing when [tags] is empty.
class SubjectTagsRow extends StatelessWidget {
  const SubjectTagsRow({super.key, required this.tags});

  final List<SubjectTag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) => TagChip(label: '${tag.name} ${tag.count}')).toList(),
    );
  }
}
```

- [ ] **Step 4: Run the test, confirm it passes.**

```bash
flutter test test/ui/subject/subject_tags_row_test.dart
```

Expected: 2/2 pass.

- [ ] **Step 5: Wire it into `subject_detail_screen.dart`.**

In `lib/ui/subject/subject_detail_screen.dart`:

1. Add the import: `import 'subject_tags_row.dart';`
2. In `_SubjectInfoSection.build`'s data branch, replace:

```dart
if (subject.tags.isNotEmpty)
  Wrap(
    spacing: 4,
    children: subject.tags
        .map((tag) => Chip(label: Text('${tag.name} ${tag.count}')))
        .toList(),
  ),
```

with:

```dart
SubjectTagsRow(tags: subject.tags),
```

(the `if` check is dropped since `SubjectTagsRow` already renders `SizedBox.shrink()` for an empty list). Same testing rationale as Task 1's Step 5 applies: no new test is added directly to `subject_detail_screen.dart` for this wiring, since `SubjectTagsRow` itself is fully covered above and the screen has no existing test harness to extend.

- [ ] **Step 6: Full regression.**

```bash
flutter test
flutter analyze
```

Expected: `flutter test` passes in full (baseline + 2 more new tests). `flutter analyze` unchanged count (same reasoning as Task 1).

- [ ] **Step 7: Commit.**

```bash
git add lib/ui/subject/subject_tags_row.dart test/ui/subject/subject_tags_row_test.dart lib/ui/subject/subject_detail_screen.dart
git commit -m "feat(subject): replace tag Chips with TagChip"
```

---

## Definition of Done

- `flutter test` passes in full (baseline 295 + 4 new tests across Tasks 1-2 = 299).
- `flutter analyze` reports only the same 3 known issue categories established throughout this session, with unchanged counts (neither new test file imports plain `package:riverpod`).
- Both task commits are present in `git log` on `main`.
- Manual/non-blocking verification: run the app, open any subject's detail page, confirm the blurred immersive header renders correctly with a real cover image (blur + gradient + sharp thumbnail), and that tags render as outlined `TagChip`s instead of filled `Chip`s.
- Explicitly out of scope for Phase D (already covered by earlier phases or deferred to later ones): the AppBar itself, the collection-status buttons (`_CollectionButtons`), the rating section (`_RatingSection`), the cast/staff avatar rows (`_CastStaffSection`), and the episode list — none of these are touched by this phase. My Collections page (Phase E) and the player screen (Phase F) are also out of scope.
