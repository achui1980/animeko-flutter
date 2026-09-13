// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_played_episode_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(lastPlayedEpisodeStorage)
final lastPlayedEpisodeStorageProvider = LastPlayedEpisodeStorageProvider._();

final class LastPlayedEpisodeStorageProvider
    extends
        $FunctionalProvider<
          AsyncValue<LastPlayedEpisodeStorage>,
          LastPlayedEpisodeStorage,
          FutureOr<LastPlayedEpisodeStorage>
        >
    with
        $FutureModifier<LastPlayedEpisodeStorage>,
        $FutureProvider<LastPlayedEpisodeStorage> {
  LastPlayedEpisodeStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastPlayedEpisodeStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastPlayedEpisodeStorageHash();

  @$internal
  @override
  $FutureProviderElement<LastPlayedEpisodeStorage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LastPlayedEpisodeStorage> create(Ref ref) {
    return lastPlayedEpisodeStorage(ref);
  }
}

String _$lastPlayedEpisodeStorageHash() =>
    r'e5065049c5c20128459554248f2b983e0368e331';
