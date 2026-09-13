// lib/ui/subject/character_avatar.dart

import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';

/// 圆形角色头像，缺图或加载失败时退回一个人形占位图标。
///
/// 后端返回的是 `imageMedium` / `imageLarge` 两个字段（不存在 `imageUrl`，
/// 见 [CharacterInfo] 的文档注释）。这里优先用 `imageMedium`：设计文档
/// `2026-09-12-subject-detail-three-column-layout-design.md` 的「修
/// `CharacterInfo`」一节写的是「头像用 `imageMedium`（横向头像行只有 64px
/// 直径，不需要 large）」—— 默认 [radius] 32 正好是那个 64。
///
/// 加载失败退占位图标同样出自设计文档，「加载 / 错误 / 空态」一节：「封面 /
/// 角色头像 / 评价者头像 加载失败 → 占位图标」。所以这是个
/// [StatefulWidget]：`CircleAvatar.backgroundImage` 没有 `errorBuilder`，
/// 想换成占位图标只能靠 `onBackgroundImageError` 回调 + `setState`。
/// 这个回调还必须给：不接它时加载失败会把异常抛到 `FlutterError`，在 widget
/// 测试里会直接把测试判成失败。
///
/// 注意 `CircleAvatar` 把 `child` 画在 `backgroundImage` **之上**，所以占位
/// 图标只能在没有可用 URL 时才渲染，不能无条件塞进 `child`。
class CharacterAvatar extends StatefulWidget {
  const CharacterAvatar({super.key, required this.character, this.radius = 32});

  final CharacterInfo character;
  final double radius;

  @override
  State<CharacterAvatar> createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar> {
  /// 已经加载失败过的那张图的 URL。记 URL 而不是一个 bool，是因为横向行的
  /// cell 没有 key：Flutter 会把这个 [State] 复用到同一位置的另一个角色上，
  /// 存 bool 会把上一个角色的失败状态带过去，让新角色也只显示占位图标。
  String? _failedUrl;

  @override
  Widget build(BuildContext context) {
    final source = widget.character.imageMedium ?? widget.character.imageLarge;
    final url = source == _failedUrl ? null : source;
    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: url == null ? null : NetworkImage(url),
      onBackgroundImageError: url == null
          ? null
          // 图片流是异步回调的，widget 可能已经被移除了 —— 不加 `mounted`
          // 守卫就是一个 `setState() called after dispose` 崩溃。
          : (_, _) {
              if (mounted) setState(() => _failedUrl = url);
            },
      child: url == null ? Icon(Icons.person, size: widget.radius) : null,
    );
  }
}
