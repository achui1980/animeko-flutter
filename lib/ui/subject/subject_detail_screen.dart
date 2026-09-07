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
          if (imageUrl != null) _ImmersiveHeader(subjectId: subjectId, imageUrl: imageUrl!),
          _BangumiEpisodesSection(subjectId: subjectId, subjectName: subjectName),
          _SubjectInfoSection(subjectId: subjectId),
          _CastStaffSection(subjectId: subjectId),
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
  const _BangumiEpisodesSection({required this.subjectId, required this.subjectName});

  final int subjectId;
  final String subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bangumiProvider = subjectBangumiEpisodesControllerProvider(subjectId: subjectId);
    final bangumiEpisodes = ref.watch(bangumiProvider);
    final mergedEpisodesAsync = ref.watch(
      subjectEpisodesControllerProvider(subjectId: subjectId, subjectName: subjectName),
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
            const SizedBox(height: 8),
            SubjectTagsRow(tags: subject.tags),
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
    final score = subject.score != null ? double.tryParse(subject.score!) : null;
    final airDateLabel = _formatAirDateYearMonth(subject.airDate);
    final hasScoreOrRank = score != null || subject.rank != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (hasScoreOrRank || airDateLabel != null)
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
              if (airDateLabel != null)
                Padding(
                  padding: EdgeInsets.only(left: hasScoreOrRank ? 12 : 0),
                  child: Text(
                    hasScoreOrRank ? '· $airDateLabel' : airDateLabel,
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
          .read(subjectCollectionControllerProvider(subjectId: widget.subjectId).notifier)
          .setCollectionType(type);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新收藏状态失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(subjectCollectionControllerProvider(subjectId: widget.subjectId).notifier)
          .removeFromCollection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('取消收藏失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subjectCollectionControllerProvider(subjectId: widget.subjectId));
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
            ActionChip(label: const Text('移除'), onPressed: _busy ? null : _remove),
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

/// Two vertical [ListTile] lists (cast, then staff). Either list fails
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
              : _PersonList(
                  title: '角色',
                  items: list
                      .map(
                        (c) => (
                          c.character.name,
                          c.character.imageUrl,
                          _characterRoleLabel(c.role),
                        ),
                      )
                      .toList(),
                ),
        ),
        staff.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : _PersonList(
                  title: '制作人员',
                  items: list.map((s) => (s.name, s.imageUrl, s.role ?? '')).toList(),
                ),
        ),
      ],
    );
  }
}

/// A titled vertical list of people ([ListTile]s: avatar, name, and an
/// optional relation/role subtitle) -- e.g. "主角"/"配角"/"客串" for
/// cast, or a staff role like "导演". Replaces the previous horizontal
/// avatar-only carousel (Kazumi's `character_card.dart`/`staff_card.dart`
/// use this same vertical-`ListTile` layout, which surfaces the
/// relation/role that a bare avatar row can't). No tap-through to a
/// person detail page (explicitly excluded, see the design doc).
class _PersonList extends StatelessWidget {
  const _PersonList({required this.title, required this.items});

  final String title;

  /// (name, imageUrl, subtitle) -- subtitle is '' when there's nothing
  /// to show (no `ListTile.subtitle` is rendered in that case).
  final List<(String, String?, String)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final (name, imageUrl, subtitle) in items)
          ListTile(
            leading: CircleAvatar(
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(name),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
          ),
      ],
    );
  }
}

/// Maps a [RelatedCharacter.role] to Bangumi's confirmed convention
/// (verified against the real Kotlin client's `AniCharacterSubject.kt`
/// doc comment: `1 = 主角, 2 = 配角, 3 = 客串`). Any other value
/// (including future additions) falls back to an empty string rather
/// than guessing.
String _characterRoleLabel(int role) {
  switch (role) {
    case 1:
      return '主角';
    case 2:
      return '配角';
    case 3:
      return '客串';
    default:
      return '';
  }
}
