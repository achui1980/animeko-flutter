// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_recommendations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeRecommendationsController)
final homeRecommendationsControllerProvider =
    HomeRecommendationsControllerProvider._();

final class HomeRecommendationsControllerProvider
    extends
        $AsyncNotifierProvider<
          HomeRecommendationsController,
          HomeRecommendationsPage
        > {
  HomeRecommendationsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeRecommendationsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeRecommendationsControllerHash();

  @$internal
  @override
  HomeRecommendationsController create() => HomeRecommendationsController();
}

String _$homeRecommendationsControllerHash() =>
    r'c650010e33d00bc63e2d39e911bbf46c715e1d38';

abstract class _$HomeRecommendationsController
    extends $AsyncNotifier<HomeRecommendationsPage> {
  FutureOr<HomeRecommendationsPage> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<HomeRecommendationsPage>,
              HomeRecommendationsPage
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<HomeRecommendationsPage>,
                HomeRecommendationsPage
              >,
              AsyncValue<HomeRecommendationsPage>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
