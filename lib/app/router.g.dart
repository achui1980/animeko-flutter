// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Most of the app is browsable without logging in. There is no global
/// auth gate: guest users land straight on `/home`, and only the specific
/// actions/screens that actually require a Bangumi session send the user
/// to `/login` on demand (see `domain/auth/auth_gate.dart`'s
/// `requireLogin()`).

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Most of the app is browsable without logging in. There is no global
/// auth gate: guest users land straight on `/home`, and only the specific
/// actions/screens that actually require a Bangumi session send the user
/// to `/login` on demand (see `domain/auth/auth_gate.dart`'s
/// `requireLogin()`).

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Most of the app is browsable without logging in. There is no global
  /// auth gate: guest users land straight on `/home`, and only the specific
  /// actions/screens that actually require a Bangumi session send the user
  /// to `/login` on demand (see `domain/auth/auth_gate.dart`'s
  /// `requireLogin()`).
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'3a50760792e3f7a95ed293a1eb2f0198370f5a3b';
