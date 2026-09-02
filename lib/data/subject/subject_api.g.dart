// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(subjectApi)
final subjectApiProvider = SubjectApiProvider._();

final class SubjectApiProvider
    extends $FunctionalProvider<SubjectApi, SubjectApi, SubjectApi>
    with $Provider<SubjectApi> {
  SubjectApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subjectApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subjectApiHash();

  @$internal
  @override
  $ProviderElement<SubjectApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SubjectApi create(Ref ref) {
    return subjectApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubjectApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubjectApi>(value),
    );
  }
}

String _$subjectApiHash() => r'ef71274b9ab38e2bb7a0c319e2c757b6c26b6b24';
