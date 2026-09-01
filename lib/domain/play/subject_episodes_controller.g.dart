// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_episodes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SubjectEpisodesController)
final subjectEpisodesControllerProvider = SubjectEpisodesControllerFamily._();

final class SubjectEpisodesControllerProvider
    extends
        $AsyncNotifierProvider<SubjectEpisodesController, List<Anime1Episode>> {
  SubjectEpisodesControllerProvider._({
    required SubjectEpisodesControllerFamily super.from,
    required ({int subjectId, String subjectName}) super.argument,
  }) : super(
         retry: null,
         name: r'subjectEpisodesControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectEpisodesControllerHash();

  @override
  String toString() {
    return r'subjectEpisodesControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SubjectEpisodesController create() => SubjectEpisodesController();

  @override
  bool operator ==(Object other) {
    return other is SubjectEpisodesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectEpisodesControllerHash() =>
    r'5fca0be2f1311258315d04a3e80bdebaf044ccaa';

final class SubjectEpisodesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectEpisodesController,
          AsyncValue<List<Anime1Episode>>,
          List<Anime1Episode>,
          FutureOr<List<Anime1Episode>>,
          ({int subjectId, String subjectName})
        > {
  SubjectEpisodesControllerFamily._()
    : super(
        retry: null,
        name: r'subjectEpisodesControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SubjectEpisodesControllerProvider call({
    required int subjectId,
    required String subjectName,
  }) => SubjectEpisodesControllerProvider._(
    argument: (subjectId: subjectId, subjectName: subjectName),
    from: this,
  );

  @override
  String toString() => r'subjectEpisodesControllerProvider';
}

abstract class _$SubjectEpisodesController
    extends $AsyncNotifier<List<Anime1Episode>> {
  late final _$args = ref.$arg as ({int subjectId, String subjectName});
  int get subjectId => _$args.subjectId;
  String get subjectName => _$args.subjectName;

  FutureOr<List<Anime1Episode>> build({
    required int subjectId,
    required String subjectName,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<Anime1Episode>>, List<Anime1Episode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Anime1Episode>>, List<Anime1Episode>>,
              AsyncValue<List<Anime1Episode>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(subjectId: _$args.subjectId, subjectName: _$args.subjectName),
    );
  }
}
