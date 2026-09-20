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
///
/// [YinghuaMediaSource] is intentionally *not* registered here: its CDN
/// lines have repeatedly been observed dead/blocked in the wild (e.g. a
/// `vip.ffzy-plays.com` line returning HTTP 403 on every request), so the
/// source is disabled at the app level rather than removed outright --
/// [YinghuaMediaSource]/[YinghuaApi] remain intact and can be re-added to
/// this list if the situation improves.
///
/// [DilidiliMediaSource] is also intentionally *not* registered here:
/// users have reported playback repeatedly stalling at ~2 seconds (the
/// player's reported total duration was only ~2s, not the real episode
/// length), on at least one real title/CDN line combination. The exact
/// resolved URL was independently verified (via direct HTTP replication
/// of the app's own request chain) to be fully reachable and structurally
/// valid end-to-end -- an AES-128-encrypted HLS playlist with a relative
/// key URI, all segments and the key itself fetched successfully -- so
/// the root cause was not conclusively identified (a proxy interaction
/// with the encrypted/relative-key-URI playlist chain is suspected but
/// unconfirmed). Disabled as a stopgap per explicit user request rather
/// than left broken for users. [DilidiliMediaSource]/[DilidiliApi] remain
/// intact and can be re-added to this list if the issue is resolved.
///

@ProviderFor(mediaSources)
final mediaSourcesProvider = MediaSourcesProvider._();

/// Every registered [MediaSource], queried concurrently by
/// `SubjectEpisodesController`. Add a new source here (and nowhere else)
/// to make it participate in the merged search/episode-list flow.
///
/// [YinghuaMediaSource] is intentionally *not* registered here: its CDN
/// lines have repeatedly been observed dead/blocked in the wild (e.g. a
/// `vip.ffzy-plays.com` line returning HTTP 403 on every request), so the
/// source is disabled at the app level rather than removed outright --
/// [YinghuaMediaSource]/[YinghuaApi] remain intact and can be re-added to
/// this list if the situation improves.
///
/// [DilidiliMediaSource] is also intentionally *not* registered here:
/// users have reported playback repeatedly stalling at ~2 seconds (the
/// player's reported total duration was only ~2s, not the real episode
/// length), on at least one real title/CDN line combination. The exact
/// resolved URL was independently verified (via direct HTTP replication
/// of the app's own request chain) to be fully reachable and structurally
/// valid end-to-end -- an AES-128-encrypted HLS playlist with a relative
/// key URI, all segments and the key itself fetched successfully -- so
/// the root cause was not conclusively identified (a proxy interaction
/// with the encrypted/relative-key-URI playlist chain is suspected but
/// unconfirmed). Disabled as a stopgap per explicit user request rather
/// than left broken for users. [DilidiliMediaSource]/[DilidiliApi] remain
/// intact and can be re-added to this list if the issue is resolved.
///

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
  ///
  /// [YinghuaMediaSource] is intentionally *not* registered here: its CDN
  /// lines have repeatedly been observed dead/blocked in the wild (e.g. a
  /// `vip.ffzy-plays.com` line returning HTTP 403 on every request), so the
  /// source is disabled at the app level rather than removed outright --
  /// [YinghuaMediaSource]/[YinghuaApi] remain intact and can be re-added to
  /// this list if the situation improves.
  ///
  /// [DilidiliMediaSource] is also intentionally *not* registered here:
  /// users have reported playback repeatedly stalling at ~2 seconds (the
  /// player's reported total duration was only ~2s, not the real episode
  /// length), on at least one real title/CDN line combination. The exact
  /// resolved URL was independently verified (via direct HTTP replication
  /// of the app's own request chain) to be fully reachable and structurally
  /// valid end-to-end -- an AES-128-encrypted HLS playlist with a relative
  /// key URI, all segments and the key itself fetched successfully -- so
  /// the root cause was not conclusively identified (a proxy interaction
  /// with the encrypted/relative-key-URI playlist chain is suspected but
  /// unconfirmed). Disabled as a stopgap per explicit user request rather
  /// than left broken for users. [DilidiliMediaSource]/[DilidiliApi] remain
  /// intact and can be re-added to this list if the issue is resolved.
  ///
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

String _$mediaSourcesHash() => r'af67699aea83b7a4ba34e3d295ca404e9dfca9a9';
