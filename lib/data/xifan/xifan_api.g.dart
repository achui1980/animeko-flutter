// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xifan_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(xifanDio)
final xifanDioProvider = XifanDioProvider._();

final class XifanDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  XifanDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xifanDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xifanDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return xifanDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$xifanDioHash() => r'148740d5dc63ff270a2d9e7a7f1193e9cc21df31';

@ProviderFor(xifanApi)
final xifanApiProvider = XifanApiProvider._();

final class XifanApiProvider
    extends $FunctionalProvider<XifanApi, XifanApi, XifanApi>
    with $Provider<XifanApi> {
  XifanApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xifanApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xifanApiHash();

  @$internal
  @override
  $ProviderElement<XifanApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  XifanApi create(Ref ref) {
    return xifanApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(XifanApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<XifanApi>(value),
    );
  }
}

String _$xifanApiHash() => r'd644792a60625a09fc80611b199fc6f131ba081e';
