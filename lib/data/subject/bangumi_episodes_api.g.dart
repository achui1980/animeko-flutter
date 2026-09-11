// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_episodes_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bangumiEpisodesDio)
final bangumiEpisodesDioProvider = BangumiEpisodesDioProvider._();

final class BangumiEpisodesDioProvider
    extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  BangumiEpisodesDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bangumiEpisodesDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bangumiEpisodesDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return bangumiEpisodesDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$bangumiEpisodesDioHash() =>
    r'e0b7e2eaa5c8bd6f0d03972c4b601478e651f30d';

@ProviderFor(bangumiEpisodesApi)
final bangumiEpisodesApiProvider = BangumiEpisodesApiProvider._();

final class BangumiEpisodesApiProvider
    extends
        $FunctionalProvider<
          BangumiEpisodesApi,
          BangumiEpisodesApi,
          BangumiEpisodesApi
        >
    with $Provider<BangumiEpisodesApi> {
  BangumiEpisodesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bangumiEpisodesApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bangumiEpisodesApiHash();

  @$internal
  @override
  $ProviderElement<BangumiEpisodesApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BangumiEpisodesApi create(Ref ref) {
    return bangumiEpisodesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BangumiEpisodesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BangumiEpisodesApi>(value),
    );
  }
}

String _$bangumiEpisodesApiHash() =>
    r'3d93321394ee931203c628057e8c2d2bf0cbe641';
