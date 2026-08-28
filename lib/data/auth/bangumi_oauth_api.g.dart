// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_oauth_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bangumiOAuthApi)
final bangumiOAuthApiProvider = BangumiOAuthApiProvider._();

final class BangumiOAuthApiProvider
    extends
        $FunctionalProvider<BangumiOAuthApi, BangumiOAuthApi, BangumiOAuthApi>
    with $Provider<BangumiOAuthApi> {
  BangumiOAuthApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bangumiOAuthApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bangumiOAuthApiHash();

  @$internal
  @override
  $ProviderElement<BangumiOAuthApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BangumiOAuthApi create(Ref ref) {
    return bangumiOAuthApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BangumiOAuthApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BangumiOAuthApi>(value),
    );
  }
}

String _$bangumiOAuthApiHash() => r'121fc744c1b9a3a450e3f2cc77d702cdddc99dff';
