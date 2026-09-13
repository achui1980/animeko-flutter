// lib/ui/subject/subject_characters_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/subject_models.dart';
import '../../domain/subject/subject_detail_controller.dart';
import 'character_avatar.dart';

/// 「查看全部」角色列表。用 bottom sheet 而不是新路由 —— 详情页的三个
/// 「查看全部」都是 sheet，不新增 go_router 路由。
///
/// 复用 `subjectCharactersProvider`：横向行已经把数据拉过来了，sheet 打开
/// 时命中同一个 provider 缓存，不会再发一次请求。
class SubjectCharactersSheet extends ConsumerWidget {
  const SubjectCharactersSheet({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final characters =
        ref.watch(subjectCharactersProvider(subjectId: subjectId)).value ??
        const <RelatedCharacter>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('全部角色', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${characters.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: characters.length,
                itemBuilder: (context, index) {
                  final character = characters[index].character;
                  final actor = character.primaryActor;
                  return ListTile(
                    leading: CharacterAvatar(character: character, radius: 20),
                    title: Text(character.displayName),
                    subtitle: actor == null ? null : Text(actor.displayName),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
