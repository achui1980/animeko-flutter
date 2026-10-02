// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'airplay_cast_channel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(airPlayCastChannel)
final airPlayCastChannelProvider = AirPlayCastChannelProvider._();

final class AirPlayCastChannelProvider
    extends
        $FunctionalProvider<
          AirPlayCastChannel,
          AirPlayCastChannel,
          AirPlayCastChannel
        >
    with $Provider<AirPlayCastChannel> {
  AirPlayCastChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'airPlayCastChannelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$airPlayCastChannelHash();

  @$internal
  @override
  $ProviderElement<AirPlayCastChannel> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AirPlayCastChannel create(Ref ref) {
    return airPlayCastChannel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AirPlayCastChannel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AirPlayCastChannel>(value),
    );
  }
}

String _$airPlayCastChannelHash() =>
    r'8ace30dac4883e5204bcab30b41bd2e76264b8a5';
