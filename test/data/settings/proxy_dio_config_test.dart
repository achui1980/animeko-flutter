import 'package:animeko_flutter/data/settings/proxy_dio_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decideProxy', () {
    test('returns DIRECT when proxyUrl is null', () {
      expect(decideProxy(null), 'DIRECT');
    });

    test('returns DIRECT when proxyUrl is empty', () {
      expect(decideProxy(''), 'DIRECT');
    });

    test('returns a PROXY directive for a valid http:// URL', () {
      expect(decideProxy('http://127.0.0.1:2222'), 'PROXY 127.0.0.1:2222');
    });

    test('returns DIRECT for a malformed proxyUrl', () {
      expect(decideProxy('not a url'), 'DIRECT');
    });

    test('returns DIRECT when the URL has no explicit port', () {
      // Regression guard: `Uri.port` defaults to 80 for http URLs with no
      // explicit port, it is never 0 -- so a naive `uri.port == 0` check
      // would silently treat this as `PROXY 127.0.0.1:80` instead of
      // rejecting it. Must use `!uri.hasPort` instead.
      expect(decideProxy('http://127.0.0.1'), 'DIRECT');
    });
  });
}
