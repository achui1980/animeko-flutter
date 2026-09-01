// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_play_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EpisodePlayController)
final episodePlayControllerProvider = EpisodePlayControllerFamily._();

final class EpisodePlayControllerProvider
    extends $AsyncNotifierProvider<EpisodePlayController, MediaPlaybackSource> {
  EpisodePlayControllerProvider._({
    required EpisodePlayControllerFamily super.from,
    required MergedEpisode super.argument,
  }) : super(
         retry: null,
         name: r'episodePlayControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$episodePlayControllerHash();

  @override
  String toString() {
    return r'episodePlayControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EpisodePlayController create() => EpisodePlayController();

  @override
  bool operator ==(Object other) {
    return other is EpisodePlayControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$episodePlayControllerHash() =>
    r'c7e74be1e0b9aa809383ad6d2c848197c9d30698';

final class EpisodePlayControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EpisodePlayController,
          AsyncValue<MediaPlaybackSource>,
          MediaPlaybackSource,
          FutureOr<MediaPlaybackSource>,
          MergedEpisode
        > {
  EpisodePlayControllerFamily._()
    : super(
        retry: null,
        name: r'episodePlayControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EpisodePlayControllerProvider call({required MergedEpisode episode}) =>
      EpisodePlayControllerProvider._(argument: episode, from: this);

  @override
  String toString() => r'episodePlayControllerProvider';
}

abstract class _$EpisodePlayController
    extends $AsyncNotifier<MediaPlaybackSource> {
  late final _$args = ref.$arg as MergedEpisode;
  MergedEpisode get episode => _$args;

  FutureOr<MediaPlaybackSource> build({required MergedEpisode episode});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MediaPlaybackSource>, MediaPlaybackSource>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MediaPlaybackSource>, MediaPlaybackSource>,
              AsyncValue<MediaPlaybackSource>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(episode: _$args));
  }
}
