# Subject Detail Two-Column Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `SubjectDetailScreen` into a two-column layout matching the approved Animeko-style reference design: a new "作品信息" work-info block, episode-grid title snippets, a horizontal character-avatar row, and a right-column staff table — with airDate/tags relocated out of their current spots to avoid duplication.

**Architecture:** Two additive/mechanical changes (a new `SubjectDetail.aliases` field; a `BangumiEpisodeGrid` button content/size tweak) followed by one larger integration task that restructures `subject_detail_screen.dart`'s widget tree — replacing the flat single-column `ListView` body with a `Row`-based two-column layout, adding three new private widgets (`_WorkInfoSection`, `_CharacterSection`, `_StaffSection`), and deleting the now-superseded `_CastStaffSection`/`_PersonList`/`_characterRoleLabel`.

**Tech Stack:** Flutter/Dart, Riverpod 3.x (`@riverpod` codegen), `json_serializable` (`@JsonSerializable`), `flutter_test`/`mocktail`.

## Global Constraints

- Design spec (approved, all 7 sections): `docs/superpowers/specs/2026-09-07-subject-detail-two-column-redesign-design.md` (commit `0e976f9`).
- No new backend/API endpoints in this feature. `aliases` comes from a field already present in the raw `api.animeko.org` `/v2/subjects/{id}` response but currently unparsed by `SubjectDetail`. Episode count comes from `subjectBangumiEpisodesControllerProvider`'s already-fetched list length. Episode title snippets come from `BangumiEpisode.displayName`, which already exists.
- **Accepted, deliberate limitation:** the new `_CharacterSection` renders character name only, with NO CV/actor-name line, because no such field exists anywhere in `CharacterInfo`/`RelatedCharacter` (confirmed by reading `lib/data/subject/subject_models.dart` and its test fixtures). This diverges from the literal reference screenshot but adding a new field would require unconfirmed API investigation — explicitly out of scope. Document this via a doc comment on `_CharacterSection`, do not attempt to "fix" it.
- Do not touch `lib/ui/subject/episode_source_grid.dart`, `lib/ui/subject/episode_source_sheet.dart`, `lib/domain/play/subject_episodes_controller.dart`, or `lib/domain/media/media_registry.dart` — unrelated to this feature, still used by `PlayerScreen`'s in-player drawer.
- `_RatingSection` (the user's own self-rating widget) stays exactly where it currently is inside `_SubjectInfoSection`'s left-column flow — do not relocate it.
- The "查看全部" text next to "角色" is static — no `onPressed`, no navigation, no expand logic. The new "制作人员" table has NO "查看全部" link at all.
- The "制作人员" table is NOT deduplicated by role — render every `(role, name)` pair from the API response in original order, even if multiple rows share the same role.
- **Critical established lesson (this session): any `dart format` invocation MUST be scoped only to the exact files touched by that task — NEVER run `dart format lib test` on the whole tree.** A prior task in this same session did that and caused a 91-file mass-reformat incident requiring manual cleanup.
- Run `dart run build_runner build --delete-conflicting-outputs` after any `@JsonSerializable`/`@riverpod` shape change (only Task 1 needs this).
- `flutter analyze` must show 0 errors and `flutter test` must show all tests passing after every task that touches `lib/` or `test/`. Baseline before this plan: 429/429 tests passing, 0 analyze errors (28 pre-existing info-level issues).
- Conventional Commits with scope, one commit per task except Task 4 (verification only, no commit).
- `SubjectDetailScreen` and its private sub-widgets have NO pre-existing widget-test file — this is an accepted, pre-existing gap; this plan does not introduce new widget tests for `subject_detail_screen.dart` itself (Task 3 has no test file).

---

### Task 1: Add `SubjectDetail.aliases` field

**Files:**
- Modify: `lib/data/subject/subject_models.dart:41-79` (the `SubjectDetail` class)
- Test: `test/data/subject/subject_models_test.dart` (append 2 tests to the `SubjectDetail` group)

**Interfaces:**
- Produces: `SubjectDetail.aliases` — `final List<String> aliases;`, defaults to `const []` both in the constructor and via `@JsonKey(defaultValue: <String>[])` so JSON missing the key and direct Dart construction without the param both work. Consumed by Task 3's `_WorkInfoSection`.

- [ ] **Step 1: Write the failing tests**

Open `test/data/subject/subject_models_test.dart`. Find the `baseJson({String? collectionType})` helper (line 40) and the `SubjectDetail` `group(...)` block. Add these two tests inside that group, after the existing tests in the group (do not modify `baseJson` itself — it must keep NOT including an `aliases` key, since that's exactly what the second new test relies on):

```dart
    test('parses aliases when present', () {
      final json = baseJson()
        ..['aliases'] = ['Sousou no Frieren', '葬送のフリーレン'];
      final detail = SubjectDetail.fromJson(json);
      expect(detail.aliases, ['Sousou no Frieren', '葬送のフリーレン']);
    });

    test('defaults aliases to an empty list when absent from JSON', () {
      final detail = SubjectDetail.fromJson(baseJson());
      expect(detail.aliases, isEmpty);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: FAIL — `SubjectDetail` has no `aliases` getter (compile error), or `NoSuchMethodError`.

- [ ] **Step 3: Add the field**

In `lib/data/subject/subject_models.dart`, modify the `SubjectDetail` class. Current constructor (line ~42-53):

```dart
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
```

Change to:

```dart
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
  });
