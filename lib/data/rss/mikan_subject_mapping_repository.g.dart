// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mikan_subject_mapping_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mikanSubjectMappingRepository)
final mikanSubjectMappingRepositoryProvider =
    MikanSubjectMappingRepositoryProvider._();

final class MikanSubjectMappingRepositoryProvider
    extends
        $FunctionalProvider<
          MikanSubjectMappingRepository,
          MikanSubjectMappingRepository,
          MikanSubjectMappingRepository
        >
    with $Provider<MikanSubjectMappingRepository> {
  MikanSubjectMappingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mikanSubjectMappingRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mikanSubjectMappingRepositoryHash();

  @$internal
  @override
  $ProviderElement<MikanSubjectMappingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MikanSubjectMappingRepository create(Ref ref) {
    return mikanSubjectMappingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MikanSubjectMappingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MikanSubjectMappingRepository>(
        value,
      ),
    );
  }
}

String _$mikanSubjectMappingRepositoryHash() =>
    r'893507b742fe851c72816fb9f955220bc1579f30';
