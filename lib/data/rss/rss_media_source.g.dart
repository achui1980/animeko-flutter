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
