// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_refresher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Builds [SessionApi] on its own bare, non-intercepted [Dio] instance --
/// it must never go through [AuthInterceptor], or a failing refresh (e.g.
/// an expired refresh token) would recurse into another refresh attempt.

@ProviderFor(sessionApi)
final sessionApiProvider = SessionApiProvider._();

/// Builds [SessionApi] on its own bare, non-intercepted [Dio] instance --
/// it must never go through [AuthInterceptor], or a failing refresh (e.g.
/// an expired refresh token) would recurse into another refresh attempt.

final class SessionApiProvider
    extends $FunctionalProvider<SessionApi, SessionApi, SessionApi>
    with $Provider<SessionApi> {
  /// Builds [SessionApi] on its own bare, non-intercepted [Dio] instance --
  /// it must never go through [AuthInterceptor], or a failing refresh (e.g.
  /// an expired refresh token) would recurse into another refresh attempt.
  SessionApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionApiHash();

  @$internal
  @override
  $ProviderElement<SessionApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionApi create(Ref ref) {
    return sessionApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionApi>(value),
    );
  }
}

String _$sessionApiHash() => r'3491e4740b503a85926d0796d015403b16884ab1';

@ProviderFor(sessionRefresher)
final sessionRefresherProvider = SessionRefresherProvider._();

final class SessionRefresherProvider
    extends
        $FunctionalProvider<
          SessionRefresher,
          SessionRefresher,
          SessionRefresher
        >
    with $Provider<SessionRefresher> {
  SessionRefresherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionRefresherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionRefresherHash();

  @$internal
  @override
  $ProviderElement<SessionRefresher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionRefresher create(Ref ref) {
    return sessionRefresher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionRefresher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionRefresher>(value),
    );
  }
}

String _$sessionRefresherHash() => r'51518d5e65b4fb05b8b4bbb8ea8ecf51c5fe1a4c';