```

Then, in the fields list right after `final List<SubjectTag> tags;`, add:

```dart
  /// Alternate titles for this subject (e.g. original Japanese title,
  /// English title). Parsed from the `aliases` field already present in
  /// the raw `api.animeko.org` `/v2/subjects/{id}` response but not
  /// previously modeled here. Defaults to an empty list when the key is
  /// absent, so existing test fixtures/responses without this key still
  /// parse cleanly.
  @JsonKey(defaultValue: <String>[])
  final List<String> aliases;
```

- [ ] **Step 4: Regenerate codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, regenerates `lib/data/subject/subject_models.g.dart` with `aliases` threaded through `_$SubjectDetailFromJson`/`_$SubjectDetailToJson`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: PASS, all tests in the file (including the 2 new ones).

- [ ] **Step 6: Run the full suite and analyze to check for regressions**

Run: `flutter test`
Expected: all tests pass (429 baseline + 2 new = 431).

Run: `flutter analyze lib/data/subject/subject_models.dart lib/data/subject/subject_models.g.dart test/data/subject/subject_models_test.dart`
Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/data/subject/subject_models.dart lib/data/subject/subject_models.g.dart test/data/subject/subject_models_test.dart
git commit -m "feat(subject): add SubjectDetail.aliases field"
```

---

### Task 2: Add episode title snippet to `BangumiEpisodeGrid` buttons

**Files:**
- Modify: `lib/ui/subject/bangumi_episode_grid.dart:89-128` (the `_EpisodeNumberButton` class)
- Test: `test/ui/subject/bangumi_episode_grid_test.dart` (append 2 new tests; the 4 existing tests are unaffected and must not be modified)

**Interfaces:**
- Consumes: `BangumiEpisode.displayName` (already exists, `lib/data/subject/bangumi_episode_models.dart`, returns `nameCn` if non-empty else `name`).
- No new public interface — `BangumiEpisodeGrid`'s own constructor/parameters are unchanged; only `_EpisodeNumberButton`'s internal rendering changes.

- [ ] **Step 1: Write the failing tests**

Open `test/ui/subject/bangumi_episode_grid_test.dart`. It already defines a top-level `episodes` fixture (2 `BangumiEpisode`s with `nameCn: '第1集'` / `'第2集'`). Add these two `testWidgets` after the existing 4 (inside `main()`, do not touch the existing tests):

