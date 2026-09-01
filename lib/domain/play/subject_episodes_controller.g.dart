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
        $AsyncNotifierProvider<SubjectEpisodesController, List<MergedEpisode>> {
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
    r'6b7ee29939ad52e8ea4774b77a6aa0afe3a3db0a';

final class SubjectEpisodesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectEpisodesController,
          AsyncValue<List<MergedEpisode>>,
          List<MergedEpisode>,
          FutureOr<List<MergedEpisode>>,
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
    extends $AsyncNotifier<List<MergedEpisode>> {
  late final _$args = ref.$arg as ({int subjectId, String subjectName});
  int get subjectId => _$args.subjectId;
  String get subjectName => _$args.subjectName;

  FutureOr<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<MergedEpisode>>, List<MergedEpisode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MergedEpisode>>, List<MergedEpisode>>,
              AsyncValue<List<MergedEpisode>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(subjectId: _$args.subjectId, subjectName: _$args.subjectName),
    );
  }
}
