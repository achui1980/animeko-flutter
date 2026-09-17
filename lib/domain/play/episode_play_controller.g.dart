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
    extends
        $AsyncNotifierProvider<
          EpisodePlayController,
          List<MediaPlaybackSource>
        > {
  EpisodePlayControllerProvider._({
    required EpisodePlayControllerFamily super.from,
    required ({MergedEpisode episode, int subjectId}) super.argument,
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
        '$argument';
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
    r'5de89423edd2553b3630a1ba894eac3d4755b4ff';

final class EpisodePlayControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EpisodePlayController,
          AsyncValue<List<MediaPlaybackSource>>,
          List<MediaPlaybackSource>,
          FutureOr<List<MediaPlaybackSource>>,
          ({MergedEpisode episode, int subjectId})
        > {
  EpisodePlayControllerFamily._()
    : super(
        retry: null,
        name: r'episodePlayControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EpisodePlayControllerProvider call({
    required MergedEpisode episode,
    required int subjectId,
  }) => EpisodePlayControllerProvider._(
    argument: (episode: episode, subjectId: subjectId),
    from: this,
  );

  @override
  String toString() => r'episodePlayControllerProvider';
}

abstract class _$EpisodePlayController
    extends $AsyncNotifier<List<MediaPlaybackSource>> {
  late final _$args = ref.$arg as ({MergedEpisode episode, int subjectId});
  MergedEpisode get episode => _$args.episode;
  int get subjectId => _$args.subjectId;

  FutureOr<List<MediaPlaybackSource>> build({
    required MergedEpisode episode,
    required int subjectId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<MediaPlaybackSource>>,
              List<MediaPlaybackSource>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MediaPlaybackSource>>,
                List<MediaPlaybackSource>
              >,
              AsyncValue<List<MediaPlaybackSource>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(episode: _$args.episode, subjectId: _$args.subjectId),
    );
  }
}
