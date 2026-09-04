// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dynamic_color_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DynamicColorController)
final dynamicColorControllerProvider = DynamicColorControllerProvider._();

final class DynamicColorControllerProvider
    extends $AsyncNotifierProvider<DynamicColorController, bool> {
  DynamicColorControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dynamicColorControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dynamicColorControllerHash();

  @$internal
  @override
  DynamicColorController create() => DynamicColorController();
}

String _$dynamicColorControllerHash() =>
    r'42c797346d7430dd1a5a658379cca6ba547fb5cd';

abstract class _$DynamicColorController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
