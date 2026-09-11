// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xifan_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(xifanDio)
final xifanDioProvider = XifanDioProvider._();

final class XifanDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  XifanDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xifanDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xifanDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return xifanDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$xifanDioHash() => r'3763e9cb680a4b307523738877c2124fd4f38c55';

/// Dio for 稀饭动漫's Supabase-backed API (`next.xifanacg.com`) --
/// PRIMARY backend for [XifanApi.search]/[XifanApi.listEpisodes]/
/// [XifanApi.resolvePlaybackUrl] as of 2026-09-10 (see [XifanBackend]).

@ProviderFor(xifanSupabaseDio)
final xifanSupabaseDioProvider = XifanSupabaseDioProvider._();

/// Dio for 稀饭动漫's Supabase-backed API (`next.xifanacg.com`) --
/// PRIMARY backend for [XifanApi.search]/[XifanApi.listEpisodes]/
/// [XifanApi.resolvePlaybackUrl] as of 2026-09-10 (see [XifanBackend]).

final class XifanSupabaseDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// Dio for 稀饭动漫's Supabase-backed API (`next.xifanacg.com`) --
  /// PRIMARY backend for [XifanApi.search]/[XifanApi.listEpisodes]/
  /// [XifanApi.resolvePlaybackUrl] as of 2026-09-10 (see [XifanBackend]).
  XifanSupabaseDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xifanSupabaseDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xifanSupabaseDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return xifanSupabaseDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$xifanSupabaseDioHash() => r'4f413384d396ba49b3c5ebfec4b373788b46194c';

@ProviderFor(xifanApi)
final xifanApiProvider = XifanApiProvider._();

final class XifanApiProvider
    extends $FunctionalProvider<XifanApi, XifanApi, XifanApi>
    with $Provider<XifanApi> {
  XifanApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xifanApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xifanApiHash();

  @$internal
  @override
  $ProviderElement<XifanApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  XifanApi create(Ref ref) {
    return xifanApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(XifanApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<XifanApi>(value),
    );
  }
}

String _$xifanApiHash() => r'25c81a31db671a30232531603022c7a58ba466c9';
