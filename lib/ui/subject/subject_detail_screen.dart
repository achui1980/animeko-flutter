// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_models.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/subject_bangumi_episodes_controller.dart';
import '../../domain/subject/subject_collection_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../common/error_retry_view.dart';
import '../common/rating_stars.dart';
import 'bangumi_episode_grid.dart';
import 'episode_playback_sheet.dart';
import 'expandable_summary.dart';
import 'subject_blurred_header.dart';
import 'subject_tags_row.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: ListView(
        children: [
          if (imageUrl != null)
            _ImmersiveHeader(subjectId: subjectId, imageUrl: imageUrl!),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WorkInfoSection(subjectId: subjectId),
                      _SubjectInfoSection(subjectId: subjectId),
                      _BangumiEpisodesSection(
                        subjectId: subjectId,
                        subjectName: subjectName,
                      ),
                      _CharacterSection(subjectId: subjectId),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _StaffSection(subjectId: subjectId)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Bangumi-canonical episode-number grid, replacing the old single
/// "开始观看" button. Sits directly after the immersive header and
/// before [_SubjectInfoSection] (design doc Section 1). Tapping a
/// number opens [EpisodePlaybackSheet] for that one episode -- see
/// Section 3.
class _BangumiEpisodesSection extends ConsumerWidget {
  const _BangumiEpisodesSection({
    required this.subjectId,
    required this.subjectName,
  });

  final int subjectId;
  final String subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bangumiProvider = subjectBangumiEpisodesControllerProvider(
      subjectId: subjectId,
    );
    final bangumiEpisodes = ref.watch(bangumiProvider);
    final mergedEpisodesAsync = ref.watch(
      subjectEpisodesControllerProvider(
        subjectId: subjectId,
        subjectName: subjectName,
      ),
    );

    return bangumiEpisodes.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => ErrorRetryView(
        message: '加载剧集列表失败：$error',
        onRetry: () => ref.invalidate(bangumiProvider),
      ),
      data: (episodes) {
        if (episodes.isEmpty) return const SizedBox.shrink();
        return BangumiEpisodeGrid(
          episodes: episodes,
          mergedEpisodesAsync: mergedEpisodesAsync,
          onEpisodeTap: (ordinalIndex, episode) => showModalBottomSheet(
            context: context,
            builder: (_) => EpisodePlaybackSheet(
              subjectId: subjectId,
              subjectName: subjectName,
              ordinalIndex: ordinalIndex,
              bangumiEpisode: episode,
            ),
          ),
        );
      },
    );
  }
}

/// New "作品信息" (work info) block: shows the subject's broadcast
/// start date, episode count, aliases, and tags. Combines data from two
/// independent providers (`subjectDetailControllerProvider` for
/// airDate/aliases/tags, `subjectBangumiEpisodesControllerProvider` for
/// the episode count) -- if either hasn't resolved yet, the
/// corresponding line is simply omitted rather than shown as a loading
/// placeholder, since this is a low-priority informational block.
class _WorkInfoSection extends ConsumerWidget {
  const _WorkInfoSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      subjectDetailControllerProvider(subjectId: subjectId),
    );
    final episodesAsync = ref.watch(
      subjectBangumiEpisodesControllerProvider(subjectId: subjectId),
    );

    return detailAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (subject) {
        final airDateLabel = _formatAirDateYearMonth(subject.airDate);
        final episodeCount = episodesAsync.value?.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('作品信息', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (airDateLabel != null) Text('放送开始：$airDateLabel'),
              if (episodeCount != null) Text('话数：$episodeCount'),
              if (subject.aliases.isNotEmpty)
                Text('别名：${subject.aliases.join(' / ')}'),
              const SizedBox(height: 8),
              SubjectTagsRow(tags: subject.tags),
            ],
          ),
        );
      },
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
            ExpandableSummary(text: subject.summary),
            const SizedBox(height: 16),
            _RatingSection(subjectId: subjectId),
          ],
        ),
      ),
    );
  }
}

/// The subject's title/rating stars/collection buttons, overlaid inside
/// [SubjectBlurredHeader]'s bottom area next to the sharp foreground
/// thumbnail -- mirroring Kazumi's `bangumi_info_card.dart`, which
/// bundles this same information inside its header card rather than
/// leaving it to a separate section below. Renders just the plain
/// header (no info overlay) while the subject is still loading or
/// failed to load, since there's nothing meaningful to show yet.
class _ImmersiveHeader extends ConsumerWidget {
  const _ImmersiveHeader({required this.subjectId, required this.imageUrl});

  final int subjectId;
  final String imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectDetailControllerProvider(subjectId: subjectId);
    final detail = ref.watch(provider);
    return SubjectBlurredHeader(
      imageUrl: imageUrl,
      info: detail.maybeWhen(
        data: (subject) => _HeaderInfo(subjectId: subjectId, subject: subject),
        orElse: () => null,
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.subjectId, required this.subject});

