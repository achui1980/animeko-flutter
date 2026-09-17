// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_episodes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadedEpisodes)
final downloadedEpisodesProvider = DownloadedEpisodesProvider._();

final class DownloadedEpisodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DownloadedEpisodeSummary>>,
          List<DownloadedEpisodeSummary>,
          Stream<List<DownloadedEpisodeSummary>>
        >
    with
        $FutureModifier<List<DownloadedEpisodeSummary>>,
        $StreamProvider<List<DownloadedEpisodeSummary>> {
  DownloadedEpisodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedEpisodesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedEpisodesHash();

  @$internal
  @override
  $StreamProviderElement<List<DownloadedEpisodeSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DownloadedEpisodeSummary>> create(Ref ref) {
    return downloadedEpisodes(ref);
  }
}

String _$downloadedEpisodesHash() =>
    r'01be9cad49e9019eefb4ff3006185b1da0e269a2';
