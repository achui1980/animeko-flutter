// lib/ui/subject/subject_character_row.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/subject_models.dart';
import '../../domain/subject/subject_detail_controller.dart';
import 'character_avatar.dart';
import 'subject_characters_sheet.dart';

/// 中栏的「角色」横向头像行：头像 + 角色名 + 声优名。
///
/// 加载中时渲染带标题的外框 + 一个小 spinner（不是整块隐藏），这样数据到
/// 位时页面不会跳动 —— 见设计文档
/// `2026-09-12-subject-detail-three-column-layout-design.md` 的
/// 「加载 / 错误 / 空态」一节。失败和空列表都整块静默隐藏：角色不是详情页
/// 的主线信息，缺了不该显示报错。
class SubjectCharacterRow extends ConsumerWidget {
  const SubjectCharacterRow({super.key, required this.subjectId});

  /// 行内最多显示多少个角色，其余交给「查看全部」sheet。
  ///
  /// 12 是本计划引入的估算值：设计文档的「已知的估算项」一节里没有它，别处
  /// 也没有规定这个数，所以调它不需要改设计文档。全量渲染不可行 —— 设计文档
  /// 「后端接口实测结果」一节记录 subject 302286 的 characters 接口返回
  /// 104 项。
  static const int maxVisible = 12;

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subjectCharactersProvider(subjectId: subjectId));
    final characters = async.value;

    if (characters == null) {
      if (async.isLoading) {
        return _frame(
          context,
          child: const SizedBox(
            height: 96,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    if (characters.isEmpty) return const SizedBox.shrink();

    return _frame(
      context,
      onSeeAll: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SubjectCharactersSheet(subjectId: subjectId),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final related in characters.take(maxVisible))
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _CharacterCell(character: related.character),
              ),
          ],
        ),
      ),
    );
  }

  Widget _frame(
    BuildContext context, {
    required Widget child,
    VoidCallback? onSeeAll,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('角色', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (onSeeAll != null)
                TextButton(onPressed: onSeeAll, child: const Text('查看全部 ›')),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CharacterCell extends StatelessWidget {
  const _CharacterCell({required this.character});

  final CharacterInfo character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = character.primaryActor;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          CharacterAvatar(character: character),
          const SizedBox(height: 4),
          Text(
            character.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (actor != null)
            Text(
              actor.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
