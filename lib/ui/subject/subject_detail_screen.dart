// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/subject/collection_type.dart';
import '../../domain/media/media_registry.dart';
import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/subject_collection_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../common/error_retry_view.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.imageUrl,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectEpisodesControllerProvider(
      subjectId: subjectId,
      subjectName: subjectName,
    );
    final episodes = ref.watch(provider);
    final sources = ref.watch(mediaSourcesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: ListView(
        children: [
          if (imageUrl != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(imageUrl!, fit: BoxFit.cover),
            ),
          _SubjectInfoSection(subjectId: subjectId),
          _CastStaffSection(subjectId: subjectId),
          const Divider(),
          ...episodes.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, stack) {
              if (error is MediaNotFoundException) {
                return const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('未找到该番剧的播放资源')),
                  ),
                ];
              }
              return [
                ErrorRetryView(
                  message: '加载失败：$error',
                  onRetry: () => ref.invalidate(provider),
                ),
              ];
            },
            data: (episodeList) => episodeList
                .map(
                  (episode) => ListTile(
                    title: Text(episode.title),
                    trailing: Chip(label: Text(_sourceLabel(sources, episode.sourceId))),
                    onTap: () => context.push(
                      '/subject/$subjectId/play',
                      extra: episode,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Summary/tags/score/rank + the collection-status buttons + the rating
/// input -- one section, since collection status and rating both read
/// from the same [SubjectCollectionController].
class _SubjectInfoSection extends ConsumerWidget {
  const _SubjectInfoSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectDetailControllerProvider(subjectId: subjectId);
    final detail = ref.watch(provider);

    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => ErrorRetryView(
        message: '加载详情失败：$error',
        onRetry: () => ref.invalidate(provider),
      ),
      data: (subject) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject.summary),
            const SizedBox(height: 8),
            if (subject.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: subject.tags
                    .map((tag) => Chip(label: Text('${tag.name} ${tag.count}')))
                    .toList(),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (subject.score != null) Text('评分：${subject.score}'),
                if (subject.rank != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('排名：#${subject.rank}'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _CollectionButtons(subjectId: subjectId),
            const SizedBox(height: 16),
            _RatingSection(subjectId: subjectId),
          ],
        ),
      ),
    );
  }
}

/// The 5 collection-status buttons + a "移除" (remove) button, shown
/// only when the subject is already collected. Tapping a button calls
/// [SubjectCollectionController]'s optimistic-update methods and shows a
/// one-off SnackBar on failure (the controller has already rolled back
/// its own state by the time the exception reaches here).
class _CollectionButtons extends ConsumerWidget {
  const _CollectionButtons({required this.subjectId});

  final int subjectId;

  static const _labels = {
    CollectionType.wish: '想看',
    CollectionType.doing: '在看',
    CollectionType.done: '看过',
    CollectionType.onHold: '搁置',
    CollectionType.dropped: '弃番',
  };

  Future<void> _setType(BuildContext context, WidgetRef ref, CollectionType type) async {
    try {
      await ref
          .read(subjectCollectionControllerProvider(subjectId: subjectId).notifier)
          .setCollectionType(type);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新收藏状态失败：$e')));
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(subjectCollectionControllerProvider(subjectId: subjectId).notifier)
          .removeFromCollection();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('取消收藏失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subjectCollectionControllerProvider(subjectId: subjectId));
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (collection) => Wrap(
        spacing: 8,
        children: [
          for (final type in CollectionType.values)
            ChoiceChip(
              label: Text(_labels[type]!),
              selected: collection.collectionType == type,
              onSelected: (_) => _setType(context, ref, type),
            ),
          if (collection.collectionType != null)
            ActionChip(label: const Text('移除'), onPressed: () => _remove(context, ref)),
        ],
      ),
    );
  }
}

/// The rating input -- collapsed to a single button/label showing the
/// current rating (if any) until tapped, then expands into a 1-10
/// slider + optional comment + privacy toggle + submit button. Local
/// UI state (expanded/score/comment/privacy) lives here, not in the
/// controller -- [SubjectCollectionController.submitRating] is
/// deliberately not optimistic (design doc "评分提交"), so on failure
/// this widget keeps the form open with the user's input intact.
class _RatingSection extends ConsumerStatefulWidget {
  const _RatingSection({required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends ConsumerState<_RatingSection> {
  bool _expanded = false;
  int _score = 5;
  bool _isPrivate = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      await ref
          .read(subjectCollectionControllerProvider(subjectId: widget.subjectId).notifier)
          .submitRating(
            _score,
            comment: _commentController.text.isEmpty ? null : _commentController.text,
            isPrivate: _isPrivate,
          );
      if (mounted) setState(() => _expanded = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评分已提交')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交评分失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subjectCollectionControllerProvider(subjectId: widget.subjectId));
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (collection) {
        if (!_expanded) {
          return TextButton(
            onPressed: () => setState(() {
              _score = collection.selfRating.score > 0 ? collection.selfRating.score : 5;
              _expanded = true;
            }),
            child: Text(
              collection.selfRating.score > 0 ? '我的评分：${collection.selfRating.score}' : '评分',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: _score.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_score',
              onChanged: (value) => setState(() => _score = value.round()),
            ),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(hintText: '评论（可选）'),
            ),
            SwitchListTile(
              title: const Text('仅自己可见'),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
            FilledButton(onPressed: _submit, child: const Text('提交')),
          ],
        );
      },
    );
  }
}

/// Two horizontal avatar rows (cast, then staff). Either row fails
/// silently (hides itself entirely) without affecting the other or
/// `_SubjectInfoSection` -- the design doc's "per-source silent
/// failure" pattern.
class _CastStaffSection extends ConsumerWidget {
  const _CastStaffSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(subjectCharactersProvider(subjectId: subjectId));
    final staff = ref.watch(subjectStaffProvider(subjectId: subjectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        characters.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : _AvatarRow(
                  title: '角色',
                  items: list.map((c) => (c.character.name, c.character.imageUrl)).toList(),
                ),
        ),
        staff.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : _AvatarRow(
                  title: '制作人员',
                  items: list.map((s) => (s.name, s.imageUrl)).toList(),
                ),
        ),
      ],
    );
  }
}

/// A titled horizontal-scroll row of circular avatars + names. No
/// tap-through to a person detail page (explicitly excluded, see the
/// design doc).
class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.title, required this.items});

  final String title;
  final List<(String, String?)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final (name, imageUrl) = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null ? const Icon(Icons.person) : null,
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Human-readable label for the merged-episode-list source badge
/// (Decision 6). Looks up the owning [MediaSource]'s [MediaSource.displayName]
/// so this stays in sync with the single source of truth instead of
/// re-deriving it from a hardcoded switch on `sourceId`. Falls back to the
/// raw `sourceId` for any `sourceId` with no matching registered source --
/// never crashes, just looks slightly less polished.
String _sourceLabel(List<MediaSource> sources, String sourceId) {
  for (final source in sources) {
    if (source.id == sourceId) return source.displayName;
  }
  return sourceId;
}
