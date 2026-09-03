# Settings / Bottom-Nav Redesign — Design

**Status:** Approved (verbal), pending written-spec review.

## Motivation

The user reported the current UI layout for reaching Settings still feels awkward: Settings is reached via an `AppBar` icon from any of the three tabs, account info lives on a separate `/account` page, and the bottom nav bar has only 3 destinations. The user wants Settings promoted to a peer bottom-nav tab (matching Home/Search/Schedule), with account info folded into the top of the Settings page instead of being a separate destination.

## Scope

This is a narrowly-scoped restructuring of navigation and the Settings page only. It does **not** touch Home/Search/Schedule/Collection/Subject-Detail/Player pages beyond the one-line `buildStandardActions()` icon change described below. Confirmed with the user explicitly ("只做设置/底部导航这一个改动").

## Decisions (from brainstorming Q&A)

1. **Bottom nav becomes 4 tabs**: 首页 (Home) / 搜索 (Search) / 追番日历 (Schedule) / 设置 (Settings). The existing 3 tabs are unchanged; Settings is added as a 4th peer `StatefulShellBranch`.
2. **"不要 AppBar" means**: only the AppBar-icon-based *navigation entry point* to Settings is removed. The Settings screen itself (and other screens) keep their own `AppBar` with a title. No broader "remove all AppBars" intent.
3. **`/account` is deleted**: `AccountScreen` and its route are removed entirely. Its content (avatar, nickname, sign-out) is merged into a new top section of the Settings screen.
4. **`buildStandardActions()` keeps only the Collection icon**: Collection is *not* promoted to a 5th bottom-nav tab; it remains reachable via the one AppBar icon that Home/Search/Schedule already share.

## Architecture

### Routing (`lib/app/router.dart`)

- Remove the `/account` `GoRoute` and its `AccountScreen` import.
- Remove `/settings` as a standalone top-level `GoRoute` reached by `context.push`.
- Add a 4th `StatefulShellBranch` to the existing `StatefulShellRoute.indexedStack`, wrapping a route tree rooted at `/settings` (peer to the existing `/home`, `/search`, `/schedule` branches). Each branch keeps its own independent navigation stack, matching the existing pattern — so pushing `/settings/proxy` from within the Settings tab still works exactly as it does today, just reached from a shell branch instead of a top-level route.
- `/settings/proxy` and `/collection` remain unchanged as top-level pushed routes (reached via `context.push`, not shell branches).

### Bottom navigation (`lib/ui/shell/main_shell.dart`)

- Add a 4th `NavigationDestination` for Settings, using `Icons.settings` and the label `'Settings'` — matching the existing destinations' English-label convention (`'Home'`/`'Search'`/`'Schedule'`), even though the rest of the app's UI text is Chinese. This preserves internal consistency with the existing 3 labels rather than mixing languages within the same widget.

### Settings screen (`lib/ui/settings/settings_screen.dart`)

- Remove the existing "账户" `_SettingsGroup` (the `ListTile` that pushed to `/account`).
- Add a new top-of-page section, `AccountSummarySection`, rendered above the existing "通用" (theme) and "网络" (proxy) groups. `SettingsScreen`'s own `body` becomes: `AccountSummarySection()`, `SizedBox(height:16)`, then the same "通用"/"网络" `_SettingsGroup`s as before (unchanged content).

### New widget: `lib/ui/settings/account_summary_section.dart`

`AccountSummarySection extends ConsumerWidget`, watching `selfUserProvider` directly (not passed in as a parameter — it needs its own async loading/error handling, consistent with the established pattern of extracting a self-contained section rather than making the whole page wait on one combined state). Reuses the exact avatar/nickname/divider/sign-out/confirm-dialog code from the old `AccountScreen.build()`'s data branch:

