# Plan 1b-1 Final-Review Follow-ups

Recorded during the whole-plan holistic code-quality review after all 8 tasks of
[Plan 1b-1: Data Foundation Layer](2026-08-28-plan1b-1-data-foundation.md) were
individually implemented, reviewed, and approved. Item **C1** (startup could
block indefinitely on a slow/absent network) was fixed immediately as part of
Plan 1b-1 itself (commit `7b66fb2`). The remaining items below are genuine,
newly-discovered architectural gaps that only became visible once the whole
auth stack was traced end-to-end as one system — they were correctly
undetectable by any single task's own (heavily-mocked) unit tests. They should
be addressed by **Plan 1b-2** (or whichever plan first wires a real repository
through `dioProvider` and adds a second app screen), not before, since they
depend on infrastructure (an authenticated repository, a real post-login
screen) that doesn't exist yet.

## I-A — No path for a background token-refresh failure to route the user back to login

`AuthInterceptor`'s one-shot 401-refresh-and-retry (`lib/data/auth_interceptor.dart`)
clears local storage on a hard refresh failure (via `SessionRefresher`), but
nothing ties that outcome back to `authControllerProvider`. Once
`restoreSession()` has set `AuthAuthenticated(userId)` at startup, that state
is permanently cached (`AuthController.build()` unconditionally calls
`ref.keepAlive()` — pre-existing, tracked separately as I1 in
[the Plan 1a follow-ups doc](2026-08-28-plan1a-followups.md)). If, during
later ordinary use, a background refresh triggered by the interceptor fails
(refresh token finally revoked/expired), storage is silently cleared but the
controller — and therefore any UI built on top of it — keeps reporting
`AuthAuthenticated` forever, with every subsequent request just 401ing anew.

This contradicts the approved design doc's stated behavior
(`docs/superpowers/specs/2026-08-28-plan1b-series-design.md`, "会话恢复"
section: *"仍失败则清空会话回到登录页"* — "if still failing, clear the
session and return to the login page").

**Currently dormant, not yet a live bug**: the only screen in the app today
(`LoginScreen`) never calls any repository through `dioProvider`, so the
interceptor's refresh path is never actually exercised end-to-end yet.

**Fix direction for Plan 1b-2**: give repositories built on `dioProvider` a
way to force `AuthController` back to `AuthUnauthenticated` when they observe
an `AuthExpiredError` (see I-B below) that survived a failed
interceptor-driven refresh — e.g. a `signOut()`/`reset()` method on
`AuthController`, invoked by a shared error-handling layer in the repository
base class, rather than each repository re-implementing this.

## I-B — `SessionRefresher.refresh()`'s "never throws" contract discards `AppError` type information

`AuthController.login()`'s failure path preserves the exact `AppError`
subtype (`NetworkError`/`ServerError`/`AuthExpiredError`/`UnknownAppError`,
see `lib/domain/app_error.dart`) all the way to the UI via
`mapToAppError(e)`. `restoreSession()`'s failure path, built on top of
`SessionRefresher.refresh()`'s "never throws, returns `StoredSession?`"
contract, collapses every possible refresh failure — no network, a 500, or a
genuinely dead refresh token — into a bare `null`. The only visible effect is
"stay `AuthUnauthenticated`" with no message anywhere. A user opening the app
offline with a soon-to-expire token sees a plain "log in" button with no hint
that a network problem (not an expired session) is why they were logged
out — the exact class of user-facing regression that Task 3 (`AppError`
introduction, M3) was built specifically to prevent, reintroduced one layer
up by Task 4's simpler boolean/null contract.

**Fix direction for Plan 1b-2**: have `SessionRefresher.refresh()` return (or
let its caller capture, e.g. via an `onError` callback or a richer result
type) the `AppError` it currently swallows, so `restoreSession()` — and any
future repository-level refresh failure — can distinguish "you're offline"
from "your session is dead" the same way `login()` already does. At minimum,
log the swallowed error (ties into M4, "no logging anywhere", already
tracked in the Plan 1a follow-ups doc).

## Minor items (no action required, noted for awareness only)

- **M-A (file placement)**: `lib/data/auth_interceptor.dart` sits directly
  under `lib/data/`, while its three sibling classes from the same plan
  (`SessionApi`, `SessionRefresher`, `SecureTokenStorage`) all live under
  `lib/data/auth/`. Plausible rationale (it's wired directly into the
  top-level `api_client.dart`), but undocumented. Consider moving it under
  `lib/data/auth/` for consistency next time this file is touched.
- **M-B (dormant throw path)**: `AuthController.login()` calls
  `ref.read(platformInfoProvider)` outside its surrounding `try`/`catch`.
  Since Task 1, that provider can throw `UnsupportedError` for an
  unrecognized ABI (the old `_os`/`_arch` static getters it replaced never
  threw). Currently inert (only macOS is built/tested), but if ever hit,
  `login()` would throw uncaught, leaving state stuck at
  `AuthAwaitingBrowser` forever instead of degrading to `AuthError`. Move the
  `ref.read(platformInfoProvider)` call inside the `try` block when this file
  is next touched.
- **M-C (I2 partially, incidentally resolved)**: [Plan 1a follow-up
  I2](2026-08-28-plan1a-followups.md) flagged "zero HTTP timeouts" as part of
  a larger unbounded-polling concern. Plan 1b-1's `rawAniDio()` addition
  (Task 4) gives `bangumiOAuthApiProvider` real `connectTimeout`/
  `receiveTimeout` values as a side effect (it shares `dioProvider`), so the
  "zero timeouts" half of I2 is now incidentally fixed. The *loop-boundedness*
  half of I2 (the OAuth login poll loop is still a literal `while (true)`
  with no deadline/cancellation) remains completely unaddressed. Worth noting
  next time I2 is revisited so the timeout half isn't rediscovered as "still
  broken."
