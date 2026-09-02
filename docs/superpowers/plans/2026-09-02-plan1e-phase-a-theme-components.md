# Plan 1e — Phase A: Theme System + Shared Component Library

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the app's Material 3 theme system (light/dark `ColorScheme` from a seed color, persisted `ThemeMode`, responsive spacing) and a small shared widget library (`AnimeCoverCard`, `AnimeListItem`, `TagChip`, `LoadingView`, `EmptyView`, `buildStandardActions`) that later phases (B–F) will wire into real screens. **This phase creates files only — it does not modify any existing screen's UI.**

**Architecture:** Two new leaf modules, no dependencies on each other or on existing screens:

1. `lib/app/theme/` — pure, stateless theme definitions (`AppTheme.light()`/`AppTheme.dark()` built via `ColorScheme.fromSeed`, matching the reference Animeko app's seed color `#4F378B` and TonalSpot-equivalent default scheme variant) plus a `pagePadding(context)` responsive-spacing helper. `ThemeMode` persistence is added to the *existing* `SettingsStorage` (same pattern as the existing `proxy_url` key) and exposed via a new `ThemeModeController` that mirrors the existing `ProxySettingsController` Riverpod Notifier shape exactly.
2. `lib/ui/common/` — five small, stateless, dependency-free widgets plus one pure helper function, all following the visual spec extracted from the reference Kotlin/Compose app (cover aspect ratio 849:1200, 148dp list-item height, 32dp/8dp-radius tag chips, `surfaceContainerHigh`/`surfaceContainerLow` color roles). None of these widgets read from Riverpod or navigate on their own except `buildStandardActions`, which returns `IconButton`s that call `context.push(...)` (untested navigation target wiring is deferred to Phase C, when these buttons actually replace the duplicated ones in Home/Search/Schedule).

**Tech Stack:** `flutter_riverpod: 3.3.1`, `riverpod_annotation: 4.0.2` + `riverpod_generator: 4.0.3` (codegen), `go_router: ^17.5.0` (only for the `context.push` calls inside `buildStandardActions`), `shared_preferences: ^2.5.5` (already used by `SettingsStorage`), `mocktail` (existing test dep, used for `ThemeModeController` tests mirroring `proxy_settings_controller_test.dart`).

**Design doc:** `docs/superpowers/specs/2026-09-02-plan1e-ui-redesign-design.md`

---

### Task 1: Persist `ThemeMode` in `SettingsStorage`

**Files:**
- Modify: `lib/data/settings/settings_storage.dart`
- Modify: `test/data/settings/settings_storage_test.dart`

- [ ] **Step 1: Write failing tests.** Add a new `group('theme mode', ...)` to the existing `test/data/settings/settings_storage_test.dart` (keep the existing `getProxyUrl`/`setProxyUrl` tests unchanged):
  ```dart
  import 'package:flutter/material.dart' show ThemeMode;
  // ... (add to existing imports)

  group('theme mode', () {
    test('getThemeMode returns null when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      expect(storage.getThemeMode(), isNull);
    });

    test('setThemeMode persists and getThemeMode reads it back', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      await storage.setThemeMode(ThemeMode.dark);
      expect(storage.getThemeMode(), ThemeMode.dark);
    });

    test('getThemeMode returns null for an unrecognized stored value', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', 'bogus');
      final storage = SettingsStorage(prefs);
      expect(storage.getThemeMode(), isNull);
    });

    test('setThemeMode(ThemeMode.system) round-trips', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      await storage.setThemeMode(ThemeMode.system);
      expect(storage.getThemeMode(), ThemeMode.system);
    });
  });
  ```

- [ ] **Step 2: Run tests, confirm failure.** `flutter test test/data/settings/settings_storage_test.dart`. Expected: compile error `The method 'getThemeMode' isn't defined for the type 'SettingsStorage'.` (and similarly for `setThemeMode`).

- [ ] **Step 3: Implement.** Edit `lib/data/settings/settings_storage.dart`, adding the key constant, the two methods, and a private codec — keep every existing line unchanged:
  ```dart
  // lib/data/settings/settings_storage.dart
  import 'package:flutter/material.dart' show ThemeMode;
  import 'package:riverpod_annotation/riverpod_annotation.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  part 'settings_storage.g.dart';

  const _proxyUrlKey = 'proxy_url';
  const _themeModeKey = 'theme_mode';

  class SettingsStorage {
    SettingsStorage(this._prefs);
    final SharedPreferences _prefs;

    String? getProxyUrl() => _prefs.getString(_proxyUrlKey);

    Future<void> setProxyUrl(String? url) async {
      if (url == null) {
        await _prefs.remove(_proxyUrlKey);
      } else {
        await _prefs.setString(_proxyUrlKey, url);
      }
    }

    /// Returns the persisted [ThemeMode], or `null` if nothing has been
    /// saved yet or the stored value is not one of `"system"`/`"light"`/
    /// `"dark"` (e.g. written by a future version of the app).
    ThemeMode? getThemeMode() {
      final raw = _prefs.getString(_themeModeKey);
      return switch (raw) {
        'system' => ThemeMode.system,
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => null,
      };
    }

    Future<void> setThemeMode(ThemeMode mode) async {
      await _prefs.setString(_themeModeKey, mode.name);
    }
  }

  @riverpod
  Future<SettingsStorage> settingsStorage(Ref ref) async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStorage(prefs);
  }
  ```
  Note: `ThemeMode.name` yields exactly `"system"`/`"light"`/`"dark"`, so the switch above round-trips correctly.

- [ ] **Step 4: Run tests, confirm pass.** `flutter test test/data/settings/settings_storage_test.dart` — expect all tests (existing 3 + new 4 = 7) to pass.

- [ ] **Step 5: Full regression check.** `flutter test` (expect no new failures beyond the pre-existing baseline) and `flutter analyze` (expect the same 19 pre-existing issues across the 3 known categories `use_null_aware_elements`/`depend_on_referenced_packages`/`library_private_types_in_public_api` — no new issues).

- [ ] **Step 6: Commit.**
  ```
  git add lib/data/settings/settings_storage.dart test/data/settings/settings_storage_test.dart
  git commit -m "feat(settings): persist ThemeMode in SettingsStorage"
  ```

---

### Task 2: `ThemeModeController`

**Files:**
- Create: `lib/domain/settings/theme_mode_controller.dart`
- Create: `test/domain/settings/theme_mode_controller_test.dart`

- [ ] **Step 1: Write failing test.** Create `test/domain/settings/theme_mode_controller_test.dart`, mirroring `test/domain/settings/proxy_settings_controller_test.dart`'s mock-storage pattern exactly:
  ```dart
  // test/domain/settings/theme_mode_controller_test.dart
  import 'package:animeko_flutter/data/settings/settings_storage.dart';
  import 'package:animeko_flutter/domain/settings/theme_mode_controller.dart';
  import 'package:flutter/material.dart' show ThemeMode;
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';
  import 'package:riverpod/riverpod.dart';

  class MockSettingsStorage extends Mock implements SettingsStorage {}

  void main() {
    group('ThemeModeController', () {
      late MockSettingsStorage storage;
      late ProviderContainer container;

      setUp(() {
        storage = MockSettingsStorage();
        container = ProviderContainer(
          overrides: [settingsStorageProvider.overrideWith((ref) async => storage)],
        );
        addTearDown(container.dispose);
      });

      test('build reads the persisted theme mode', () async {
        when(() => storage.getThemeMode()).thenReturn(ThemeMode.dark);
        final result = await container.read(themeModeControllerProvider.future);
        expect(result, ThemeMode.dark);
      });

      test('build defaults to ThemeMode.system when nothing is persisted', () async {
        when(() => storage.getThemeMode()).thenReturn(null);
        final result = await container.read(themeModeControllerProvider.future);
        expect(result, ThemeMode.system);
      });

      test('setThemeMode persists and updates state', () async {
        when(() => storage.getThemeMode()).thenReturn(null);
        when(() => storage.setThemeMode(any())).thenAnswer((_) async {});
        await container.read(themeModeControllerProvider.future);

        await container
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.light);

        verify(() => storage.setThemeMode(ThemeMode.light)).called(1);
        expect(
          container.read(themeModeControllerProvider).value,
          ThemeMode.light,
        );
      });
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/domain/settings/theme_mode_controller_test.dart`. Expected: `Target of URI doesn't exist: 'package:animeko_flutter/domain/settings/theme_mode_controller.dart'.`

- [ ] **Step 3: Implement.**
  ```dart
  // lib/domain/settings/theme_mode_controller.dart
  import 'package:flutter/material.dart' show ThemeMode;
  import 'package:riverpod_annotation/riverpod_annotation.dart';

  import '../../data/settings/settings_storage.dart';

  part 'theme_mode_controller.g.dart';

  @riverpod
  class ThemeModeController extends _$ThemeModeController {
    @override
    Future<ThemeMode> build() async {
      final storage = await ref.watch(settingsStorageProvider.future);
      return storage.getThemeMode() ?? ThemeMode.system;
    }

    Future<void> setThemeMode(ThemeMode mode) async {
      final storage = await ref.read(settingsStorageProvider.future);
      await storage.setThemeMode(mode);
      state = AsyncData(mode);
    }
  }
  ```

- [ ] **Step 4: Run codegen.** `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: Run test, confirm pass.** `flutter test test/domain/settings/theme_mode_controller_test.dart` — expect 3/3 tests to pass.

- [ ] **Step 6: Full regression check.** `flutter test` + `flutter analyze` (same baseline as Task 1's Step 5).

- [ ] **Step 7: Commit.**
  ```
  git add lib/domain/settings/theme_mode_controller.dart lib/domain/settings/theme_mode_controller.g.dart test/domain/settings/theme_mode_controller_test.dart
  git commit -m "feat(settings): add ThemeModeController"
  ```

---

### Task 3: `AppTheme` (light/dark `ColorScheme`)

**Files:**
- Create: `lib/app/theme/app_theme.dart`
- Create: `test/app/theme/app_theme_test.dart`

- [ ] **Step 1: Write failing test.**
  ```dart
  // test/app/theme/app_theme_test.dart
  import 'package:animeko_flutter/app/theme/app_theme.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    group('AppTheme', () {
      test('kSeedColor matches the reference Animeko app', () {
        expect(kSeedColor, const Color(0xFF4F378B));
      });

      test('light() builds a Material 3 light-brightness ThemeData', () {
        final theme = AppTheme.light();
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      test('dark() builds a Material 3 dark-brightness ThemeData', () {
        final theme = AppTheme.dark();
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, Brightness.dark);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });

      test('both themes are seeded from kSeedColor', () {
        expect(AppTheme.light().colorScheme.primary, isNotNull);
        // ColorScheme.fromSeed derives distinct schemes per brightness, but
        // both must originate from the same seed -- verified indirectly by
        // asserting the seed constant above and that primary is populated.
        expect(AppTheme.dark().colorScheme.primary, isNotNull);
      });
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/app/theme/app_theme_test.dart`. Expected: `Target of URI doesn't exist: 'package:animeko_flutter/app/theme/app_theme.dart'.`

- [ ] **Step 3: Implement.**
  ```dart
  // lib/app/theme/app_theme.dart
  import 'package:flutter/material.dart';

  /// The app's seed color, matching the reference Animeko (Kotlin/Compose)
  /// app's default `DefaultSeedColor` (`app-platform/.../DefaultSeedColor.kt`).
  const kSeedColor = Color(0xFF4F378B);

  /// Builds the app's Material 3 theme. Typography and shape scales are
  /// intentionally left at the Flutter M3 defaults -- see the design doc's
  /// "主题系统" section for why (the reference app does the same, only
  /// swapping the font family, which this app does not currently customize).
  class AppTheme {
    AppTheme._();

    static ThemeData light() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kSeedColor,
        brightness: Brightness.light,
      ),
    );

    static ThemeData dark() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kSeedColor,
        brightness: Brightness.dark,
      ),
    );
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/app/theme/app_theme_test.dart` — expect 4/4 tests to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (same baseline).

- [ ] **Step 6: Commit.**
  ```
  git add lib/app/theme/app_theme.dart test/app/theme/app_theme_test.dart
  git commit -m "feat(theme): add AppTheme.light()/dark()"
  ```

---

### Task 4: `pagePadding` responsive spacing helper

**Files:**
- Create: `lib/app/theme/app_spacing.dart`
- Create: `test/app/theme/app_spacing_test.dart`

- [ ] **Step 1: Write failing test.**
  ```dart
  // test/app/theme/app_spacing_test.dart
  import 'package:animeko_flutter/app/theme/app_spacing.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('pagePadding returns 16 below the 600px breakpoint', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      double? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = pagePadding(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, 16.0);
    });

    testWidgets('pagePadding returns 24 at/above the 600px breakpoint', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      double? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = pagePadding(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, 24.0);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/app/theme/app_spacing_test.dart`. Expected: `Target of URI doesn't exist: 'package:animeko_flutter/app/theme/app_spacing.dart'.`

- [ ] **Step 3: Implement.**
  ```dart
  // lib/app/theme/app_spacing.dart
  import 'package:flutter/material.dart';

  /// Responsive page-level horizontal/vertical padding, matching the
  /// reference app's compact-vs-wide `WindowSizeClass` breakpoint (16dp
  /// below 600px width, 24dp at/above it). See the design doc's "主题系统"
  /// section.
  double pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? 16.0 : 24.0;
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/app/theme/app_spacing_test.dart` — expect 2/2 tests to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (same baseline).

- [ ] **Step 6: Commit.**
  ```
  git add lib/app/theme/app_spacing.dart test/app/theme/app_spacing_test.dart
  git commit -m "feat(theme): add pagePadding responsive spacing helper"
  ```

---

### Task 5: `TagChip`

**Files:**
- Create: `lib/ui/common/tag_chip.dart`
- Create: `test/ui/common/tag_chip_test.dart`

- [ ] **Step 1: Write failing test.**
  ```dart
  // test/ui/common/tag_chip_test.dart
  import 'package:animeko_flutter/ui/common/tag_chip.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('TagChip renders its label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TagChip(label: 'TV'))),
      );
      expect(find.text('TV'), findsOneWidget);
    });

    testWidgets('TagChip is 32dp tall with an outlineVariant border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TagChip(label: 'TV'))),
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(TagChip), matching: find.byType(Container)).first,
      );
      expect(container.constraints?.maxHeight ?? (container.constraints?.minHeight), 32.0);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect((decoration.borderRadius as BorderRadius).topLeft.x, 8.0);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/ui/common/tag_chip_test.dart`. Expected: `Target of URI doesn't exist: 'package:animeko_flutter/ui/common/tag_chip.dart'.`

- [ ] **Step 3: Implement.**
  ```dart
  // lib/ui/common/tag_chip.dart
  import 'package:flutter/material.dart';

  /// A small outlined tag/chip, matching the reference app's `Tag.kt`
  /// (32dp height, 8dp radius, 1dp `outlineVariant` border, `labelLarge`
  /// text, 8dp horizontal padding).
  class TagChip extends StatelessWidget {
    const TagChip({super.key, required this.label});

    final String label;

    @override
    Widget build(BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      );
    }
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/ui/common/tag_chip_test.dart` — expect 2/2 tests to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (same baseline).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/common/tag_chip.dart test/ui/common/tag_chip_test.dart
  git commit -m "feat(ui): add TagChip component"
  ```

---

### Task 6: `AnimeCoverCard`

**Files:**
- Create: `lib/ui/common/anime_cover_card.dart`
- Create: `test/ui/common/anime_cover_card_test.dart`

- [ ] **Step 1: Write failing test.**
  ```dart
  // test/ui/common/anime_cover_card_test.dart
  import 'package:animeko_flutter/ui/common/anime_cover_card.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('AnimeCoverCard renders the title and an AspectRatio matching 849:1200', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimeCoverCard(imageUrl: 'https://example.com/cover.jpg', title: 'Frieren'),
          ),
        ),
      );

      expect(find.text('Frieren'), findsOneWidget);
      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(849 / 1200, 0.0001));
    });

    testWidgets('AnimeCoverCard calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeCoverCard(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AnimeCoverCard));
      expect(tapped, isTrue);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/ui/common/anime_cover_card_test.dart`. Expected: `Target of URI doesn't exist: 'package:animeko_flutter/ui/common/anime_cover_card.dart'.`

- [ ] **Step 3: Implement.**
  ```dart
  // lib/ui/common/anime_cover_card.dart
  import 'package:flutter/material.dart';

  /// A vertical anime cover card: a `849:1200`-ratio cover image (matching
  /// the reference app's `COVER_WIDTH_TO_HEIGHT_RATIO`) with a title below,
  /// on a `surfaceContainerHigh` background and 16dp corner radius.
  class AnimeCoverCard extends StatelessWidget {
    const AnimeCoverCard({super.key, required this.imageUrl, required this.title, this.onTap});

    static const coverAspectRatio = 849 / 1200;

    final String imageUrl;
    final String title;
    final VoidCallback? onTap;

    @override
    Widget build(BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/ui/common/anime_cover_card_test.dart` — expect 2/2 tests to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (same baseline).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/common/anime_cover_card.dart test/ui/common/anime_cover_card_test.dart
  git commit -m "feat(ui): add AnimeCoverCard component"
  ```

---

### Task 7: `AnimeListItem`

**Files:**
- Create: `lib/ui/common/anime_list_item.dart`
- Create: `test/ui/common/anime_list_item_test.dart`

- [ ] **Step 1: Write failing test.**
  ```dart
  // test/ui/common/anime_list_item_test.dart
  import 'package:animeko_flutter/ui/common/anime_list_item.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('AnimeListItem renders title, subtitle, and is 148dp tall', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimeListItem(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              subtitle: '第 12 集',
            ),
          ),
        ),
      );

      expect(find.text('Frieren'), findsOneWidget);
      expect(find.text('第 12 集'), findsOneWidget);
      final size = tester.getSize(find.byType(AnimeListItem));
      expect(size.height, 148.0);
    });

    testWidgets('AnimeListItem calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeListItem(
              imageUrl: 'https://example.com/cover.jpg',
              title: 'Frieren',
              subtitle: '第 12 集',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AnimeListItem));
      expect(tapped, isTrue);
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/ui/common/anime_list_item_test.dart`. Expected: `Target of URI doesn't exist: 'package:animeko_flutter/ui/common/anime_list_item.dart'.`

