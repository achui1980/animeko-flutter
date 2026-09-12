// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rss_media_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mikanRssDio)
final mikanRssDioProvider = MikanRssDioProvider._();

final class MikanRssDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  MikanRssDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mikanRssDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mikanRssDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return mikanRssDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$mikanRssDioHash() => r'26282b11d744b4d53c7d4f56ab07c4f60d0ad0f2';

/// Resolves Bangumi subject ids to Mikan bangumi ids for
/// [RssMediaSource.search].
///
/// Deliberately built on the same [mikanRssDio] as the feed requests: the
/// 条目 search page and bangumi pages live on the same host and need the
/// same proxy handling and timeout bounds. The `!` is safe by construction
/// -- [mikanRssSourceConfig] always declares a [RssSourceConfig.subjectSearchUrl].

@ProviderFor(mikanSubjectLocator)
final mikanSubjectLocatorProvider = MikanSubjectLocatorProvider._();

/// Resolves Bangumi subject ids to Mikan bangumi ids for
/// [RssMediaSource.search].
///
/// Deliberately built on the same [mikanRssDio] as the feed requests: the
/// 条目 search page and bangumi pages live on the same host and need the
/// same proxy handling and timeout bounds. The `!` is safe by construction
/// -- [mikanRssSourceConfig] always declares a [RssSourceConfig.subjectSearchUrl].

final class MikanSubjectLocatorProvider
    extends
        $FunctionalProvider<
          MikanSubjectLocator,
          MikanSubjectLocator,
          MikanSubjectLocator
        >
    with $Provider<MikanSubjectLocator> {
  /// Resolves Bangumi subject ids to Mikan bangumi ids for
  /// [RssMediaSource.search].
  ///
  /// Deliberately built on the same [mikanRssDio] as the feed requests: the
  /// 条目 search page and bangumi pages live on the same host and need the
  /// same proxy handling and timeout bounds. The `!` is safe by construction
  /// -- [mikanRssSourceConfig] always declares a [RssSourceConfig.subjectSearchUrl].
  MikanSubjectLocatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mikanSubjectLocatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mikanSubjectLocatorHash();

  @$internal
  @override
  $ProviderElement<MikanSubjectLocator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MikanSubjectLocator create(Ref ref) {
    return mikanSubjectLocator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MikanSubjectLocator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MikanSubjectLocator>(value),
    );
  }
}

String _$mikanSubjectLocatorHash() =>
    r'c8382943db54fa73f2fa01f606bf61dae95ff1f5';
