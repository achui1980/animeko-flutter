# 详情页右栏新增评分柱状分布图 设计

日期：2026-09-08。状态：已批准（Approved）。

## 背景

两栏详情页重设计（`2026-09-07-subject-detail-two-column-redesign-design.md`）完成后，右栏只有"制作人员"表格，上方特意留白，为将来的评分分布图/热门评价预留空间。用户现在希望把这块空间用起来，具体选择了"评分柱状分布图（1-10分）"，明确排除了"热门评价"和"收藏统计数字"两项（分别需要全新的 Bangumi 评论接口和聚合收藏接口，本次都不做）。

## 关键发现：不需要新接口

调查确认：本应用自己的后端 `api.animeko.org` 的 `GET /v2/subjects/{id}` 响应里，**已经自带 `scoreDetails` 字段**（形如 `{"1":130,"2":37,...,"10":7445}`，key 是 1~10 分的字符串，value 是该分数的票数），跟 Bangumi 官方 `https://api.bgm.tv/v0/subjects/{id}` 返回的 `rating.count` 字段数值几乎一致（有细微的缓存滞后，可忽略）。因此本功能：
- 不需要新增任何 Dio 客户端/Provider。
- 只需给现有 `SubjectDetail` 模型（`lib/data/subject/subject_models.dart`）新增一个字段，从已经在抓取的同一个响应里解析出来。
- 复用现有的 `subjectDetailControllerProvider`，不新增 provider。

确认 `pubspec.yaml` 中没有任何图表库依赖（`grep -n "chart\|fl_chart\|syncfusion"` 无匹配），跟本应用一贯"简单 UI 手搓，不引入额外依赖"的风格一致（`RatingStars`、`SubjectTagsRow` 都是手搓的）。

## 范围内

1. `SubjectDetail` 新增字段 `Map<String, int>? scoreDetails`，从 `api.animeko.org` 现有响应的 `scoreDetails` 字段解析；类顶部文档注释里"未建模字段"列表中删除 `scoreDetails`（该注释目前是过时的）。
2. 新增私有组件 `_RatingHistogramSection`（`ConsumerWidget`），watch 现有的 `subjectDetailControllerProvider(subjectId:)`。
3. 纵向柱状图：横轴 1~10 分，每个分数一根竖直柱子，柱高按"该分数票数 / 最高票数分数"的比例渲染，用 `Container` 手搓（不引入图表库）。
4. 图表上方一行小字："`{score}分 · {total}人评价`"（如"8.5分 · 36151人评价"）。`score` 复用已有 `SubjectDetail.score` 字段；`total` = `scoreDetails` 各档票数求和。
5. 容错：`scoreDetails` 为 `null` 或全空时，整个区块静默隐藏（`SizedBox.shrink()`），跟 `_StaffSection` 现有的容错方式一致。
6. 位置：加入右栏（`Expanded(flex:1)`），放在 `_StaffSection` **之前**（右栏最上方），填上此前设计特意留白的空间。

## 范围外

- 热门评价列表（需要全新的 Bangumi 评论/评价接口，本次不做）。
- 收藏/在看/想看 集合收藏统计数字（需要新的 Bangumi 聚合收藏接口，本次不做）。
- 不改动 `_StaffSection`、`_CharacterSection`、`_WorkInfoSection`、`_BangumiEpisodesSection`、`_SubjectInfoSection`、`_HeaderInfo`、`_RatingSection` 等既有组件的逻辑，只在右栏新增一个组件。
- 不改动 `lib/ui/subject/episode_source_grid.dart`、`episode_source_sheet.dart`、`lib/domain/play/subject_episodes_controller.dart`、`lib/domain/media/media_registry.dart`（跟本功能无关，仍被 `PlayerScreen` 的播放内选源抽屉使用）。
- 不引入图表库依赖。

## 现状代码基线

`lib/data/subject/subject_models.dart`（222 行）：`SubjectDetail` 当前字段：`id, name, nameCn, summary, airDate, tags, aliases(List<String>, 已在两栏重设计 Task1 中添加), score(String?), rank(int?), collectionType(CollectionType?), selfRating`。`@JsonSerializable()` 标注，`part 'subject_models.g.dart';`。

`lib/ui/subject/subject_detail_screen.dart`（当前，两栏重设计 Task3 之后）：右栏结构为 `Expanded(flex:1, child: _StaffSection(subjectId:subjectId))`——目前右栏只有一个子组件。本功能把这里改为 `Expanded(flex:1, child: Column(children:[_RatingHistogramSection(subjectId:subjectId), _StaffSection(subjectId:subjectId)]))`（或等效结构）。

## 风险与已知限制

- `scoreDetails` 各档票数之和（`total`）跟 Bangumi 官方 `rating.total` 字段理论上应该一致，但由于是从各档票数手动求和而非直接读取后端的 `total` 字段（`api.animeko.org` 的响应里没有单独的顶层 `total`/`rating.total` 字段，只有 `scoreDetails` 这个逐档 map；已通过 curl 确认），此计算依赖 `scoreDetails` 完整无缺失——这是合理假设，暂不做额外校验。
