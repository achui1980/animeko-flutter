# AGENTS.md

Flutter port of **Animeko** (formerly Ani), a Bangumi-backed anime tracking/streaming
app. The original is Kotlin Multiplatform + Compose Multiplatform; this repo is a
from-scratch Flutter rewrite, currently targeting **macOS desktop only** (Phase 1).
The KMP app is not in this repo — don't go looking for it here.

Design/planning docs for *why* things are built this way live in
`docs/superpowers/specs/` and `docs/superpowers/plans/` (dated markdown files).
Read `docs/superpowers/specs/2026-08-27-flutter-migration-phase1-design.md` first
for the full architecture rationale if a task touches app-wide structure.

## Commands

```bash
flutter pub get              # install deps (run after pulling or editing pubspec.yaml)
flutter test                 # full suite: ~359 tests, ~20s
flutter test test/path/to/foo_test.dart   # single file
flutter test --plain-name "some test name"  # single test by name
flutter analyze              # static analysis; must be clean of errors (infos are pre-existing/ok)
dart format lib test         # formatting
dart run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart (see below)
dart run build_runner watch --delete-conflicting-outputs   # codegen watch mode while iterating
```

No CI workflow exists yet in this repo — `flutter analyze` + `flutter test` are the
only gates; run both before considering work done.

## Codegen — you WILL need this

Generated `*.g.dart` files are checked into `lib/` alongside their sources
(41+ files as of writing). If you add/edit any of the following, you must
regenerate before the code will compile or the change will take effect:

- Any `@riverpod` annotated function/class (riverpod_generator) — every provider
  file has `part 'foo.g.dart';` at the top.
- `LocalDatabase` / Drift tables (`lib/data/local_database.dart` → `local_database.g.dart`).
- `@JsonSerializable` models (json_serializable).

Run `dart run build_runner build --delete-conflicting-outputs` after such edits.
Forgetting this is the most common source of confusing "undefined class/mixin"
errors in this codebase (e.g. `_$FooNotifier`, `$FooProvider`).

Note: this project uses **Riverpod 3.x** (`flutter_riverpod: 3.3.1`,
`riverpod_annotation: 4.0.2`) — API differs from Riverpod 2.x in ways that may
not match older training data/examples; check existing providers in
`lib/domain/**` for the current idiom (`@riverpod` functions/classes with `Ref`,
not `AutoDisposeProviderRef` etc.) before writing new ones from memory.

## Architecture — layered, mirrors the original KMP app

```
lib/
  app/       entrypoint (main.dart), go_router routes+redirects, theming, DI (ProviderContainer)
  domain/    UseCase/controller logic (Riverpod providers), business rules
  data/      Repository impls, hand-written dio API clients, Drift DB, shared_preferences/secure_storage wrappers
  platform/  platform-specific glue (browser launching, platform info)
  ui/        widgets/screens, one subdir per feature (auth, home, player, schedule, search, settings, shell, subject, collection, common)
```

`test/` mirrors this tree 1:1 (e.g. `lib/domain/auth/auth_controller.dart` ↔
`test/domain/auth/auth_controller_test.dart`) — put new tests in the matching path.

**`domain/` is intended to stay pure Dart (no `package:flutter` imports)** so
business logic is unit-testable without widget test scaffolding. Two existing
files (`domain/settings/seed_color_controller.dart`,
`domain/settings/theme_mode_controller.dart`) are exceptions because they need
`Color`/`ThemeMode` types — don't use that as precedent to import flutter
elsewhere in domain/.

There is **no OpenAPI-generated client** despite some doc comments mentioning
"the OpenAPI spec" (e.g. `lib/data/home/home_recommendations_api.dart`) — all
API clients in `data/` are hand-written `dio`-based classes. The migration
design doc originally proposed generating clients but Phase 1 shipped without
it; don't assume generated client code exists.

## Key conventions

- **State/DI**: Riverpod only, via `@riverpod` codegen (not manual `Provider`/
  `StateNotifierProvider` declarations). See any file in `lib/domain/**` for the pattern.
- **Routing**: `go_router`, declared in `lib/app/router.dart` (+ generated `router.g.dart`).
- **Local persistence**: Drift (`lib/data/local_database.dart`) for relational data,
  `shared_preferences` for plain settings, `flutter_secure_storage` for OAuth tokens
  (Bangumi access/refresh tokens — never store these in shared_preferences).
- **Video playback**: `media_kit` (libmpv-based). `MediaKit.ensureInitialized()` must
  run in `main()` before any `Player()` is constructed — see comments in `lib/app/main.dart`.
- **Auth flow**: Bangumi OAuth is server-hosted (the backend owns the redirect callback);
  the client only opens a browser via `url_launcher` and polls a `/result` endpoint.
  There is no local callback server/port and no custom URL scheme — don't reintroduce one.
- **Commit style**: Conventional Commits with scope, e.g. `feat(player): ...`,
  `fix(collection): ...`, `docs: ...`, `perf(subject): ...`. Match existing `git log`.

## Repo-specific dev workflow (superpowers SDD)

This repo is developed via the `subagent-driven-development` skill workflow:
design → plan → per-task subagent implementation → code review, with artifacts
persisted in two places:
- `docs/superpowers/specs/` and `docs/superpowers/plans/` — durable, dated design
  docs and implementation plans (check these before large features; a relevant
  plan may already exist).
- `.superpowers/sdd/` — ephemeral per-task briefs/reports/review diffs and a
  running `progress.md` log of completed tasks. Useful for recent history but
  not authoritative design documentation.

If asked to implement a feature that already has a doc under
`docs/superpowers/{specs,plans}/`, follow that plan rather than re-deriving the
approach from scratch.
