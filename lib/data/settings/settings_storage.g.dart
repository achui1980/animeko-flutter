// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(settingsStorage)
final settingsStorageProvider = SettingsStorageProvider._();

final class SettingsStorageProvider
    extends
        $FunctionalProvider<
          AsyncValue<SettingsStorage>,
          SettingsStorage,
          FutureOr<SettingsStorage>
        >
    with $FutureModifier<SettingsStorage>, $FutureProvider<SettingsStorage> {
  SettingsStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsStorageHash();

  @$internal
  @override
  $FutureProviderElement<SettingsStorage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SettingsStorage> create(Ref ref) {
    return settingsStorage(ref);
  }
}

String _$settingsStorageHash() => r'3d622cf9c8ae9753c7da3a07f9daf903e8467821';
