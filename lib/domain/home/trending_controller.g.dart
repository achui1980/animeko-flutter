// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trending_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The home page's "trending" carousel data. `GET /v1/trends` has no
/// pagination params -- it's a small, curated, fixed-size list meant for
/// a carousel, not a scrollable feed (see the design doc).

@ProviderFor(trending)
final trendingProvider = TrendingProvider._();

/// The home page's "trending" carousel data. `GET /v1/trends` has no
/// pagination params -- it's a small, curated, fixed-size list meant for
/// a carousel, not a scrollable feed (see the design doc).

final class TrendingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SubjectCard>>,
          List<SubjectCard>,
          FutureOr<List<SubjectCard>>
        >
    with
        $FutureModifier<List<SubjectCard>>,
        $FutureProvider<List<SubjectCard>> {
  /// The home page's "trending" carousel data. `GET /v1/trends` has no
  /// pagination params -- it's a small, curated, fixed-size list meant for
  /// a carousel, not a scrollable feed (see the design doc).
  TrendingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingHash();

  @$internal
  @override
  $FutureProviderElement<List<SubjectCard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SubjectCard>> create(Ref ref) {
    return trending(ref);
  }
}

String _$trendingHash() => r'dde2ba8b53658b68a52e1c8247f857a555926080';
