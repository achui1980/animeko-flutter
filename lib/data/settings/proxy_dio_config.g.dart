// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'proxy_dio_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A [Dio] instance for the download pipeline that bypasses the user's
/// configured proxy, for use with MediaPlaybackSource candidates whose
/// `prefersDirectConnection` is `true`.

@ProviderFor(downloadDirectDio)
final downloadDirectDioProvider = DownloadDirectDioProvider._();

/// A [Dio] instance for the download pipeline that bypasses the user's
/// configured proxy, for use with MediaPlaybackSource candidates whose
/// `prefersDirectConnection` is `true`.

final class DownloadDirectDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// A [Dio] instance for the download pipeline that bypasses the user's
  /// configured proxy, for use with MediaPlaybackSource candidates whose
  /// `prefersDirectConnection` is `true`.
  DownloadDirectDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadDirectDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadDirectDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return downloadDirectDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$downloadDirectDioHash() => r'afcfd27227c600ee730a38ccbf3dc6468d5cd7a5';
