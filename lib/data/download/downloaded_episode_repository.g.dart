// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_episode_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadedEpisodeRepository)
final downloadedEpisodeRepositoryProvider =
    DownloadedEpisodeRepositoryProvider._();

final class DownloadedEpisodeRepositoryProvider
    extends
        $FunctionalProvider<
          DownloadedEpisodeRepository,
          DownloadedEpisodeRepository,
          DownloadedEpisodeRepository
        >
    with $Provider<DownloadedEpisodeRepository> {
  DownloadedEpisodeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedEpisodeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedEpisodeRepositoryHash();

  @$internal
  @override
  $ProviderElement<DownloadedEpisodeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadedEpisodeRepository create(Ref ref) {
    return downloadedEpisodeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadedEpisodeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadedEpisodeRepository>(value),
    );
  }
}

String _$downloadedEpisodeRepositoryHash() =>
    r'8c59fb4b8715bbee55b4c216263d680821e61ec3';
