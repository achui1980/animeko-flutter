// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yinghua_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(yinghuaDio)
final yinghuaDioProvider = YinghuaDioProvider._();

final class YinghuaDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  YinghuaDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'yinghuaDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$yinghuaDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return yinghuaDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$yinghuaDioHash() => r'94ddd59b65a754f876be06cac4aa5fe30c028897';

@ProviderFor(yinghuaApi)
final yinghuaApiProvider = YinghuaApiProvider._();

final class YinghuaApiProvider
    extends $FunctionalProvider<YinghuaApi, YinghuaApi, YinghuaApi>
    with $Provider<YinghuaApi> {
  YinghuaApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'yinghuaApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$yinghuaApiHash();

  @$internal
  @override
  $ProviderElement<YinghuaApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  YinghuaApi create(Ref ref) {
    return yinghuaApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(YinghuaApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<YinghuaApi>(value),
    );
  }
}

String _$yinghuaApiHash() => r'ef5514b6ef282653bbcb3120a671293368ea5220';
