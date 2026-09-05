// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime1_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(anime1Dio)
final anime1DioProvider = Anime1DioProvider._();

final class Anime1DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  Anime1DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'anime1DioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$anime1DioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return anime1Dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$anime1DioHash() => r'f8056f30282b85b588be54b8f63aebd509243a08';

@ProviderFor(anime1Api)
final anime1ApiProvider = Anime1ApiProvider._();

final class Anime1ApiProvider
    extends $FunctionalProvider<Anime1Api, Anime1Api, Anime1Api>
    with $Provider<Anime1Api> {
  Anime1ApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'anime1ApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$anime1ApiHash();

  @$internal
  @override
  $ProviderElement<Anime1Api> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Anime1Api create(Ref ref) {
    return anime1Api(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Anime1Api value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Anime1Api>(value),
    );
  }
}

String _$anime1ApiHash() => r'4e01ad4ff640907138dc5c30cfb2794b3d2d1de5';
