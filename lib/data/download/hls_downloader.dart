import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

class HlsDownloadResult {
  const HlsDownloadResult(this.playlist, this.fileSizeBytes);

  final File playlist;
  final int fileSizeBytes;
}

class HlsDownloader {
  HlsDownloader(this._dio);

  final Dio _dio;

  Future<HlsDownloadResult> download({
    required Uri manifestUrl,
    required Directory targetDirectory,
    Map<String, String> headers = const {},
    void Function(int received, int total)? onProgress,
  }) async {
    await targetDirectory.create(recursive: true);
    var playlistUrl = manifestUrl;
    var playlistText = await _getText(playlistUrl, headers);
    final masterVariant = _firstMasterVariant(playlistText);
    if (masterVariant != null) {
      playlistUrl = playlistUrl.resolve(masterVariant);
      playlistText = await _getText(playlistUrl, headers);
    }

    final lines = playlistText.split(RegExp(r'\r?\n'));
    final output = List<String>.from(lines);
    final segmentLineIndexes = <int>[];
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].isNotEmpty && !lines[index].startsWith('#')) {
        segmentLineIndexes.add(index);
      }
    }

    var received = 0;
    for (var index = 0; index < segmentLineIndexes.length; index++) {
      final segment = File(
        p.join(
          targetDirectory.path,
          'segment_${index.toString().padLeft(4, '0')}.ts',
        ),
      );
      final lineIndex = segmentLineIndexes[index];
      await _dio.downloadUri(
        playlistUrl.resolve(lines[lineIndex]),
        segment.path,
        options: Options(headers: headers),
      );
      received += await segment.length();
      output[lineIndex] = segment.uri.pathSegments.last;
      onProgress?.call(received, 0);
    }

    final playlist = File(p.join(targetDirectory.path, 'playlist.m3u8'));
    await playlist.writeAsString(output.join('\n'));
    return HlsDownloadResult(playlist, received + await playlist.length());
  }

  Future<String> _getText(Uri url, Map<String, String> headers) async =>
      (await _dio.getUri<String>(
        url,
        options: Options(headers: headers),
      )).data!;

  String? _firstMasterVariant(String playlistText) {
    final lines = playlistText.split(RegExp(r'\r?\n'));
    for (var index = 0; index + 1 < lines.length; index++) {
      if (lines[index].startsWith('#EXT-X-STREAM-INF')) return lines[index + 1];
    }
    return null;
  }
}
