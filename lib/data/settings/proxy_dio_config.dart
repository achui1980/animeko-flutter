// lib/data/settings/proxy_dio_config.dart
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/settings/proxy_settings_controller.dart';

/// Pure decision function for [HttpClient.findProxy]. Kept separate from
/// [ProxyHttpOverrides] so it can be unit-tested without a real [HttpClient]
/// -- see the design doc's "测试策略" section.
///
/// Returns `'DIRECT'` when [proxyUrl] is null, empty, or malformed (falling
/// back to a direct connection rather than throwing), or a `'PROXY
/// host:port'` directive for a well-formed URL.
///
/// [requestUri], when given, is the URL being requested. Requests to a
/// loopback address are always `'DIRECT'`: the rqbit sidecar's HTTP API and
/// the local stream URLs it hands to the player live on `127.0.0.1`, and
/// sending those through an external proxy would break playback.
String decideProxy(String? proxyUrl, {Uri? requestUri}) {
  if (proxyUrl == null || proxyUrl.isEmpty) return 'DIRECT';
  if (requestUri != null && _isLoopbackHost(requestUri.host)) return 'DIRECT';

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

/// `Uri.host` strips the brackets from IPv6 literals, so `[::1]` arrives here
/// as `::1` and parses fine. `InternetAddress.isLoopback` covers the whole
/// `127.0.0.0/8` range, not just `127.0.0.1`.
bool _isLoopbackHost(String host) {
  if (host.isEmpty) return false;
  if (host == 'localhost') return true;
  return InternetAddress.tryParse(host)?.isLoopback ?? false;
}

/// Reads the currently configured proxy URL, or null for a direct connection.
typedef ProxyUrlReader = String? Function();

/// Routes every [HttpClient] created in this process through the user's
/// configured proxy.
///
/// `HttpClient()` (the factory constructor) delegates to
/// `HttpOverrides.current`, so installing this as [HttpOverrides.global]
/// covers *every* HTTP client in the app without each call site having to
/// opt in: all `dio` instances (whose default `IOHttpClientAdapter` builds
/// its client with a bare `HttpClient()`), the un-intercepted `rawAniDio()`
/// used by `SessionRefresher` for token refreshes, and Flutter's own shared
/// client behind `Image.network`/`NetworkImage` for cover art.
///
/// It also avoids the lifecycle hazard of the previous per-`Dio` approach,
/// which captured the *dio provider's* `Ref` inside the `findProxy` closure:
/// every dio provider is autoDispose, so a `Dio` outliving its provider
/// element (e.g. a `TorrentPlaybackSource` still holding `mikanRssDio`) made
/// that read throw `UnmountedRefException` from deep inside dart:io,
/// surfacing as an opaque connection failure.
///
/// [ProxyUrlReader] is re-read on every request, so changing the setting
/// takes effect on the next request with no need to rebuild any client.
class ProxyHttpOverrides extends HttpOverrides {
  ProxyHttpOverrides(
    this._readProxyUrl, {
    HttpClient Function(SecurityContext? context)? createClient,
  }) : _createClient = createClient;

  final ProxyUrlReader _readProxyUrl;

  /// Test seam: lets a test observe the client that gets configured.
  /// Production uses `super.createHttpClient`, i.e. dart:io's real client
  /// (calling `HttpClient()` here would re-enter this override forever).
  final HttpClient Function(SecurityContext? context)? _createClient;

  /// The `findProxy` directive for a request to [requestUri].
  String proxyDirectiveFor(Uri requestUri) =>
      decideProxy(_readProxyUrl(), requestUri: requestUri);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client =
        _createClient?.call(context) ?? super.createHttpClient(context);
    client.findProxy = proxyDirectiveFor;
    return client;
  }
}

/// Installs [ProxyHttpOverrides] process-wide, backed by [container]'s
/// [proxySettingsControllerProvider].
///
/// Call this from `main()` before any HTTP request is made. Reading from the
/// container (rather than from a provider's `Ref`) is safe for the lifetime
/// of the app because that provider is `keepAlive`, so the read never
/// re-mounts a fresh `AsyncLoading` element and never sees a null value once
/// `main()` has pre-warmed it.
void installProxyHttpOverrides(ProviderContainer container) {
  HttpOverrides.global = ProxyHttpOverrides(
    () => container.read(proxySettingsControllerProvider).value,
  );
}
