// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reacts to native `AirPlayCastEngine` lifecycle events (via
/// [airPlayCastChannelProvider]) and exposes the current [CastState] to
/// `PlayerScreen`. See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4
/// "状态同步与交互流程" for the full state-transition narrative this
/// implements.

@ProviderFor(CastController)
final castControllerProvider = CastControllerProvider._();

/// Reacts to native `AirPlayCastEngine` lifecycle events (via
/// [airPlayCastChannelProvider]) and exposes the current [CastState] to
/// `PlayerScreen`. See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4
/// "状态同步与交互流程" for the full state-transition narrative this
/// implements.
final class CastControllerProvider
    extends $NotifierProvider<CastController, CastState> {
  /// Reacts to native `AirPlayCastEngine` lifecycle events (via
  /// [airPlayCastChannelProvider]) and exposes the current [CastState] to
  /// `PlayerScreen`. See
  /// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4
  /// "状态同步与交互流程" for the full state-transition narrative this
  /// implements.
  CastControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castControllerHash();

  @$internal
  @override
  CastController create() => CastController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastState>(value),
    );
  }
}

String _$castControllerHash() => r'cf2ba5d2b961668cfbfcf8cb2e10e729668a66fa';

/// Reacts to native `AirPlayCastEngine` lifecycle events (via
/// [airPlayCastChannelProvider]) and exposes the current [CastState] to
/// `PlayerScreen`. See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §4
/// "状态同步与交互流程" for the full state-transition narrative this
/// implements.

abstract class _$CastController extends $Notifier<CastState> {
  CastState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CastState, CastState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CastState, CastState>,
              CastState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
