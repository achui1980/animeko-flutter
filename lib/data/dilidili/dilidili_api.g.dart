// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dilidili_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dilidiliDio)
final dilidiliDioProvider = DilidiliDioProvider._();

final class DilidiliDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  DilidiliDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dilidiliDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dilidiliDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dilidiliDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dilidiliDioHash() => r'c3d65d175b753987ba44a3bff0c61a02a766a590';

@ProviderFor(dilidiliApi)
final dilidiliApiProvider = DilidiliApiProvider._();

final class DilidiliApiProvider
    extends $FunctionalProvider<DilidiliApi, DilidiliApi, DilidiliApi>
    with $Provider<DilidiliApi> {
  DilidiliApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dilidiliApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dilidiliApiHash();

  @$internal
  @override
  $ProviderElement<DilidiliApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DilidiliApi create(Ref ref) {
    return dilidiliApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DilidiliApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DilidiliApi>(value),
    );
  }
}

String _$dilidiliApiHash() => r'b0c0c852cc06c979eaf15bf369737da759d71f41';
