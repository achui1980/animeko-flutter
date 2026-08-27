// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browser_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(browserLauncher)
final browserLauncherProvider = BrowserLauncherProvider._();

final class BrowserLauncherProvider
    extends
        $FunctionalProvider<BrowserLauncher, BrowserLauncher, BrowserLauncher>
    with $Provider<BrowserLauncher> {
  BrowserLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'browserLauncherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$browserLauncherHash();

  @$internal
  @override
  $ProviderElement<BrowserLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BrowserLauncher create(Ref ref) {
    return browserLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrowserLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BrowserLauncher>(value),
    );
  }
}

String _$browserLauncherHash() => r'cba054bac3220a9395b32e13373bf64e0c85b47d';
