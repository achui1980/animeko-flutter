// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'proxy_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProxySettingsController)
final proxySettingsControllerProvider = ProxySettingsControllerProvider._();

final class ProxySettingsControllerProvider
    extends $AsyncNotifierProvider<ProxySettingsController, String?> {
  ProxySettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'proxySettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$proxySettingsControllerHash();

  @$internal
  @override
  ProxySettingsController create() => ProxySettingsController();
}

String _$proxySettingsControllerHash() =>
    r'b7ec08ceacde25b58ed1972ee6d349bab18d1d13';

abstract class _$ProxySettingsController extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
