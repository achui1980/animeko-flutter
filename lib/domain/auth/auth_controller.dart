// lib/domain/auth/auth_controller.dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../data/auth/bangumi_oauth_api.dart';
import '../../data/auth/bangumi_oauth_models.dart';
import '../../data/auth/refresh_result.dart';
import '../../data/auth/secure_token_storage.dart';
import '../../data/auth/session_refresher.dart';
import '../../data/dio_error_mapper.dart';
import '../../platform/browser_launcher.dart';
import '../../platform/platform_info.dart';
import 'auth_state.dart';

part 'auth_controller.g.dart';

/// Delay between polls of GET /v2/users/bangumi/result. Overridden to
/// `Duration.zero` in tests so the polling loop runs instantly.
@riverpod
Duration authPollInterval(Ref ref) => const Duration(seconds: 1);

/// Bound on how long `restoreSession()` will wait for
/// `SessionRefresher.refresh()` before giving up and treating it as a
/// failed refresh.
///
/// This exists because `restoreSession()` is awaited in `main()` *before*
/// `runApp()`, specifically so already-authenticated users don't see a
/// login-screen flash. `refresh()` makes a real HTTP call via
/// `rawAniDio()`, whose `connectTimeout`/`receiveTimeout` are 15 seconds
/// each -- on a device with no network yet (e.g. just woken from sleep) or
/// a slow server, that could block the very first frame from rendering for
/// up to ~30 seconds. This timeout is deliberately much shorter than that
/// general 15s Dio timeout: it only needs to cover a normal fast round
/// trip to a nearby server, because on expiry we fall back to showing the
/// login screen (the user can just tap "log in" again) rather than leaving
/// the app blank/frozen indefinitely.
const _restoreSessionRefreshTimeout = Duration(seconds: 3);

/// Orchestrates the full Bangumi OAuth flow described in the design doc:
/// generate requestId -> fetch redirect url (oauth or bind) -> open system
/// browser -> poll for the result, treating HTTP 425 as "not ready yet" ->
/// persist tokens -> emit AuthAuthenticated.
@riverpod
class AuthController extends _$AuthController {
  @override
  AuthState build() {
    // login() performs async work across several await gaps; without this,
    // the (autoDispose) provider can be torn down mid-flow once nothing is
    // actively listening to it, making later `state = ...` writes throw.
    ref.keepAlive();
    return const AuthUnauthenticated();
  }

  Future<void> login({required bool isRegister}) async {
    final requestId = _generateRequestId();
    state = AuthAwaitingBrowser(requestId);
    final platform = ref.read(platformInfoProvider);

    final api = ref.read(bangumiOAuthApiProvider);
    final launcher = ref.read(browserLauncherProvider);
    final storage = ref.read(secureTokenStorageProvider);

    try {
      final redirect = isRegister
          ? await api.oauth(
              requestId: requestId,
              os: platform.os,
              arch: platform.arch,
            )
          : await api.bind(
              requestId: requestId,
              os: platform.os,
              arch: platform.arch,
            );

      await launcher.open(redirect.url);
      state = AuthPolling(requestId);

      final result = await _pollUntilReady(requestId, api);
      await storage.saveSession(
        StoredSession(userId: result.userId, tokens: result.tokens),
      );
      state = AuthAuthenticated(result.userId);
    } catch (e) {
      state = AuthError(mapToAppError(e));
    }
  }

  /// Called once at app startup. Restores an authenticated session
  /// without a fresh Bangumi OAuth round trip if a valid (or refreshable)
  /// session is already stored.
  Future<void> restoreSession() async {
    try {
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
      RefreshResult? result;
      try {
        result = await refresher
            .refresh(session.tokens.refreshToken)
            .timeout(_restoreSessionRefreshTimeout);
      } on TimeoutException {
        // Took too long for a startup-blocking call; fall through to the
        // same "stay unauthenticated" branch as a failed refresh.
        result = null;
      }
      switch (result) {
        case RefreshSuccess(session: final refreshed):
          state = AuthAuthenticated(refreshed.userId);
        case RefreshFailure():
        case null:
          // Storage handling on failure is `SessionRefresher`'s
          // responsibility (see RefreshResult's doc comment): a
          // definitively-dead refresh token has already been cleared;
          // a transient local-save failure leaves the old (now expired)
          // session untouched. Either way (and on a `null` here, meaning
          // the call timed out) we fall back to whatever build() set --
          // AuthUnauthenticated.
          break;
      }
    } catch (_) {
      // Defense-in-depth: readSession()/refresher.refresh() are documented
      // to never throw, but if anything unexpected still does, don't let
      // it propagate out of restoreSession() -- just leave state as
      // whatever build() returned (AuthUnauthenticated).
    }
  }

  Future<UserAuthRoutingLoginResponse> _pollUntilReady(
    String requestId,
    BangumiOAuthApi api,
  ) async {
    final interval = ref.read(authPollIntervalProvider);
    while (true) {
      final result = await api.getResult(requestId);
      if (result != null) return result;
      await Future<void>.delayed(interval);
    }
  }

  String _generateRequestId() {
    // The server correlates this value with the OAuth `state` parameter and
    // validates it as a well-formed UUID (matching the Kotlin reference
    // client's `Uuid.random()`); a non-UUID string is rejected with 400.
    return const Uuid().v4();
  }
}
