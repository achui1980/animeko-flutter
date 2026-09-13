// lib/ui/subject/subject_info_table.dart

import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';
import 'subject_meta_text.dart';
import 'subject_tags_row.dart';

/// 左栏的「作品信息」两列表：`放送开始 / 话数 / 别名`，下面接标签行。
///
/// 取值策略：`放送开始`、`话数` 优先读 `infobox`——设计文档
/// `2026-09-12-subject-detail-three-column-layout-design.md` 的「后端接口
/// 实测结果」一节实测到 `放送开始` 在后端返回的 infobox 里已经是中文成品
/// 字符串（`"2022年10月10日"`，「已是中文格式」），比自己格式化更贴近
/// Bangumi 页面；拿不到时才退回 [SubjectDetail.airDate] /
/// [SubjectDetail.episodeCount]。
///
/// `别名` 反过来——优先用 [SubjectDetail.aliases]，因为后端已经把 infobox
/// 里的多个别名拍平成数组，而 [SubjectDetail.infoboxValue] 只取第一个值。
///
/// 三行全都拿不到、且没有标签时整块隐藏（不显示一个空的「作品信息」标题）。
///
/// 目标位置是 `subject_detail_left_pane.dart` 里「封面 / 继续观看 / 追番 /
/// 收藏统计 / 作品信息」的纵向组合（设计文档「UI 结构设计」一节的文件职责
/// 表），那个 pane 是后面的任务，所以目前还没有任何地方构造这个 widget。
class SubjectInfoTable extends StatelessWidget {
  const SubjectInfoTable({super.key, required this.subject});

  final SubjectDetail subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final airDate =
        subject.infoboxValue('放送开始') ?? formatAirDateYearMonth(subject.airDate);
    final episodeCount =
        subject.infoboxValue('话数') ?? subject.episodeCount?.toString();
    final aliases = subject.aliases.isNotEmpty
        ? subject.aliases.join(' / ')
        : subject.infoboxValue('别名');

    final rows = <(String, String)>[
      if (airDate != null) ('放送开始', airDate),
      if (episodeCount != null) ('话数', episodeCount),
      if (aliases != null) ('别名', aliases),
    ];

    if (rows.isEmpty && subject.tags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('作品信息', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (rows.isNotEmpty)
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: [
              for (final (label, value) in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 6),
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(value, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
            ],
          ),
        if (subject.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          SubjectTagsRow(tags: subject.tags),
        ],
      ],
    );
  }
}
