// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_registry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every registered [MediaSource], queried concurrently by
/// `SubjectEpisodesController`. Add a new source here (and nowhere else)
/// to make it participate in the merged search/episode-list flow.

@ProviderFor(mediaSources)
final mediaSourcesProvider = MediaSourcesProvider._();

/// Every registered [MediaSource], queried concurrently by
/// `SubjectEpisodesController`. Add a new source here (and nowhere else)
/// to make it participate in the merged search/episode-list flow.

final class MediaSourcesProvider
    extends
        $FunctionalProvider<
          List<MediaSource>,
          List<MediaSource>,
          List<MediaSource>
        >
    with $Provider<List<MediaSource>> {
  /// Every registered [MediaSource], queried concurrently by
  /// `SubjectEpisodesController`. Add a new source here (and nowhere else)
  /// to make it participate in the merged search/episode-list flow.
  MediaSourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaSourcesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaSourcesHash();

  @$internal
  @override
  $ProviderElement<List<MediaSource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<MediaSource> create(Ref ref) {
    return mediaSources(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MediaSource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MediaSource>>(value),
    );
  }
}

String _$mediaSourcesHash() => r'a15f28a1f1f895df925612007045152dd395a1c3';