```dart
  testWidgets('shows the title snippet below the number', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangumiEpisodeGrid(
            episodes: episodes,
            mergedEpisodesAsync: const AsyncLoading(),
            onEpisodeTap: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('第2集'), findsOneWidget);
  });

  testWidgets('renders number-only (no title line) when displayName is empty', (
    tester,
  ) async {
    const noTitleEpisodes = [
      BangumiEpisode(id: 11, sort: 11, name: '', nameCn: '', airdate: '', type: 0),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangumiEpisodeGrid(
            episodes: noTitleEpisodes,
            mergedEpisodesAsync: const AsyncLoading(),
            onEpisodeTap: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('11'), findsOneWidget);
    // No second, empty/blank Text line should be rendered for this button.
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/subject/bangumi_episode_grid_test.dart`
Expected: the 4 pre-existing tests PASS; the 2 new tests FAIL (`find.text('第1集')` finds nothing; the descendant-Text-count assertion may pass or fail depending on current rendering — the key failure is the title text not being findable).

- [ ] **Step 3: Modify `_EpisodeNumberButton`**

In `lib/ui/subject/bangumi_episode_grid.dart`, the current `_EpisodeNumberButton.build()` is:

```dart
  @override
  Widget build(BuildContext context) {
    final label = Text(episode.sort.round().toString().padLeft(2, '0'));

    if (hasSource == false) {
      final disabledColor = Theme.of(context).disabledColor;
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 40),
          foregroundColor: disabledColor,
          side: BorderSide(color: disabledColor),
        ),
        child: label,
      );
    }
    // hasSource == true or null (still loading) both render as the
    // normal/neutral clickable style -- see the class doc comment.
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(minimumSize: const Size(48, 40)),
      child: label,
    );
  }
```

Replace it with:

```dart
  @override
  Widget build(BuildContext context) {
    final numberLabel = Text(episode.sort.round().toString().padLeft(2, '0'));
    final title = episode.displayName;
    final Widget child = title.isEmpty
        ? numberLabel
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              numberLabel,
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          );

    if (hasSource == false) {
      final disabledColor = Theme.of(context).disabledColor;
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(96, 40),
          foregroundColor: disabledColor,
          side: BorderSide(color: disabledColor),
        ),
        child: child,
      );
    }
    // hasSource == true or null (still loading) both render as the
    // normal/neutral clickable style -- see the class doc comment.
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
      child: child,
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ui/subject/bangumi_episode_grid_test.dart`
Expected: PASS, all 6 tests (4 existing + 2 new).

- [ ] **Step 5: Run the full suite and analyze**

Run: `flutter test`
Expected: all tests pass (431 from Task 1 + 2 new = 433).

Run: `flutter analyze lib/ui/subject/bangumi_episode_grid.dart test/ui/subject/bangumi_episode_grid_test.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/subject/bangumi_episode_grid.dart test/ui/subject/bangumi_episode_grid_test.dart
git commit -m "feat(subject): show episode title snippet in BangumiEpisodeGrid buttons"
```

---

### Task 3: Restructure `SubjectDetailScreen` into a two-column layout

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart` (whole file, 508 lines — multiple sections)

**Interfaces:**
- Consumes: `SubjectDetail.aliases` (Task 1), `BangumiEpisodeGrid`'s already-updated buttons (Task 2), `subjectDetailControllerProvider`, `subjectBangumiEpisodesControllerProvider`, `subjectCharactersProvider`, `subjectStaffProvider` (all pre-existing, unchanged), `SubjectTagsRow`, `_formatAirDateYearMonth` (pre-existing top-level function in this same file, reused not rewritten).
- No new public interface exported from this file — `SubjectDetailScreen`'s own constructor is unchanged.
- No test file for this task (accepted pre-existing gap, per Global Constraints).

This task is one large edit. Do the sub-steps in order; each one is independently verifiable by reading the file afterward, but only the final step (Step 8) requires running analyze/test, since the file will not compile cleanly between steps.

- [ ] **Step 1: Restructure `SubjectDetailScreen.build()` into two columns**

Current `build()` (lines 31-44):

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: ListView(
        children: [
          if (imageUrl != null) _ImmersiveHeader(imageUrl: imageUrl!, subjectId: subjectId),
          _BangumiEpisodesSection(subjectId: subjectId, subjectName: subjectName),
          _SubjectInfoSection(subjectId: subjectId),
          _CastStaffSection(subjectId: subjectId),
        ],
      ),
    );
  }
```

