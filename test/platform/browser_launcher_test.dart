// test/platform/browser_launcher_test.dart
import 'package:animeko_flutter/platform/browser_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'open() parses the url and delegates to the injected launch function',
    () async {
      Uri? capturedUri;
      final launcher = BrowserLauncher(
        launch: (uri) async {
          capturedUri = uri;
          return true;
        },
      );

      final result = await launcher.open(
        'https://bgm.tv/oauth/authorize?state=req-1',
      );

      expect(result, isTrue);
      expect(
        capturedUri,
        Uri.parse('https://bgm.tv/oauth/authorize?state=req-1'),
      );
    },
  );

  test('open() returns false when the launch function fails', () async {
    final launcher = BrowserLauncher(launch: (_) async => false);

    final result = await launcher.open('https://bgm.tv/x');

    expect(result, isFalse);
  });
}
