// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_user_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current user's own profile. The account screen is the only
/// consumer -- no caching/refresh policy beyond Riverpod's default is
/// needed.

@ProviderFor(selfUser)
final selfUserProvider = SelfUserProvider._();

/// The current user's own profile. The account screen is the only
/// consumer -- no caching/refresh policy beyond Riverpod's default is
/// needed.

final class SelfUserProvider
    extends
        $FunctionalProvider<AsyncValue<SelfUser>, SelfUser, FutureOr<SelfUser>>
    with $FutureModifier<SelfUser>, $FutureProvider<SelfUser> {
  /// The current user's own profile. The account screen is the only
  /// consumer -- no caching/refresh policy beyond Riverpod's default is
  /// needed.
  SelfUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selfUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selfUserHash();

  @$internal
  @override
  $FutureProviderElement<SelfUser> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SelfUser> create(Ref ref) {
    return selfUser(ref);
  }
}

String _$selfUserHash() => r'f8c1803c14c206cb6932e1a63b3f5d36d47875d7';
