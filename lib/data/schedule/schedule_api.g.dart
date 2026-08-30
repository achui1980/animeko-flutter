// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(scheduleApi)
final scheduleApiProvider = ScheduleApiProvider._();

final class ScheduleApiProvider
    extends $FunctionalProvider<ScheduleApi, ScheduleApi, ScheduleApi>
    with $Provider<ScheduleApi> {
  ScheduleApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduleApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduleApiHash();

  @$internal
  @override
  $ProviderElement<ScheduleApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScheduleApi create(Ref ref) {
    return scheduleApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduleApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduleApi>(value),
    );
  }
}

String _$scheduleApiHash() => r'afbfb1fb75b781b09f2fc305c9eebb1a72d91719';