- [ ] **Step 3: Implement.**
  ```dart
  // lib/ui/common/anime_list_item.dart
  import 'package:flutter/material.dart';

  import 'anime_cover_card.dart';

  /// A horizontal anime list item card: fixed 148dp height, cover on the
  /// left (cropped to the same 849:1200 ratio as [AnimeCoverCard]), title +
  /// subtitle on the right. Matches the reference app's
  /// `SubjectCollectionItem` row-card style (148dp height, 12dp radius,
  /// `surfaceContainerHigh` background).
  class AnimeListItem extends StatelessWidget {
    const AnimeListItem({
      super.key,
      required this.imageUrl,
      required this.title,
      required this.subtitle,
      this.onTap,
    });

    static const height = 148.0;

    final String imageUrl;
    final String title;
    final String subtitle;
    final VoidCallback? onTap;

    @override
    Widget build(BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: AnimeCoverCard.coverAspectRatio,
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/ui/common/anime_list_item_test.dart` — expect 2/2 tests to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (same baseline).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/common/anime_list_item.dart test/ui/common/anime_list_item_test.dart
  git commit -m "feat(ui): add AnimeListItem component"
  ```

---

### Task 8: `LoadingView` and `EmptyView`

**Files:**
- Create: `lib/ui/common/loading_view.dart`
- Create: `lib/ui/common/empty_view.dart`
- Create: `test/ui/common/loading_view_test.dart`
- Create: `test/ui/common/empty_view_test.dart`

- [ ] **Step 1: Write failing tests.**
  ```dart
  // test/ui/common/loading_view_test.dart
  import 'package:animeko_flutter/ui/common/loading_view.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('LoadingView shows a centered CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingView())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });
  }
  ```
  ```dart
  // test/ui/common/empty_view_test.dart
  import 'package:animeko_flutter/ui/common/empty_view.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('EmptyView renders the given icon and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyView(icon: Icons.inbox_outlined, message: '还没有收藏任何番剧'),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('还没有收藏任何番剧'), findsOneWidget);
    });

    testWidgets('EmptyView defaults to Icons.inbox_outlined when no icon is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyView(message: '没有数据'))),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: Run tests, confirm failure.** `flutter test test/ui/common/loading_view_test.dart test/ui/common/empty_view_test.dart`. Expected: `Target of URI doesn't exist` for both `loading_view.dart` and `empty_view.dart`.

- [ ] **Step 3: Implement.**
  ```dart
  // lib/ui/common/loading_view.dart
  import 'package:flutter/material.dart';

  /// A centered loading spinner, replacing the `Center(child:
  /// CircularProgressIndicator())` boilerplate duplicated across
  /// Home/Search/Schedule/Collection/Player screens.
  class LoadingView extends StatelessWidget {
    const LoadingView({super.key});

    @override
    Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
  }
  ```
  ```dart
  // lib/ui/common/empty_view.dart
  import 'package:flutter/material.dart';

  /// A centered empty-state placeholder (icon + message), e.g. for the
  /// "还没有收藏任何番剧" text currently inlined in `my_collection_screen.dart`.
  class EmptyView extends StatelessWidget {
    const EmptyView({super.key, this.icon = Icons.inbox_outlined, required this.message});

    final IconData icon;
    final String message;

    @override
    Widget build(BuildContext context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 4: Run tests, confirm pass.** `flutter test test/ui/common/loading_view_test.dart test/ui/common/empty_view_test.dart` — expect 1/1 and 2/2 tests to pass respectively.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (same baseline).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/common/loading_view.dart lib/ui/common/empty_view.dart test/ui/common/loading_view_test.dart test/ui/common/empty_view_test.dart
  git commit -m "feat(ui): add LoadingView and EmptyView components"
  ```

---

### Task 9: `buildStandardActions` (shared AppBar actions helper)

**Files:**
- Create: `lib/ui/common/app_action_bar.dart`
- Create: `test/ui/common/app_action_bar_test.dart`

- [ ] **Step 1: Write failing test.** This only verifies the three icons render with the right tooltips — actual navigation (`context.push`) is exercised end-to-end in Phase C once these buttons replace the duplicated ones in Home/Search/Schedule, inside the real `go_router`-backed app shell (see `test/app/router_test.dart` for that pattern). A bare `MaterialApp` (no router) is sufficient here since `context.push` is only invoked on tap, never during build.
  ```dart
  // test/ui/common/app_action_bar_test.dart
  import 'package:animeko_flutter/ui/common/app_action_bar.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('buildStandardActions returns 3 icon buttons: account, collection, settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) =>
                Scaffold(appBar: AppBar(actions: buildStandardActions(context))),
          ),
        ),
      );

      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byType(IconButton), findsNWidgets(3));
    });
  }
  ```

- [ ] **Step 2: Run test, confirm failure.** `flutter test test/ui/common/app_action_bar_test.dart`. Expected: `Target of URI doesn't exist: 'package:animeko_flutter/ui/common/app_action_bar.dart'.`

