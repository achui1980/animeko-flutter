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

/// Maps a Dart [Abi] onto the server's `os`/`arch` vocabulary.
///
/// The accepted vocabulary was verified empirically against
/// `GET https://api.animeko.org/v2/users/bangumi/oauth`: `os` must be
/// lower-case (`macos`, `android`, `ios`, `windows`, `linux` all pass;
/// `Android` returns HTTP 400 "Bad client platform or architecture"), and
/// `arch` must be one of `aarch64`, `x86_64`, `arm64-v8a`, `armeabi-v7a`,
/// `x86` (`arm64`, `x64` and `armv7a` are all rejected). Note that on
/// Android the Kotlin client sends the *Android ABI* names
/// (`arm64-v8a`/`armeabi-v7a`), not `aarch64`.
PlatformInfo platformInfoFor(Abi abi) {
  switch (abi) {
    case Abi.macosArm64:
      return const PlatformInfo(os: 'macos', arch: 'aarch64');
    case Abi.macosX64:
      return const PlatformInfo(os: 'macos', arch: 'x86_64');
    case Abi.androidArm64:
      return const PlatformInfo(os: 'android', arch: 'arm64-v8a');
    case Abi.androidArm:
      return const PlatformInfo(os: 'android', arch: 'armeabi-v7a');
    case Abi.androidX64:
      return const PlatformInfo(os: 'android', arch: 'x86_64');
    case Abi.androidIA32:
      return const PlatformInfo(os: 'android', arch: 'x86');
    case Abi.iosArm64:
      return const PlatformInfo(os: 'ios', arch: 'aarch64');
    case Abi.iosX64:
      return const PlatformInfo(os: 'ios', arch: 'x86_64');
    case Abi.windowsArm64:
      return const PlatformInfo(os: 'windows', arch: 'aarch64');
    case Abi.windowsX64:
      return const PlatformInfo(os: 'windows', arch: 'x86_64');
    case Abi.linuxArm64:
      return const PlatformInfo(os: 'linux', arch: 'aarch64');
    case Abi.linuxX64:
      return const PlatformInfo(os: 'linux', arch: 'x86_64');
    default:
      // Anything left (Fuchsia, riscv, 32-bit desktop/iOS) has no name in
      // the server's vocabulary, so there is nothing correct to send.
      throw UnsupportedError('PlatformInfo has no mapping for $abi');
  }
}

@riverpod
PlatformInfo platformInfo(Ref ref) => platformInfoFor(Abi.current());