- `loading` → `LoadingView()`.
- `error` → `ErrorRetryView(message, onRetry: () => ref.invalidate(selfUserProvider))`.
- `data(user)` → centered `CircleAvatar` (radius 48, `NetworkImage(user.mediumAvatar)` when present, else `Icon(Icons.person, size:48)`) + `SizedBox(height:16)` + bold centered nickname (`titleLarge`) + `SizedBox(height:16)` + `Divider()` + `ListTile` (icon `Icons.logout` + text `'退出登录'`, both `colorScheme.error`) that opens the same confirm `AlertDialog` ("退出登录" / "确定要退出登录吗？" / "取消" + "退出登录" buttons), calling `ref.read(authControllerProvider.notifier).signOut()` on confirm.

This is a direct extraction of `AccountScreen`'s existing widget tree into a smaller, independently-testable component — no new behavior, just a new home for the same behavior.

### `lib/ui/account/account_screen.dart` — deleted entirely

Along with `test/ui/account/account_screen_test.dart`. Their logic/tests migrate to `account_summary_section.dart`/`account_summary_section_test.dart`.

### `lib/ui/common/app_action_bar.dart`

`buildStandardActions()` is trimmed from 3 `IconButton`s (account, collection, settings) to exactly 1 (collection → `/collection`). The function keeps its plural-sounding name despite now returning a singleton list — renaming it isn't warranted by this change (YAGNI: minimal churn, the function's contract — "the list of shared AppBar actions" — is unchanged even though its cardinality shrinks). Home/Search/Schedule's own files need no changes since they already just call `actions: buildStandardActions(context)`.

## Testing strategy

- `test/ui/common/app_action_bar_test.dart` — update the existing test to assert exactly 1 `IconButton` (collection/bookmark icon), removing the account/settings icon assertions.
- `test/ui/settings/account_summary_section_test.dart` (new) — migrate the 2 sign-out tests from the deleted `account_screen_test.dart` (confirm sign-out calls `signOut()`; cancel does not), reusing the same `_FakeAuthController`-with-`signOutCalled`-flag pattern and `selfUserProvider` override.
- `test/ui/settings/settings_screen_test.dart` — update: remove the "tapping account entry navigates to /account" test (no longer applicable); add `selfUserProvider` override to the test's `_wrap()` helper (not currently overridden, but now required since `AccountSummarySection` is inline); add an assertion that the account section (e.g. the nickname) renders inline on the Settings page. The existing "shows persisted theme/proxy/auth summary" and "tapping proxy entry navigates to /settings/proxy" tests are kept, adapting only what's needed for the new inline account section.
- `test/app/router_test.dart` — remove the "navigating to /account renders AccountScreen" test entirely (route no longer exists). The "navigating to /settings/proxy renders ProxySettingsScreen" test is expected to need no changes, since it pushes directly to `/settings/proxy` without depending on whether `/settings` itself is a shell branch or a standalone route. Add one new test verifying that switching to the Settings tab (via the 4th shell branch) renders the Settings screen correctly.
- No test is added asserting `/account` fails to resolve — there's no product requirement for graceful handling of the now-defunct route; removing the old test is sufficient (YAGNI).
- `main_shell.dart` has no existing test file; adding a minimal one to assert 4 destinations are present is a reasonable option but not required by this design (left to the implementation plan to decide granularity — could equally be covered end-to-end by the new router test above).

## Out of scope

- No changes to Home/Search/Schedule/Collection/Subject-Detail/Player screens beyond the `buildStandardActions()` icon count.
- No changes to `/settings/proxy`'s own content or route path.
- No handling for deep-links or bookmarks that might reference the now-removed `/account` path.
- No visual redesign of the Settings page's existing "通用"/"网络" groups beyond making room for the new account section above them.

## Spec self-review (performed inline)

- **Placeholder scan**: no TBD/TODO markers remain.
- **Internal consistency**: the routing section, bottom-nav section, and settings-screen section agree on what moves where; the testing section's file list matches every file touched by the architecture section.
- **Scope check**: single, focused restructuring — appropriately sized for one implementation plan.
- **Ambiguity check**: the one previously-ambiguous point (destination label language) has been resolved explicitly (English label `'Settings'`, matching the existing 3 destinations' convention) rather than left open.