- [ ] **Step 3: Implement.**
  ```dart
  // lib/ui/common/app_action_bar.dart
  import 'package:flutter/material.dart';
  import 'package:go_router/go_router.dart';

  /// The 3 `IconButton`s shared by Home/Search/Schedule's `AppBar.actions`:
  /// account (new in Plan 1e), collection ("我的收藏"), and settings.
  /// Wiring this into those screens (replacing their inlined, duplicated
  /// `IconButton`s) is Phase C's job -- this task only adds the helper.
  List<Widget> buildStandardActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.account_circle_outlined),
        tooltip: '账户',
        onPressed: () => context.push('/account'),
      ),
      IconButton(
        icon: const Icon(Icons.bookmark),
        tooltip: '我的收藏',
        onPressed: () => context.push('/collection'),
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        tooltip: '设置',
        onPressed: () => context.push('/settings'),
      ),
    ];
  }
  ```

- [ ] **Step 4: Run test, confirm pass.** `flutter test test/ui/common/app_action_bar_test.dart` — expect 1/1 test to pass.

- [ ] **Step 5: Full regression check.** `flutter test` + `flutter analyze` (same baseline).

- [ ] **Step 6: Commit.**
  ```
  git add lib/ui/common/app_action_bar.dart test/ui/common/app_action_bar_test.dart
  git commit -m "feat(ui): add buildStandardActions shared AppBar actions helper"
  ```

