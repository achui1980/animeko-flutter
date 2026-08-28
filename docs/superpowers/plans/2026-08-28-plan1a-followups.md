# Plan 1a — Follow-ups from the final code review

Plan 1a (bootstrap, network layer, Bangumi OAuth) is complete: a real Bangumi OAuth
login was verified end-to-end against production `https://api.animeko.org` on macOS,
with tokens confirmed persisted in the Keychain under App Sandbox.

The final holistic review found **no Critical issues** and concluded
*"wrap up with noted follow-ups"*. This document records those follow-ups so they are
not lost. Items marked **[do before Plan 1b]** get materially more expensive once
session restore and stored tokens exist.

## Important

### I1 — The login flow has no escape from `AuthError` or `AuthPolling`
`lib/ui/auth/login_screen.dart:33` renders `AuthError` as bare text with no retry
affordance, and the polling branch has no cancel. `AuthController.build()` calls
`ref.keepAlive()` unconditionally (`lib/domain/auth/auth_controller.dart:31`), so the
state cannot even reset by disposal. One failed request is a full dead end until the
app is restarted. The Kotlin reference returns to `State.Idle`
(`OAuthConfigurator.kt:88`).

Fix: add `void reset() => state = const AuthUnauthenticated();`, render a "Try again"
button in the `AuthError` branch and a Cancel in the polling branch, and scope
`keepAlive` to the async work instead of the whole notifier lifetime:

```dart
Future<void> login({required bool isRegister}) async {
  final link = ref.keepAlive();
  try { /* ... */ } finally { link.close(); }
}
```

### I2 — Unbounded poll loop combined with zero HTTP timeouts
`auth_controller.dart:64-68` is `while (true)`, and `lib/data/api_client.dart:14`
constructs `Dio` with no `connectTimeout`/`receiveTimeout`/`sendTimeout`. If the user
closes the browser tab without approving, the app polls `api.animeko.org` every second
for the rest of the process lifetime.

The Kotlin loop is also unbounded, but it lives in a cancellable coroutine scope and
handles `CancellationException` explicitly (`OAuthConfigurator.kt:70-75,87-89`). Dart
has no structured-concurrency equivalent, so the port silently lost the mechanism that
bounded the original — "same as the reference" does not mean "equally safe" here.

Fix: set timeouts on `BaseOptions`, bound the loop with a wall-clock deadline that
emits `AuthError` on expiry, and check a cancellation flag each iteration (set by
`reset()` from I1).

### I3 — `BrowserLauncher.open()`'s failure signal is dropped
`auth_controller.dart:48` discards the `bool` from `await launcher.open(...)`, even
though `browser_launcher_test.dart:29-35` explicitly tests the `false` path. If no
browser handler is registered the user sees an infinite spinner with no browser and no
error.

Fix: emit `AuthError('Could not open the system browser')` when `open()` returns
false, and add a controller test for it.

### I4 — `_os`/`_arch` are un-injectable statics in the wrong layer **[do before Plan 1b]**
`auth_controller.dart:78-88`. Three distinct problems:

- **Coverage hole (highest-risk item in the slice).** The controller tests match with
  `any(named: 'os')` / `any(named: 'arch')` / `any(named: 'requestId')`. A regression
  back to `'arm64'`, or back to the pre-fix `req-$micros` request id, passes all 32
  tests. Three of the four bugs found by hand during Task 11 live precisely in the
  values the suite refuses to look at.
- **Layering.** OS/arch detection is a platform fact and `lib/platform/` already
  exists for exactly that. `dart:ffi` in the domain layer respects the letter of the
  "no Flutter imports" rule but not its intent.
- **Latent correctness for Plan 1c.** The heuristic
  `Abi.current().toString().contains('arm64') ? 'aarch64' : 'x86_64'` returns
  `'aarch64'` on Android arm64, where Kotlin sends `arm64-v8a` (`Platform.kt:104`);
  and `Abi.androidArm` (32-bit) contains neither token, so it falls through to
  `'x86_64'` — flatly wrong. Correct for macOS only.

Fix: extract `lib/platform/platform_info.dart` exposing
`@riverpod PlatformInfo platformInfo(Ref)` with `os`/`arch`, inject it into
`AuthController`, and assert exact values.

**The single highest-value test to add first:** capture the real arguments with
`captureAny(named: ...)` in `auth_controller_test.dart` and assert `os == 'macos'`,
`arch == 'aarch64'`, and that `requestId` matches a UUID-v4 pattern. That one test
locks down three of the four bugs that previously required a human at a terminal.

