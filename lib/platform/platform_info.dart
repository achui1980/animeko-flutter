// lib/platform/platform_info.dart
import 'dart:ffi' show Abi;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_info.g.dart';

/// OS/CPU-architecture identifiers matching the Kotlin reference client's
/// `Platform.name`/`Arch.displayName` vocabulary exactly (see
/// utils/platform/.../Platform.kt in the Ani repo: "Don't change, used by
/// the server"). ani-api-server validates these against a fixed
/// vocabulary, so Dart's own naming ("arm64"/"x64") is rejected with HTTP
/// 400 -- it must be "aarch64"/"x86_64". Extracted out of `AuthController`
/// per Plan 1a follow-up I4 (it's a platform fact, not domain logic).
class PlatformInfo {
  const PlatformInfo({required this.os, required this.arch});

  final String os;
  final String arch;
}

@riverpod
PlatformInfo platformInfo(Ref ref) {
  switch (Abi.current()) {
    case Abi.macosArm64:
      return const PlatformInfo(os: 'macos', arch: 'aarch64');
    case Abi.macosX64:
      return const PlatformInfo(os: 'macos', arch: 'x86_64');
    default:
      // Only macOS is exercised today. iOS was scaffolded in Plan 1a
      // Task 1 but never built/run; other platforms are deliberately
      // unsupported until a future platform-expansion plan verifies the
      // exact os/arch values the server expects for them.
      throw UnsupportedError(
        'PlatformInfo has no mapping for ${Abi.current()}',
      );
  }
}