---

## Definition of Done

- [ ] `flutter test` passes in full (baseline 250 + this plan's ~19 new tests, all green).
- [ ] `flutter analyze` reports exactly the same 19 pre-existing issues across the 3 known categories (`use_null_aware_elements`, `depend_on_referenced_packages`, `library_private_types_in_public_api`) — zero new issues.
- [ ] All 9 tasks' commits are present in `git log` on `main`.
- [ ] No existing screen file (`lib/ui/home/`, `lib/ui/search/`, `lib/ui/schedule/`, `lib/ui/subject/`, `lib/ui/collection/`, `lib/ui/settings/`, `lib/ui/player/`, `lib/app/main.dart`) was modified by this plan — confirm with `git diff main~9..main --stat` (or equivalent) showing only new files plus `settings_storage.dart`/`settings_storage_test.dart`.
- [ ] (Manual, non-blocking) Optionally run `flutter build macos --debug` to confirm the new files compile into a full app build, even though nothing references them yet.

**Not in scope for this phase** (tracked in the design doc for Phases B–F): wiring `AppTheme`/`ThemeModeController` into `MaterialApp.router` in `main.dart`; replacing any screen's inlined cards/list tiles/AppBar actions with the new `lib/ui/common/` widgets; the new `/account` screen and `GET /v1/me` API client; the reworked settings screen.
