// lib/domain/auth/auth_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../data/auth/bangumi_oauth_api.dart';
import '../../data/auth/bangumi_oauth_models.dart';
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
      final refreshed = await refresher.refresh(session.tokens.refreshToken);
      if (refreshed != null) {
        state = AuthAuthenticated(refreshed.userId);
      }
      // else: refresh failed. This means either the refresh token itself was
      // rejected by the server (storage was cleared by SessionRefresher in
      // that case), or the refresh succeeded but the local save failed
      // (storage was left untouched with the old, now-expired tokens in
      // that case). Either way we stay unauthenticated here; a future
      // login will overwrite whatever is in storage.
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
