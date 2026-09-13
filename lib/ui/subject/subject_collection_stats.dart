// lib/ui/subject/subject_collection_stats.dart

import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';

/// 把整数格式化成带千分位逗号的字符串（`7781` -> `'7,781'`）。
///
/// 手写而不用 `intl`：本项目 `pubspec.yaml` 里没有 `intl` 依赖，而这里只
/// 需要最朴素的三位分组，不需要 locale 相关的数字格式。
String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

/// 左栏的收藏统计三联块：`收藏 / 在看 / 想看`。
///
/// 字段映射（spec「收藏统计的字段映射」）：收藏 = [SubjectFavorite.done]、
/// 在看 = [SubjectFavorite.doing]、想看 = [SubjectFavorite.wish]。
/// `onHold`/`dropped` 拿得到但不展示——设计文档那一节的映射表只列了这三项，
/// 给出的理由是「`favorite` 有 5 个数字，参考图只显示 3 个」。
///
/// 「收藏 = `done`」目前仍是暂定的：设计文档同一节要求「实施时用一个真实
/// subject 与 Bangumi 网页上的数字对照一次，确认「收藏」确实对应 `done`
/// 而不是五项求和」，这次核对挂在 plan 的 Task 25 Step 5 第 8 项；若网页的
/// 「收藏」等于五项之和，这里要改成五项求和，
/// `test/ui/subject/subject_collection_stats_test.dart` 的期望值也要跟着改。
///
/// [favorite] 为 `null`（接口没返回 `favorite`）时整块隐藏，而不是显示
/// 三个 `0`。
class SubjectCollectionStats extends StatelessWidget {
  const SubjectCollectionStats({super.key, required this.favorite});

  final SubjectFavorite? favorite;

  @override
  Widget build(BuildContext context) {
    final favorite = this.favorite;
    if (favorite == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(value: favorite.done, label: '收藏'),
        _StatItem(value: favorite.doing, label: '在看'),
        _StatItem(value: favorite.wish, label: '想看'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          formatCount(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
