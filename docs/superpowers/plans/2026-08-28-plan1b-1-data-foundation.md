# Plan 1b-1: Data Foundation Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land Plan 1a's follow-up fixes (I4/I5/M3), add a Dio auth interceptor with real session-refresh support, wire automatic session restoration into app startup, and lay the Drift + `json_serializable` groundwork that Plan 1b-2/1b-3/1b-4 will build on.

**Architecture:** `PlatformInfo` moves OS/arch detection out of the domain layer into `lib/platform/`. `SecureTokenStorage` becomes a single atomic JSON blob keyed by `ani_session` (was 3 separate Keychain keys), storing `userId` alongside the token triple so a cold-started app can go straight to `AuthAuthenticated` without a network call. A new `AuthInterceptor` attaches the stored access token to every Dio request and, on a 401, calls a shared `SessionRefresher` (hits the real `POST /v2/users/auth/refresh` endpoint) exactly once before giving up; `AuthController.restoreSession()` reuses the same `SessionRefresher` at startup. Errors are normalized into a typed `AppError` hierarchy so the domain layer never touches `DioException` directly. Drift and `json_serializable` are wired up with minimal schemas/smoke tests only — the real Subject/Episode/Collection models are out of scope (Plan 1b-2/1b-3's job).

**Tech Stack:** Dart/Flutter, Riverpod (`riverpod_annotation`/`riverpod_generator`, existing), Dio (existing), `flutter_secure_storage` (existing), Drift + `path_provider` + `path` (new), `json_annotation`/`json_serializable` (new, dev), `mocktail` (existing).

**Reference docs:**
- Design doc: `docs/superpowers/specs/2026-08-28-plan1b-series-design.md`
- Plan 1a follow-ups (source of I4/I5/M3): `docs/superpowers/plans/2026-08-28-plan1a-followups.md`
- Plan 1a itself (prior implementation, same patterns): `docs/superpowers/plans/2026-08-27-phase1a-bootstrap-network-auth.md`

**Explicitly out of scope:** I1/I2 (retry/cancel UI, unbounded-poll timeout — the OAuth *login* flow itself is untouched except for the `PlatformInfo`/`AppError` refactors), I3, M2, M4-M10 (all remain in the follow-ups doc). No Subject/Episode/Collection network models or endpoints (Plan 1b-2/1b-3). No cloud sync (Plan 1b-4).

**Corrected from the design doc:** the design doc's "网络层" section named `POST /v2/users/bangumi/loginWithRefreshToken` as the refresh endpoint. That endpoint is actually for *binding* an Ani account to an existing **Bangumi** refresh token — unrelated. The real Ani-session-refresh endpoint, verified against the Kotlin reference client (`UserAuthenticationAniApi.refreshToken`), is **`POST /v2/users/auth/refresh`** with body `{"refreshToken": "..."}`, returning the same `{userId, tokens: {accessToken, refreshToken, expiresAtMillis, bangumiAccessToken?}}` shape as the existing `UserAuthRoutingLoginResponse`/`AniTokens` models from Plan 1a. This plan uses the corrected endpoint.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/platform/platform_info.dart` (new) | `PlatformInfo{os, arch}` value + provider, extracted from `AuthController` (I4) |
| `lib/domain/app_error.dart` (new) | `AppError` sealed hierarchy: `NetworkError`/`ServerError`/`AuthExpiredError`/`UnknownAppError` (M3) |
| `lib/data/dio_error_mapper.dart` (new) | `mapToAppError(Object)` converting `DioException`/anything into an `AppError` |
| `lib/data/auth/secure_token_storage.dart` (rewrite) | Single-blob `StoredSession{userId, tokens}` storage (I5) |
| `lib/data/auth/session_api.dart` (new) | `SessionApi.refreshToken()` wrapping `POST /v2/users/auth/refresh` |
| `lib/data/auth/session_refresher.dart` (new) | `SessionRefresher` — shared refresh-and-persist-or-clear logic used by both the interceptor and `restoreSession()` |
| `lib/data/auth_interceptor.dart` (new) | `AuthInterceptor` — attaches bearer token, one-shot 401 refresh-and-retry |
| `lib/data/api_client.dart` (modify) | Add timeouts, wire `AuthInterceptor` onto the shared `Dio` |
| `lib/domain/auth/auth_state.dart` (modify) | `AuthError` now carries an `AppError` instead of a raw `String` |
| `lib/domain/auth/auth_controller.dart` (modify) | Use `PlatformInfo`/`AppError`; add `restoreSession()` |
| `lib/app/main.dart` (modify) | Call `restoreSession()` once before `runApp` |
| `lib/data/local_database.dart` (new) | Drift `AppDatabase` with `Subjects`/`Episodes`/`SubjectCollections`/`SearchHistory` tables |
| `pubspec.yaml` (modify) | Add `drift`, `path_provider`, `path`; dev: `drift_dev`, `json_annotation`, `json_serializable` |

Corresponding `test/` files mirror each of the above (see each task).

---

### Task 1: Extract `PlatformInfo` out of `AuthController` (I4)

**Files:**
- Create: `lib/platform/platform_info.dart`
- Test: `test/platform/platform_info_test.dart`
- Modify: `lib/domain/auth/auth_controller.dart`
- Modify: `test/domain/auth/auth_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/platform/platform_info_test.dart
import 'package:animeko_flutter/platform/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('platformInfoProvider returns macos with a valid arch on this dev machine', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final info = container.read(platformInfoProvider);

    expect(info.os, 'macos');
    expect(info.arch, anyOf('aarch64', 'x86_64'));
  });

  test('PlatformInfo stores os and arch as given', () {
    const info = PlatformInfo(os: 'ios', arch: 'aarch64');

    expect(info.os, 'ios');
    expect(info.arch, 'aarch64');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/platform/platform_info_test.dart`
Expected: FAIL — `Error when reading 'lib/platform/platform_info.dart': No such file or directory` (or `Target of URI doesn't exist`)

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/platform/platform_info.dart
import 'dart:ffi' show Abi;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_info.g.dart';

/// OS/CPU-architecture identifiers matching the Kotlin reference client's
/// `Platform.name`/`Arch.displayName` vocabulary exactly (see
/// utils/platform/.../Platform.kt in the Ani repo: "Don't change, used by
/// the server"). ani-api-server validates these against a fixed
/// vocabulary, so Dart's own naming ("arm64"/"x64") is rejected with HTTP
/// 400 -- it must be "aarch64"/"x86_64". Extracted out of `AuthController`
/// per Plan 1a follow-up I4 (it's a platform fact, not domain logic).
class PlatformInfo {
  const PlatformInfo({required this.os, required this.arch});

  final String os;
  final String arch;
}

@riverpod
PlatformInfo platformInfo(Ref ref) {
  switch (Abi.current()) {
    case Abi.macosArm64:
      return const PlatformInfo(os: 'macos', arch: 'aarch64');
    case Abi.macosX64:
      return const PlatformInfo(os: 'macos', arch: 'x86_64');
    default:
      // Only macOS is exercised today. iOS was scaffolded in Plan 1a
      // Task 1 but never built/run; other platforms are deliberately
      // unsupported until a future platform-expansion plan verifies the
      // exact os/arch values the server expects for them.
      throw UnsupportedError(
        'PlatformInfo has no mapping for ${Abi.current()}',
      );
  }
}
```

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: writes `lib/platform/platform_info.g.dart`

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/platform/platform_info_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Wire `PlatformInfo` into `AuthController`, removing the old `_os`/`_arch`**

In `lib/domain/auth/auth_controller.dart`:
- Remove `import 'dart:ffi' show Abi;`
- Add `import '../../platform/platform_info.dart';`
- Remove the `static const _os = 'macos';` and `static String get _arch => ...` members entirely
- In `login()`, right after `state = AuthAwaitingBrowser(requestId);`, add:
  ```dart
  final platform = ref.read(platformInfoProvider);
  ```
- Replace `os: _os, arch: _arch` with `os: platform.os, arch: platform.arch` in **both** the `api.oauth(...)` and `api.bind(...)` calls.

- [ ] **Step 6: Update `auth_controller_test.dart` to override `platformInfoProvider` and assert exact captured values**

Add the import: `import 'package:animeko_flutter/platform/platform_info.dart';`

Add to the `overrides` list in `setUp()`:
```dart
platformInfoProvider.overrideWithValue(
  const PlatformInfo(os: 'macos', arch: 'aarch64'),
),
```

In the `'register flow: oauth -> open browser -> poll (425 then success) -> authenticated'` test, replace the block:
```dart
      expect(callCount, 2);
      verify(() => launcher.open('https://bgm.tv/x')).called(1);
      verify(() => storage.saveTokens(any())).called(1);
```
with:
```dart
      expect(callCount, 2);
      final captured = verify(
        () => api.oauth(
          requestId: captureAny(named: 'requestId'),
          os: captureAny(named: 'os'),
          arch: captureAny(named: 'arch'),
        ),
      ).captured;
      expect(
        captured[0],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(captured[1], 'macos');
      expect(captured[2], 'aarch64');
      verify(() => launcher.open('https://bgm.tv/x')).called(1);
      verify(() => storage.saveTokens(any())).called(1);
```
(This is the single highest-value test named in the Plan 1a follow-ups doc: three of the four real bugs found during Plan 1a's manual smoke test — the `arch` value and the `requestId` format — lived in exactly the fields this previously wildcarded away with plain `any()`.)

Regenerate: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 7: Run the full suite to verify no regressions**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test`
Expected: PASS, all tests (34 total: 32 existing + 2 new)

- [ ] **Step 8: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/platform/platform_info.dart lib/platform/platform_info.g.dart test/platform/platform_info_test.dart lib/domain/auth/auth_controller.dart lib/domain/auth/auth_controller.g.dart test/domain/auth/auth_controller_test.dart
git commit -m "fix: extract PlatformInfo out of AuthController (Plan 1a follow-up I4)"
```

---

### Task 2: `SecureTokenStorage` single atomic session blob (I5)

**Files:**
- Modify (full rewrite): `lib/data/auth/secure_token_storage.dart`
- Modify (full rewrite): `test/data/auth/secure_token_storage_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/auth/secure_token_storage_test.dart
import 'dart:convert';

import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage backing;
  late SecureTokenStorage storage;

  setUp(() {
    backing = MockFlutterSecureStorage();
    storage = SecureTokenStorage(backing);
  });

  test('saveSession writes userId and the full token triple as one JSON blob', () async {
    when(
      () => backing.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((_) async {});

    await storage.saveSession(
      const StoredSession(
        userId: 'user-1',
        tokens: AniTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          expiresAtMillis: 1700000000000,
        ),
      ),
    );

    final captured = verify(
      () => backing.write(key: 'ani_session', value: captureAny(named: 'value')),
    ).captured.single as String;
    final decoded = jsonDecode(captured) as Map<String, dynamic>;
    expect(decoded, {
      'userId': 'user-1',
      'accessToken': 'access-1',
      'refreshToken': 'refresh-1',
      'expiresAtMillis': 1700000000000,
      'bangumiAccessToken': null,
    });
  });

  test('readSession round-trips a previously saved session', () async {
    when(() => backing.read(key: 'ani_session')).thenAnswer(
      (_) async => jsonEncode({
        'userId': 'user-2',
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresAtMillis': 42,
        'bangumiAccessToken': 'bgm-token',
      }),
    );

    final session = await storage.readSession();

    expect(session, isNotNull);
    expect(session!.userId, 'user-2');
    expect(session.tokens.accessToken, 'a');
    expect(session.tokens.bangumiAccessToken, 'bgm-token');
  });

  test('readSession returns null when nothing is stored', () async {
    when(() => backing.read(key: 'ani_session')).thenAnswer((_) async => null);

    expect(await storage.readSession(), isNull);
  });

  test('readSession returns null for corrupt JSON instead of throwing', () async {
    when(() => backing.read(key: 'ani_session')).thenAnswer((_) async => 'not json{{{');

    expect(await storage.readSession(), isNull);
  });

  test('clear deletes the single session key', () async {
    when(() => backing.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    await storage.clear();

    verify(() => backing.delete(key: 'ani_session')).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/secure_token_storage_test.dart`
Expected: FAIL — `StoredSession` undefined, `saveSession`/`readSession` undefined on `SecureTokenStorage`

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/data/auth/secure_token_storage.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'bangumi_oauth_models.dart';

part 'secure_token_storage.g.dart';

/// A logged-in user's id plus their Ani token triple -- everything needed
/// to both display "logged in as X" and refresh the session without a
/// round trip through the Bangumi OAuth flow again.
class StoredSession {
  const StoredSession({required this.userId, required this.tokens});

  final String userId;
  final AniTokens tokens;
}

/// Persists the current [StoredSession] in the platform secure store
/// (Keychain on macOS) as a single atomically-written JSON blob under one
/// key, rather than several separate keys (Plan 1a follow-up I5): a save
/// is one write (no risk of a partial userId/access/refresh/expiry
/// combination if the process is interrupted mid-write) and a restore is
/// one read.
class SecureTokenStorage {
  SecureTokenStorage(this._backing);

  final FlutterSecureStorage _backing;

  static const _sessionKey = 'ani_session';

  Future<void> saveSession(StoredSession session) {
    return _backing.write(
      key: _sessionKey,
      value: jsonEncode({
        'userId': session.userId,
        'accessToken': session.tokens.accessToken,
        'refreshToken': session.tokens.refreshToken,
        'expiresAtMillis': session.tokens.expiresAtMillis,
        'bangumiAccessToken': session.tokens.bangumiAccessToken,
      }),
    );
  }

  /// Reads back the stored session, or null if nothing (or a corrupt
  /// value) is stored.
  Future<StoredSession?> readSession() async {
    final raw = await _backing.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return StoredSession(
        userId: json['userId'] as String,
        tokens: AniTokens.fromJson(json),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clear() => _backing.delete(key: _sessionKey);
}

@riverpod
SecureTokenStorage secureTokenStorage(Ref ref) {
  // usesDataProtectionKeychain defaults to true in flutter_secure_storage,
  // which requires the binary to be signed with a real Apple Team ID;
  // locally signed builds fail with errSecMissingEntitlement (-34018). We
  // use the legacy file-based keychain instead, which works for both
  // local and distributed builds. (Plan 1a follow-up M8 flags this as an
  // unconditional security tradeoff worth revisiting for signed release
  // builds -- not addressed in this plan.)
  return SecureTokenStorage(
    const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  );
}
```

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/secure_token_storage_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Update every other call site of the old `saveTokens`/`readAccessToken`/`readRefreshToken` API**

In `lib/domain/auth/auth_controller.dart`'s `login()`, replace:
```dart
      await storage.saveTokens(result.tokens);
      state = AuthAuthenticated(result.userId);
```
with:
```dart
      await storage.saveSession(
        StoredSession(userId: result.userId, tokens: result.tokens),
      );
      state = AuthAuthenticated(result.userId);
```
Add `import '../../data/auth/secure_token_storage.dart';` if not already present (it already is, for `secureTokenStorageProvider`).

In `test/domain/auth/auth_controller_test.dart`:
- Replace `when(() => storage.saveTokens(any())).thenAnswer((_) async {});` with `when(() => storage.saveSession(any())).thenAnswer((_) async {});`
- Replace the `setUpAll` fallback-value registration:
  ```dart
  registerFallbackValue(
    const AniTokens(accessToken: '', refreshToken: '', expiresAtMillis: 0),
  );
  ```
  with:
  ```dart
  registerFallbackValue(
    const StoredSession(
      userId: '',
      tokens: AniTokens(accessToken: '', refreshToken: '', expiresAtMillis: 0),
    ),
  );
  ```
- Replace every `verify(() => storage.saveTokens(any())).called(1);` with `verify(() => storage.saveSession(any())).called(1);`
- Add `import 'package:animeko_flutter/data/auth/secure_token_storage.dart';` (needed for `StoredSession`; `MockSecureTokenStorage` already imports this file).

- [ ] **Step 6: Regenerate, run full suite**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test`
Expected: PASS, all tests

- [ ] **Step 7: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/auth/secure_token_storage.dart test/data/auth/secure_token_storage_test.dart lib/domain/auth/auth_controller.dart test/domain/auth/auth_controller_test.dart
git commit -m "fix: store Ani session as a single atomic JSON blob (Plan 1a follow-up I5)"
```

---

### Task 3: Typed `AppError` (M3)

**Files:**
- Create: `lib/domain/app_error.dart`
- Test: `test/domain/app_error_test.dart`
- Create: `lib/data/dio_error_mapper.dart`
- Test: `test/data/dio_error_mapper_test.dart`
- Modify: `lib/domain/auth/auth_state.dart`
- Modify: `test/domain/auth/auth_state_test.dart`
- Modify: `lib/domain/auth/auth_controller.dart`
- Modify: `test/ui/auth/login_screen_test.dart`

- [ ] **Step 1: Write the failing test for `AppError`**

```dart
// test/domain/app_error_test.dart
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NetworkError message mentions the connection', () {
    expect(const NetworkError().message, contains('connection'));
  });

  test('ServerError message includes the status code', () {
    expect(const ServerError(500).message, contains('500'));
  });

  test('AuthExpiredError message tells the user to log in again', () {
    expect(const AuthExpiredError().message, contains('log in again'));
  });

  test('UnknownAppError message includes the underlying cause', () {
    expect(const UnknownAppError('boom').message, contains('boom'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/app_error_test.dart`
Expected: FAIL — file not found

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/app_error.dart

/// Typed representation of failures surfaced to the UI, replacing raw
/// exception `toString()` text (Plan 1a follow-up M3). Pure Dart, no Dio
/// or Flutter import -- the domain layer must not know about either.
sealed class AppError {
  const AppError();

  /// Short human-readable message; UI code may show this directly.
  String get message;
}

class NetworkError extends AppError {
  const NetworkError();

  @override
  String get message => 'Could not reach the server. Check your connection.';
}

class ServerError extends AppError {
  const ServerError(this.statusCode);

  final int statusCode;

  @override
  String get message => 'Server error ($statusCode).';
}

class AuthExpiredError extends AppError {
  const AuthExpiredError();

  @override
  String get message => 'Your session has expired. Please log in again.';
}

class UnknownAppError extends AppError {
  const UnknownAppError(this.cause);

  final Object cause;

  @override
  String get message => 'Something went wrong: $cause';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/app_error_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Write the failing test for the Dio-to-AppError mapper**

```dart
// test/data/dio_error_mapper_test.dart
import 'package:animeko_flutter/data/dio_error_mapper.dart';
import 'package:animeko_flutter/domain/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final options = RequestOptions(path: '/x');

  test('connection errors map to NetworkError', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );

    expect(mapToAppError(error), isA<NetworkError>());
  });

  test('a 401 response maps to AuthExpiredError', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: 401),
    );

    expect(mapToAppError(error), isA<AuthExpiredError>());
  });

  test('a 500 response maps to ServerError(500)', () {
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: 500),
    );

    final mapped = mapToAppError(error);
    expect(mapped, isA<ServerError>());
    expect((mapped as ServerError).statusCode, 500);
  });

  test('a non-Dio object maps to UnknownAppError', () {
    final mapped = mapToAppError(Exception('boom'));

    expect(mapped, isA<UnknownAppError>());
    expect(mapped.message, contains('boom'));
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/dio_error_mapper_test.dart`
Expected: FAIL — file not found

- [ ] **Step 7: Write minimal implementation**

```dart
// lib/data/dio_error_mapper.dart
import 'package:dio/dio.dart';

import '../domain/app_error.dart';

/// Converts a caught [Object] (expected to usually be a [DioException])
/// into the domain layer's [AppError] hierarchy so callers/UI never need
/// to know about Dio directly (Plan 1a follow-up M3).
AppError mapToAppError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkError();
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) return const AuthExpiredError();
        if (status != null) return ServerError(status);
        return UnknownAppError(error);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return UnknownAppError(error);
    }
  }
  return UnknownAppError(error);
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/dio_error_mapper_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 9: Wire `AppError` into `AuthState.AuthError`**

In `lib/domain/auth/auth_state.dart`, add `import 'app_error.dart';` at the top, then replace:
```dart
class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
```
with:
```dart
class AuthError extends AuthState {
  const AuthError(this.error);
  final AppError error;

  /// Convenience forwarding getter so existing call sites (login_screen,
  /// tests) that read `.message` keep working unchanged.
  String get message => error.message;
}
```

In `test/domain/auth/auth_state_test.dart`, add `import 'package:animeko_flutter/domain/app_error.dart';`, and change the `'AuthError carries a message'` test from:
```dart
    const state = AuthError('network down');
    expect(state.message, 'network down');
```
to:
```dart
    const state = AuthError(UnknownAppError('network down'));
    expect(state.message, contains('network down'));
```
(No other test in this file needs to change — the switch-exhaustiveness test's `AuthError(message: final m)` pattern still matches against the `message` getter identically to a field.)

- [ ] **Step 10: Wire `mapToAppError` into `AuthController.login()`**

In `lib/domain/auth/auth_controller.dart`, add `import '../../data/dio_error_mapper.dart';`, then change:
```dart
    } catch (e) {
      state = AuthError(e.toString());
    }
```
to:
```dart
    } catch (e) {
      state = AuthError(mapToAppError(e));
    }
```

- [ ] **Step 11: Update `login_screen_test.dart`'s error test**

In `test/ui/auth/login_screen_test.dart`, add `import 'package:animeko_flutter/domain/app_error.dart';`, then in the `'shows the error message on error'` test, change:
```dart
wrap(const AuthError('network down'));
```
to:
```dart
wrap(const AuthError(UnknownAppError('network down')));
```
The assertion `expect(find.textContaining('network down'), findsOneWidget);` (or equivalent `find.text('Login failed: network down')`, whichever this test currently uses) continues to pass unchanged since `UnknownAppError('network down').message` is `'Something went wrong: network down'`, which still contains the substring `'network down'`.

- [ ] **Step 12: Run the full suite**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test`
Expected: PASS, all tests

- [ ] **Step 13: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/domain/app_error.dart test/domain/app_error_test.dart lib/data/dio_error_mapper.dart test/data/dio_error_mapper_test.dart lib/domain/auth/auth_state.dart test/domain/auth/auth_state_test.dart lib/domain/auth/auth_controller.dart test/ui/auth/login_screen_test.dart
git commit -m "fix: introduce typed AppError, replacing raw exception text (Plan 1a follow-up M3)"
```

---

### Task 4: Real session-refresh endpoint (`SessionApi` + `SessionRefresher`)

**Files:**
- Create: `lib/data/auth/session_api.dart`
- Test: `test/data/auth/session_api_test.dart`
- Create: `lib/data/auth/session_refresher.dart`
- Test: `test/data/auth/session_refresher_test.dart`

- [ ] **Step 1: Write the failing test for `SessionApi`**

```dart
// test/data/auth/session_api_test.dart
import 'package:animeko_flutter/data/auth/session_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late SessionApi api;

  setUp(() {
    dio = MockDio();
    api = SessionApi(dio);
  });

  test('refreshToken POSTs to /v2/users/auth/refresh with the refresh token', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/v2/users/auth/refresh',
        data: {'refreshToken': 'old-refresh'},
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/v2/users/auth/refresh'),
        data: {
          'userId': 'user-1',
          'tokens': {
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
            'expiresAtMillis': 123,
          },
        },
      ),
    );

    final result = await api.refreshToken('old-refresh');

    expect(result.userId, 'user-1');
    expect(result.tokens.accessToken, 'new-access');
  });

  test('a non-2xx response rethrows the DioException as-is', () async {
    final requestOptions = RequestOptions(path: '/v2/users/auth/refresh');
    when(
      () => dio.post<Map<String, dynamic>>(
        '/v2/users/auth/refresh',
        data: {'refreshToken': 'expired'},
      ),
    ).thenThrow(
      DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      ),
    );

    expect(() => api.refreshToken('expired'), throwsA(isA<DioException>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/session_api_test.dart`
Expected: FAIL — file not found

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/data/auth/session_api.dart
import 'package:dio/dio.dart';

import 'bangumi_oauth_models.dart';

/// POST /v2/users/auth/refresh -- refreshes an Ani session using a stored
/// refresh token. Verified against the Kotlin-generated
/// `UserAuthenticationAniApi.refreshToken` / `AniRefreshTokenRequest` /
/// `AniUserAuthRoutingLoginResponse` models (NOT
/// `/v2/users/bangumi/loginWithRefreshToken`, which binds an Ani account
/// to an existing *Bangumi* refresh token -- a different, unrelated
/// operation. See this plan's header for the correction.)
class SessionApi {
  SessionApi(this._dio);

  final Dio _dio;

  Future<UserAuthRoutingLoginResponse> refreshToken(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v2/users/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return UserAuthRoutingLoginResponse.fromJson(response.data!);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/session_api_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Write the failing test for `SessionRefresher`**

```dart
// test/data/auth/session_refresher_test.dart
import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth/session_api.dart';
import 'package:animeko_flutter/data/auth/session_refresher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionApi extends Mock implements SessionApi {}

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late MockSessionApi api;
  late MockSecureTokenStorage storage;
  late SessionRefresher refresher;

  setUpAll(() {
    registerFallbackValue(
      const StoredSession(
        userId: '',
        tokens: AniTokens(accessToken: '', refreshToken: '', expiresAtMillis: 0),
      ),
    );
  });

  setUp(() {
    api = MockSessionApi();
    storage = MockSecureTokenStorage();
    refresher = SessionRefresher(api, storage);
  });

  test('a successful refresh persists and returns the new session', () async {
    when(() => api.refreshToken('old-refresh')).thenAnswer(
      (_) async => const UserAuthRoutingLoginResponse(
        userId: 'user-1',
        tokens: AniTokens(accessToken: 'new-a', refreshToken: 'new-r', expiresAtMillis: 999),
      ),
    );
    when(() => storage.saveSession(any())).thenAnswer((_) async {});

    final session = await refresher.refresh('old-refresh');

    expect(session, isNotNull);
    expect(session!.userId, 'user-1');
    verify(() => storage.saveSession(any())).called(1);
  });

  test('a failed refresh clears storage and returns null', () async {
    when(() => api.refreshToken('expired')).thenThrow(Exception('401'));
    when(() => storage.clear()).thenAnswer((_) async {});

    final session = await refresher.refresh('expired');

    expect(session, isNull);
    verify(() => storage.clear()).called(1);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth/session_refresher_test.dart`
Expected: FAIL — file not found

- [ ] **Step 7: Write minimal implementation**

```dart
// lib/data/auth/session_refresher.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'secure_token_storage.dart';
import 'session_api.dart';

part 'session_refresher.g.dart';

/// Shared refresh-and-persist-or-clear logic, used both by
/// [AuthInterceptor]'s 401 handling and by `AuthController.restoreSession()`
/// at app startup, so the two don't duplicate this behavior.
class SessionRefresher {
  SessionRefresher(this._api, this._storage);

  final SessionApi _api;
  final SecureTokenStorage _storage;

  /// Attempts to refresh using [refreshToken]. On success, persists and
  /// returns the new [StoredSession]. On any failure, clears storage and
  /// returns null.
  Future<StoredSession?> refresh(String refreshToken) async {
    try {
      final result = await _api.refreshToken(refreshToken);
      final session = StoredSession(userId: result.userId, tokens: result.tokens);
      await _storage.saveSession(session);
      return session;
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }
}

/// Builds [SessionApi] on its own bare, non-intercepted [Dio] instance --
/// it must never go through [AuthInterceptor], or a failing refresh (e.g.
/// an expired refresh token) would recurse into another refresh attempt.
@riverpod
SessionApi sessionApi(Ref ref) {
  return SessionApi(rawAniDio());
}

@riverpod
SessionRefresher sessionRefresher(Ref ref) {
  return SessionRefresher(
    ref.watch(sessionApiProvider),
    ref.watch(secureTokenStorageProvider),
  );
}
```

This references a new `rawAniDio()` helper that Step 8 below adds to `lib/data/api_client.dart` (a plain, uninterceptable `Dio` factory, extracted so both `dio()` and `sessionApi()` can build an un-intercepted client without duplicating `BaseOptions`).

- [ ] **Step 8: Add `rawAniDio()` to `api_client.dart` ahead of Task 5's interceptor wiring**

In `lib/data/api_client.dart`, add (above the existing `dio()` function):
```dart
const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 15);

/// A plain `Dio` pointed at [aniApiBaseUrl] with no interceptors attached.
/// Used both by the main `dio()` provider (as its starting point, before
/// interceptors are added) and by anything that must never recurse
/// through [AuthInterceptor] -- see `SessionRefresher`.
Dio rawAniDio() {
  return Dio(
    BaseOptions(
      baseUrl: aniApiBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    ),
  );
}

@riverpod
Dio dio(Ref ref) {
  return rawAniDio();
}
```
(The `AuthInterceptor` itself is not wired onto `dio()` yet -- that's Step 9. This step only introduces `rawAniDio()` and adds the timeouts.)

- [ ] **Step 9: Regenerate, run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/data/auth/session_refresher_test.dart test/data/api_client_test.dart 2>/dev/null; flutter test`
Expected: PASS, all tests (no `api_client_test.dart` exists yet — that `2>/dev/null` guard is harmless if so; the trailing `flutter test` is the authoritative check)

- [ ] **Step 10: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/auth/session_api.dart test/data/auth/session_api_test.dart lib/data/auth/session_refresher.dart lib/data/auth/session_refresher.g.dart test/data/auth/session_refresher_test.dart lib/data/api_client.dart lib/data/api_client.g.dart
git commit -m "feat: add SessionApi and SessionRefresher for /v2/users/auth/refresh"
```

---

### Task 5: `AuthInterceptor` — token attach + one-shot 401 refresh-and-retry

**Files:**
- Create: `lib/data/auth_interceptor.dart`
- Test: `test/data/auth_interceptor_test.dart`
- Modify: `lib/data/api_client.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/auth_interceptor_test.dart
import 'dart:typed_data';

import 'package:animeko_flutter/data/auth/bangumi_oauth_models.dart';
import 'package:animeko_flutter/data/auth/secure_token_storage.dart';
import 'package:animeko_flutter/data/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

/// A fake transport that inspects the Authorization header it was sent
/// and returns 200 for a "valid" header, 401 otherwise -- lets us test the
/// interceptor's retry logic without a real network call.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.validBearer);

  final String validBearer;
  final List<String?> seenAuthHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final header = options.headers['Authorization'] as String?;
    seenAuthHeaders.add(header);
    if (header == 'Bearer $validBearer') {
      return ResponseBody.fromString('{"ok":true}', 200, headers: {
        'content-type': ['application/json'],
      });
    }
    return ResponseBody.fromString('{}', 401, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockSecureTokenStorage storage;

  setUp(() {
    storage = MockSecureTokenStorage();
  });

  Dio buildDio(_FakeAdapter adapter, SecureTokenStorage storage, RefreshTokenFn refresh) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio, storage, refresh));
    return dio;
  }

  test('attaches the stored access token as a Bearer header', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'u',
        tokens: AniTokens(accessToken: 'good-token', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    final adapter = _FakeAdapter('good-token');
    final dio = buildDio(adapter, storage, () async => false);

    final response = await dio.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(adapter.seenAuthHeaders, ['Bearer good-token']);
  });

  test('sends no Authorization header when nothing is stored', () async {
    when(() => storage.readSession()).thenAnswer((_) async => null);
    final adapter = _FakeAdapter('irrelevant');
    final dio = buildDio(adapter, storage, () async => false);

    await expectLater(dio.get<Map<String, dynamic>>('/x'), throwsA(isA<DioException>()));
    expect(adapter.seenAuthHeaders, [null]);
  });

  test('refreshes once and retries on a 401, succeeding with the fresh token', () async {
    var readCount = 0;
    when(() => storage.readSession()).thenAnswer((_) async {
      readCount++;
      final token = readCount == 1 ? 'stale-token' : 'fresh-token';
      return StoredSession(
        userId: 'u',
        tokens: AniTokens(accessToken: token, refreshToken: 'r', expiresAtMillis: 1),
      );
    });
    final adapter = _FakeAdapter('fresh-token');
    var refreshCalls = 0;
    final dio = buildDio(adapter, storage, () async {
      refreshCalls++;
      return true;
    });

    final response = await dio.get<Map<String, dynamic>>('/x');

    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(adapter.seenAuthHeaders, ['Bearer stale-token', 'Bearer fresh-token']);
  });

  test('gives up after a failed refresh without a second retry attempt', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'u',
        tokens: AniTokens(accessToken: 'stale-token', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    final adapter = _FakeAdapter('never-matches');
    var refreshCalls = 0;
    final dio = buildDio(adapter, storage, () async {
      refreshCalls++;
      return false;
    });

    await expectLater(dio.get<Map<String, dynamic>>('/x'), throwsA(isA<DioException>()));
    expect(refreshCalls, 1);
    expect(adapter.seenAuthHeaders, ['Bearer stale-token']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth_interceptor_test.dart`
Expected: FAIL — file not found

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/data/auth_interceptor.dart
import 'dart:async';

import 'package:dio/dio.dart';

import 'auth/secure_token_storage.dart';

/// Returns true if the refresh succeeded (new tokens are now in storage),
/// false otherwise.
typedef RefreshTokenFn = Future<bool> Function();

/// Attaches the current Ani access token (if any) as a Bearer
/// Authorization header to every outgoing request made through the Dio
/// instance it is installed on, and on a 401 response attempts exactly
/// one token refresh + request retry before giving up. See Plan 1a
/// follow-up M3 and the Plan 1b series design doc's "网络层" section.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._storage, this._refresh);

  final Dio _dio;
  final SecureTokenStorage _storage;
  final RefreshTokenFn _refresh;

  static const _retriedFlag = 'ani_auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _attachToken(options).then((_) => handler.next(options));
  }

  Future<void> _attachToken(RequestOptions options) async {
    final session = await _storage.readSession();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.tokens.accessToken}';
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    if (status != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }
    unawaited(_retryAfterRefresh(err, handler));
  }

  Future<void> _retryAfterRefresh(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final refreshed = await _refresh();
    if (!refreshed) {
      handler.next(err);
      return;
    }
    final options = err.requestOptions;
    options.extra[_retriedFlag] = true;
    await _attachToken(options);
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/auth_interceptor_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Wire `AuthInterceptor` onto the real `dio()` provider**

In `lib/data/api_client.dart`, add the imports:
```dart
import 'auth/secure_token_storage.dart';
import 'auth/session_refresher.dart';
import 'auth_interceptor.dart';
```
Change the `dio()` provider from:
```dart
@riverpod
Dio dio(Ref ref) {
  return rawAniDio();
}
```
to:
```dart
@riverpod
Dio dio(Ref ref) {
  final dio = rawAniDio();
  final storage = ref.watch(secureTokenStorageProvider);
  final refresher = ref.watch(sessionRefresherProvider);

  dio.interceptors.add(
    AuthInterceptor(dio, storage, () async {
      final session = await storage.readSession();
      if (session == null) return false;
      final refreshed = await refresher.refresh(session.tokens.refreshToken);
      return refreshed != null;
    }),
  );

  return dio;
}
```

- [ ] **Step 6: Regenerate, run the full suite**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test`
Expected: PASS, all tests (this wiring is exercised indirectly since no existing test overrides `dioProvider` directly with a real network dependency; all existing tests override the higher-level API providers, so this change is a no-op for every current test)

- [ ] **Step 7: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/data/auth_interceptor.dart test/data/auth_interceptor_test.dart lib/data/api_client.dart lib/data/api_client.g.dart
git commit -m "feat: add AuthInterceptor with token attach and one-shot 401 refresh-retry"
```

---

### Task 6: `AuthController.restoreSession()` + wire into app startup

**Files:**
- Modify: `lib/domain/auth/auth_controller.dart`
- Modify: `test/domain/auth/auth_controller_test.dart`
- Modify: `lib/app/main.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/domain/auth/auth_controller_test.dart` (needs a `MockSessionRefresher` and override; add near the top, alongside the other mocks):
```dart
class MockSessionRefresher extends Mock implements SessionRefresher {}
```
and add `sessionRefresherProvider.overrideWithValue(refresher)` to the `overrides` list (declare `late MockSessionRefresher refresher;` alongside the other `late` mocks and instantiate it in `setUp()`). Add the import: `import 'package:animeko_flutter/data/auth/session_refresher.dart';`

Then add these 4 tests at the end of `main()`:
```dart
  test('restoreSession does nothing when no session is stored', () async {
    when(() => storage.readSession()).thenAnswer((_) async => null);

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('restoreSession authenticates immediately for an unexpired token', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => StoredSession(
        userId: 'user-3',
        tokens: AniTokens(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAtMillis: DateTime.now().millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
        ),
      ),
    );

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).userId, 'user-3');
    verifyNever(() => refresher.refresh(any()));
  });

  test('restoreSession refreshes an expired token and authenticates on success', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'user-4',
        tokens: AniTokens(accessToken: 'stale', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    when(() => refresher.refresh('r')).thenAnswer(
      (_) async => const StoredSession(
        userId: 'user-4',
        tokens: AniTokens(accessToken: 'fresh', refreshToken: 'r2', expiresAtMillis: 999999999999),
      ),
    );

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).userId, 'user-4');
  });

  test('restoreSession stays unauthenticated when refreshing an expired token fails', () async {
    when(() => storage.readSession()).thenAnswer(
      (_) async => const StoredSession(
        userId: 'user-5',
        tokens: AniTokens(accessToken: 'stale', refreshToken: 'r', expiresAtMillis: 1),
      ),
    );
    when(() => refresher.refresh('r')).thenAnswer((_) async => null);

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.restoreSession();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/domain/auth/auth_controller_test.dart`
Expected: FAIL — `restoreSession` undefined on `AuthController`

- [ ] **Step 3: Write minimal implementation**

In `lib/domain/auth/auth_controller.dart`, add the import `import '../../data/auth/session_refresher.dart';`, then add this method inside the `AuthController` class (alongside `login()`):
```dart
  /// Called once at app startup. Restores an authenticated session
  /// without a fresh Bangumi OAuth round trip if a valid (or refreshable)
  /// session is already stored.
  Future<void> restoreSession() async {
    final storage = ref.read(secureTokenStorageProvider);
    final session = await storage.readSession();
    if (session == null) return;

    const safetyMargin = Duration(minutes: 5);
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      session.tokens.expiresAtMillis,
    );
    final isStillValid = DateTime.now().add(safetyMargin).isBefore(expiresAt);

    if (isStillValid) {
      state = AuthAuthenticated(session.userId);
      return;
    }

    final refresher = ref.read(sessionRefresherProvider);
    final refreshed = await refresher.refresh(session.tokens.refreshToken);
    if (refreshed != null) {
      state = AuthAuthenticated(refreshed.userId);
    }
    // else: storage was already cleared by SessionRefresher; state stays
    // AuthUnauthenticated (the value build() returned).
  }
```

- [ ] **Step 4: Regenerate, run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/domain/auth/auth_controller_test.dart`
Expected: PASS (8 tests: 4 existing + 4 new)

- [ ] **Step 5: Call `restoreSession()` once before `runApp`**

Rewrite `lib/app/main.dart`:
```dart
// lib/app/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth/auth_controller.dart';
import 'router.dart';

Future<void> main() async {
  final container = ProviderContainer();
  await container.read(authControllerProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AnimekoFlutterApp(),
    ),
  );
}

class AnimekoFlutterApp extends StatelessWidget {
  const AnimekoFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'Animeko', routerConfig: appRouter);
  }
}
```
(`UncontrolledProviderScope` is `flutter_riverpod`'s supported way to hand a pre-built `ProviderContainer` to the widget tree, so `restoreSession()` can run and settle *before* the first frame — avoiding a startup flash of the login button for users who are already logged in.)

- [ ] **Step 6: Run the full suite and a debug build to confirm the app still launches**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test && flutter build macos --debug`
Expected: PASS, all tests; build succeeds

- [ ] **Step 7: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add lib/domain/auth/auth_controller.dart lib/domain/auth/auth_controller.g.dart test/domain/auth/auth_controller_test.dart lib/app/main.dart
git commit -m "feat: add AuthController.restoreSession() and call it on app startup"
```

---

### Task 7: Drift local database setup

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/data/local_database.dart`
- Test: `test/data/local_database_test.dart`

- [ ] **Step 1: Add dependencies**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter pub add drift path_provider path && flutter pub add --dev drift_dev`
Expected: `pubspec.yaml` gains `drift`, `path_provider`, `path` under `dependencies` and `drift_dev` under `dev_dependencies`. (Desktop SQLite is auto-bundled by `drift`/`sqlite3` since drift 2.32+, per drift's own platform-support docs — no `sqlite3_flutter_libs` dependency is needed.)

- [ ] **Step 2: Write the failing test**

```dart
// test/data/local_database_test.dart
import 'package:animeko_flutter/data/local_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('subjects table round-trips a row', () async {
    await db.into(db.subjects).insert(
          SubjectsCompanion.insert(id: 1, name: 'Test Anime', nameCn: '测试动画'),
        );

    final rows = await db.select(db.subjects).get();

    expect(rows, hasLength(1));
    expect(rows.single.name, 'Test Anime');
  });

  test('episodes table round-trips a row', () async {
    await db.into(db.subjects).insert(
          SubjectsCompanion.insert(id: 1, name: 'Test Anime', nameCn: '测试动画'),
        );
    await db.into(db.episodes).insert(
          EpisodesCompanion.insert(id: 10, subjectId: 1, sort: '1', name: 'Episode 1'),
        );

    final rows = await db.select(db.episodes).get();

    expect(rows, hasLength(1));
    expect(rows.single.subjectId, 1);
  });

  test('subjectCollections table round-trips a dirty row', () async {
    await db.into(db.subjects).insert(
          SubjectsCompanion.insert(id: 1, name: 'Test Anime', nameCn: '测试动画'),
        );
    await db.into(db.subjectCollections).insert(
          SubjectCollectionsCompanion.insert(subjectId: 1, collectionType: 'DOING', dirty: true),
        );

    final rows = await db.select(db.subjectCollections).get();

    expect(rows, hasLength(1));
    expect(rows.single.dirty, isTrue);
    expect(rows.single.syncedAt, isNull);
  });

  test('searchHistory table round-trips a row', () async {
    await db.into(db.searchHistory).insert(
          SearchHistoryCompanion.insert(query: 'mahou shoujo', searchedAt: DateTime(2026, 1, 1)),
        );

    final rows = await db.select(db.searchHistory).get();

    expect(rows, hasLength(1));
    expect(rows.single.query, 'mahou shoujo');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test test/data/local_database_test.dart`
Expected: FAIL — file not found

- [ ] **Step 4: Write minimal implementation**

```dart
// lib/data/local_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';

/// Cached subject (anime) metadata. Minimal columns for now -- the full
/// Subject model with tags/characters/staff/etc. is Plan 1b-2/1b-3's job;
/// this table only proves the persistence layer and its migration path
/// work.
class Subjects extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get nameCn => text()();
  TextColumn get summary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached episode metadata for a subject.
class Episodes extends Table {
  IntColumn get id => integer()();
  IntColumn get subjectId => integer().references(Subjects, #id)();
  TextColumn get sort => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The user's local collection (favorite/watch-progress) state for a
/// subject, with `dirty`/`syncedAt` tracking for Plan 1b-4's cloud sync:
/// `dirty` is set on any local edit and cleared once a push to the server
/// succeeds; `syncedAt` records the last successful sync time.
class SubjectCollections extends Table {
  IntColumn get subjectId => integer().references(Subjects, #id)();
  TextColumn get collectionType => text()();
  IntColumn get selfRatingScore => integer().nullable()();
  TextColumn get selfRatingComment => text().nullable()();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {subjectId};
}

/// Purely local search-history entries -- never synced to the server.
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();
}

@DriftDatabase(tables: [Subjects, Episodes, SubjectCollections, SearchHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'animeko.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
```

- [ ] **Step 5: Regenerate, run test to verify it passes**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/data/local_database_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Run the full suite**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test`
Expected: PASS, all tests

- [ ] **Step 7: Commit**

```bash
cd /Users/portz/js/animeko-flutter
git add pubspec.yaml pubspec.lock lib/data/local_database.dart lib/data/local_database.g.dart test/data/local_database_test.dart
git commit -m "feat: add Drift local database with subjects/episodes/collections/search-history tables"
```

---

### Task 8: `json_serializable` toolchain smoke test

**Files:**
- Modify: `pubspec.yaml`
- Create then delete: `lib/data/json_smoke_test_model.dart` (temporary, proves the toolchain, removed at the end of this task)

- [ ] **Step 1: Add dependencies**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter pub add --dev json_serializable && flutter pub add json_annotation`
Expected: `pubspec.yaml` gains `json_annotation` under `dependencies` and `json_serializable` under `dev_dependencies`.

- [ ] **Step 2: Write a temporary smoke-test model exercising `@JsonSerializable()`**

```dart
// lib/data/json_smoke_test_model.dart
import 'package:json_annotation/json_annotation.dart';

part 'json_smoke_test_model.g.dart';

/// TEMPORARY -- exists only to prove `build_runner` runs
/// `json_serializable` alongside the existing `riverpod_generator` builder
/// without conflict. Deleted at the end of this task; Plan 1b-2's real
/// Subject/Episode models will be the first permanent users of this
/// pattern.
@JsonSerializable()
class JsonSmokeTestModel {
  JsonSmokeTestModel({required this.value});

  final String value;

  factory JsonSmokeTestModel.fromJson(Map<String, dynamic> json) =>
      _$JsonSmokeTestModelFromJson(json);

  Map<String, dynamic> toJson() => _$JsonSmokeTestModelToJson(this);
}
```

- [ ] **Step 3: Run `build_runner` and verify it generates the `.g.dart` file alongside the existing generators with no conflicts**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: build succeeds; `lib/data/json_smoke_test_model.g.dart` is created containing `_$JsonSmokeTestModelFromJson`/`_$JsonSmokeTestModelToJson`; no errors about conflicting builders between `json_serializable` and `riverpod_generator`/`drift_dev`

- [ ] **Step 4: Run `flutter analyze` and the full test suite to confirm nothing else broke**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter analyze && flutter test`
Expected: analyze clean (modulo the 2 pre-existing known info lints); all tests pass

- [ ] **Step 5: Delete the temporary smoke-test model and its generated file**

```bash
cd /Users/portz/js/animeko-flutter
rm lib/data/json_smoke_test_model.dart lib/data/json_smoke_test_model.g.dart
```

- [ ] **Step 6: Confirm the suite still passes with the smoke-test model removed (proving nothing else depended on it) and commit just the dependency additions**

Run: `export PATH="/Users/portz/soft/dart-sdk/flutter/bin:$PATH" && cd /Users/portz/js/animeko-flutter && flutter test`
Expected: PASS, all tests (unchanged count from before Task 8 — the smoke-test model added no permanent test)

```bash
cd /Users/portz/js/animeko-flutter
git add pubspec.yaml pubspec.lock
git commit -m "chore: add json_serializable/json_annotation for future Subject/Episode models"
```

---

## Definition of Done

- [ ] `flutter test` passes with zero failures (expect ~46 tests: 32 pre-existing + 2 Task 1 + 5 Task 2 net-new/rewritten + 4 Task 3 + 6 Task 3 tests total... exact count will be confirmed by the final `flutter test` run in Task 8's Step 4/6 — the important invariant is zero failures, not a specific count).
- [ ] `flutter analyze` is clean modulo the 2 pre-existing known info-level lints.
- [ ] `flutter build macos --debug` succeeds.
- [ ] A fresh `flutter run -d macos` with no stored session shows the login button (unchanged behavior); manually seeding a valid session in the Keychain and relaunching goes straight to the authenticated screen without opening a browser (manual verification only — not automated in this plan, consistent with Plan 1a's Task 11 precedent for OAuth-adjacent manual checks; if a full manual smoke test is wanted, it should be a final unnumbered checkpoint before merging, not a scored task).
- [ ] All 8 task commits are present in `git log` on `main`.

**Not covered by this plan** (remain in the follow-ups doc or deferred to later Plan 1b sub-plans): I1 (retry/cancel UI for login), I2 (bounded OAuth poll loop + login-specific timeouts), I3 (surfacing `BrowserLauncher.open()`'s bool failure signal), M2/M4-M10 (doc-comment accuracy, logging, re-entrancy guard, etc.), and all Subject/Episode/Collection network models, endpoints, and UI (Plan 1b-2/1b-3), and cloud sync itself (Plan 1b-4).
