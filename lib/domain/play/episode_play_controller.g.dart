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
        $AsyncNotifierProvider<EpisodePlayController, Anime1PlaybackSource> {
  EpisodePlayControllerProvider._({
    required EpisodePlayControllerFamily super.from,
    required String super.argument,
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
    r'b82e415d6731dad91d4b64018b8f1020061c6a68';

final class EpisodePlayControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EpisodePlayController,
          AsyncValue<Anime1PlaybackSource>,
          Anime1PlaybackSource,
          FutureOr<Anime1PlaybackSource>,
          String
        > {
  EpisodePlayControllerFamily._()
    : super(
        retry: null,
        name: r'episodePlayControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EpisodePlayControllerProvider call({required String episodePageUrl}) =>
      EpisodePlayControllerProvider._(argument: episodePageUrl, from: this);

  @override
  String toString() => r'episodePlayControllerProvider';
}

abstract class _$EpisodePlayController
    extends $AsyncNotifier<Anime1PlaybackSource> {
  late final _$args = ref.$arg as String;
  String get episodePageUrl => _$args;

  FutureOr<Anime1PlaybackSource> build({required String episodePageUrl});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Anime1PlaybackSource>, Anime1PlaybackSource>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Anime1PlaybackSource>,
                Anime1PlaybackSource
              >,
              AsyncValue<Anime1PlaybackSource>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(episodePageUrl: _$args));
  }
}
