// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_speed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlaybackSpeedController)
final playbackSpeedControllerProvider = PlaybackSpeedControllerProvider._();

final class PlaybackSpeedControllerProvider
    extends $AsyncNotifierProvider<PlaybackSpeedController, double> {
  PlaybackSpeedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackSpeedControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackSpeedControllerHash();

  @$internal
  @override
  PlaybackSpeedController create() => PlaybackSpeedController();
}

String _$playbackSpeedControllerHash() =>
    r'5bcdc086808cc670ffb520137b46d39ba479bfa0';

abstract class _$PlaybackSpeedController extends $AsyncNotifier<double> {
  FutureOr<double> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<double>, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<double>, double>,
              AsyncValue<double>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
