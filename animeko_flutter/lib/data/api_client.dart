// lib/data/api_client.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_client.g.dart';

/// Single fixed ani-api-server endpoint for Phase 1. No failover to
/// alternate servers (danmaku-cn/danmaku-global/s1-animeko) is implemented
/// — see design doc "本地持久化"/服务器地址处理 note under Phase 1 scope.
const aniApiBaseUrl = 'https://api.animeko.org';

@riverpod
Dio dio(Ref ref) {
  return Dio(BaseOptions(baseUrl: aniApiBaseUrl));
}
