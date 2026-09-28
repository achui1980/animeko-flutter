import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Routes requests by full URL. Unknown URLs fail like an unreachable host.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  final Map<String, Future<ResponseBody> Function()> routes;
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    final route = routes[url];
    if (route == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'unreachable in test',
      );
    }
    return route();
  }

  @override
  void close({bool force = false}) {}
}

Future<ResponseBody> Function() respond(String body, [int status = 200]) =>
    () async => ResponseBody.fromString(body, status);
