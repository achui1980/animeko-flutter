// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SelfUser _$SelfUserFromJson(Map<String, dynamic> json) => SelfUser(
  id: json['id'] as String,
  nickname: json['nickname'] as String,
  hasPassword: json['hasPassword'] as bool,
  isBangumiSessionValid: json['isBangumiSessionValid'] as bool,
  email: json['email'] as String?,
  smallAvatar: json['smallAvatar'] as String?,
  mediumAvatar: json['mediumAvatar'] as String?,
  largeAvatar: json['largeAvatar'] as String?,
  registerTime: (json['registerTime'] as num?)?.toInt(),
  lastLoginTime: (json['lastLoginTime'] as num?)?.toInt(),
  clientVersion: json['clientVersion'] as String?,
  bangumiUsername: json['bangumiUsername'] as String?,
);

Map<String, dynamic> _$SelfUserToJson(SelfUser instance) => <String, dynamic>{
  'id': instance.id,
  'nickname': instance.nickname,
  'hasPassword': instance.hasPassword,
  'isBangumiSessionValid': instance.isBangumiSessionValid,
  'email': instance.email,
  'smallAvatar': instance.smallAvatar,
  'mediumAvatar': instance.mediumAvatar,
  'largeAvatar': instance.largeAvatar,
  'registerTime': instance.registerTime,
  'lastLoginTime': instance.lastLoginTime,
  'clientVersion': instance.clientVersion,
  'bangumiUsername': instance.bangumiUsername,
};