(Exact parameter names/formatting may differ slightly by a few characters — match by structure, not literal whitespace.)

Replace with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: ListView(
        children: [
          if (imageUrl != null) _ImmersiveHeader(imageUrl: imageUrl!, subjectId: subjectId),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WorkInfoSection(subjectId: subjectId),
                      _SubjectInfoSection(subjectId: subjectId),
                      _BangumiEpisodesSection(subjectId: subjectId, subjectName: subjectName),
                      _CharacterSection(subjectId: subjectId),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _StaffSection(subjectId: subjectId)),
              ],
            ),
          ),
        ],
      ),
    );
  }
```

Note `_BangumiEpisodesSection` MOVES from being a full-width sibling of the header into the left column, positioned after `_SubjectInfoSection` and before `_CharacterSection` — this matches the approved design's Section 1 ordering (header → 作品信息 → 简介/评分 → 剧集网格 → 角色, all in the left column; 制作人员 alone in the right column).

- [ ] **Step 2: Remove `airDate` from `_HeaderInfo`**

Current `_HeaderInfo` (relevant excerpt, lines ~161-213) computes and renders a 3-child Row including airDate. Find the block that looks like:

```dart
    final airDateLabel = _formatAirDateYearMonth(subject.airDate);
    final hasScoreOrRank = score != null || subject.rank != null;
    ...
        if (hasScoreOrRank || airDateLabel != null)
          Row(
            children: [
              if (score != null) RatingStars(score: ...),
              if (subject.rank != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('排名：#${subject.rank}'),
                ),
              if (airDateLabel != null)
                Padding(
                  padding: EdgeInsets.only(left: hasScoreOrRank ? 12 : 0),
                  child: Text(hasScoreOrRank ? '· $airDateLabel' : airDateLabel),
                ),
            ],
          ),
```

Replace with (removing the `airDateLabel` computation entirely, and the 3rd Row child, reverting to the original 2-child guard):

```dart
        if (score != null || subject.rank != null)
          Row(
            children: [
              if (score != null) RatingStars(score: ...),
              if (subject.rank != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('排名：#${subject.rank}'),
                ),
            ],
          ),
```

(Keep the actual `RatingStars(score: ...)` call's exact existing arguments — only the surrounding guard/airDate logic changes. Delete the now-unused `airDateLabel`/`hasScoreOrRank` local variable declarations from this function if nothing else in the function references them — `hasScoreOrRank` is no longer needed since the guard is now a plain inline condition.)

Do NOT delete the top-level `_formatAirDateYearMonth` function itself (it currently sits around lines 220-224) — it is reused in Step 3 below.

- [ ] **Step 3: Remove the tags line from `_SubjectInfoSection`**

Current `_SubjectInfoSection`'s `data:` branch renders:

```dart
              ExpandableSummary(text: subject.summary),
              const SizedBox(height: 8),
              SubjectTagsRow(tags: subject.tags),
              const SizedBox(height: 16),
              _RatingSection(subjectId: subjectId),
```

Remove the `SubjectTagsRow(tags: subject.tags)` line and its preceding `const SizedBox(height: 8)`, leaving:

```dart
              ExpandableSummary(text: subject.summary),
              const SizedBox(height: 16),
              _RatingSection(subjectId: subjectId),
```

- [ ] **Step 4: Add the new `_WorkInfoSection` widget**

Add this new private widget anywhere in the file at top level (e.g. right before `_SubjectInfoSection`'s class definition):

```dart
/// New "作品信息" (work info) block: shows the subject's broadcast
/// start date, episode count, aliases, and tags. Combines data from two
/// independent providers (`subjectDetailControllerProvider` for
/// airDate/aliases/tags, `subjectBangumiEpisodesControllerProvider` for
/// the episode count) -- if either hasn't resolved yet, the
/// corresponding line is simply omitted rather than shown as a loading
/// placeholder, since this is a low-priority informational block.
class _WorkInfoSection extends ConsumerWidget {
  const _WorkInfoSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(subjectDetailControllerProvider(subjectId: subjectId));
    final episodesAsync = ref.watch(
      subjectBangumiEpisodesControllerProvider(subjectId: subjectId),
    );

