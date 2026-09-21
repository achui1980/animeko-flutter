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
/// 角色头像 / 评价者头像 加载失败 → 占位图标」。
///
/// **裁切必须对齐顶部。** Bangumi 的角色图是竖构图立绘：`imageMedium` 只是把
/// `large` 按比例缩到宽 400，实测同一部作品里就有 400x533 / 400x623 /
/// 400x1139 / 400x1164，长宽比从 1:1.3 一直到 1:2.9。用 [BoxFit.cover] 配默认
/// 的居中对齐时，圆形窗口取的是缩放后图片正中间那一条，落在衣服或腿上 ——
/// 整行头像会变成一排布料而不是脸。所以这里用
/// `alignment: Alignment.topCenter` 取顶部那一条。
///
/// 这也是为什么不能用 `CircleAvatar`：它内部自己拼 `DecorationImage`，不暴露
/// `alignment`，也没有 `errorBuilder`。换成 `ClipOval` + [Image.network] 之后
/// 两个问题一起解决 —— `errorBuilder` 直接就能渲染占位图标，不再需要
/// `onBackgroundImageError` + `setState` 去记「这张图挂了」，于是这个 widget
/// 也不用再是 [StatefulWidget]（顺带消掉了一个坑：横向行的 cell 没有 key，
/// Flutter 会把 [State] 复用到同一位置的另一个角色上）。
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({super.key, required this.character, this.radius = 32});

  final CharacterInfo character;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = character.imageMedium ?? character.imageLarge;
    final diameter = radius * 2;
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: url == null
            ? _placeholder(context)
            : Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, _, _) => _placeholder(context),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(child: Icon(Icons.person, size: radius)),
  );
}
