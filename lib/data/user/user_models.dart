// lib/data/user/user_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'user_models.g.dart';

/// The current user's own profile. Verified against the real
/// `AniAniSelfUser` model (Kotlin generated client
/// `models/AniAniSelfUser.kt`) -- see the design doc's "数据与 API
/// 变更" section. Returned by `GET /v1/me`.
@JsonSerializable()
class SelfUser {
  const SelfUser({
    required this.id,
    required this.nickname,
    required this.hasPassword,
    required this.isBangumiSessionValid,
    this.email,
    this.smallAvatar,
    this.mediumAvatar,
    this.largeAvatar,
    this.registerTime,
    this.lastLoginTime,
    this.clientVersion,
    this.bangumiUsername,
  });

  final String id;
  final String nickname;
  final bool hasPassword;
  final bool isBangumiSessionValid;
  final String? email;
  final String? smallAvatar;
  final String? mediumAvatar;
  final String? largeAvatar;
  final int? registerTime;
  final int? lastLoginTime;
  final String? clientVersion;
  final String? bangumiUsername;

  factory SelfUser.fromJson(Map<String, dynamic> json) => _$SelfUserFromJson(json);

  Map<String, dynamic> toJson() => _$SelfUserToJson(this);
}
