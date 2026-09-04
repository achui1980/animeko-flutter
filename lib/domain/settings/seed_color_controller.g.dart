// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed_color_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SeedColorController)
final seedColorControllerProvider = SeedColorControllerProvider._();

final class SeedColorControllerProvider
    extends $AsyncNotifierProvider<SeedColorController, Color> {
  SeedColorControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seedColorControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seedColorControllerHash();

  @$internal
  @override
  SeedColorController create() => SeedColorController();
}

String _$seedColorControllerHash() =>
    r'ac663e6b60cb1f388c216d33f83725015788aec3';

abstract class _$SeedColorController extends $AsyncNotifier<Color> {
  FutureOr<Color> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Color>, Color>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Color>, Color>,
              AsyncValue<Color>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
