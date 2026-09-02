// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating). Cast ([SubjectCharacters]) and staff
/// ([SubjectStaff]) are fetched via separate providers so either can
/// fail independently without affecting this one or each other -- see
/// the design doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).

@ProviderFor(SubjectDetailController)
final subjectDetailControllerProvider = SubjectDetailControllerFamily._();

/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating). Cast ([SubjectCharacters]) and staff
/// ([SubjectStaff]) are fetched via separate providers so either can
/// fail independently without affecting this one or each other -- see
/// the design doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).
final class SubjectDetailControllerProvider
    extends $AsyncNotifierProvider<SubjectDetailController, SubjectDetail> {
  /// Fetches the main subject-detail payload (summary/tags/score/rank/
  /// collection status/self-rating). Cast ([SubjectCharacters]) and staff
  /// ([SubjectStaff]) are fetched via separate providers so either can
  /// fail independently without affecting this one or each other -- see
  /// the design doc's "per-source silent failure" pattern (mirrors how
  /// `SubjectEpisodesController` isolates each `MediaSource`'s failure).
  SubjectDetailControllerProvider._({
    required SubjectDetailControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'subjectDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectDetailControllerHash();

  @override
  String toString() {
    return r'subjectDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubjectDetailController create() => SubjectDetailController();

  @override
  bool operator ==(Object other) {
    return other is SubjectDetailControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectDetailControllerHash() =>
    r'20c2661d85ddebfb6e0b534bfd822b5f2ff796a6';

/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating). Cast ([SubjectCharacters]) and staff
/// ([SubjectStaff]) are fetched via separate providers so either can
/// fail independently without affecting this one or each other -- see
/// the design doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).

final class SubjectDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectDetailController,
          AsyncValue<SubjectDetail>,
          SubjectDetail,
          FutureOr<SubjectDetail>,
          int
        > {
  SubjectDetailControllerFamily._()
    : super(
        retry: null,
        name: r'subjectDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the main subject-detail payload (summary/tags/score/rank/
  /// collection status/self-rating). Cast ([SubjectCharacters]) and staff
  /// ([SubjectStaff]) are fetched via separate providers so either can
  /// fail independently without affecting this one or each other -- see
  /// the design doc's "per-source silent failure" pattern (mirrors how
  /// `SubjectEpisodesController` isolates each `MediaSource`'s failure).

  SubjectDetailControllerProvider call({required int subjectId}) =>
      SubjectDetailControllerProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'subjectDetailControllerProvider';
}

/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating). Cast ([SubjectCharacters]) and staff
/// ([SubjectStaff]) are fetched via separate providers so either can
/// fail independently without affecting this one or each other -- see
/// the design doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).

abstract class _$SubjectDetailController extends $AsyncNotifier<SubjectDetail> {
  late final _$args = ref.$arg as int;
  int get subjectId => _$args;

  FutureOr<SubjectDetail> build({required int subjectId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SubjectDetail>, SubjectDetail>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SubjectDetail>, SubjectDetail>,
              AsyncValue<SubjectDetail>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(subjectId: _$args));
  }
}

/// Cast (characters + voice actors, per `SubjectApi.getCharacters`
/// always requesting `withActors=true`). `SubjectDetailScreen` hides
/// this whole section on error rather than showing a retry button.

@ProviderFor(SubjectCharacters)
final subjectCharactersProvider = SubjectCharactersFamily._();

/// Cast (characters + voice actors, per `SubjectApi.getCharacters`
/// always requesting `withActors=true`). `SubjectDetailScreen` hides
/// this whole section on error rather than showing a retry button.
final class SubjectCharactersProvider
    extends $AsyncNotifierProvider<SubjectCharacters, List<RelatedCharacter>> {
  /// Cast (characters + voice actors, per `SubjectApi.getCharacters`
  /// always requesting `withActors=true`). `SubjectDetailScreen` hides
  /// this whole section on error rather than showing a retry button.
  SubjectCharactersProvider._({
    required SubjectCharactersFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'subjectCharactersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectCharactersHash();

  @override
  String toString() {
    return r'subjectCharactersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubjectCharacters create() => SubjectCharacters();

  @override
  bool operator ==(Object other) {
    return other is SubjectCharactersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectCharactersHash() => r'cc4da1e589d45948c838519dd2a910c535e6aa24';

/// Cast (characters + voice actors, per `SubjectApi.getCharacters`
/// always requesting `withActors=true`). `SubjectDetailScreen` hides
/// this whole section on error rather than showing a retry button.

final class SubjectCharactersFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectCharacters,
          AsyncValue<List<RelatedCharacter>>,
          List<RelatedCharacter>,
          FutureOr<List<RelatedCharacter>>,
          int
        > {
  SubjectCharactersFamily._()
    : super(
        retry: null,
        name: r'subjectCharactersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Cast (characters + voice actors, per `SubjectApi.getCharacters`
  /// always requesting `withActors=true`). `SubjectDetailScreen` hides
  /// this whole section on error rather than showing a retry button.

  SubjectCharactersProvider call({required int subjectId}) =>
      SubjectCharactersProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'subjectCharactersProvider';
}

/// Cast (characters + voice actors, per `SubjectApi.getCharacters`
/// always requesting `withActors=true`). `SubjectDetailScreen` hides
/// this whole section on error rather than showing a retry button.

abstract class _$SubjectCharacters
    extends $AsyncNotifier<List<RelatedCharacter>> {
  late final _$args = ref.$arg as int;
  int get subjectId => _$args;

  FutureOr<List<RelatedCharacter>> build({required int subjectId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<RelatedCharacter>>, List<RelatedCharacter>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RelatedCharacter>>,
                List<RelatedCharacter>
              >,
              AsyncValue<List<RelatedCharacter>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(subjectId: _$args));
  }
}

/// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].

@ProviderFor(SubjectStaff)
final subjectStaffProvider = SubjectStaffFamily._();

/// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].
final class SubjectStaffProvider
    extends $AsyncNotifierProvider<SubjectStaff, List<StaffMember>> {
  /// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].
  SubjectStaffProvider._({
    required SubjectStaffFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'subjectStaffProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectStaffHash();

  @override
  String toString() {
    return r'subjectStaffProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubjectStaff create() => SubjectStaff();

  @override
  bool operator ==(Object other) {
    return other is SubjectStaffProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectStaffHash() => r'cdf38fd8dfbf39674f58f096d1badf1250ba804c';

/// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].

final class SubjectStaffFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectStaff,
          AsyncValue<List<StaffMember>>,
          List<StaffMember>,
          FutureOr<List<StaffMember>>,
          int
        > {
  SubjectStaffFamily._()
    : super(
        retry: null,
        name: r'subjectStaffProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].

  SubjectStaffProvider call({required int subjectId}) =>
      SubjectStaffProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'subjectStaffProvider';
}

/// Staff. Same per-source-silent-failure treatment as [SubjectCharacters].

abstract class _$SubjectStaff extends $AsyncNotifier<List<StaffMember>> {
  late final _$args = ref.$arg as int;
  int get subjectId => _$args;

  FutureOr<List<StaffMember>> build({required int subjectId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<StaffMember>>, List<StaffMember>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<StaffMember>>, List<StaffMember>>,
              AsyncValue<List<StaffMember>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(subjectId: _$args));
  }
}
