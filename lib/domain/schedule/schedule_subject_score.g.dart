// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_subject_score.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(scheduleSubjectScore)
final scheduleSubjectScoreProvider = ScheduleSubjectScoreFamily._();

final class ScheduleSubjectScoreProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  ScheduleSubjectScoreProvider._({
    required ScheduleSubjectScoreFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'scheduleSubjectScoreProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scheduleSubjectScoreHash();

  @override
  String toString() {
    return r'scheduleSubjectScoreProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as int;
    return scheduleSubjectScore(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduleSubjectScoreProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scheduleSubjectScoreHash() =>
    r'53d1ffec72853233ee274e4de5c58a7924ef8b38';

final class ScheduleSubjectScoreFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, int> {
  ScheduleSubjectScoreFamily._()
    : super(
        retry: null,
        name: r'scheduleSubjectScoreProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ScheduleSubjectScoreProvider call(int subjectId) =>
      ScheduleSubjectScoreProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'scheduleSubjectScoreProvider';
}