    return detailAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (subject) {
        final airDateLabel = _formatAirDateYearMonth(subject.airDate);
        final episodeCount = episodesAsync.value?.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('作品信息', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (airDateLabel != null) Text('放送开始：$airDateLabel'),
              if (episodeCount != null) Text('话数：$episodeCount'),
              if (subject.aliases.isNotEmpty) Text('别名：${subject.aliases.join(' / ')}'),
              const SizedBox(height: 8),
              SubjectTagsRow(tags: subject.tags),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Delete `_CastStaffSection`**

Find and delete the entire `_CastStaffSection` class (currently around lines 403-451):

```dart
class _CastStaffSection extends ConsumerWidget {
  ... (entire class body) ...
}
```

- [ ] **Step 6: Add `_CharacterSection`**

Add this new private widget in place of (or near) where `_CastStaffSection` was:

```dart
/// Horizontal, scrollable row of character avatars, matching the
/// Animeko reference layout. Deliberately renders the character name
/// ONLY -- there is no voice-actor/CV field anywhere on
/// [CharacterInfo]/[RelatedCharacter] today, so a CV line (present in
/// the reference screenshot) cannot be shown without adding a new,
/// unconfirmed API field, which is out of scope for this pass. The
/// "查看全部" text is a static label with no navigation/expand
/// behavior, per the approved design.
class _CharacterSection extends ConsumerWidget {
  const _CharacterSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charactersAsync = ref.watch(subjectCharactersProvider(subjectId: subjectId));

    return charactersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (characters) {
        if (characters.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('角色', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text('查看全部', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final related in characters)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: related.character.imageUrl != null
                                  ? NetworkImage(related.character.imageUrl!)
                                  : null,
                              child: related.character.imageUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 72,
                              child: Text(
                                related.character.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 7: Add `_StaffSection`**

Add this new private widget (placement anywhere at top level, e.g. right after `_CharacterSection`):

```dart
/// Right-column "制作人员" (staff) table: a flat, two-column
/// key/value list of every (role, name) pair from the API response, in
/// original order. Deliberately NOT deduplicated by role -- if two
/// staff members share the same role (e.g. two "音乐" credits), both
/// render as separate rows. No avatars (the reference screenshot's
/// staff table is text-only) and no "查看全部" link (unlike the
/// 角色 section), per the approved design.
class _StaffSection extends ConsumerWidget {
  const _StaffSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(subjectStaffProvider(subjectId: subjectId));

    return staffAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (staff) {
        if (staff.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('制作人员', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Table(
                columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                children: [
                  for (final member in staff)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 6),
                          child: Text(
                            member.role ?? '',
                            style: TextStyle(color: Theme.of(context).hintColor),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(member.name),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 8: Delete `_PersonList` and `_characterRoleLabel`**

After Step 5/6/7, neither `_PersonList` (currently around lines 460-490) nor `_characterRoleLabel` (currently around lines 497-508) is referenced by anything in the file anymore — `_CharacterSection`/`_StaffSection` each render their own content inline instead of delegating to `_PersonList`, and `_CharacterSection` doesn't render a role label at all. Delete both:

```dart
class _PersonList extends StatelessWidget {
  ... (entire class body) ...
}
```

```dart
String _characterRoleLabel(int role) {
  ... (entire function body) ...
}
```

- [ ] **Step 9: Verify no leftover references, run analyze and full test suite**

Run: `grep -n "_CastStaffSection\|_PersonList\|_characterRoleLabel" lib/ui/subject/subject_detail_screen.dart`
Expected: no output (all three symbols fully removed, no dangling references).

Run: `flutter analyze lib/ui/subject/subject_detail_screen.dart`
Expected: no issues — specifically no `unused_element` warnings (confirming the deleted classes/function aren't just unreferenced but fully removed) and no `undefined_identifier` (confirming `_WorkInfoSection`/`_CharacterSection`/`_StaffSection` and their provider references are all correctly wired).

Run: `flutter test`
Expected: all tests pass (433 from Task 2, no new tests added by this task, so still 433).

- [ ] **Step 10: Commit**

```bash
git add lib/ui/subject/subject_detail_screen.dart
git commit -m "feat(subject): restructure detail page into two-column Bangumi-style layout

- Header stays full-width; body below it splits into a Row: left
  column (flex 2) holds a new 作品信息 block, summary/tags/rating,
  the Bangumi episode grid, and a new horizontal 角色 avatar row;
  right column (flex 1) holds a new 制作人员 table only.
- airDate moves from the header's rating/rank row into the new
  作品信息 block (via the same _formatAirDateYearMonth helper,
  reused not rewritten) so it no longer appears in both places.
- Tags move from _SubjectInfoSection into the same 作品信息 block.
- Replaces _CastStaffSection/_PersonList/_characterRoleLabel with
  _CharacterSection (horizontal avatar row, no CV/actor-name line --
  no such field exists on CharacterInfo/RelatedCharacter, an
  accepted limitation) and _StaffSection (flat, non-deduplicated
  two-column role/name table, no avatars, no 查看全部 link)."
```

---

### Task 4: Final sanity pass

**Files:** none — verification only.

**Interfaces:** none produced; consumes the full state of Tasks 1-3.

- [ ] **Step 1: Regenerate codegen as a safety net**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, 0 outputs written (no drift — Task 1 already regenerated, Tasks 2-3 touch no `@JsonSerializable`/`@riverpod` code).

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: 0 errors, same ~28 pre-existing info-level issue count as the session baseline (no new issues from this feature).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass (433 total: 429 baseline + 2 from Task 1 + 2 from Task 2).

- [ ] **Step 4: Check git state**

Run: `git status --short && git log --oneline -6`
Expected: clean tree except the same 2 pre-existing unrelated untracked items (`android/build/`, `assets/icon/image.png`); commits newest-first: Task 3 → Task 2 → Task 1 → `0e976f9` (design spec) → ... (prior session history).

- [ ] **Step 5: Report to the user (in Chinese)**

Report, in Chinese, that:
- The subject detail page is now a two-column layout matching the approved design: 作品信息/简介/评分/剧集网格/角色 in the left column, 制作人员 table in the right column.
- The 角色 (character) row deliberately shows character names only, with no CV/voice-actor line — this data doesn't exist anywhere in the app's current character model, and adding it would need new, unconfirmed API investigation, which is out of scope for this pass.
- Reiterate the still-open, non-blocking question from earlier in this session about whether to push all of this session's accumulated un-pushed work (this feature plus 4 prior fully-completed features) to `origin/main`.

## Self-Review Notes

- **Spec coverage:** Section 1 (two-column Row/Expanded) → Task 3 Step 1. Section 2 (作品信息 block: airDate/episode-count/aliases/tags) → Task 1 (aliases field) + Task 3 Steps 2-4 (airDate relocation, tags relocation, new block). Section 3 (episode-grid title snippet) → Task 2. Section 4 (角色 horizontal row, static 查看全部) → Task 3 Step 6. Section 5 (制作人员 table, no dedup, no avatars, no 查看全部) → Task 3 Step 7. Section 6 (airDate removed from header) → Task 3 Step 2. Section 7 (explicit out-of-scope list) → reflected via Global Constraints and the accepted-limitation doc comments; no task implements any of the 6 deferred items (collection stats, rating histogram, hot reviews, continue-watching button, `_RatingSection` relocation, 查看全部 click logic) — confirmed by omission.
- **Placeholder scan:** no TBD/TODO left in any task; the one open numeric detail (exact button width in Task 2, `Size(96, 40)`) is a concrete chosen value, not a placeholder.
- **Type consistency:** `_WorkInfoSection`/`_CharacterSection`/`_StaffSection` names are used consistently across Task 3's steps and the Global Constraints/commit message. `SubjectDetail.aliases: List<String>` (Task 1) matches its usage in `_WorkInfoSection` (`subject.aliases.join(' / ')`, `subject.aliases.isNotEmpty`) in Task 3 Step 4. `BangumiEpisode.displayName` (pre-existing) matches its usage in Task 2.
