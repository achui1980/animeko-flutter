// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_bangumi_episodes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches the Bangumi-canonical episode list for [subjectId] via
/// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
/// SP/OP/ED excluded, defensive even though the API's own `type=0`
/// query param already filters server-side), and sorts ascending by
/// [BangumiEpisode.sort].
///
/// Fully independent of `SubjectEpisodesController` -- neither provider
/// blocks the other; see the design doc's Section 4.

@ProviderFor(SubjectBangumiEpisodesController)
final subjectBangumiEpisodesControllerProvider =
    SubjectBangumiEpisodesControllerFamily._();

/// Fetches the Bangumi-canonical episode list for [subjectId] via
/// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
/// SP/OP/ED excluded, defensive even though the API's own `type=0`
/// query param already filters server-side), and sorts ascending by
/// [BangumiEpisode.sort].
///
/// Fully independent of `SubjectEpisodesController` -- neither provider
/// blocks the other; see the design doc's Section 4.
final class SubjectBangumiEpisodesControllerProvider
    extends
        $AsyncNotifierProvider<
          SubjectBangumiEpisodesController,
          List<BangumiEpisode>
        > {
  /// Fetches the Bangumi-canonical episode list for [subjectId] via
  /// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
  /// SP/OP/ED excluded, defensive even though the API's own `type=0`
  /// query param already filters server-side), and sorts ascending by
  /// [BangumiEpisode.sort].
  ///
  /// Fully independent of `SubjectEpisodesController` -- neither provider
  /// blocks the other; see the design doc's Section 4.
  SubjectBangumiEpisodesControllerProvider._({
    required SubjectBangumiEpisodesControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'subjectBangumiEpisodesControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectBangumiEpisodesControllerHash();

  @override
  String toString() {
    return r'subjectBangumiEpisodesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubjectBangumiEpisodesController create() =>
      SubjectBangumiEpisodesController();

  @override
  bool operator ==(Object other) {
    return other is SubjectBangumiEpisodesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectBangumiEpisodesControllerHash() =>
    r'23202f1874121ae130b2e44ed77feaaf50b8af9f';

/// Fetches the Bangumi-canonical episode list for [subjectId] via
/// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
/// SP/OP/ED excluded, defensive even though the API's own `type=0`
/// query param already filters server-side), and sorts ascending by
/// [BangumiEpisode.sort].
///
/// Fully independent of `SubjectEpisodesController` -- neither provider
/// blocks the other; see the design doc's Section 4.

final class SubjectBangumiEpisodesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectBangumiEpisodesController,
          AsyncValue<List<BangumiEpisode>>,
          List<BangumiEpisode>,
          FutureOr<List<BangumiEpisode>>,
          int
        > {
  SubjectBangumiEpisodesControllerFamily._()
    : super(
        retry: null,
        name: r'subjectBangumiEpisodesControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the Bangumi-canonical episode list for [subjectId] via
  /// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
  /// SP/OP/ED excluded, defensive even though the API's own `type=0`
  /// query param already filters server-side), and sorts ascending by
  /// [BangumiEpisode.sort].
  ///
  /// Fully independent of `SubjectEpisodesController` -- neither provider
  /// blocks the other; see the design doc's Section 4.

  SubjectBangumiEpisodesControllerProvider call({required int subjectId}) =>
      SubjectBangumiEpisodesControllerProvider._(
        argument: subjectId,
        from: this,
      );

  @override
  String toString() => r'subjectBangumiEpisodesControllerProvider';
}

/// Fetches the Bangumi-canonical episode list for [subjectId] via
/// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
/// SP/OP/ED excluded, defensive even though the API's own `type=0`
/// query param already filters server-side), and sorts ascending by
/// [BangumiEpisode.sort].
///
/// Fully independent of `SubjectEpisodesController` -- neither provider
/// blocks the other; see the design doc's Section 4.

abstract class _$SubjectBangumiEpisodesController
    extends $AsyncNotifier<List<BangumiEpisode>> {
  late final _$args = ref.$arg as int;
  int get subjectId => _$args;

  FutureOr<List<BangumiEpisode>> build({required int subjectId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<BangumiEpisode>>, List<BangumiEpisode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<BangumiEpisode>>,
                List<BangumiEpisode>
              >,
              AsyncValue<List<BangumiEpisode>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(subjectId: _$args));
  }
}
