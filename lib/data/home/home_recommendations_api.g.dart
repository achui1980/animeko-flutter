// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_recommendations_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(homeRecommendationsApi)
final homeRecommendationsApiProvider = HomeRecommendationsApiProvider._();

final class HomeRecommendationsApiProvider
    extends
        $FunctionalProvider<
          HomeRecommendationsApi,
          HomeRecommendationsApi,
          HomeRecommendationsApi
        >
    with $Provider<HomeRecommendationsApi> {
  HomeRecommendationsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeRecommendationsApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeRecommendationsApiHash();

  @$internal
  @override
  $ProviderElement<HomeRecommendationsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HomeRecommendationsApi create(Ref ref) {
    return homeRecommendationsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeRecommendationsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeRecommendationsApi>(value),
    );
  }
}

String _$homeRecommendationsApiHash() =>
    r'a1f67e5a361f061ae975dfb898d76ebc1f518c71';
