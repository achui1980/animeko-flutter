import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const defaultProbeTimeout = Duration(seconds: 4);
const _maxProbeBytes = 1024;

/// Concurrently fetches the head of each line's top-level m3u8 and returns
/// only the lines that answered 2xx with a body starting with `#EXTM3U`
/// within [timeout]. Original order is preserved; failures are dropped
/// silently. Does not follow variant playlists or fetch segments.
Future<List<T>> probeM3u8Lines<T>(
  List<T> lines, {
  required String Function(T line) urlOf,
  required Dio dio,
  Duration timeout = defaultProbeTimeout,
}) async {
  final alive = await Future.wait(
    lines.map((line) => _isLive(dio, urlOf(line), timeout)),
  );
  return [
    for (var i = 0; i < lines.length; i++)
      if (alive[i]) lines[i],
  ];
}

/// True when [head] (first bytes of a response) is an HLS playlist.
bool looksLikeM3u8(List<int> head) {
  var text = utf8.decode(head, allowMalformed: true);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return text.trimLeft().startsWith('#EXTM3U');
}

Future<bool> _isLive(Dio dio, String url, Duration timeout) async {
  final cancel = CancelToken();
  try {
    return await _readHead(dio, url, cancel).timeout(timeout);
  } catch (_) {
    return false;
  } finally {
    if (!cancel.isCancelled) cancel.cancel();
  }
}

Future<bool> _readHead(Dio dio, String url, CancelToken cancel) async {
  final response = await dio.get<ResponseBody>(
    url,
    cancelToken: cancel,
    options: Options(
      responseType: ResponseType.stream,
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  );
  final body = response.data;
  if (body == null) return false;
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in body.stream) {
    bytes.add(chunk);
    if (bytes.length >= _maxProbeBytes) break;
  }
  return looksLikeM3u8(bytes.takeBytes());
}
