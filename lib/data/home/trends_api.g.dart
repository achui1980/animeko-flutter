// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trends_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trendsApi)
final trendsApiProvider = TrendsApiProvider._();

final class TrendsApiProvider
    extends $FunctionalProvider<TrendsApi, TrendsApi, TrendsApi>
    with $Provider<TrendsApi> {
  TrendsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendsApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendsApiHash();

  @$internal
  @override
  $ProviderElement<TrendsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrendsApi create(Ref ref) {
    return trendsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrendsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrendsApi>(value),
    );
  }
}

String _$trendsApiHash() => r'29270acb8dbbeeff9c9e9b366544f20000da1b6d';
