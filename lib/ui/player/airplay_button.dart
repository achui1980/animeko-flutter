// lib/ui/player/airplay_button.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/play/airplay_cast_channel.dart';

/// Reserves layout space for the native floating AirPlay button (see
/// `macos/Runner/AirPlayButtonOverlay.swift`) and reports this widget's
/// on-screen frame/visibility to native so the real `AVRoutePickerView`
/// can be positioned to match -- this widget itself renders nothing
/// visible. See
/// `docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §2 for
/// why a true embedded platform view isn't used instead.
///
/// [visible] should be `false` whenever the current playback candidate
/// isn't cast-eligible (see `isCastable` in
/// `lib/domain/play/cast_eligibility.dart`) -- the native button is
/// fully hidden, not grayed out, in that case.
class AirPlayButton extends ConsumerStatefulWidget {
  const AirPlayButton({super.key, required this.visible});

  final bool visible;

  @override
  ConsumerState<AirPlayButton> createState() => _AirPlayButtonState();
}

class _AirPlayButtonState extends ConsumerState<AirPlayButton> {
  final _key = GlobalKey();

  // Captured during build() rather than read in dispose(): with Riverpod
  // 3.x, calling `ref.read`/`ref.watch` once a ConsumerStatefulElement is
  // unmounting throws a StateError ("Using 'ref' when a widget is about
  // to or has been unmounted is unsafe"), so dispose() must use this
  // cached reference instead of touching `ref` directly.
  late AirPlayCastChannel _channel;

  @override
  void didUpdateWidget(AirPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    unawaited(_channel.setButtonVisible(false));
    super.dispose();
  }

  void _report() {
    unawaited(_channel.setButtonVisible(widget.visible));
    if (!widget.visible) return;
    final renderObject = _key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final offset = renderObject.localToGlobal(Offset.zero);
    unawaited(
      _channel.setButtonFrame(
        x: offset.dx,
        y: offset.dy,
        width: renderObject.size.width,
        height: renderObject.size.height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _channel = ref.watch(airPlayCastChannelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return SizedBox(key: _key, width: 44, height: 44);
  }
}
