// test/platform/platform_info_test.dart
import 'package:animeko_flutter/platform/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('platformInfoProvider returns macos with a valid arch on this dev machine', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final info = container.read(platformInfoProvider);

    expect(info.os, 'macos');
    expect(info.arch, anyOf('aarch64', 'x86_64'));
  });

  test('PlatformInfo stores os and arch as given', () {
    const info = PlatformInfo(os: 'ios', arch: 'aarch64');

    expect(info.os, 'ios');
    expect(info.arch, 'aarch64');
  });
}
