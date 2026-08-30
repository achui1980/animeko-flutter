// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchApi)
final searchApiProvider = SearchApiProvider._();

final class SearchApiProvider
    extends $FunctionalProvider<SearchApi, SearchApi, SearchApi>
    with $Provider<SearchApi> {
  SearchApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchApiHash();

  @$internal
  @override
  $ProviderElement<SearchApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SearchApi create(Ref ref) {
    return searchApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchApi>(value),
    );
  }
}

String _$searchApiHash() => r'5a9250f519640b15deb1161e58b8edc812554aaa';
