// test/platform/platform_info_test.dart
import 'dart:ffi' show Abi;

import 'package:animeko_flutter/platform/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test(
    'platformInfoProvider returns macos with a valid arch on this dev machine',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final info = container.read(platformInfoProvider);

      expect(info.os, 'macos');
      expect(info.arch, anyOf('aarch64', 'x86_64'));
    },
  );

  test('PlatformInfo stores os and arch as given', () {
    const info = PlatformInfo(os: 'ios', arch: 'aarch64');

    expect(info.os, 'ios');
    expect(info.arch, 'aarch64');
  });

  group('platformInfoFor', () {
    test('maps macOS ABIs', () {
      expect(platformInfoFor(Abi.macosArm64).os, 'macos');
      expect(platformInfoFor(Abi.macosArm64).arch, 'aarch64');
      expect(platformInfoFor(Abi.macosX64).os, 'macos');
      expect(platformInfoFor(Abi.macosX64).arch, 'x86_64');
    });

    // The server rejects anything outside its fixed vocabulary with HTTP 400
    // "Bad client platform or architecture" (verified against
    // api.animeko.org/v2/users/bangumi/oauth). On Android the Kotlin client
    // sends the Android ABI names, not the JVM/LLVM ones.
    test('maps Android ABIs to the Android ABI names Kotlin sends', () {
      expect(platformInfoFor(Abi.androidArm64).os, 'android');
      expect(platformInfoFor(Abi.androidArm64).arch, 'arm64-v8a');
      expect(platformInfoFor(Abi.androidArm).os, 'android');
      expect(platformInfoFor(Abi.androidArm).arch, 'armeabi-v7a');
      expect(platformInfoFor(Abi.androidX64).arch, 'x86_64');
      expect(platformInfoFor(Abi.androidIA32).arch, 'x86');
    });

    test('maps iOS ABIs', () {
      expect(platformInfoFor(Abi.iosArm64).os, 'ios');
      expect(platformInfoFor(Abi.iosArm64).arch, 'aarch64');
      expect(platformInfoFor(Abi.iosX64).os, 'ios');
      expect(platformInfoFor(Abi.iosX64).arch, 'x86_64');
    });

    test('maps Windows and Linux ABIs', () {
      expect(platformInfoFor(Abi.windowsX64).os, 'windows');
      expect(platformInfoFor(Abi.windowsX64).arch, 'x86_64');
      expect(platformInfoFor(Abi.windowsArm64).arch, 'aarch64');
      expect(platformInfoFor(Abi.linuxX64).os, 'linux');
      expect(platformInfoFor(Abi.linuxX64).arch, 'x86_64');
      expect(platformInfoFor(Abi.linuxArm64).arch, 'aarch64');
    });

    test('throws for ABIs the server vocabulary has no name for', () {
      expect(
        () => platformInfoFor(Abi.fuchsiaX64),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
