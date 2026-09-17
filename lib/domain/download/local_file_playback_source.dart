import '../media/media_source.dart';

class LocalFilePlaybackSource extends MediaPlaybackSource {
  const LocalFilePlaybackSource(this.localPath);
  final String localPath;
  @override
  String get url => localPath;
  @override
  Map<String, String> get headers => const {};
  @override
  String get label => '本地下载';
}
