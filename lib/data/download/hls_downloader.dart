import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

class HlsDownloadResult {
  const HlsDownloadResult(this.playlist, this.fileSizeBytes);

  final File playlist;
  final int fileSizeBytes;
}

final _keyUriPattern = RegExp(r'URI="([^"]*)"');

/// Downloads the AES-128 key referenced by a `#EXT-X-KEY` line (if any)
/// and returns the rewritten line pointing at the local key file, or
/// `null` if [line] isn't a `#EXT-X-KEY` line or has no `URI=` attribute.
///
/// OmoFun's HLS streams are AES-128 encrypted with a fixed all-zero IV
/// (confirmed by hand against a live stream during design -- the key
/// never rotates, so a downloaded key stays valid for the episode's
/// full runtime). `METHOD=`/`IV=` attributes are preserved verbatim;
/// only `URI=` is rewritten, so decryption still works against the
/// locally saved key file.
Future<String?> _rewriteKeyLine(
  String line,
  Uri playlistUrl,
  Map<String, String> headers,
  Directory targetDirectory,
  Dio dio,
) async {
  if (!line.startsWith('#EXT-X-KEY')) return null;
  final match = _keyUriPattern.firstMatch(line);
  if (match == null) return null;
  final keyUri = playlistUrl.resolve(match.group(1)!);
  final keyFile = File('${targetDirectory.path}/key_0000.key');
  final alreadyDownloaded =
      await keyFile.exists() && await keyFile.length() > 0;
  if (!alreadyDownloaded) {
    await dio.downloadUri(
      keyUri,
      keyFile.path,
      options: Options(headers: headers),
    );
  }
  return line.replaceFirst(_keyUriPattern, 'URI="key_0000.key"');
}

class HlsDownloader {
  HlsDownloader(this._dio);

  final Dio _dio;

  Future<HlsDownloadResult> download({
    required Uri manifestUrl,
    required Directory targetDirectory,
    Map<String, String> headers = const {},
    CancelToken? cancelToken,
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
    for (var index = 0; index < output.length; index++) {
      final rewritten = await _rewriteKeyLine(
        output[index],
        playlistUrl,
        headers,
        targetDirectory,
        _dio,
      );
      if (rewritten != null) output[index] = rewritten;
    }
    final segmentLineIndexes = <int>[];
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].isNotEmpty && !lines[index].startsWith('#')) {
        segmentLineIndexes.add(index);
      }
    }

    final totalSegments = segmentLineIndexes.length;
    var downloadedSegments = 0;
    var totalBytes = 0;
    onProgress?.call(downloadedSegments, totalSegments);
    for (var index = 0; index < segmentLineIndexes.length; index++) {
      final segment = File(
        p.join(
          targetDirectory.path,
          'segment_${index.toString().padLeft(4, '0')}.ts',
        ),
      );
      final lineIndex = segmentLineIndexes[index];
      final alreadyDownloaded =
          segment.existsSync() && segment.lengthSync() > 0;
      if (!alreadyDownloaded) {
        await _dio.downloadUri(
          playlistUrl.resolve(lines[lineIndex]),
          segment.path,
          cancelToken: cancelToken,
          options: Options(headers: headers),
        );
      }
      totalBytes += await segment.length();
      output[lineIndex] = segment.uri.pathSegments.last;
      downloadedSegments++;
      onProgress?.call(downloadedSegments, totalSegments);
    }

    final playlist = File(p.join(targetDirectory.path, 'playlist.m3u8'));
    await playlist.writeAsString(output.join('\n'));
    return HlsDownloadResult(playlist, totalBytes + await playlist.length());
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
