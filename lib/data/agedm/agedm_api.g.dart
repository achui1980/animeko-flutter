// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agedm_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(agedmDio)
final agedmDioProvider = AgedmDioProvider._();

final class AgedmDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  AgedmDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agedmDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agedmDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return agedmDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$agedmDioHash() => r'6434f2d8a5d25c1592e32b7da2b48b656e3bf920';

@ProviderFor(agedmApi)
final agedmApiProvider = AgedmApiProvider._();

final class AgedmApiProvider
    extends $FunctionalProvider<AgedmApi, AgedmApi, AgedmApi>
    with $Provider<AgedmApi> {
  AgedmApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agedmApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agedmApiHash();

  @$internal
  @override
  $ProviderElement<AgedmApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgedmApi create(Ref ref) {
    return agedmApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgedmApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgedmApi>(value),
    );
  }
}

String _$agedmApiHash() => r'0e7ad3d1a29d3276c376c96a0c0c9ceb319a5410';
