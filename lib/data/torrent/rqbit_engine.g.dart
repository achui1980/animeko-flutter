// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rqbit_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(rqbitEngine)
final rqbitEngineProvider = RqbitEngineProvider._();

final class RqbitEngineProvider
    extends $FunctionalProvider<RqbitEngine, RqbitEngine, RqbitEngine>
    with $Provider<RqbitEngine> {
  RqbitEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rqbitEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rqbitEngineHash();

  @$internal
  @override
  $ProviderElement<RqbitEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RqbitEngine create(Ref ref) {
    return rqbitEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RqbitEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RqbitEngine>(value),
    );
  }
}

String _$rqbitEngineHash() => r'90f76f39b2e3bbbb71b07c2f3f8b8530b4a6dc02';