### I5 — `SecureTokenStorage` writes three keys non-atomically **[do before Plan 1b]**
`lib/data/auth/secure_token_storage.dart:26-33` performs three sequential writes. An
interruption mid-write leaves an access token with no refresh token (or no expiry), so
Plan 1b's session-restore path would have to defensively handle every partial
combination. Storing a single JSON blob under one key makes the write atomic and
restore a single read. Cheapest to change now, while there is no stored data to
migrate.

Note: the write-only `expiresAtMillis` is **not** itself a problem — the value is
persisted, tested, and cleared correctly; Plan 1b only needs to add a reader against
the same key constant.

## Minor

- **M2** — `auth_state.dart:15-17`: `AuthAwaitingBrowser`'s doc comment claims the
  link was fetched and the browser opened, but `auth_controller.dart:37` enters this
  state *before* both. It actually means "fetching link / opening browser".
- **M3** — `auth_controller.dart:55` renders raw `e.toString()` to the user;
  `DioException.toString()` embeds the request path and often the response body.
  Introduce a typed error (network / server / cancelled / unknown) — Plan 1b needs one
  regardless.
- **M4** — No logging anywhere in the app. The Kotlin reference logs flow start,
  success with a token *hash*, and failure with the request id
  (`OAuthConfigurator.kt:54,78,94-96`). This is why Task 11's four bugs needed manual
  discovery, and it scales badly against Plan 1b's endpoint count. Follow upstream's
  habit of logging `hashCode` rather than the token.
- **M5** — `auth_controller.dart:64-68` polls before its first delay; Kotlin delays
  first. Costs one guaranteed-425 request per login.
- **M6** — `login()` has no re-entrancy guard. Unreachable today (the button only
  renders in `AuthUnauthenticated`), but I1's retry button makes two concurrent
  unbounded poll loops reachable. Guard it as part of I1.
- **M7** — Leftover `flutter create` scaffolding: unused `cupertino_icons`,
  "A new Flutter project." in `pubspec.yaml`/`README.md`, empty
  `macos|ios/RunnerTests/RunnerTests.swift` stubs, commented-out assets/fonts blocks.
- **M8** — `secure_token_storage.dart:48-58` sets `usesDataProtectionKeychain: false`
  unconditionally, including release builds. The comment explains *why* it is needed
  (local signing) but not that the legacy file-based keychain is the **weaker** store;
  `MacOsOptions.accessibility` is also left at its default. Either gate on
  `kDebugMode`, or add an explicit TODO tied to obtaining an Apple Team ID +
  `keychain-access-groups` so a signed release does not silently inherit the weaker
  store.
- **M9** — Both remaining analyzer infos are one-line fixes: import
  `package:flutter_riverpod/flutter_riverpod.dart` in `auth_controller_test.dart:10`
  (it re-exports `ProviderContainer`), and make `_FakeAuthController` non-private in
  `login_screen_test.dart:25`. A permanently non-zero analyzer is how real warnings
  get missed later.
- **M10** — The "domain is Flutter-free" invariant is unenforced (`riverpod_lint` was
  deliberately deviated away in `3b4bba4` for a real version conflict). A ~10-line
  test asserting no file under `lib/domain/` contains `package:flutter` would pin the
  design doc's central architectural claim for almost nothing.
- **CI gate** — add `dart run build_runner build && git diff --exit-code` so committed
  generated code cannot drift again (it had drifted; fixed in `9593a32`).

## Hand-written Dio vs. the planned openapi-generator

Keep the hand-written client for these three endpoints — for three endpoints it was
the right call, and they are genuinely special (the only unauthenticated, pre-session
endpoints). The precedent risk is narrow but real:

- `bangumi_oauth_models.dart` uses unchecked casts, so a server field rename becomes a
  runtime `TypeError` surfaced as a login-failure string, with no schema to diff
  against.
- There is no shared interceptor, so every authenticated endpoint added in Plan 1b
  would re-implement bearer-token attachment and status translation.

Because `dioProvider` (`lib/data/api_client.dart:13`) is a single injection point,
generated and hand-written clients can coexist. The fix is additive: land the
auth/error interceptor and the generator path before the endpoint count grows, and
leave these three as they are.

## Prioritized order

1. **Make the login flow escapable and bounded** — I1 + I2 + I3 + scoped `keepAlive` +
   M6. Largest user-visible gap; almost entirely confined to `auth_controller.dart`
   and `login_screen.dart`.
2. **Extract `PlatformInfo` and add the exact-value request test** — I4. Fixes the one
   real layering violation, pre-empts the Android `arm64-v8a` bug before Plan 1c, and
   closes the coverage hole that let three of four hand-found bugs through a green
   suite.
3. **Settle the persistence and networking shapes while they are free** — I5 (single
   JSON blob) plus the Dio auth/error interceptor and typed error model (M3), which
   Plan 1b's token-refresh work needs on day one. Fold in the codegen CI gate.
