// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_collection_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SubjectCollectionController)
final subjectCollectionControllerProvider =
    SubjectCollectionControllerFamily._();

final class SubjectCollectionControllerProvider
    extends
        $AsyncNotifierProvider<
          SubjectCollectionController,
          SubjectCollectionState
        > {
  SubjectCollectionControllerProvider._({
    required SubjectCollectionControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'subjectCollectionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectCollectionControllerHash();

  @override
  String toString() {
    return r'subjectCollectionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubjectCollectionController create() => SubjectCollectionController();

  @override
  bool operator ==(Object other) {
    return other is SubjectCollectionControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectCollectionControllerHash() =>
    r'0661068394b2f48371d791622ec73c6dd70d80c7';

final class SubjectCollectionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectCollectionController,
          AsyncValue<SubjectCollectionState>,
          SubjectCollectionState,
          FutureOr<SubjectCollectionState>,
          int
        > {
  SubjectCollectionControllerFamily._()
    : super(
        retry: null,
        name: r'subjectCollectionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SubjectCollectionControllerProvider call({required int subjectId}) =>
      SubjectCollectionControllerProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'subjectCollectionControllerProvider';
}

abstract class _$SubjectCollectionController
    extends $AsyncNotifier<SubjectCollectionState> {
  late final _$args = ref.$arg as int;
  int get subjectId => _$args;

  FutureOr<SubjectCollectionState> build({required int subjectId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<SubjectCollectionState>, SubjectCollectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SubjectCollectionState>,
                SubjectCollectionState
              >,
              AsyncValue<SubjectCollectionState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(subjectId: _$args));
  }
}
