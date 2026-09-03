// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_position_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playbackPositionStorage)
final playbackPositionStorageProvider = PlaybackPositionStorageProvider._();

final class PlaybackPositionStorageProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlaybackPositionStorage>,
          PlaybackPositionStorage,
          FutureOr<PlaybackPositionStorage>
        >
    with
        $FutureModifier<PlaybackPositionStorage>,
        $FutureProvider<PlaybackPositionStorage> {
  PlaybackPositionStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackPositionStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackPositionStorageHash();

  @$internal
  @override
  $FutureProviderElement<PlaybackPositionStorage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlaybackPositionStorage> create(Ref ref) {
    return playbackPositionStorage(ref);
  }
}

String _$playbackPositionStorageHash() =>
    r'13578500b1ff3293f4d4a32fbc24006ffbfb6b44';
