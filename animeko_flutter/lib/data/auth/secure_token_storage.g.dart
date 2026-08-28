// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secure_token_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secureTokenStorage)
final secureTokenStorageProvider = SecureTokenStorageProvider._();

final class SecureTokenStorageProvider
    extends
        $FunctionalProvider<
          SecureTokenStorage,
          SecureTokenStorage,
          SecureTokenStorage
        >
    with $Provider<SecureTokenStorage> {
  SecureTokenStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureTokenStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureTokenStorageHash();

  @$internal
  @override
  $ProviderElement<SecureTokenStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecureTokenStorage create(Ref ref) {
    return secureTokenStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureTokenStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureTokenStorage>(value),
    );
  }
}

String _$secureTokenStorageHash() =>
    r'da54347a15be64fb07762f6de51284affc22f32b';
