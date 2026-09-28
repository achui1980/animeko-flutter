// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'omofun_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(omofunDio)
final omofunDioProvider = OmofunDioProvider._();

final class OmofunDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  OmofunDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'omofunDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$omofunDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return omofunDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$omofunDioHash() => r'207d24679e980bd60fa7de97c658a0c2cd04958e';

@ProviderFor(omofunProbeDio)
final omofunProbeDioProvider = OmofunProbeDioProvider._();

final class OmofunProbeDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  OmofunProbeDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'omofunProbeDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$omofunProbeDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return omofunProbeDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$omofunProbeDioHash() => r'2ed61a738321bc936467740a53e42094af1870e3';

@ProviderFor(omofunApi)
final omofunApiProvider = OmofunApiProvider._();

final class OmofunApiProvider
    extends $FunctionalProvider<OmofunApi, OmofunApi, OmofunApi>
    with $Provider<OmofunApi> {
  OmofunApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'omofunApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$omofunApiHash();

  @$internal
  @override
  $ProviderElement<OmofunApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OmofunApi create(Ref ref) {
    return omofunApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OmofunApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OmofunApi>(value),
    );
  }
}

String _$omofunApiHash() => r'91ef03fc3ad2c84b706b19f98a6920f83a835dd8';
