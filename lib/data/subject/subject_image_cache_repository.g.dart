// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_image_cache_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(subjectImageCacheRepository)
final subjectImageCacheRepositoryProvider =
    SubjectImageCacheRepositoryProvider._();

final class SubjectImageCacheRepositoryProvider
    extends
        $FunctionalProvider<
          SubjectImageCacheRepository,
          SubjectImageCacheRepository,
          SubjectImageCacheRepository
        >
    with $Provider<SubjectImageCacheRepository> {
  SubjectImageCacheRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subjectImageCacheRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subjectImageCacheRepositoryHash();

  @$internal
  @override
  $ProviderElement<SubjectImageCacheRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubjectImageCacheRepository create(Ref ref) {
    return subjectImageCacheRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubjectImageCacheRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubjectImageCacheRepository>(value),
    );
  }
}

String _$subjectImageCacheRepositoryHash() =>
    r'21d984056bfe73f641a60884d42fce5b8a2744c6';
