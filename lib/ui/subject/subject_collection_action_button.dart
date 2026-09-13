// lib/ui/subject/subject_collection_action_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/collection_type.dart';
import '../../domain/subject/subject_collection_controller.dart';

/// 收藏状态控件：未收藏时是单个「＋ 追番」主按钮（一键置为
/// [CollectionType.wish]）；已收藏时是「★ <当前状态> ▾」，点开是一个
/// [PopupMenuButton]，列出其余四个状态和「移除」。
///
/// 取代改版前平铺的 5 个 [ChoiceChip]（旧 `_CollectionButtons`）。菜单项
/// 的泛型是 `CollectionType?`，`null` 代表「移除」，这样 `onSelected` 只
/// 需要一个分支判断，不必额外定义一个 sealed 的动作类型。但注意
/// [PopupMenuButton] 把 `null` 的返回值当成「菜单被取消」交给
/// `onCanceled`、并不会传给 `onSelected`（framework `popup_menu.dart` 里
/// `showMenu(...)` 的 `.then`），所以「移除」实际是由它那一项自己的
/// `onTap` 分发的。
///
/// 乐观更新/回滚与失败重试都由
/// [SubjectCollectionController.setCollectionType] 负责，本控件只负责在
/// 请求进行中禁用交互（[_busy]）并把失败呈现为一次性 [SnackBar]。
class SubjectCollectionActionButton extends ConsumerStatefulWidget {
  const SubjectCollectionActionButton({
    super.key,
    required this.subjectId,
    this.imageUrl,
  });

  final int subjectId;

  /// 封面图地址（来自路由 query 参数）。传入时会在收藏成功后写入本地封面
  /// 缓存，供「我的收藏」列表使用——收藏列表接口本身不返回封面。
  final String? imageUrl;

  @override
  ConsumerState<SubjectCollectionActionButton> createState() =>
      _SubjectCollectionActionButtonState();
}

class _SubjectCollectionActionButtonState
    extends ConsumerState<SubjectCollectionActionButton> {
  static const Map<CollectionType, String> labels = {
    CollectionType.wish: '想看',
    CollectionType.doing: '在看',
    CollectionType.done: '看过',
    CollectionType.onHold: '搁置',
    CollectionType.dropped: '弃番',
  };

  bool _busy = false;

  Future<void> _setType(CollectionType type) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(
            subjectCollectionControllerProvider(
              subjectId: widget.subjectId,
            ).notifier,
          )
          .setCollectionType(type, imageUrl: widget.imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新收藏状态失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(
            subjectCollectionControllerProvider(
              subjectId: widget.subjectId,
            ).notifier,
          )
          .removeFromCollection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消收藏失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(
      subjectCollectionControllerProvider(subjectId: widget.subjectId),
    );
    final collection = collectionAsync.value;
    if (collection == null) return const SizedBox.shrink();

    final current = collection.collectionType;
    if (current == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: _busy ? null : () => _setType(CollectionType.wish),
          icon: const Icon(Icons.add),
          label: const Text('追番'),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: PopupMenuButton<CollectionType?>(
        enabled: !_busy,
        tooltip: '修改收藏状态',
        position: PopupMenuPosition.under,
        // 这里只可能收到非 null 值：[PopupMenuButton] 把 `null` 的返回值当作
        // 「菜单被取消」处理（framework `popup_menu.dart` 里 `showMenu(...)`
        // 的 `.then` 对 `newValue == null` 直接调 `onCanceled` 并 return），
        // 所以「移除」不能挂在这里的 `null` 分支上，改由该菜单项自己的
        // `onTap` 触发 [_remove]。
        onSelected: (value) {
          if (value != null) _setType(value);
        },
        itemBuilder: (context) => [
          for (final type in CollectionType.values)
            if (type != current)
              PopupMenuItem<CollectionType?>(
                value: type,
                child: Text(labels[type]!),
              ),
          const PopupMenuDivider(),
          PopupMenuItem<CollectionType?>(
            value: null,
            onTap: _remove,
            child: const Text('移除'),
          ),
        ],
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                labels[current]!,
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
