// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(defaultDownloadDirectory)
final defaultDownloadDirectoryProvider = DefaultDownloadDirectoryProvider._();

final class DefaultDownloadDirectoryProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  DefaultDownloadDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultDownloadDirectoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultDownloadDirectoryHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return defaultDownloadDirectory(ref);
  }
}

String _$defaultDownloadDirectoryHash() =>
    r'8fb6937f48459a871e99ca08e66ed694bc254524';

@ProviderFor(DownloadSettingsController)
final downloadSettingsControllerProvider =
    DownloadSettingsControllerProvider._();

final class DownloadSettingsControllerProvider
    extends $AsyncNotifierProvider<DownloadSettingsController, String> {
  DownloadSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadSettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadSettingsControllerHash();

  @$internal
  @override
  DownloadSettingsController create() => DownloadSettingsController();
}

String _$downloadSettingsControllerHash() =>
    r'5d204299b62512abbe8bf6cddea512fca2b4e447';

abstract class _$DownloadSettingsController extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
