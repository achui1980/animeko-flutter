// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Delay between polls of GET /v2/users/bangumi/result. Overridden to
/// `Duration.zero` in tests so the polling loop runs instantly.

@ProviderFor(authPollInterval)
final authPollIntervalProvider = AuthPollIntervalProvider._();

/// Delay between polls of GET /v2/users/bangumi/result. Overridden to
/// `Duration.zero` in tests so the polling loop runs instantly.

final class AuthPollIntervalProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// Delay between polls of GET /v2/users/bangumi/result. Overridden to
  /// `Duration.zero` in tests so the polling loop runs instantly.
  AuthPollIntervalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authPollIntervalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authPollIntervalHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return authPollInterval(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$authPollIntervalHash() => r'8b50104f84ff2d1de86e2215777b689cfc93031a';

/// Orchestrates the full Bangumi OAuth flow described in the design doc:
/// generate requestId -> fetch redirect url (oauth or bind) -> open system
/// browser -> poll for the result, treating HTTP 425 as "not ready yet" ->
/// persist tokens -> emit AuthAuthenticated.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// Orchestrates the full Bangumi OAuth flow described in the design doc:
/// generate requestId -> fetch redirect url (oauth or bind) -> open system
/// browser -> poll for the result, treating HTTP 425 as "not ready yet" ->
/// persist tokens -> emit AuthAuthenticated.
final class AuthControllerProvider
    extends $NotifierProvider<AuthController, AuthState> {
  /// Orchestrates the full Bangumi OAuth flow described in the design doc:
  /// generate requestId -> fetch redirect url (oauth or bind) -> open system
  /// browser -> poll for the result, treating HTTP 425 as "not ready yet" ->
  /// persist tokens -> emit AuthAuthenticated.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authControllerHash() => r'20c6d1ebfa32036aec0f2e4fa2457be3ce933003';

/// Orchestrates the full Bangumi OAuth flow described in the design doc:
/// generate requestId -> fetch redirect url (oauth or bind) -> open system
/// browser -> poll for the result, treating HTTP 425 as "not ready yet" ->
/// persist tokens -> emit AuthAuthenticated.

abstract class _$AuthController extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
