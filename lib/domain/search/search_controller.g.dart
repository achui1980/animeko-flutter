// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Delay before firing a search after the last keystroke. Overridden to
/// [Duration.zero] in tests so debounced searches run instantly.

@ProviderFor(searchDebounceDuration)
final searchDebounceDurationProvider = SearchDebounceDurationProvider._();

/// Delay before firing a search after the last keystroke. Overridden to
/// [Duration.zero] in tests so debounced searches run instantly.

final class SearchDebounceDurationProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// Delay before firing a search after the last keystroke. Overridden to
  /// [Duration.zero] in tests so debounced searches run instantly.
  SearchDebounceDurationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchDebounceDurationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchDebounceDurationHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return searchDebounceDuration(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$searchDebounceDurationHash() =>
    r'7905ef96065cb4913fa1ae7e2d617b5eca763d71';

@ProviderFor(SearchController)
final searchControllerProvider = SearchControllerProvider._();

final class SearchControllerProvider
    extends $AsyncNotifierProvider<SearchController, List<SubjectCard>> {
  SearchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchControllerHash();

  @$internal
  @override
  SearchController create() => SearchController();
}

String _$searchControllerHash() => r'2904a22d960d1fc5353af8bd39b564682c73905f';

abstract class _$SearchController extends $AsyncNotifier<List<SubjectCard>> {
  FutureOr<List<SubjectCard>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<SubjectCard>>, List<SubjectCard>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SubjectCard>>, List<SubjectCard>>,
              AsyncValue<List<SubjectCard>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
