import 'package:animeko_flutter/domain/download/local_file_playback_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not send HTTP headers for a local file', () {
    const source = LocalFilePlaybackSource('/offline/video.mp4');

    expect(source.url, '/offline/video.mp4');
    expect(source.headers, isEmpty);
    expect(source.label, '本地下载');
  });
}
