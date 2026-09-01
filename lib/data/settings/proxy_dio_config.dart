// lib/data/settings/proxy_dio_config.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/settings/proxy_settings_controller.dart';

/// Pure decision function for [HttpClient.findProxy]. Kept separate from
/// [configureProxy] so it can be unit-tested without a real [HttpClient] --
/// see the design doc's "测试策略" section.
///
/// Returns `'DIRECT'` when [proxyUrl] is null, empty, or malformed (falling
/// back to a direct connection rather than throwing), or a `'PROXY
/// host:port'` directive for a well-formed URL.
String decideProxy(String? proxyUrl) {
  if (proxyUrl == null || proxyUrl.isEmpty) return 'DIRECT';

  final proxyUri = Uri.tryParse(proxyUrl);
  // Note: `Uri.port` defaults to the scheme's default port (e.g. 80 for
  // http) when no port is specified in the URL -- it is never `0` for a
  // successfully-parsed http URI. So `proxyUri.port == 0` would NOT detect
  // a missing port here; `!proxyUri.hasPort` is the correct check (mirrors
  // `validateProxyUrl` in proxy_settings_controller.dart).
  if (proxyUri == null || proxyUri.host.isEmpty || !proxyUri.hasPort) {
    return 'DIRECT';
  }
  return 'PROXY ${proxyUri.host}:${proxyUri.port}';
}

/// Configures [dio]'s underlying [HttpClient] to route through whatever
/// proxy is currently set in [ProxySettingsController], if any. Call this
/// once per [Dio] instance during provider construction -- the installed
/// `findProxy` closure re-reads [proxySettingsControllerProvider] on every
/// request, so changing the setting takes effect on the very next request
/// with no need to rebuild the [Dio] instance or restart the app.
void configureProxy(Dio dio, Ref ref) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) =>
          decideProxy(ref.read(proxySettingsControllerProvider).value);
      return client;
    },
  );
}
