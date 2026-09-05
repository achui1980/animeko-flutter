// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ScheduleController)
final scheduleControllerProvider = ScheduleControllerProvider._();

final class ScheduleControllerProvider
    extends $AsyncNotifierProvider<ScheduleController, List<ScheduleDay>> {
  ScheduleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduleControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduleControllerHash();

  @$internal
  @override
  ScheduleController create() => ScheduleController();
}

String _$scheduleControllerHash() =>
    r'36a1a3fcb6da7a99ef342b9482d31f13789840cb';

abstract class _$ScheduleController extends $AsyncNotifier<List<ScheduleDay>> {
  FutureOr<List<ScheduleDay>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<ScheduleDay>>, List<ScheduleDay>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ScheduleDay>>, List<ScheduleDay>>,
              AsyncValue<List<ScheduleDay>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