  final int subjectId;
  final SubjectDetail subject;

  @override
  Widget build(BuildContext context) {
    final score = subject.score != null
        ? double.tryParse(subject.score!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (score != null || subject.rank != null)
          Row(
            children: [
              if (score != null) RatingStars(score: score),
              if (subject.rank != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '排名：#${subject.rank}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        _CollectionButtons(subjectId: subjectId),
      ],
    );
  }
}

/// Formats [airDate] (e.g. `"2023-09-29"`) as `"2023年9月"` for the
/// header's metadata row (design doc Section 5: year-month
/// granularity, not a full date). Returns null for an empty/unparsable
/// date so the caller can omit the whole element rather than showing a
/// blank `"· "`.
String? _formatAirDateYearMonth(String airDate) {
  final date = DateTime.tryParse(airDate);
  if (date == null) return null;
  return '${date.year}年${date.month}月';
}

/// The 5 collection-status buttons + a "移除" (remove) button, shown
/// only when the subject is already collected. Tapping a button calls
/// [SubjectCollectionController]'s optimistic-update methods and shows a
/// one-off SnackBar on failure (the controller has already rolled back
/// its own state by the time the exception reaches here).
///
/// Disables all chips while a mutation is in flight (local `_busy`
/// flag) so two overlapping taps can't race -- the controller itself
/// has no mutex, so without this guard a second tap's optimistic update
/// could be stomped by the first tap's failure-triggered rollback.
class _CollectionButtons extends ConsumerStatefulWidget {
  const _CollectionButtons({required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<_CollectionButtons> createState() => _CollectionButtonsState();
}

class _CollectionButtonsState extends ConsumerState<_CollectionButtons> {
  bool _busy = false;

  static const _labels = {
    CollectionType.wish: '想看',
    CollectionType.doing: '在看',
    CollectionType.done: '看过',
    CollectionType.onHold: '搁置',
    CollectionType.dropped: '弃番',
  };

  Future<void> _setType(CollectionType type) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(
            subjectCollectionControllerProvider(
              subjectId: widget.subjectId,
            ).notifier,
          )
          .setCollectionType(type);
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
    final state = ref.watch(
      subjectCollectionControllerProvider(subjectId: widget.subjectId),
    );
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
              onSelected: _busy ? null : (_) => _setType(type),
            ),
          if (collection.collectionType != null)
            ActionChip(
              label: const Text('移除'),
              onPressed: _busy ? null : _remove,
            ),
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
          .read(
            subjectCollectionControllerProvider(
              subjectId: widget.subjectId,
            ).notifier,
          )
          .submitRating(
            _score,
            comment: _commentController.text.isEmpty
                ? null
                : _commentController.text,
            isPrivate: _isPrivate,
          );
      if (mounted) setState(() => _expanded = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('评分已提交')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('提交评分失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      subjectCollectionControllerProvider(subjectId: widget.subjectId),
    );
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (collection) {
        if (!_expanded) {
          return TextButton(
            onPressed: () => setState(() {
              _score = collection.selfRating.score > 0
                  ? collection.selfRating.score
                  : 5;
              _expanded = true;
            }),
            child: Text(
              collection.selfRating.score > 0
                  ? '我的评分：${collection.selfRating.score}'
                  : '评分',
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

/// Horizontal, scrollable row of character avatars, matching the
/// Animeko reference layout. Deliberately renders the character name
/// ONLY -- there is no voice-actor/CV field anywhere on
/// [CharacterInfo]/[RelatedCharacter] today, so a CV line (present in
/// the reference screenshot) cannot be shown without adding a new,
/// unconfirmed API field, which is out of scope for this pass. The
/// "查看全部" text is a static label with no navigation/expand
/// behavior, per the approved design.
class _CharacterSection extends ConsumerWidget {
  const _CharacterSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charactersAsync = ref.watch(
      subjectCharactersProvider(subjectId: subjectId),
    );

    return charactersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (characters) {
        if (characters.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('角色', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final related in characters)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage:
                                  related.character.imageUrl != null
                                  ? NetworkImage(related.character.imageUrl!)
                                  : null,
                              child: related.character.imageUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 72,
                              child: Text(
                                related.character.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Right-column "制作人员" (staff) table: a flat, two-column
/// key/value list of every (role, name) pair from the API response, in
/// original order. Deliberately NOT deduplicated by role -- if two
/// staff members share the same role (e.g. two "音乐" credits), both
/// render as separate rows. No avatars (the reference screenshot's
/// staff table is text-only) and no "查看全部" link (unlike the
/// 角色 section), per the approved design.
class _StaffSection extends ConsumerWidget {
  const _StaffSection({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(subjectStaffProvider(subjectId: subjectId));

    return staffAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (staff) {
        if (staff.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('制作人员', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth(),
                },
                children: [
                  for (final member in staff)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 6),
                          child: Text(
                            member.role ?? '',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(member.name),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
