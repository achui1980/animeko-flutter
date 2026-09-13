# 详情页三栏布局 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把番剧详情页从「沉浸式头图 + 两栏」改成参考 Animeko 原版的「左中右三栏」布局，同时修掉三处线上接口形状与代码模型不符的缺陷，并补上收藏统计、CV 名字、热门评价三块新内容。

**Architecture:** 数据层先行 —— 先把 `SubjectDetail` 补上 `favorite`/`infobox` 两个线上已有但未解析的字段、修好 `CharacterInfo` 与 `getCharacters` 的裸数组解析、删掉整条永远报错的 staff API 链（制作人员改由 `infobox` 驱动）、新增 reviews 接口与 BBCode 清洗、新增「最近播放集数」本地存储。数据层稳定后再重写 UI：`subject_detail_screen.dart` 只保留 `Scaffold` + `AppBar` + 一个 `LayoutBuilder` 断点分支，所有区块内容拆到 `lib/ui/subject/` 下的独立文件里，宽屏（≥1000）三栏、窄屏单栏堆叠。

**Tech Stack:** Flutter / Dart、Riverpod 3.x（`@riverpod` codegen）、`json_serializable`、`dio`、`shared_preferences`、`flutter_test`。每次改动 `@riverpod` 或 `@JsonSerializable` 后必须跑 `dart run build_runner build --delete-conflicting-outputs`。

**设计文档：** `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`（已批准）

---

## 阅读须知（给实施者）

在动手前请务必知道这几件事，否则会踩坑：

1. **codegen 是硬性步骤。** 本仓库的 `*.g.dart` 是签入 git 的。任何 `@riverpod` 或 `@JsonSerializable` 的增删改，都必须跑
   `dart run build_runner build --delete-conflicting-outputs`
   否则会报 `_$FooNotifier` / `$FooProvider` 未定义之类的莫名错误。生成的 `.g.dart` 要和源文件一起 commit。

2. **Riverpod 是 3.x**，不是 2.x。写新 provider 前先看 `lib/domain/subject/subject_detail_controller.dart` 里的现成写法（`@riverpod class Foo extends _$Foo`，函数式 provider 第一个参数类型是 `Ref`，不是 `FooRef`）。

   ⚠️ **Riverpod 3 里 `AsyncValue` 没有 `valueOrNull`**，只有可空的 `value`（`riverpod-3.2.1/lib/src/core/async_value.dart`：`ValueT? get value => _value?.$1;`）。2.x 的 `value` 会在 error 态抛异常、要用 `valueOrNull` 规避——3.x 已经把 `value` 本身改成可空，`valueOrNull` 整个被删掉了。本文档里凡是读「有值就用、没值就退化」的地方统一写 `.value`。

3. **测试的 import 前缀是 `package:animeko_flutter/`。**

4. **验收门：** `flutter analyze` 不能有 error（info 是历史遗留，可以有），`flutter test` 必须全绿。每个 Task 结束都要跑。

5. **提交风格：** Conventional Commits 带 scope，例如 `fix(subject): ...`、`feat(subject): ...`、`refactor(subject): ...`。

6. **不要在 `lib/domain/` 里 import `package:flutter`。** 只有两个历史例外文件，不要拿它们当先例。

   ⚠️ **次要文字用 `theme.colorScheme.onSurfaceVariant`，不要用 `theme.hintColor`。** 本 App 是 `useMaterial3: true` + `ColorScheme.fromSeed`（`lib/app/theme/app_theme.dart:17-28`），而 `ThemeData` 把 `hintColor` 默认成与 ColorScheme 无关的固定灰（`theme_data.dart:487`：`isDark ? Colors.white60 : Colors.black.withOpacity(0.6)`），且本仓库没有覆写它——用 `hintColor` 的文字不会跟着用户的 seed 色调走，周围的文字却会。仓库现状也是 `colorScheme` 为主（29 处引用，`hintColor` 只有 1 处历史用法，就在本轮要拆掉的 `subject_detail_screen.dart` 里）。

7. **接口返回的真实形状已经实测过**，写在设计文档的「后端接口实测结果」一节。不要凭猜测改模型。特别注意：
   - `/v2/subjects/{id}/characters` 返回**裸 JSON 数组**，没有 `items` 外层。
   - `/v2/subjects/{id}/reviews` 返回 `{total, items}`，但 `total` 是 `limit+1` 哨兵值，**不是真实总数**。
   - 角色头像字段叫 `imageMedium`/`imageLarge`，**没有** `imageUrl` 这个 key。

---

## 文件结构

### 数据层（`lib/data/`）

| 文件 | 动作 | 职责 |
| --- | --- | --- |
| `lib/data/subject/subject_models.dart` | 修改 | 新增 `SubjectFavorite`、`SubjectInfobox`、`InfoboxField`、`InfoboxValue`、`PersonInfo`；`SubjectDetail` 增加 `favorite`/`infobox` 字段与 `infoboxValue()`/`staffFields` getter；`CharacterInfo` 换字段；**删除 `StaffMember`** |
| `lib/data/subject/subject_api.dart` | 修改 | `getCharacters` 改成裸数组解析；**删除 `getStaff`**；新增 `getReviews` |
| `lib/data/subject/review_models.dart` | 新建 | `ReviewAuthor`、`SubjectReview`、`PaginatedReviews` |
| `lib/data/subject/bbcode.dart` | 新建 | 纯函数 `stripBbcode(String)` |
| `lib/data/play/last_played_episode_storage.dart` | 新建 | `subjectId → episodeId` 的 SharedPreferences 存储 |

### 领域层（`lib/domain/`）

| 文件 | 动作 | 职责 |
| --- | --- | --- |
| `lib/domain/subject/subject_detail_controller.dart` | 修改 | **删除 `SubjectStaff`** provider |
| `lib/domain/subject/subject_reviews_controller.dart` | 新建 | 分页拉取热门评价，`loadMore()` 追加 |
| `lib/domain/subject/continue_watching_controller.dart` | 新建 | 算出「继续观看」该播哪一集 |

### 主题 / 布局常量

| 文件 | 动作 | 职责 |
| --- | --- | --- |
| `lib/app/theme/app_spacing.dart` | 修改 | 追加 `subjectDetailThreeColumnBreakpoint = 1000` |

### UI 层（`lib/ui/subject/`，全部平铺）

| 文件 | 动作 | 职责 |
| --- | --- | --- |
| `subject_detail_screen.dart` | 重写 | 只有 `Scaffold` + `AppBar` + `LayoutBuilder` 断点分支，不含任何区块内容 |
| `subject_detail_left_pane.dart` | 新建 | 左栏：封面、继续观看、追番、收藏统计、作品信息 |
| `subject_detail_main_pane.dart` | 新建 | 中栏：标题块、简介、选集、角色 |
| `subject_detail_side_pane.dart` | 新建 | 右栏：评分卡、热门评价卡、制作人员卡 |
| `subject_title_block.dart` | 新建 | 中文名 + 原名 + meta 行；导出共享的 meta 文本纯函数 |
| `subject_meta_text.dart` | 新建 | 纯函数：`formatAirDateYearMonth`、`formatEpisodeProgress`、`buildSubjectMetaLine` |
| `continue_watching_button.dart` | 新建 | 「继续观看 第N集」/「开始观看」 |
| `subject_collection_action_button.dart` | 新建 | 「＋追番」/「★在看 ▾」+ 下拉菜单 |
| `subject_collection_stats.dart` | 新建 | 收藏 / 在看 / 想看 三个数字 |
| `subject_info_table.dart` | 新建 | 作品信息（放送开始 / 话数 / 别名 / 标签） |
| `subject_character_row.dart` | 新建 | 角色横向头像行（名字 + CV），含「查看全部」 |
| `subject_episodes_section.dart` | 新建 | 选集区块（标题行 + `EpisodeNumberGrid`） |
| `subject_rating_card.dart` | 新建 | 评分卡：分数、星级、排名、人数、柱状图、打分按钮 |
| `subject_rating_dialog.dart` | 新建 | 打分对话框（从原 `_RatingSection` 搬来） |
| `subject_reviews_card.dart` | 新建 | 热门评价卡（最多 3 条） |
| `subject_staff_card.dart` | 新建 | 制作人员卡（infobox 驱动） |
| `subject_characters_sheet.dart` | 新建 | 角色「查看全部」底部弹窗 |
| `subject_reviews_sheet.dart` | 新建 | 热门评价「查看全部」底部弹窗 |
| `subject_staff_sheet.dart` | 新建 | 制作人员「查看全部」底部弹窗 |
| `subject_cover.dart` | 新建 | 封面图（宽栏 200dp / 窄屏 120dp 共用，含占位图） |
| `subject_side_card.dart` | 新建 | 右栏三张卡片共用的 `Card` 外框（标题 + trailing + 内容） |
| `character_avatar.dart` | 新建 | 角色圆头像（行与 sheet 共用，避免循环 import） |
| `review_avatar.dart` | 新建 | 评价者圆头像（卡片与 sheet 共用，避免循环 import） |
| `subject_reviews_card_frame.dart` | 新建 | 热门评价卡的加载态/数据态共用外框（避免布局跳动） |
| `subject_blurred_header.dart` | **删除** | 三栏布局不再有沉浸式头图 |

> 设计文档列了 17 个 UI 文件，这里是 25 个。多出来的 8 个（`subject_meta_text.dart`、`subject_episodes_section.dart`、`subject_cover.dart`、`subject_side_card.dart`、`character_avatar.dart`、`review_avatar.dart`、`subject_reviews_card_frame.dart`，以及把 `subject_title_block.dart` 的纯函数拆出去）都是实现期的拆分：共享的纯函数、共享的头像/卡框、以及被两处复用的封面。职责更单一，也让 widget test 不必绕过 provider。

保留复用不改：`expandable_summary.dart`、`subject_tags_row.dart`、`episode_number_grid.dart`、`episode_playback_sheet.dart`、`lib/ui/common/rating_stars.dart`、`tag_chip.dart`、`error_retry_view.dart`。

### 测试（`test/` 与 `lib/` 1:1 对应）

新建：`test/data/subject/review_models_test.dart`、`test/data/subject/bbcode_test.dart`、`test/data/play/last_played_episode_storage_test.dart`、`test/domain/subject/continue_watching_controller_test.dart`、`test/domain/subject/subject_reviews_controller_test.dart`、`test/ui/subject/subject_detail_screen_test.dart`、以及每个新 UI 组件对应的 widget test。
修改：`test/data/subject/subject_models_test.dart`、`test/app/theme/app_spacing_test.dart`。
删除：`test/ui/subject/subject_blurred_header_test.dart`。

---

## 任务顺序总览

- Task 1–7：数据层（模型、接口、BBCode、本地存储）
- Task 8–9：领域层 provider
- Task 10：布局常量
- Task 11–21：UI 叶子组件（自底向上，先叶子后容器）
- Task 22：三个 pane 容器 + 封面组件
- Task 23：重写 `subject_detail_screen.dart`，接线三栏 / 单栏断点
- Task 24：播放时写入「最近播放集数」（打通 Task 7/8 的写入端）
- Task 25：删除废弃文件，全量回归 + 手动验收

---

## Task 1: `SubjectDetail.favorite` —— 收藏统计字段

线上 `GET /v2/subjects/{id}` 已经返回 `favorite: {"wish":2138,"done":7420,"doing":1102,"onHold":360,"dropped":177}`，但模型没解析。这一步只加字段，不动 UI。

**Files:**
- Modify: `lib/data/subject/subject_models.dart`
- Test: `test/data/subject/subject_models_test.dart`

- [ ] **Step 1: 写失败的测试**

在 `test/data/subject/subject_models_test.dart` 的 `void main() {` 里追加一个新 group：

```dart
  group('SubjectFavorite', () {
    test('parses the favorite object from the wire', () {
      final subject = SubjectDetail.fromJson({
        'id': 302286,
        'name': 'BLEACH 千年血戦篇',
        'nameCn': '境·界 千年血战篇',
        'summary': '',
        'airDate': '2022-10-10',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'favorite': {
          'wish': 2138,
          'done': 7420,
          'doing': 1102,
          'onHold': 360,
          'dropped': 177,
        },
      });

      expect(subject.favorite, isNotNull);
      expect(subject.favorite!.wish, 2138);
      expect(subject.favorite!.done, 7420);
      expect(subject.favorite!.doing, 1102);
      expect(subject.favorite!.onHold, 360);
      expect(subject.favorite!.dropped, 177);
    });

    test('favorite is null when the key is absent', () {
      final subject = SubjectDetail.fromJson({
        'id': 1,
        'name': 'x',
        'nameCn': 'x',
        'summary': '',
        'airDate': '2020-01-01',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
      });

      expect(subject.favorite, isNull);
    });

    test('missing counters default to zero', () {
      final subject = SubjectDetail.fromJson({
        'id': 1,
        'name': 'x',
        'nameCn': 'x',
        'summary': '',
        'airDate': '2020-01-01',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'favorite': {'done': 5},
      });

      expect(subject.favorite!.done, 5);
      expect(subject.favorite!.wish, 0);
      expect(subject.favorite!.doing, 0);
      expect(subject.favorite!.onHold, 0);
      expect(subject.favorite!.dropped, 0);
    });
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: 编译失败，报 `The getter 'favorite' isn't defined for the class 'SubjectDetail'` 以及 `Undefined name 'SubjectFavorite'`（如果测试里引用了它）。

- [ ] **Step 3: 新增 `SubjectFavorite` 模型**

在 `lib/data/subject/subject_models.dart` 里，紧跟在 `SelfRating` 类之后、`SubjectDetail` 之前，插入：

```dart
/// Aggregate collection counters for a subject, from `SubjectDetail`'s
/// `favorite` object. Live-verified shape (subject 302286):
/// `{"wish":2138,"done":7420,"doing":1102,"onHold":360,"dropped":177}`.
///
/// Note the backend uses camelCase `onHold` (not Bangumi's official
/// snake_case `on_hold`) and `done` (not Bangumi's `collect`). Every
/// counter defaults to 0 so a partial object still parses -- the UI
/// only shows `done`/`doing`/`wish`.
@JsonSerializable()
class SubjectFavorite {
  const SubjectFavorite({
    required this.wish,
    required this.done,
    required this.doing,
    required this.onHold,
    required this.dropped,
  });

  @JsonKey(defaultValue: 0)
  final int wish;
  @JsonKey(defaultValue: 0)
  final int done;
  @JsonKey(defaultValue: 0)
  final int doing;
  @JsonKey(defaultValue: 0)
  final int onHold;
  @JsonKey(defaultValue: 0)
  final int dropped;

  factory SubjectFavorite.fromJson(Map<String, dynamic> json) =>
      _$SubjectFavoriteFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectFavoriteToJson(this);
}
```

- [ ] **Step 4: 给 `SubjectDetail` 加字段**

在 `SubjectDetail` 的构造函数参数列表里，`scoreDetails` 之后加上 `this.favorite,`；在字段声明区 `Map<String, int>? scoreDetails;` 之后加上：

```dart
  /// Aggregate collection counters. Nullable because the field is absent
  /// on some responses; the 收藏统计 block hides itself when null.
  final SubjectFavorite? favorite;
```

同时把类文档里 `favorite` 从「none of which the UI needs」那串里去掉 —— 把原来那句

```
/// the real wire shape also has `type`/`nsfw`/`favorite`/`metaTags`/`relations`/`infobox`/`platform`/`airingInfo`/`updatedAt`, none of which the UI needs
```

改成

```
/// the real wire shape also has `type`/`nsfw`/`metaTags`/`relations`/
/// `platform`/`airingInfo`/`updatedAt`, none of which the UI needs.
/// `favorite` and `infobox` ARE parsed (see the fields below).
```

- [ ] **Step 5: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功，`lib/data/subject/subject_models.g.dart` 里出现 `_$SubjectFavoriteFromJson`。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: 全部 PASS。

- [ ] **Step 7: 静态分析**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 8: 提交**

```bash
git add lib/data/subject/subject_models.dart lib/data/subject/subject_models.g.dart test/data/subject/subject_models_test.dart
git commit -m "feat(subject): parse the favorite collection counters on SubjectDetail"
```

---

## Task 2: `SubjectDetail.infobox` —— infobox 解析 + `infoboxValue()` + `staffFields`

制作人员要靠 infobox 里的中文 key（原作 / 音乐 / 系列构成 …）驱动，因为 `/staff` 接口只给整数 position 码（实测 343 条里有 52 个不同的码），没有映射表就没法显示。

**Files:**
- Modify: `lib/data/subject/subject_models.dart`
- Test: `test/data/subject/subject_models_test.dart`

- [ ] **Step 1: 写失败的测试**

在 `test/data/subject/subject_models_test.dart` 追加：

```dart
  group('SubjectInfobox', () {
    /// Real subset of subject 302286's infobox.
    SubjectDetail buildWithInfobox(Map<String, dynamic> infobox) {
      return SubjectDetail.fromJson({
        'id': 302286,
        'name': 'BLEACH 千年血戦篇',
        'nameCn': '境·界 千年血战篇',
        'summary': '',
        'airDate': '2022-10-10',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
        'infobox': infobox,
      });
    }

    const realInfobox = {
      'template': 'Infobox animanga/TVAnime',
      'fields': [
        {
          'key': '中文名',
          'values': [
            {'v': '境·界 千年血战篇'},
          ],
        },
        {
          'key': '放送开始',
          'values': [
            {'v': '2022年10月10日'},
          ],
        },
        {
          'key': '话数',
          'values': [
            {'v': '13'},
          ],
        },
        {
          'key': '原作',
          'values': [
            {'v': '「BLEACH」久保帯人（集英社「週刊少年ジャンプ」連載）'},
          ],
        },
        {
          'key': '音乐',
          'values': [
            {'v': '鷺巣詩郎'},
          ],
        },
        {
          'key': '系列构成',
          'values': [
            {'v': '田口智久'},
            {'v': '平松正樹'},
          ],
        },
        {
          'key': '官方网站',
          'values': [
            {'v': 'https://example.com'},
          ],
        },
      ],
    };

    test('parses template and fields', () {
      final subject = buildWithInfobox(realInfobox);

      expect(subject.infobox, isNotNull);
      expect(subject.infobox!.template, 'Infobox animanga/TVAnime');
      expect(subject.infobox!.fields.length, 7);
      expect(subject.infobox!.fields.first.key, '中文名');
      expect(subject.infobox!.fields.first.values.first.v, '境·界 千年血战篇');
    });

    test('parses a field with multiple values', () {
      final subject = buildWithInfobox(realInfobox);
      final field = subject.infobox!.fields.firstWhere(
        (f) => f.key == '系列构成',
      );

      expect(field.values.map((value) => value.v).toList(), [
        '田口智久',
        '平松正樹',
      ]);
    });

    test('value k is null when absent', () {
      final subject = buildWithInfobox(realInfobox);

      expect(subject.infobox!.fields.first.values.first.k, isNull);
    });

    test('value k is parsed when present', () {
      final subject = buildWithInfobox({
        'fields': [
          {
            'key': '主题歌',
            'values': [
              {'k': 'OP', 'v': 'Scar'},
            ],
          },
        ],
      });

      expect(subject.infobox!.fields.first.values.first.k, 'OP');
      expect(subject.infobox!.fields.first.values.first.v, 'Scar');
    });

    test('infobox is null when the key is absent', () {
      final subject = SubjectDetail.fromJson({
        'id': 1,
        'name': 'x',
        'nameCn': 'x',
        'summary': '',
        'airDate': '2020-01-01',
        'tags': <dynamic>[],
        'selfRating': {'score': 0, 'tags': <dynamic>[], 'isPrivate': false},
      });

      expect(subject.infobox, isNull);
      expect(subject.infoboxValue('原作'), isNull);
      expect(subject.staffFields, isEmpty);
    });

    test('fields defaults to empty when absent', () {
      final subject = buildWithInfobox({'template': 'x'});

      expect(subject.infobox!.fields, isEmpty);
    });

    group('infoboxValue', () {
      test('returns the first value of a matching field', () {
        final subject = buildWithInfobox(realInfobox);

        expect(subject.infoboxValue('放送开始'), '2022年10月10日');
        expect(subject.infoboxValue('话数'), '13');
        expect(subject.infoboxValue('系列构成'), '田口智久');
      });

      test('returns null for a key that is not present', () {
        final subject = buildWithInfobox(realInfobox);

        expect(subject.infoboxValue('不存在的键'), isNull);
      });
    });

    group('staffFields', () {
      test('keeps staff roles and drops blocklisted metadata keys', () {
        final subject = buildWithInfobox(realInfobox);
        final keys = subject.staffFields.map((field) => field.key).toList();

        expect(keys, ['原作', '音乐', '系列构成']);
        expect(keys, isNot(contains('中文名')));
        expect(keys, isNot(contains('放送开始')));
        expect(keys, isNot(contains('话数')));
        expect(keys, isNot(contains('官方网站')));
      });

      test('keeps a role key that was never observed before', () {
        final subject = buildWithInfobox({
          'fields': [
            {
              'key': '某种全新的没见过的职位',
              'values': [
                {'v': '某人'},
              ],
            },
          ],
        });

        expect(subject.staffFields.map((field) => field.key).toList(), [
          '某种全新的没见过的职位',
        ]);
      });
    });
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: 编译失败，`Undefined name 'SubjectInfobox'` / `The getter 'infobox' isn't defined` / `The method 'infoboxValue' isn't defined`。

- [ ] **Step 3: 新增三个 infobox 模型**

在 `lib/data/subject/subject_models.dart` 里 `SubjectFavorite` 之后插入：

```dart
/// One value of an infobox field. Bangumi's infobox format allows an
/// optional sub-key (`k`) -- e.g. `主题歌` fields use `k: "OP"` -- but
/// most fields only carry `v`, so `k` is nullable.
@JsonSerializable()
class InfoboxValue {
  const InfoboxValue({this.k, required this.v});

  final String? k;
  final String v;

  factory InfoboxValue.fromJson(Map<String, dynamic> json) =>
      _$InfoboxValueFromJson(json);

  Map<String, dynamic> toJson() => _$InfoboxValueToJson(this);
}

/// One infobox row: a Chinese label (`key`) plus one or more values.
@JsonSerializable()
class InfoboxField {
  const InfoboxField({required this.key, this.values = const []});

  final String key;
  @JsonKey(defaultValue: <InfoboxValue>[])
  final List<InfoboxValue> values;

  factory InfoboxField.fromJson(Map<String, dynamic> json) =>
      _$InfoboxFieldFromJson(json);

  Map<String, dynamic> toJson() => _$InfoboxFieldToJson(this);
}

/// The `infobox` object on `GET /v2/subjects/{id}`. This is the ONLY
/// source of human-readable Chinese staff role names -- the
/// `/v2/subjects/{id}/staff` endpoint returns integer `position` codes
/// (52 distinct codes observed on a single subject) with no label, and
/// we deliberately do not maintain a code->label mapping table.
@JsonSerializable()
class SubjectInfobox {
  const SubjectInfobox({this.template, this.fields = const []});

  final String? template;
  @JsonKey(defaultValue: <InfoboxField>[])
  final List<InfoboxField> fields;

  factory SubjectInfobox.fromJson(Map<String, dynamic> json) =>
      _$SubjectInfoboxFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectInfoboxToJson(this);
}

/// Infobox keys that are subject metadata, not staff credits. Used by
/// [SubjectDetail.staffFields].
///
/// This is a BLOCKLIST, not an allowlist, on purpose: staff role keys
/// are free text and 40+ distinct ones have been observed across
/// subjects. An allowlist would silently drop any role we hadn't seen
/// yet, which is worse than occasionally showing one metadata row we
/// forgot to exclude.
const subjectInfoboxNonStaffKeys = <String>{
  '中文名',
  '别名',
  '话数',
  '放送开始',
  '放送星期',
  '放送结束',
  '官方网站',
  '在线播放平台',
  '播放电视台',
  '其他电视台',
  '链接',
  '其他',
  'Copyright',
};
```

- [ ] **Step 4: 给 `SubjectDetail` 加字段和两个 getter**

构造函数参数列表里 `this.favorite,` 之后加 `this.infobox,`。字段声明区 `favorite` 之后加：

```dart
  /// The raw infobox. Nullable; `staffFields` returns empty when null.
  final SubjectInfobox? infobox;
```

在 `episodeCount` getter 之后加：

```dart
  /// First value of the infobox field named [key], or null when the
  /// field (or the whole infobox) is absent. Used for the pre-formatted
  /// Chinese `放送开始` / `话数` / `别名` rows in 作品信息.
  String? infoboxValue(String key) {
    final fields = infobox?.fields;
    if (fields == null) return null;
    for (final field in fields) {
      if (field.key == key && field.values.isNotEmpty) {
        return field.values.first.v;
      }
    }
    return null;
  }

  /// Infobox fields that represent staff credits -- everything except
  /// [subjectInfoboxNonStaffKeys]. Drives the 制作人员 card.
  List<InfoboxField> get staffFields {
    final fields = infobox?.fields;
    if (fields == null) return const [];
    return fields
        .where((field) => !subjectInfoboxNonStaffKeys.contains(field.key))
        .toList();
  }
```

- [ ] **Step 5: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功，`.g.dart` 里出现 `_$SubjectInfoboxFromJson` / `_$InfoboxFieldFromJson` / `_$InfoboxValueFromJson`。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: 全部 PASS。

- [ ] **Step 7: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 8: 提交**

```bash
git add lib/data/subject/subject_models.dart lib/data/subject/subject_models.g.dart test/data/subject/subject_models_test.dart
git commit -m "feat(subject): parse the subject infobox and expose staffFields"
```

---

## Task 3: 修 `CharacterInfo` + `getCharacters` 的裸数组解析（缺陷 #1 和 #3）

两个 bug 一起修，因为分开修中间态是编译不过的。

现状：`CharacterInfo` 只声明了 `name` 和 `imageUrl`，但线上根本没有 `imageUrl` 这个 key（真实字段是 `imageMedium`/`imageLarge`），而且 `getCharacters` 用 `_dio.get<Map<String, dynamic>>` 读 `response.data!['items']`，线上却是裸数组 —— 所以 `getCharacters` **每次调用都抛异常**，角色区块（静默失败）从来没渲染过。

实测真实形状：

```json
[{"index":0,
  "character":{"id":3320,"name":"黒崎一護","nameCn":"黑崎一护",
    "imageLarge":"https://api.animeko.org/v2/characters/3320/image?size=large",
    "imageMedium":"https://api.animeko.org/v2/characters/3320/image?size=medium",
    "actors":[{"id":4716,"name":"森田成一","nameCn":"森田成一","type":1,
               "imageLarge":"...","imageMedium":"...","summary":""}]},
  "role":1}]
```

**Files:**
- Modify: `lib/data/subject/subject_models.dart`
- Modify: `lib/data/subject/subject_api.dart`
- Modify: `lib/ui/subject/subject_detail_screen.dart`（临时改一行让它编译过；Task 23 会整体重写）
- Test: `test/data/subject/subject_models_test.dart`

- [ ] **Step 1: 写失败的测试**

在 `test/data/subject/subject_models_test.dart` 追加：

```dart
  group('CharacterInfo', () {
    /// Real item shape from `GET /v2/subjects/302286/characters?withActors=true`
    /// (a bare JSON array, one element shown).
    const realItem = {
      'index': 0,
      'character': {
        'id': 3320,
        'name': '黒崎一護',
        'nameCn': '黑崎一护',
        'imageLarge':
            'https://api.animeko.org/v2/characters/3320/image?size=large',
        'imageMedium':
            'https://api.animeko.org/v2/characters/3320/image?size=medium',
        'actors': [
          {
            'id': 4716,
            'name': '森田成一',
            'nameCn': '森田成一',
            'type': 1,
            'imageLarge': 'https://example.com/large',
            'imageMedium': 'https://example.com/medium',
            'summary': '',
          },
        ],
      },
      'role': 1,
    };

    test('parses the real wire shape', () {
      final related = RelatedCharacter.fromJson(
        Map<String, dynamic>.from(realItem),
      );

      expect(related.index, 0);
      expect(related.role, 1);
      expect(related.character.name, '黒崎一護');
      expect(related.character.nameCn, '黑崎一护');
      expect(
        related.character.imageMedium,
        'https://api.animeko.org/v2/characters/3320/image?size=medium',
      );
      expect(
        related.character.imageLarge,
        'https://api.animeko.org/v2/characters/3320/image?size=large',
      );
    });

    test('parses the voice actors', () {
      final related = RelatedCharacter.fromJson(
        Map<String, dynamic>.from(realItem),
      );

      expect(related.character.actors, hasLength(1));
      expect(related.character.actors.first.id, 4716);
      expect(related.character.actors.first.name, '森田成一');
      expect(related.character.actors.first.nameCn, '森田成一');
      expect(related.character.actors.first.imageMedium,
          'https://example.com/medium');
    });

    test('actors defaults to empty when the key is absent', () {
      final related = RelatedCharacter.fromJson({
        'index': 3,
        'character': {'id': 9, 'name': 'ナメック星人'},
        'role': 2,
      });

      expect(related.character.actors, isEmpty);
      expect(related.character.nameCn, isNull);
      expect(related.character.imageMedium, isNull);
      expect(related.character.imageLarge, isNull);
    });
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: 失败，`The getter 'nameCn' isn't defined for the class 'CharacterInfo'` 等。

- [ ] **Step 3: 新增 `PersonInfo`，重写 `CharacterInfo`**

在 `lib/data/subject/subject_models.dart` 里，`CharacterInfo` 之前插入 `PersonInfo`：

```dart
/// A person (voice actor, staff member, author). Live-verified shape
/// from the `actors` array inside a character and from the (now unused)
/// `/staff` endpoint's `person` object.
@JsonSerializable()
class PersonInfo {
  const PersonInfo({
    required this.id,
    required this.name,
    this.nameCn,
    this.type,
    this.imageMedium,
    this.imageLarge,
    this.summary,
  });

  final int id;
  final String name;
  final String? nameCn;
  final int? type;
  final String? imageMedium;
  final String? imageLarge;
  final String? summary;

  /// Chinese name when it is present and non-empty, else the original.
  String get displayName =>
      (nameCn != null && nameCn!.isNotEmpty) ? nameCn! : name;

  factory PersonInfo.fromJson(Map<String, dynamic> json) =>
      _$PersonInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PersonInfoToJson(this);
}
```

然后把整个 `CharacterInfo` 类（含它上面的文档注释）替换成：

```dart
/// A single character plus its voice actors.
///
/// Live-verified against `GET /v2/subjects/{id}/characters?withActors=true`
/// (subject 302286). NOTE: an earlier version of this model declared an
/// `imageUrl` field that does not exist on the wire -- the real keys are
/// `imageMedium` / `imageLarge`. `actors` was also being silently
/// dropped even though the request always sends `withActors=true`.
@JsonSerializable()
class CharacterInfo {
  const CharacterInfo({
    required this.id,
    required this.name,
    this.nameCn,
    this.imageMedium,
    this.imageLarge,
    this.actors = const [],
  });

  final int id;
  final String name;
  final String? nameCn;
  final String? imageMedium;
  final String? imageLarge;
  @JsonKey(defaultValue: <PersonInfo>[])
  final List<PersonInfo> actors;

  /// Chinese name when it is present and non-empty, else the original.
  String get displayName =>
      (nameCn != null && nameCn!.isNotEmpty) ? nameCn! : name;

  /// The character's primary voice actor, or null when unknown. The UI
  /// hides the CV line entirely when this is null.
  PersonInfo? get primaryActor => actors.isEmpty ? null : actors.first;

  factory CharacterInfo.fromJson(Map<String, dynamic> json) =>
      _$CharacterInfoFromJson(json);

  Map<String, dynamic> toJson() => _$CharacterInfoToJson(this);
}
```

- [ ] **Step 4: 修 `getCharacters` 的裸数组解析**

把 `lib/data/subject/subject_api.dart` 里的 `getCharacters` 整个方法（含文档注释）替换成：

```dart
  /// Characters (cast). Always requested with `withActors=true` so the
  /// UI can show each character's voice actor.
  ///
  /// The endpoint returns a BARE JSON ARRAY, not an `{items: [...]}`
  /// envelope -- an earlier version of this method declared
  /// `get<Map<String, dynamic>>` and read `data['items']`, which threw
  /// on every single call. The `data is List` branch below is
  /// defensive in case the backend ever adds an envelope.
  Future<List<RelatedCharacter>> getCharacters(int subjectId) async {
    final response = await _dio.get<dynamic>(
      '/v2/subjects/$subjectId/characters',
      queryParameters: {'withActors': true},
    );
    final data = response.data;
    final items = data is List<dynamic>
        ? data
        : (data as Map<String, dynamic>)['items'] as List<dynamic>;
    return items
        .map(
          (item) => RelatedCharacter.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
```

- [ ] **Step 5: 让 UI 暂时编译通过**

`lib/ui/subject/subject_detail_screen.dart` 的 `_CharacterSection` 里有三处引用了已删除的 `related.character.imageUrl`。把那个 `CircleAvatar` + 名字的片段临时改成用新字段（Task 23 会整体重写这块，这里只求编译通过、行为不退化）：

```dart
                        CircleAvatar(
                          radius: 32,
                          backgroundImage:
                              related.character.imageMedium != null
                              ? NetworkImage(related.character.imageMedium!)
                              : null,
                          child: related.character.imageMedium == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 72,
                          child: Text(
                            related.character.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
```

- [ ] **Step 6: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功。

- [ ] **Step 7: 跑测试确认通过**

Run: `flutter test test/data/subject/subject_models_test.dart`
Expected: 全部 PASS。

- [ ] **Step 8: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。若有旧测试引用了 `CharacterInfo(name: ..., imageUrl: ...)`，改成 `CharacterInfo(id: 1, name: ..., imageMedium: ...)`。

- [ ] **Step 9: 提交**

```bash
git add -A lib/data/subject lib/ui/subject/subject_detail_screen.dart test/data/subject
git commit -m "fix(subject): parse the real character payload shape and its voice actors"
```

---

## Task 4: 删除整条 staff API 链（缺陷 #2）

`StaffMember` 期望 `{name (required), imageUrl, role}`，线上实际是 `{index, person:{...}, position:int}` —— `name` 是 required 且线上不存在，所以 `_$StaffMemberFromJson` 每次都抛异常，`subjectStaffProvider` 永远是 error，制作人员区块（静默失败）从来没渲染过。

不修它，直接删掉：制作人员改由 Task 2 的 `staffFields` 驱动，少一个网络请求，而且拿到的是中文职位名而不是整数码。

**Files:**
- Modify: `lib/data/subject/subject_models.dart`（删 `StaffMember`）
- Modify: `lib/data/subject/subject_api.dart`（删 `getStaff`）
- Modify: `lib/domain/subject/subject_detail_controller.dart`（删 `SubjectStaff`）
- Modify: `lib/ui/subject/subject_detail_screen.dart`（删 `_StaffSection` 及其引用）

- [ ] **Step 1: 确认现在没有任何测试依赖 staff**

Run: `rg -n 'StaffMember|getStaff|subjectStaff|SubjectStaff|_StaffSection' lib test`
Expected: 只出现在 `lib/data/subject/subject_models.dart`、`lib/data/subject/subject_models.g.dart`、`lib/data/subject/subject_api.dart`、`lib/domain/subject/subject_detail_controller.dart`（含 `.g.dart`）、`lib/ui/subject/subject_detail_screen.dart`。`test/` 下应无命中。若 `test/` 下有命中，一并删除那些测试。

- [ ] **Step 2: 删掉 `StaffMember` 模型**

在 `lib/data/subject/subject_models.dart` 里，删除整个 `StaffMember` 类以及它上面那段承认「shape 是猜的」的文档注释（原 `:173-192`）。

- [ ] **Step 3: 删掉 `SubjectApi.getStaff`**

在 `lib/data/subject/subject_api.dart` 里删除整个 `getStaff` 方法及其文档注释（原 `:65-78`）。

- [ ] **Step 4: 删掉 `SubjectStaff` provider**

在 `lib/domain/subject/subject_detail_controller.dart` 里删除整个 `SubjectStaff` 类及其文档注释（文件末尾 8 行），并把 `SubjectDetailController` 的文档注释改成：

```dart
/// Fetches the main subject-detail payload (summary/tags/score/rank/
/// collection status/self-rating/favorite counters/infobox). Cast
/// ([SubjectCharacters]) is fetched via a separate provider so it can
/// fail independently without affecting this one -- see the design
/// doc's "per-source silent failure" pattern (mirrors how
/// `SubjectEpisodesController` isolates each `MediaSource`'s failure).
///
/// Staff is NOT a separate provider: the 制作人员 card reads
/// `SubjectDetail.staffFields` off this payload, because the
/// `/v2/subjects/{id}/staff` endpoint only returns integer position
/// codes with no human-readable label.
```

- [ ] **Step 5: 删掉 UI 里的 `_StaffSection`**

在 `lib/ui/subject/subject_detail_screen.dart` 里：
- 删除整个 `_StaffSection` 类（文件末尾）。
- 在 `SubjectDetailScreen.build` 的右栏 `Column` 里删掉 `_StaffSection(subjectId: subjectId),` 这一行，只留 `_RatingHistogramSection(subjectId: subjectId),`。

- [ ] **Step 6: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功；`subject_models.g.dart` 里 `_$StaffMemberFromJson` 消失，`subject_detail_controller.g.dart` 里 `subjectStaffProvider` 消失。

- [ ] **Step 7: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 8: 提交**

```bash
git add -A lib
git commit -m "refactor(subject): drop the broken staff endpoint in favour of infobox credits"
```

---

## Task 5: `stripBbcode` 纯函数

热门评价的正文字段是 `contentBbcode`，可能带 BBCode 标记。卡片和弹窗都以纯文本渲染，所以需要一个纯函数把标记剥掉。

**Files:**
- Create: `lib/data/subject/bbcode.dart`
- Test: `test/data/subject/bbcode_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/data/subject/bbcode_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/bbcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripBbcode', () {
    test('returns the input unchanged when there are no tags', () {
      expect(
        stripBbcode('对比老tv质的飞跃，观感不错。'),
        '对比老tv质的飞跃，观感不错。',
      );
    });

    test('returns an empty string for empty input', () {
      expect(stripBbcode(''), '');
    });

    test('strips a simple paired tag but keeps its content', () {
      expect(stripBbcode('这集[b]太强了[/b]！'), '这集太强了！');
    });

    test('strips nested paired tags', () {
      expect(
        stripBbcode('[b][i]神作[/i][/b]无疑'),
        '神作无疑',
      );
    });

    test('strips tags with parameters', () {
      expect(
        stripBbcode('[size=16]大字[/size]'),
        '大字',
      );
      expect(
        stripBbcode('[url=https://example.com]链接[/url]'),
        '链接',
      );
    });

    test('discards img tags entirely, including their content', () {
      expect(
        stripBbcode('看这个[img]https://example.com/a.jpg[/img]很棒'),
        '看这个很棒',
      );
    });

    test('discards img tags with parameters', () {
      expect(
        stripBbcode('[img=100]https://example.com/a.jpg[/img]结束'),
        '结束',
      );
    });

    test('strips an unclosed tag and keeps the remaining text', () {
      expect(stripBbcode('[b]没有闭合的粗体'), '没有闭合的粗体');
    });

    test('strips a stray closing tag', () {
      expect(stripBbcode('孤立的闭合标签[/b]'), '孤立的闭合标签');
    });

    test('handles a mix of everything', () {
      expect(
        stripBbcode('[b]总评[/b]：[img]x.jpg[/img]还[i]不错'),
        '总评：还不错',
      );
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/subject/bbcode_test.dart`
Expected: 失败，`Error when reading 'lib/data/subject/bbcode.dart': No such file or directory`。

- [ ] **Step 3: 实现 `stripBbcode`**

创建 `lib/data/subject/bbcode.dart`：

```dart
// lib/data/subject/bbcode.dart

/// Matches an `[img]...[/img]` or `[img=param]...[/img]` block including
/// its content -- images are dropped entirely, we render plain text only.
final _imgBlock = RegExp(
  r'\[img(?:=[^\]]*)?\].*?\[/img\]',
  caseSensitive: false,
  dotAll: true,
);

/// Matches any single BBCode tag: `[b]`, `[/b]`, `[size=16]`, `[url=...]`.
final _anyTag = RegExp(r'\[/?[a-zA-Z][a-zA-Z0-9]*(?:=[^\]]*)?\]');

/// Strips BBCode markup from [input], returning plain text.
///
/// Rules:
///  - `[img]...[/img]` blocks are discarded entirely (content included).
///  - Every other tag is removed but its content is kept.
///  - Unclosed or stray tags are removed; surrounding text survives.
///  - Input without tags is returned unchanged.
///
/// Used for `SubjectReview.contentBbcode`, which the 热门评价 card and
/// sheet render as plain text.
String stripBbcode(String input) {
  if (input.isEmpty) return '';
  return input.replaceAll(_imgBlock, '').replaceAll(_anyTag, '');
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/data/subject/bbcode_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 静态分析**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 6: 提交**

```bash
git add lib/data/subject/bbcode.dart test/data/subject/bbcode_test.dart
git commit -m "feat(subject): add a stripBbcode helper for review text"
```

---

## Task 6: 热门评价模型 + `SubjectApi.getReviews`

实测 `GET /v2/subjects/{id}/reviews?limit=&offset=` 返回：

```json
{"total": 4,
 "items": [{"id":"bangumi:302286:1261526","subjectId":302286,"source":"bangumi",
   "author":{"id":"1261526","nickname":"Guating",
             "avatarUrl":"https://static.myani.org/bangumi/avatars/1261526/c49f899d85642d15.jpg"},
   "contentBbcode":"对比老tv质的飞跃，观感不错。",
   "updatedAt":"2026-09-11T13:56:03Z","rating":8,"likeCount":0}]}
```

**关键坑：`total` 不是真实总数**，实测它总是 `limit+1`（limit=1→total=2，limit=10→total=11，limit=50→total=51）。所以它只能当「还有更多」的哨兵用，绝对不能显示成「共 N 条评价」。

**Files:**
- Create: `lib/data/subject/review_models.dart`
- Modify: `lib/data/subject/subject_api.dart`
- Test: `test/data/subject/review_models_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/data/subject/review_models_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Real response from `GET /v2/subjects/302286/reviews?limit=1`.
  const realResponse = {
    'total': 2,
    'items': [
      {
        'id': 'bangumi:302286:1261526',
        'subjectId': 302286,
        'source': 'bangumi',
        'author': {
          'id': '1261526',
          'nickname': 'Guating',
          'avatarUrl':
              'https://static.myani.org/bangumi/avatars/1261526/c49f899d85642d15.jpg',
        },
        'contentBbcode': '对比老tv质的飞跃，观感不错，新加的内容是很好的补充。',
        'updatedAt': '2026-09-11T13:56:03Z',
        'rating': 8,
        'likeCount': 0,
      },
    ],
  };

  group('SubjectReview', () {
    test('parses the real wire shape', () {
      final page = PaginatedReviews.fromJson(
        Map<String, dynamic>.from(realResponse),
      );
      final review = page.items.single;

      expect(review.id, 'bangumi:302286:1261526');
      expect(review.subjectId, 302286);
      expect(review.source, 'bangumi');
      expect(review.contentBbcode, '对比老tv质的飞跃，观感不错，新加的内容是很好的补充。');
      expect(review.updatedAt, '2026-09-11T13:56:03Z');
      expect(review.rating, 8);
      expect(review.likeCount, 0);
      expect(review.author.id, '1261526');
      expect(review.author.nickname, 'Guating');
      expect(
        review.author.avatarUrl,
        'https://static.myani.org/bangumi/avatars/1261526/c49f899d85642d15.jpg',
      );
    });

    test('tolerates a missing avatar, content, rating and likeCount', () {
      final page = PaginatedReviews.fromJson({
        'total': 1,
        'items': [
          {
            'id': 'bangumi:1:2',
            'subjectId': 1,
            'source': 'bangumi',
            'author': {'id': '2', 'nickname': '匿名'},
          },
        ],
      });
      final review = page.items.single;

      expect(review.author.avatarUrl, isNull);
      expect(review.contentBbcode, isNull);
      expect(review.updatedAt, isNull);
      expect(review.rating, isNull);
      expect(review.likeCount, 0);
    });

    test('items defaults to empty when absent', () {
      final page = PaginatedReviews.fromJson({'total': 0});

      expect(page.items, isEmpty);
    });
  });

  group('PaginatedReviews.hasMore', () {
    test('is true when total exceeds the returned item count', () {
      // The backend returns total == limit + 1 whenever more rows exist.
      final page = PaginatedReviews.fromJson(
        Map<String, dynamic>.from(realResponse),
      );

      expect(page.items, hasLength(1));
      expect(page.total, 2);
      expect(page.hasMore, isTrue);
    });

    test('is false when total equals the returned item count', () {
      final page = PaginatedReviews.fromJson({
        'total': 1,
        'items': [
          {
            'id': 'bangumi:1:2',
            'subjectId': 1,
            'source': 'bangumi',
            'author': {'id': '2', 'nickname': '匿名'},
          },
        ],
      });

      expect(page.hasMore, isFalse);
    });

    test('is false for an empty page', () {
      final page = PaginatedReviews.fromJson({'total': 0, 'items': <dynamic>[]});

      expect(page.hasMore, isFalse);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/subject/review_models_test.dart`
Expected: 失败，找不到 `lib/data/subject/review_models.dart`。

- [ ] **Step 3: 实现模型**

创建 `lib/data/subject/review_models.dart`：

```dart
// lib/data/subject/review_models.dart

import 'package:json_annotation/json_annotation.dart';

part 'review_models.g.dart';

/// The author of a review. Note `id` is a STRING here (e.g. `"1261526"`),
/// unlike the int ids used elsewhere in the API.
@JsonSerializable()
class ReviewAuthor {
  const ReviewAuthor({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) =>
      _$ReviewAuthorFromJson(json);

  Map<String, dynamic> toJson() => _$ReviewAuthorToJson(this);
}

/// One other-user review (热门评价) from
/// `GET /v2/subjects/{id}/reviews`.
///
/// `contentBbcode` is BBCode-formatted; run it through
/// `stripBbcode` (`bbcode.dart`) before rendering.
@JsonSerializable()
class SubjectReview {
  const SubjectReview({
    required this.id,
    required this.subjectId,
    required this.source,
    required this.author,
    this.contentBbcode,
    this.updatedAt,
    this.rating,
    this.likeCount = 0,
  });

  final String id;
  final int subjectId;
  final String source;
  final ReviewAuthor author;
  final String? contentBbcode;

  /// ISO-8601 UTC string, e.g. `"2026-09-11T13:56:03Z"`.
  final String? updatedAt;

  /// The author's own 1-10 score, or null when they commented without
  /// rating.
  final int? rating;

  @JsonKey(defaultValue: 0)
  final int likeCount;

  factory SubjectReview.fromJson(Map<String, dynamic> json) =>
      _$SubjectReviewFromJson(json);

  Map<String, dynamic> toJson() => _$SubjectReviewToJson(this);
}

/// One page of reviews.
///
/// **WARNING: `total` is NOT a real total.** The backend returns
/// `limit + 1` whenever more rows exist (verified: limit=1 -> total=2,
/// limit=10 -> total=11, limit=50 -> total=51). Treat it purely as a
/// has-more sentinel via [hasMore]. NEVER render it as
/// 「共 N 条评价」 -- it would show a wrong number on every subject.
@JsonSerializable()
class PaginatedReviews {
  const PaginatedReviews({required this.total, this.items = const []});

  final int total;
  @JsonKey(defaultValue: <SubjectReview>[])
  final List<SubjectReview> items;

  /// Whether another page exists. See the class doc for why this is the
  /// only legitimate use of [total].
  bool get hasMore => total > items.length;

  factory PaginatedReviews.fromJson(Map<String, dynamic> json) =>
      _$PaginatedReviewsFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedReviewsToJson(this);
}
```

- [ ] **Step 4: 加 `SubjectApi.getReviews`**

在 `lib/data/subject/subject_api.dart` 顶部的 import 区加上：

```dart
import 'review_models.dart';
```

然后在 `getMyCollections` 之后（`subjectApi` provider 之前）加：

```dart
  /// Other users' reviews (热门评价), newest first as returned by the
  /// backend.
  ///
  /// The response's `total` is a `limit + 1` sentinel, not a real count
  /// -- see [PaginatedReviews].
  Future<PaginatedReviews> getReviews({
    required int subjectId,
    required int offset,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/$subjectId/reviews',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    return PaginatedReviews.fromJson(response.data!);
  }
```

- [ ] **Step 5: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 生成 `lib/data/subject/review_models.g.dart`。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/data/subject/review_models_test.dart`
Expected: 全部 PASS。

- [ ] **Step 7: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 8: 提交**

```bash
git add lib/data/subject/review_models.dart lib/data/subject/review_models.g.dart lib/data/subject/subject_api.dart test/data/subject/review_models_test.dart
git commit -m "feat(subject): add the reviews endpoint and its models"
```

---


### Task 7: 「最近播放集数」本地存储

只记录「这个条目最后播放的是哪一集」，**不是**完整的已看/未看进度系统（见 spec 的 `继续观看` 决定）。

**Files:**
- Create: `lib/data/play/last_played_episode_storage.dart`
- Test: `test/data/play/last_played_episode_storage_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/data/play/last_played_episode_storage_test.dart`：

```dart
import 'package:animeko_flutter/data/play/last_played_episode_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LastPlayedEpisodeStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<LastPlayedEpisodeStorage> storage() async {
      final prefs = await SharedPreferences.getInstance();
      return LastPlayedEpisodeStorage(prefs);
    }

    test('get returns null when nothing is stored', () async {
      final subject = await storage();
      expect(subject.get(1), isNull);
    });

    test('set then get round-trips the episode id', () async {
      final subject = await storage();
      await subject.set(1, 42);
      expect(subject.get(1), 42);
    });

    test('different subjects are stored independently', () async {
      final subject = await storage();
      await subject.set(1, 42);
      await subject.set(2, 7);
      expect(subject.get(1), 42);
      expect(subject.get(2), 7);
    });

    test('set overwrites the previous episode id for the same subject', () async {
      final subject = await storage();
      await subject.set(1, 42);
      await subject.set(1, 43);
      expect(subject.get(1), 43);
    });

    test('reads a value written by an earlier app run', () async {
      SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 99});
      final subject = await storage();
      expect(subject.get(1), 99);
    });
  });
}
```

最后一个用例把存储键写死成 `lastPlayedEpisode:1`，这样键名一旦被改掉测试就会失败——键名是要跨版本保持兼容的，必须锁住。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/play/last_played_episode_storage_test.dart`
Expected: FAIL，`Target of URI doesn't exist: 'package:animeko_flutter/data/play/last_played_episode_storage.dart'`。

- [ ] **Step 3: 写实现**

创建 `lib/data/play/last_played_episode_storage.dart`：

```dart
// lib/data/play/last_played_episode_storage.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'last_played_episode_storage.g.dart';

const _keyPrefix = 'lastPlayedEpisode:';

/// Remembers which episode was last *started* for a subject, so the
/// detail page's primary button can say 「继续观看 第 N 集」 instead of
/// always 「开始观看」.
///
/// This is deliberately NOT a watched/unwatched progress system: the
/// backend exposes no per-episode collection state (probed -- see the
/// design doc's 「后端接口实测结果」 section), and `PlaybackPositionStorage`
/// is keyed on an opaque `subjectId::sourceId::title` string that cannot
/// be mapped back to a Bangumi `episodeId`. So this stores exactly one
/// `int` per subject and nothing else. Local-only, no cloud sync, same
/// as [PlaybackPositionStorage].
class LastPlayedEpisodeStorage {
  LastPlayedEpisodeStorage(this._prefs);
  final SharedPreferences _prefs;

  /// The Bangumi `episodeId` last started for [subjectId], or null when
  /// this subject has never been played on this device.
  int? get(int subjectId) => _prefs.getInt('$_keyPrefix$subjectId');

  Future<void> set(int subjectId, int episodeId) async {
    await _prefs.setInt('$_keyPrefix$subjectId', episodeId);
  }
}

@riverpod
Future<LastPlayedEpisodeStorage> lastPlayedEpisodeStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return LastPlayedEpisodeStorage(prefs);
}
```

- [ ] **Step 4: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 生成 `lib/data/play/last_played_episode_storage.g.dart`。

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/data/play/last_played_episode_storage_test.dart`
Expected: 5 个用例全 PASS。

- [ ] **Step 6: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/data/play/last_played_episode_storage.dart lib/data/play/last_played_episode_storage.g.dart test/data/play/last_played_episode_storage_test.dart
git commit -m "feat(play): remember the last played episode per subject"
```

---

### Task 8: `continueWatchingProvider`

把 Task 7 的存储和已有的主集列表拼起来，算出「这个按钮该播哪一集」。

**Files:**
- Create: `lib/domain/subject/continue_watching_controller.dart`
- Test: `test/domain/subject/continue_watching_controller_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/domain/subject/continue_watching_controller_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/continue_watching_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectEpisode episode({required int id, required num sort}) => SubjectEpisode(
  episodeId: id,
  sort: sort,
  ep: sort.toString(),
  type: 'MAIN',
  name: 'ep$id',
  nameCn: '',
  airdate: '2026-01-01',
);

SubjectDetail detailWith(List<SubjectEpisode>? episodes) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: episodes,
);

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  void createContainer() {
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  }

  setUp(() {
    api = MockSubjectApi();
    SharedPreferences.setMockInitialValues({});
  });

  Future<SubjectEpisode?> read() =>
      container.read(continueWatchingProvider(subjectId: 1).future);

  test('returns the first episode when nothing has been played', () async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detailWith([episode(id: 11, sort: 1), episode(id: 12, sort: 2)]),
    );
    createContainer();

    final result = await read();

    expect(result?.episodeId, 11);
  });

  test('returns the stored episode when it is still in the list', () async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 12});
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detailWith([episode(id: 11, sort: 1), episode(id: 12, sort: 2)]),
    );
    createContainer();

    final result = await read();

    expect(result?.episodeId, 12);
  });

  test('falls back to the first episode when the stored id is stale', () async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 999});
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detailWith([episode(id: 11, sort: 1), episode(id: 12, sort: 2)]),
    );
    createContainer();

    final result = await read();

    expect(result?.episodeId, 11);
  });

  test('returns null when the subject has no main episodes', () async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(const []));
    createContainer();

    final result = await read();

    expect(result, isNull);
  });
}
```

注意：`SharedPreferences.setMockInitialValues` 必须在 `createContainer()` **之前**调用，因为 provider 第一次被读取时才去拿 `SharedPreferences.getInstance()`，而 mock 值是全局的。这里不 override `lastPlayedEpisodeStorageProvider`，直接用 shared_preferences 官方的 mock 通道，省掉一层 override 样板。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/domain/subject/continue_watching_controller_test.dart`
Expected: FAIL，`Target of URI doesn't exist: 'package:animeko_flutter/domain/subject/continue_watching_controller.dart'`。

- [ ] **Step 3: 写实现**

创建 `lib/domain/subject/continue_watching_controller.dart`：

```dart
// lib/domain/subject/continue_watching_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/play/last_played_episode_storage.dart';
import '../../data/subject/subject_episode_models.dart';
import 'subject_main_episodes_controller.dart';

part 'continue_watching_controller.g.dart';

/// Which episode the detail page's primary button should play.
///
/// * stored episode id still present in the main-episode list -> that
///   episode (button reads 「继续观看 第 N 集」)
/// * nothing stored, or the stored id no longer exists (the subject's
///   episode list changed) -> the first main episode (button reads
///   「开始观看」)
/// * no main episodes at all -> null, and the caller hides the button
///
/// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
/// never garbage-collected -- a subject can drop episodes, or the id can
/// come from a different data revision.
@riverpod
Future<SubjectEpisode?> continueWatching(
  Ref ref, {
  required int subjectId,
}) async {
  final episodes = await ref.watch(
    subjectMainEpisodesControllerProvider(subjectId: subjectId).future,
  );
  if (episodes.isEmpty) return null;

  final storage = await ref.watch(lastPlayedEpisodeStorageProvider.future);
  final lastPlayedId = storage.get(subjectId);
  if (lastPlayedId == null) return episodes.first;

  for (final episode in episodes) {
    if (episode.episodeId == lastPlayedId) return episode;
  }
  return episodes.first;
}
```

- [ ] **Step 4: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 生成 `lib/domain/subject/continue_watching_controller.g.dart`。

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/domain/subject/continue_watching_controller_test.dart`
Expected: 6 个用例全 PASS。

- [ ] **Step 6: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/domain/subject/continue_watching_controller.dart lib/domain/subject/continue_watching_controller.g.dart test/domain/subject/continue_watching_controller_test.dart
git commit -m "feat(subject): add the continue-watching episode provider"
```

---

### Task 9: `subjectReviewsController`

**Files:**
- Create: `lib/domain/subject/subject_reviews_controller.dart`
- Test: `test/domain/subject/subject_reviews_controller_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/domain/subject/subject_reviews_controller_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/domain/subject/subject_reviews_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectReview review(String id) => SubjectReview(
  id: id,
  subjectId: 1,
  source: 'bangumi',
  author: ReviewAuthor(id: 'u$id', nickname: 'user $id'),
  contentBbcode: 'comment $id',
);

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  final provider = subjectReviewsControllerProvider(subjectId: 1);

  // Builds a page the way the backend does: `total` is a has-more sentinel
  // that exceeds the returned row count exactly when more rows exist. (The
  // real backend returns `limit + 1`; scaled down here so the fixtures stay
  // short -- see `PaginatedReviews`'s class doc.)
  PaginatedReviews page(List<SubjectReview> items, {required bool more}) =>
      PaginatedReviews(total: items.length + (more ? 1 : 0), items: items);

  test('loads the first page with offset 0', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a'), review('b')], more: true));

    final result = await container.read(provider.future);

    expect(result.items.map((e) => e.id), ['a', 'b']);
    expect(result.hasMore, isTrue);
    verify(() => api.getReviews(subjectId: 1, offset: 0, limit: 20)).called(1);
  });

  test('loadMore appends the next page and advances the offset', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a'), review('b')], more: true));
    when(
      () => api.getReviews(subjectId: 1, offset: 2, limit: 20),
    ).thenAnswer((_) async => page([review('c')], more: false));

    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();

    final result = container.read(provider).requireValue;
    expect(result.items.map((e) => e.id), ['a', 'b', 'c']);
    expect(result.hasMore, isFalse);
  });

  // The regression test this whole task exists for. If the controller kept
  // an accumulated `PaginatedReviews` and let its `hasMore` getter
  // recompute, page 2's sentinel of 3 would be compared against the 4
  // accumulated rows, `hasMore` would silently flip to false, and every
  // row after page 2 would be unreachable. `hasMore` must come from the
  // freshly fetched page alone.
  test('keeps hasMore true when a full second page still has more', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a'), review('b')], more: true));
    when(
      () => api.getReviews(subjectId: 1, offset: 2, limit: 20),
    ).thenAnswer((_) async => page([review('c'), review('d')], more: true));

    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();

    final result = container.read(provider).requireValue;
    expect(result.items.map((e) => e.id), ['a', 'b', 'c', 'd']);
    expect(result.hasMore, isTrue);
  });

  test('loadMore is a no-op once hasMore is false', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a')], more: false));

    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();

    verifyNever(() => api.getReviews(subjectId: 1, offset: 1, limit: 20));
    expect(container.read(provider).requireValue.items.length, 1);
  });

  test('loadMore is a no-op when the first page failed', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenThrow(Exception('network error'));

    await expectLater(
      container.read(provider.future),
      throwsA(isA<Exception>()),
    );
    await container.read(provider.notifier).loadMore();

    verifyNever(() => api.getReviews(subjectId: 1, offset: 1, limit: 20));
  });

  test('propagates a first-page failure', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenThrow(Exception('network error'));

    await expectLater(container.read(provider.future), throwsA(isA<Exception>()));
  });
}
```

关键约束：控制器的累积状态是**新类 `SubjectReviewsPage`（`items` + `hasMore`）**，不是累积起来的 `PaginatedReviews`。`PaginatedReviews.hasMore` 是 `total > items.length`，而 `total` 是**单次请求**的 `limit + 1` 哨兵，只对「原样从 `getReviews` 拿到的那一页」成立。一旦把多页拼起来再拿它比对累积长度，`hasMore` 会无声变 false：`pageSize` 20、条目有 100 条评价时，第二页返回 `total: 21`，此时累积 40 条，`21 > 40` 为假，加载更多就停在 40 条，剩下 60 条永远取不到，而且没有任何报错。所以 `hasMore` 必须**只**取自刚拉到的那一页（`next.hasMore`）。`MyCollectionsPage`（`lib/domain/subject/my_collections_controller.dart:34`）把 `hasMore` 存成自己的字段，正是同一个原因。第三个用例（`keeps hasMore true when a full second page still has more`）就是专门锁这一点的回归测试。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/domain/subject/subject_reviews_controller_test.dart`
Expected: FAIL，`Target of URI doesn't exist: 'package:animeko_flutter/domain/subject/subject_reviews_controller.dart'`。

- [ ] **Step 3: 写实现**

创建 `lib/domain/subject/subject_reviews_controller.dart`：

```dart
// lib/domain/subject/subject_reviews_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/review_models.dart';
import '../../data/subject/subject_api.dart';

part 'subject_reviews_controller.g.dart';

/// The accumulated reviews the UI renders: every row fetched so far, plus
/// whether another page exists after the last one fetched.
///
/// Deliberately NOT an accumulated [PaginatedReviews]. That class's
/// `hasMore` is `total > items.length`, and `total` is a per-request
/// has-more sentinel (`limit + 1`) that is only meaningful for a single
/// page exactly as returned by `SubjectApi.getReviews`. Compare a page-2
/// sentinel against an accumulated list and it silently goes false: with
/// [SubjectReviewsController.pageSize] 20 on a subject that has 100
/// reviews, page 2 reports `total: 21` while 40 rows have accumulated,
/// `21 > 40` is false, and load-more stops at 40 -- stranding 60 rows with
/// no error anywhere. So [hasMore] is stored, taken from the freshly
/// fetched page alone. `MyCollectionsPage`
/// (`lib/domain/subject/my_collections_controller.dart:34`) keeps a
/// per-page `hasMore` field for the same reason.
class SubjectReviewsPage {
  const SubjectReviewsPage({required this.items, required this.hasMore});

  /// Every review fetched so far, first page first.
  final List<SubjectReview> items;

  /// Whether another page exists after the last one fetched.
  final bool hasMore;
}

/// Other users' short reviews (热门评价). Paginated by offset, accumulating
/// into a single [SubjectReviewsPage] so the sheet can just render
/// `state.items`.
///
/// The detail page's right-column card shows only the first few of these;
/// the 查看全部 sheet shows everything and calls [loadMore].
///
/// Failure is silent at the UI level (the whole card/sheet hides) -- see
/// the design doc's 「加载/错误/空态」 table.
@riverpod
class SubjectReviewsController extends _$SubjectReviewsController {
  /// Rows per request. The backend's default is 30; 20 is plenty for a
  /// first paint and keeps the payload small.
  static const int pageSize = 20;

  @override
  Future<SubjectReviewsPage> build({required int subjectId}) async {
    final page = await ref
        .watch(subjectApiProvider)
        .getReviews(subjectId: subjectId, offset: 0, limit: pageSize);
    return SubjectReviewsPage(items: page.items, hasMore: page.hasMore);
  }

  /// Fetches the next page and appends it. No-op while loading, on error,
  /// or once [SubjectReviewsPage.hasMore] is false.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;

    final next = await ref.read(subjectApiProvider).getReviews(
      subjectId: subjectId,
      offset: current.items.length,
      limit: pageSize,
    );
    // `hasMore` comes from the freshly fetched page and is never
    // recomputed against the accumulated list -- see [SubjectReviewsPage].
    state = AsyncData(
      SubjectReviewsPage(
        items: [...current.items, ...next.items],
        hasMore: next.hasMore,
      ),
    );
  }
}
```

- [ ] **Step 4: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 生成 `lib/domain/subject/subject_reviews_controller.g.dart`。

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/domain/subject/subject_reviews_controller_test.dart`
Expected: 6 个用例全 PASS。

- [ ] **Step 6: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/domain/subject/subject_reviews_controller.dart lib/domain/subject/subject_reviews_controller.g.dart test/domain/subject/subject_reviews_controller_test.dart
git commit -m "feat(subject): add the paginated subject reviews controller"
```

---

### Task 10: 三栏断点常量

**Files:**
- Modify: `lib/app/theme/app_spacing.dart`

这一步只加一个 `const`，本身没有行为可测（断言 `1000 == 1000` 是废测试）。断点的**行为**在 Task 23 的 `subject_detail_screen_test.dart` 里用两种视口宽度验证。所以这个 Task 没有测试步骤，只有实现 + 门禁。

- [ ] **Step 1: 加常量**

在 `lib/app/theme/app_spacing.dart` 末尾追加：

```dart

/// Width at/above which the subject detail page uses its three-column
/// desktop layout; below it the same sections stack into one column.
///
/// At the breakpoint itself the middle column is `1000 - 2*24 (page
/// padding) - 200 (left) - 300 (right) - 2*24 (gaps) = 404dp`, which fits
/// three 96dp episode buttons (`3*96 + 2*8 = 304`). A fourth needs
/// `4*96 + 3*8 = 408dp`, i.e. a window of 1004dp or wider -- so the
/// bottom 4dp of the wide layout renders a three-wide episode grid.
/// Accepted rather than moving the breakpoint to 1004: the design doc
/// lists these widths under 「已知的估算项」, and a round 1000 is easier to
/// reason about than a number derived from one grid's button size.
///
/// Deliberately unrelated to [pagePadding]'s 600dp compact/wide
/// breakpoint -- that one mirrors the reference app's `WindowSizeClass`,
/// this one is driven by the detail page's own content widths.
const double subjectDetailThreeColumnBreakpoint = 1000;
```

- [ ] **Step 2: 静态分析 + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 3: 提交**

```bash
git add lib/app/theme/app_spacing.dart
git commit -m "feat(theme): add the subject detail three-column breakpoint"
```

---


---

### Task 11: `subject_meta_text.dart`（纯函数：meta 行文案）

规格依据：spec「meta 行计算」一节。`2026年7月 · 连载至 09 · 预定全 11 话`。
中栏标题块和「选集」区块头部右侧要显示**同一份**「连载至 NN · 预定全 NN 话」文案，
所以抽成纯函数放在独立文件里，不带 Flutter 依赖，可以直接单元测试。

**Files:**
- Create: `lib/ui/subject/subject_meta_text.dart`
- Test: `test/ui/subject/subject_meta_text_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_meta_text_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/ui/subject/subject_meta_text.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectEpisode ep(int n, String airdate) => SubjectEpisode(
  episodeId: n,
  sort: n,
  ep: '$n',
  type: 'MAIN',
  name: 'E$n',
  nameCn: '第$n集',
  airdate: airdate,
);

/// 固定「今天」，让测试不随真实时间漂移。
final now = DateTime(2026, 9, 12);

void main() {
  group('formatAirDateYearMonth', () {
    test('formats an ISO date as 年月', () {
      expect(formatAirDateYearMonth('2026-07-12'), '2026年7月');
    });

    test('returns null when the date is unparseable', () {
      expect(formatAirDateYearMonth('not-a-date'), isNull);
    });

    test('returns null for an empty string', () {
      expect(formatAirDateYearMonth(''), isNull);
    });
  });

  group('formatEpisodeNumber', () {
    test('drops the decimal part for whole numbers', () {
      expect(formatEpisodeNumber(3), '3');
      expect(formatEpisodeNumber(3.0), '3');
    });

    test('keeps the decimal part for fractional sorts', () {
      expect(formatEpisodeNumber(3.5), '3.5');
    });
  });

  group('airedEpisodeCount', () {
    test('counts episodes airing today or earlier', () {
      final episodes = [
        ep(1, '2026-09-01'),
        ep(2, '2026-09-08'),
        ep(3, '2026-09-12'),
        ep(4, '2026-09-19'),
        ep(5, '2026-09-26'),
      ];
      expect(airedEpisodeCount(episodes, now: now), 3);
    });

    test('skips episodes with an unparseable airdate', () {
      final episodes = [ep(1, '2026-09-01'), ep(2, '')];
      expect(airedEpisodeCount(episodes, now: now), 1);
    });

    test('returns 0 for an empty list', () {
      expect(airedEpisodeCount(const [], now: now), 0);
    });
  });

  group('formatEpisodeProgress', () {
    test('shows both segments while still airing', () {
      final episodes = [
        for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
        ep(10, '2026-09-19'),
        ep(11, '2026-09-26'),
      ];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: 11, now: now),
        '连载至 09 · 预定全 11 话',
      );
    });

    test('omits 连载至 once every episode has aired', () {
      final episodes = [for (var i = 1; i <= 11; i++) ep(i, '2026-09-01')];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: 11, now: now),
        '预定全 11 话',
      );
    });

    test('omits 连载至 when nothing has aired yet', () {
      final episodes = [for (var i = 1; i <= 11; i++) ep(i, '2026-12-01')];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: 11, now: now),
        '预定全 11 话',
      );
    });

    test('omits 预定全 when the episode count is unknown', () {
      final episodes = [
        ep(1, '2026-09-01'),
        ep(2, '2026-09-08'),
        ep(3, '2026-09-19'),
      ];
      expect(
        formatEpisodeProgress(episodes: episodes, episodeCount: null, now: now),
        '连载至 02',
      );
    });

    test('returns null when there is nothing to say', () {
      expect(
        formatEpisodeProgress(episodes: const [], episodeCount: null, now: now),
        isNull,
      );
    });
  });

  group('buildSubjectMetaLine', () {
    test('joins every available segment with ` · `', () {
      final episodes = [
        for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
        ep(10, '2026-09-19'),
        ep(11, '2026-09-26'),
      ];
      expect(
        buildSubjectMetaLine(
          airDate: '2026-07-12',
          episodes: episodes,
          episodeCount: 11,
          now: now,
        ),
        '2026年7月 · 连载至 09 · 预定全 11 话',
      );
    });

    test('drops the 年月 segment when the air date is unparseable', () {
      final episodes = [
        for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
        ep(10, '2026-09-19'),
        ep(11, '2026-09-26'),
      ];
      expect(
        buildSubjectMetaLine(
          airDate: '',
          episodes: episodes,
          episodeCount: 11,
          now: now,
        ),
        '连载至 09 · 预定全 11 话',
      );
    });

    test('keeps only the 年月 segment when there is no episode data', () {
      expect(
        buildSubjectMetaLine(
          airDate: '2026-07-12',
          episodes: const [],
          episodeCount: null,
          now: now,
        ),
        '2026年7月',
      );
    });

    test('returns an empty string when nothing is known', () {
      expect(
        buildSubjectMetaLine(
          airDate: '',
          episodes: const [],
          episodeCount: null,
          now: now,
        ),
        '',
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_meta_text_test.dart`
Expected: 编译失败，`Error: Error when reading 'lib/ui/subject/subject_meta_text.dart': No such file or directory`

- [ ] **Step 3: 实现**

创建 `lib/ui/subject/subject_meta_text.dart`：

```dart
// lib/ui/subject/subject_meta_text.dart

import '../../data/subject/subject_episode_models.dart';

/// Pure text helpers for the subject detail page's meta line
/// (`2026年7月 · 连载至 09 · 预定全 11 话`).
///
/// Deliberately free of `package:flutter` imports so these can be unit
/// tested without widget scaffolding, and so the middle column's title
/// block and the 选集 section header can share one implementation of the
/// 「连载至 NN · 预定全 NN 话」 text instead of each rolling their own.

/// `2026-07-12` -> `2026年7月`. Returns null when [airDate] cannot be
/// parsed (the backend sends a plain `YYYY-MM-DD` string, but it can be
/// empty for unannounced subjects).
String? formatAirDateYearMonth(String airDate) {
  final date = DateTime.tryParse(airDate);
  if (date == null) return null;
  return '${date.year}年${date.month}月';
}

/// Renders an episode `sort` for display: `3` stays `3` (not `3.0`),
/// while a genuine half-episode `3.5` keeps its decimal part.
String formatEpisodeNumber(num sort) {
  if (sort % 1 == 0) return sort.toInt().toString();
  return sort.toString();
}

/// How many of [episodes] have aired as of [now] (defaults to the real
/// current time). Compares date-only, so an episode airing later today
/// still counts as aired. Episodes with an unparseable `airdate` are
/// skipped rather than guessed at.
int airedEpisodeCount(List<SubjectEpisode> episodes, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final cutoff = DateTime(today.year, today.month, today.day);
  var count = 0;
  for (final episode in episodes) {
    final airdate = DateTime.tryParse(episode.airdate);
    if (airdate == null) continue;
    if (!airdate.isAfter(cutoff)) count += 1;
  }
  return count;
}

/// `连载至 09 · 预定全 11 话`, or a subset, or null when neither segment
/// applies.
///
/// `连载至 NN` is omitted when nothing has aired yet and when everything
/// has already aired (a finished show is not "连载至"). `预定全 NN 话` is
/// omitted when [episodeCount] is null (the backend has no `eps` field;
/// `SubjectDetail.episodeCount` is derived from the embedded episode
/// list and is null when that list is absent).
String? formatEpisodeProgress({
  required List<SubjectEpisode> episodes,
  required int? episodeCount,
  DateTime? now,
}) {
  final aired = airedEpisodeCount(episodes, now: now);
  final allAired = aired >= (episodeCount ?? episodes.length);
  final parts = <String>[
    if (aired > 0 && !allAired) '连载至 ${aired.toString().padLeft(2, '0')}',
    if (episodeCount != null) '预定全 $episodeCount 话',
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// The full meta line under the title. Returns `''` when nothing is
/// known, so callers can guard with `isNotEmpty` instead of a null check.
String buildSubjectMetaLine({
  required String airDate,
  required List<SubjectEpisode> episodes,
  required int? episodeCount,
  DateTime? now,
}) {
  final progress = formatEpisodeProgress(
    episodes: episodes,
    episodeCount: episodeCount,
    now: now,
  );
  final parts = <String>[
    ?formatAirDateYearMonth(airDate),
    ?progress,
  ];
  return parts.join(' · ');
}
```

> 说明：`<String>[?maybeNull, ?maybeNull]` 是 Dart 3.9 的 null-aware element 语法。
> 如果 `flutter analyze` 报不认识 `?` 元素（SDK 低于 3.9），改成显式写法：
> ```dart
>   final parts = <String>[];
>   final yearMonth = formatAirDateYearMonth(airDate);
>   if (yearMonth != null) parts.add(yearMonth);
>   if (progress != null) parts.add(progress);
> ```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/ui/subject/subject_meta_text_test.dart`
Expected: `All tests passed!`（17 个测试）

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/subject_meta_text.dart test/ui/subject/subject_meta_text_test.dart
git commit -m "feat(subject): add pure meta-line text helpers for detail page"
```

---

### Task 12: `subject_title_block.dart`（中栏标题块）

中栏最上方：中文标题（大号加粗）+ 原名（小号灰色，与中文标题不同时才显示）+ meta 行。

**Files:**
- Create: `lib/ui/subject/subject_title_block.dart`
- Test: `test/ui/subject/subject_title_block_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_title_block_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_title_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectEpisode ep(int n, String airdate) => SubjectEpisode(
  episodeId: n,
  sort: n,
  ep: '$n',
  type: 'MAIN',
  name: 'E$n',
  nameCn: '第$n集',
  airdate: airdate,
);

SubjectDetail detail({
  String name = 'Futsutsuka na Akujo',
  String nameCn = '恶女不才',
  String airDate = '2026-07-12',
  List<SubjectEpisode>? episodes,
}) => SubjectDetail(
  id: 1,
  name: name,
  nameCn: nameCn,
  summary: 'summary',
  airDate: airDate,
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: episodes,
);

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders the Chinese title and the original name', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text('恶女不才'), findsOneWidget);
    expect(find.text('Futsutsuka na Akujo'), findsOneWidget);
  });

  testWidgets('falls back to the original name when nameCn is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(nameCn: ''),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    // Shown exactly once -- as the title, not also as the subtitle.
    expect(find.text('Futsutsuka na Akujo'), findsOneWidget);
  });

  testWidgets('does not repeat the original name when it equals the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(name: '恶女不才', nameCn: '恶女不才'),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text('恶女不才'), findsOneWidget);
  });

  testWidgets('renders the meta line', (tester) async {
    final episodes = [
      for (var i = 1; i <= 9; i++) ep(i, '2026-09-01'),
      ep(10, '2026-09-19'),
      ep(11, '2026-09-26'),
    ];
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(episodes: episodes),
          episodes: episodes,
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text('2026年7月 · 连载至 09 · 预定全 11 话'), findsOneWidget);
  });

  testWidgets('omits the meta line when nothing is known', (tester) async {
    await tester.pumpWidget(
      wrap(
        SubjectTitleBlock(
          subject: detail(airDate: ''),
          episodes: const [],
          now: DateTime(2026, 9, 12),
        ),
      ),
    );

    expect(find.text(''), findsNothing);
    expect(find.byType(Text), findsNWidgets(0));
    expect(find.byType(SelectableText), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_title_block_test.dart`
Expected: 编译失败，`Error: Error when reading 'lib/ui/subject/subject_title_block.dart': No such file or directory`

- [ ] **Step 3: 实现**

创建 `lib/ui/subject/subject_title_block.dart`：

```dart
// lib/ui/subject/subject_title_block.dart

import 'package:flutter/material.dart';

import '../../data/subject/subject_episode_models.dart';
import '../../data/subject/subject_models.dart';
import 'subject_meta_text.dart';

/// The middle column's header: Chinese title, original (Japanese) name,
/// and the meta line (`2026年7月 · 连载至 09 · 预定全 11 话`).
///
/// Takes already-resolved data instead of watching providers so it stays
/// a plain [StatelessWidget] -- the pane that composes it already has
/// both the [SubjectDetail] and the main-episode list in hand.
///
/// [now] exists only so tests can pin "today"; production callers omit it.
class SubjectTitleBlock extends StatelessWidget {
  const SubjectTitleBlock({
    super.key,
    required this.subject,
    required this.episodes,
    this.now,
  });

  final SubjectDetail subject;
  final List<SubjectEpisode> episodes;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = subject.nameCn.isNotEmpty ? subject.nameCn : subject.name;
    final showOriginal = subject.name.isNotEmpty && subject.name != title;
    final metaLine = buildSubjectMetaLine(
      airDate: subject.airDate,
      episodes: episodes,
      episodeCount: subject.episodeCount,
      now: now,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (showOriginal)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SelectableText(
              subject.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (metaLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              metaLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/ui/subject/subject_title_block_test.dart`
Expected: `All tests passed!`（5 个测试）

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/subject_title_block.dart test/ui/subject/subject_title_block_test.dart
git commit -m "feat(subject): add title block widget for detail page middle column"
```

---

### Task 13: `continue_watching_button.dart`（继续观看 / 开始观看）

左栏首个按钮。有上次播放记录时显示「继续观看 第 N 集」，否则「开始观看」（播第一集）。
点击后弹出与选集网格相同的 `EpisodePlaybackSheet`。

判断「是否续播」的方式：把 `continueWatchingProvider` 解析出的目标集与
`LastPlayedEpisodeStorage` 里存的 id 做比较。三种情况都正确：
无记录（存的是 null）→ 不等 → 「开始观看」；有效记录 → 相等 → 「继续观看」；
失效记录（存的 id 已不在列表里，provider 回退到第一集）→ 不等 → 「开始观看」。

**Files:**
- Create: `lib/ui/subject/continue_watching_button.dart`
- Test: `test/ui/subject/continue_watching_button_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/continue_watching_button_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/continue_watching_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectEpisode ep(int n) => SubjectEpisode(
  episodeId: n,
  sort: n,
  ep: '$n',
  type: 'MAIN',
  name: 'E$n',
  nameCn: '第$n集',
  airdate: '2026-01-01',
);

SubjectDetail detailWithEpisodes() => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: [ep(1), ep(2), ep(3)],
);

void main() {
  late MockSubjectApi api;

  setUp(() {
    api = MockSubjectApi();
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWithEpisodes());
  });

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [subjectApiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: ContinueWatchingButton(subjectId: 1, subjectName: 'A-cn'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows 开始观看 when there is no stored episode', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpButton(tester);

    expect(find.text('开始观看'), findsOneWidget);
  });

  testWidgets('shows 继续观看 第 N 集 for a stored episode', (tester) async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 3});

    await pumpButton(tester);

    expect(find.text('继续观看 第 3 集'), findsOneWidget);
  });

  testWidgets('shows 开始观看 when the stored episode no longer exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 999});

    await pumpButton(tester);

    expect(find.text('开始观看'), findsOneWidget);
  });

  testWidgets('renders nothing when the subject has no episodes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => SubjectDetail(
        id: 1,
        name: 'A',
        nameCn: 'A-cn',
        summary: 'summary',
        airDate: '2026-01-01',
        tags: const [],
        selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
        episodes: const [],
      ),
    );

    await pumpButton(tester);

    expect(find.byType(FilledButton), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/continue_watching_button_test.dart`
Expected: 编译失败，`Error: Error when reading 'lib/ui/subject/continue_watching_button.dart': No such file or directory`

- [ ] **Step 3: 实现**

创建 `lib/ui/subject/continue_watching_button.dart`：

```dart
// lib/ui/subject/continue_watching_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/play/last_played_episode_storage.dart';
import '../../domain/subject/continue_watching_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import 'episode_playback_sheet.dart';
import 'subject_meta_text.dart';

/// The left column's primary button: 「继续观看 第 N 集」 when there is a
/// usable last-played record, otherwise 「开始观看」 (which plays episode 1).
///
/// Tapping it opens the same [EpisodePlaybackSheet] the 选集 grid opens,
/// so there is exactly one code path for picking a playback source.
///
/// Renders nothing while the target episode is still loading, on error,
/// and when the subject has no episodes at all -- per the spec's
/// "`continueWatchingProvider` 失败 -> 退回开始观看播第一集" rule the
/// provider itself already handles the fallback, so the only empty case
/// left here is genuinely having no episodes.
class ContinueWatchingButton extends ConsumerWidget {
  const ContinueWatchingButton({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  final int subjectId;
  final String subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref
        .watch(continueWatchingProvider(subjectId: subjectId))
        .value;
    if (target == null) return const SizedBox.shrink();

    final episodes =
        ref
            .watch(subjectMainEpisodesControllerProvider(subjectId: subjectId))
            .value ??
        const [];
    final ordinalIndex = episodes.indexWhere(
      (episode) => episode.episodeId == target.episodeId,
    );
    if (ordinalIndex < 0) return const SizedBox.shrink();

    final storedEpisodeId = ref
        .watch(lastPlayedEpisodeStorageProvider)
        .value
        ?.get(subjectId);
    final resumed = storedEpisodeId == target.episodeId;
    final label = resumed
        ? '继续观看 第 ${formatEpisodeNumber(target.sort)} 集'
        : '开始观看';

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => EpisodePlaybackSheet(
            subjectId: subjectId,
            subjectName: subjectName,
            ordinalIndex: ordinalIndex,
            episode: target,
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: Text(label),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/ui/subject/continue_watching_button_test.dart`
Expected: `All tests passed!`（4 个测试）

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/continue_watching_button.dart test/ui/subject/continue_watching_button_test.dart
git commit -m "feat(subject): add continue-watching button for detail page left column"
```

---

### Task 14: `subject_collection_action_button.dart`（收藏按钮 + 下拉菜单）

替换旧的 5 个平铺 `ChoiceChip`。未收藏时是单个「＋ 追番」按钮（= `CollectionType.wish`）；已收藏时是「★ 在看 ▾」，点击弹出 `PopupMenuButton` 列出其余四个状态 + 分隔线 + 「移除」。

`PopupMenuButton` 的泛型用 `CollectionType?`，`null` 表示「移除」——这样 `onSelected` 只有一个分支判断，不需要引入额外的 sealed class。

**Files:**
- Create: `lib/ui/subject/subject_collection_action_button.dart`
- Test: `test/ui/subject/subject_collection_action_button_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_collection_action_button_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_collection_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectDetail detailWith(CollectionType? type) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-01-01',
  tags: const [],
  collectionType: type,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;

  setUpAll(() {
    registerFallbackValue(CollectionType.wish);
  });

  setUp(() {
    api = MockSubjectApi();
  });

  Future<void> pump(WidgetTester tester, CollectionType? type) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(type));
    await tester.pumpWidget(
      wrap(
        const SubjectCollectionActionButton(subjectId: 1, imageUrl: 'u'),
        overrides: [subjectApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SubjectCollectionActionButton', () {
    testWidgets('未收藏时显示「追番」', (tester) async {
      await pump(tester, null);

      expect(find.text('追番'), findsOneWidget);
      expect(find.text('在看'), findsNothing);
    });

    testWidgets('点击「追番」以 wish 调用 updateCollection', (tester) async {
      when(
        () => api.updateCollection(
          any(),
          collectionType: any(named: 'collectionType'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, null);

      await tester.tap(find.text('追番'));
      await tester.pumpAndSettle();

      verify(
        () => api.updateCollection(1, collectionType: CollectionType.wish),
      ).called(1);
    });

    testWidgets('已收藏时显示当前状态标签', (tester) async {
      await pump(tester, CollectionType.doing);

      expect(find.text('在看'), findsOneWidget);
      expect(find.text('追番'), findsNothing);
    });

    testWidgets('展开菜单列出其余状态与「移除」，不含当前状态', (tester) async {
      await pump(tester, CollectionType.doing);

      await tester.tap(find.text('在看'));
      await tester.pumpAndSettle();

      expect(find.text('想看'), findsOneWidget);
      expect(find.text('看过'), findsOneWidget);
      expect(find.text('搁置'), findsOneWidget);
      expect(find.text('弃番'), findsOneWidget);
      expect(find.text('移除'), findsOneWidget);
      // 「在看」只剩下按钮上那一个，菜单里不重复出现。
      expect(find.text('在看'), findsOneWidget);
    });

    testWidgets('菜单里选「看过」以 done 调用 updateCollection', (tester) async {
      when(
        () => api.updateCollection(
          any(),
          collectionType: any(named: 'collectionType'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, CollectionType.doing);

      await tester.tap(find.text('在看'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('看过'));
      await tester.pumpAndSettle();

      verify(
        () => api.updateCollection(1, collectionType: CollectionType.done),
      ).called(1);
    });

    testWidgets('菜单里选「移除」调用 deleteCollection', (tester) async {
      when(() => api.deleteCollection(1)).thenAnswer((_) async {});
      await pump(tester, CollectionType.doing);

      await tester.tap(find.text('在看'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();

      verify(() => api.deleteCollection(1)).called(1);
    });

    testWidgets('更新失败时弹出 SnackBar', (tester) async {
      when(
        () => api.updateCollection(
          any(),
          collectionType: any(named: 'collectionType'),
        ),
      ).thenThrow(Exception('boom'));
      await pump(tester, null);

      await tester.tap(find.text('追番'));
      await tester.pumpAndSettle();

      expect(find.textContaining('更新收藏状态失败'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_collection_action_button_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'animeko_flutter' ... subject_collection_action_button.dart` / `Target of URI doesn't exist`。

- [ ] **Step 3: 实现**

创建 `lib/ui/subject/subject_collection_action_button.dart`：

```dart
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
/// 需要一个分支判断，不必额外定义一个 sealed 的动作类型。
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
        onSelected: (value) {
          if (value == null) {
            _remove();
          } else {
            _setType(value);
          }
        },
        itemBuilder: (context) => [
          for (final type in CollectionType.values)
            if (type != current)
              PopupMenuItem<CollectionType?>(
                value: type,
                child: Text(labels[type]!),
              ),
          const PopupMenuDivider(),
          const PopupMenuItem<CollectionType?>(value: null, child: Text('移除')),
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
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/ui/subject/subject_collection_action_button_test.dart`
Expected: PASS（7 个测试全部通过）。

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/subject_collection_action_button.dart test/ui/subject/subject_collection_action_button_test.dart
git commit -m "feat(subject): add collection action button with status dropdown"
```

---

### Task 15: `subject_collection_stats.dart`（收藏统计）

左栏的 `7,781 收藏 / 5,959 在看 / 1,449 想看` 三联块。映射按 spec：收藏=`done`、在看=`doing`、想看=`wish`；`onHold`/`dropped` 不展示。`favorite` 为 `null` 时整块隐藏。

千分位分隔用本文件内的 `formatCount`，不引入 `intl` 依赖。

**Files:**
- Create: `lib/ui/subject/subject_collection_stats.dart`
- Test: `test/ui/subject/subject_collection_stats_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_collection_stats_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_collection_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCount', () {
    test('三位以内原样输出', () {
      expect(formatCount(0), '0');
      expect(formatCount(7), '7');
      expect(formatCount(999), '999');
    });

    test('四位及以上插入千分位逗号', () {
      expect(formatCount(1000), '1,000');
      expect(formatCount(1449), '1,449');
      expect(formatCount(7781), '7,781');
      expect(formatCount(1234567), '1,234,567');
    });
  });

  group('SubjectCollectionStats', () {
    testWidgets('favorite 为 null 时什么都不渲染', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SubjectCollectionStats(favorite: null)),
        ),
      );

      expect(find.text('收藏'), findsNothing);
      expect(find.text('在看'), findsNothing);
      expect(find.text('想看'), findsNothing);
    });

    testWidgets('按 done/doing/wish 映射到 收藏/在看/想看', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectCollectionStats(
              favorite: SubjectFavorite(
                wish: 1449,
                done: 7781,
                doing: 5959,
                onHold: 360,
                dropped: 177,
              ),
            ),
          ),
        ),
      );

      expect(find.text('7,781'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('5,959'), findsOneWidget);
      expect(find.text('在看'), findsOneWidget);
      expect(find.text('1,449'), findsOneWidget);
      expect(find.text('想看'), findsOneWidget);
    });

    testWidgets('不展示 搁置/弃番 的数字', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectCollectionStats(
              favorite: SubjectFavorite(
                wish: 1,
                done: 2,
                doing: 3,
                onHold: 360,
                dropped: 177,
              ),
            ),
          ),
        ),
      );

      expect(find.text('360'), findsNothing);
      expect(find.text('177'), findsNothing);
      expect(find.text('搁置'), findsNothing);
      expect(find.text('弃番'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_collection_stats_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/ui/subject/subject_collection_stats.dart'`。

- [ ] **Step 3: 实现**

创建 `lib/ui/subject/subject_collection_stats.dart`：

```dart
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
/// 字段映射（spec「收藏统计字段映射」）：收藏 = [SubjectFavorite.done]、
/// 在看 = [SubjectFavorite.doing]、想看 = [SubjectFavorite.wish]。
/// `onHold`/`dropped` 拿得到但不展示——参考应用的详情页也只显示这三项。
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
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/ui/subject/subject_collection_stats_test.dart`
Expected: PASS（5 个测试全部通过）。

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/subject_collection_stats.dart test/ui/subject/subject_collection_stats_test.dart
git commit -m "feat(subject): add collection stats block to detail page"
```

---

### Task 16: `subject_info_table.dart`（作品信息表）

左栏最下方的 `放送开始 / 话数 / 别名` 两列表 + 标签行。取值优先用 infobox 里已经是中文的字符串（`放送开始` 形如 `"2022年10月10日"`），拿不到时退回模型字段。

`别名` 反过来优先用 `SubjectDetail.aliases`（后端已经拍平成数组，比 infobox 只取第一个值更完整），infobox 作兜底。

一行都没有且没有标签时整块隐藏。

**Files:**
- Create: `lib/ui/subject/subject_info_table.dart`
- Test: `test/ui/subject/subject_info_table_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_info_table_test.dart`：

```dart
import 'package:animeko_flutter/data/search/search_models.dart' show SubjectTag;
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_info_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectDetail detail({
  String airDate = '2026-07-12',
  List<String> aliases = const [],
  List<SubjectTag> tags = const [],
  SubjectInfobox? infobox,
  List<SubjectEpisode>? episodes,
}) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: airDate,
  tags: tags,
  aliases: aliases,
  infobox: infobox,
  episodes: episodes,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
);

SubjectEpisode mainEpisode(int id) => SubjectEpisode(
  episodeId: id,
  sort: id,
  ep: '$id',
  type: 'MAIN',
  name: 'ep$id',
  nameCn: '',
  airdate: '2026-07-12',
);

Future<void> pump(WidgetTester tester, SubjectDetail subject) =>
    tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SubjectInfoTable(subject: subject))),
    );

void main() {
  group('SubjectInfoTable', () {
    testWidgets('优先用 infobox 里的中文「放送开始」原文', (tester) async {
      await pump(
        tester,
        detail(
          infobox: const SubjectInfobox(
            fields: [
              InfoboxField(
                key: '放送开始',
                values: [InfoboxValue(v: '2026年7月12日')],
              ),
            ],
          ),
        ),
      );

      expect(find.text('放送开始'), findsOneWidget);
      expect(find.text('2026年7月12日'), findsOneWidget);
    });

    testWidgets('没有 infobox 时退回 airDate 的年月格式', (tester) async {
      await pump(tester, detail(airDate: '2026-07-12'));

      expect(find.text('2026年7月'), findsOneWidget);
    });

    testWidgets('话数取 infobox，没有则用 episodeCount', (tester) async {
      await pump(tester, detail(episodes: [mainEpisode(1), mainEpisode(2)]));

      expect(find.text('话数'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('拿不到的字段整行不渲染', (tester) async {
      await pump(tester, detail(airDate: 'not-a-date'));

      expect(find.text('放送开始'), findsNothing);
      expect(find.text('话数'), findsNothing);
      expect(find.text('别名'), findsNothing);
    });

    testWidgets('别名优先用 aliases 数组并以 / 连接', (tester) async {
      await pump(
        tester,
        detail(
          aliases: const ['别名一', '别名二'],
          infobox: const SubjectInfobox(
            fields: [
              InfoboxField(key: '别名', values: [InfoboxValue(v: '只有第一个')]),
            ],
          ),
        ),
      );

      expect(find.text('别名一 / 别名二'), findsOneWidget);
      expect(find.text('只有第一个'), findsNothing);
    });

    testWidgets('有标签时渲染标签行', (tester) async {
      await pump(
        tester,
        detail(tags: const [SubjectTag(name: '奇幻', count: 12)]),
      );

      expect(find.textContaining('奇幻'), findsOneWidget);
    });

    testWidgets('没有任何行也没有标签时整块隐藏', (tester) async {
      await pump(tester, detail(airDate: 'not-a-date'));

      expect(find.text('作品信息'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_info_table_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:animeko_flutter/ui/subject/subject_info_table.dart'`。

- [ ] **Step 3: 实现**

创建 `lib/ui/subject/subject_info_table.dart`：

```dart
import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';
import 'subject_meta_text.dart';
import 'subject_tags_row.dart';

/// 左栏的「作品信息」两列表：`放送开始 / 话数 / 别名`，下面接标签行。
///
/// 取值策略：`放送开始`、`话数` 优先读 `infobox`——后端返回的 infobox 里
/// 这两项已经是中文成品字符串（`"2022年10月10日"`、`"13"`），比自己格式化
/// 更贴近 Bangumi 页面；拿不到时才退回 [SubjectDetail.airDate] /
/// [SubjectDetail.episodeCount]。
///
/// `别名` 反过来——优先用 [SubjectDetail.aliases]，因为后端已经把 infobox
/// 里的多个别名拍平成数组，而 [SubjectDetail.infoboxValue] 只取第一个值。
///
/// 三行全都拿不到、且没有标签时整块隐藏（不显示一个空的「作品信息」标题）。
class SubjectInfoTable extends StatelessWidget {
  const SubjectInfoTable({super.key, required this.subject});

  final SubjectDetail subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final airDate =
        subject.infoboxValue('放送开始') ??
        formatAirDateYearMonth(subject.airDate);
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
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/ui/subject/subject_info_table_test.dart`
Expected: PASS（7 个测试全部通过）。

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/subject_info_table.dart test/ui/subject/subject_info_table_test.dart
git commit -m "feat(subject): add infobox-driven work info table"
```

---

### Task 17: 角色头像（`character_avatar.dart` + `subject_character_row.dart` + `subject_characters_sheet.dart`）

**Files:**
- Create: `lib/ui/subject/character_avatar.dart`
- Create: `lib/ui/subject/subject_character_row.dart`
- Create: `lib/ui/subject/subject_characters_sheet.dart`
- Test: `test/ui/subject/subject_character_row_test.dart`

> 说明：`CharacterAvatar` 单独成文件，因为横向行和 sheet 都要用它；如果放在
> `subject_character_row.dart` 里，sheet 与 row 之间会形成循环 import。
> 这是本计划相对于设计文档 17 个文件清单的第三个新增文件（前两个是
> `subject_meta_text.dart` 和 `subject_episodes_section.dart`）。

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_character_row_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_character_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

/// 所有 fixture 的头像字段都留 null，避免 `NetworkImage` 在
/// `flutter_test` 里发起被拦截的 HTTP 请求并把异常报到测试上。
RelatedCharacter related({
  required int id,
  required String name,
  String? nameCn,
  List<PersonInfo> actors = const [],
}) {
  return RelatedCharacter(
    index: id,
    character: CharacterInfo(id: id, name: name, nameCn: nameCn, actors: actors),
    role: 1,
  );
}

PersonInfo actor(String name) => PersonInfo(id: 900, name: name);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUp(() {
    api = MockSubjectApi();
    overrides = [subjectApiProvider.overrideWithValue(api)];
  });

  testWidgets('renders one cell per character, preferring nameCn', (
    tester,
  ) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        related(id: 1, name: '黒崎一護', nameCn: '黑崎一护'),
        related(id: 2, name: '朽木ルキア'),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsOneWidget);
    expect(find.text('黑崎一护'), findsOneWidget);
    expect(find.text('朽木ルキア'), findsOneWidget);
    expect(find.text('黒崎一護'), findsNothing);
  });

  testWidgets('shows the primary actor name below the character name', (
    tester,
  ) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        related(
          id: 1,
          name: '黑崎一护',
          actors: [actor('森田成一'), actor('ignored')],
        ),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('森田成一'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
  });

  testWidgets('omits the actor line when actors is empty', (tester) async {
    when(
      () => api.getCharacters(1),
    ).thenAnswer((_) async => [related(id: 1, name: '黑崎一护')]);

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    // 只有角色名一个 Text 在 cell 里（外加 header 的「角色」和按钮文字）。
    expect(find.text('黑崎一护'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('renders the fallback icon when there is no avatar url', (
    tester,
  ) async {
    when(
      () => api.getCharacters(1),
    ).thenAnswer((_) async => [related(id: 1, name: 'A')]);

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('hides the whole section on error', (tester) async {
    when(() => api.getCharacters(1)).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsNothing);
  });

  testWidgets('hides the whole section when the list is empty', (tester) async {
    when(() => api.getCharacters(1)).thenAnswer((_) async => []);

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsNothing);
  });

  testWidgets('caps the inline row at maxVisible cells', (tester) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        for (var i = 0; i < SubjectCharacterRow.maxVisible + 3; i++)
          related(id: i, name: 'C$i'),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('C0'), findsOneWidget);
    expect(find.text('C${SubjectCharacterRow.maxVisible - 1}'), findsOneWidget);
    expect(find.text('C${SubjectCharacterRow.maxVisible}'), findsNothing);
  });

  testWidgets('tapping 查看全部 opens the full-cast sheet', (tester) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        related(id: 1, name: '黑崎一护', actors: [actor('森田成一')]),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部 ›'));
    await tester.pumpAndSettle();

    expect(find.text('全部角色'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_character_row_test.dart`
Expected: FAIL，`Error: Couldn't resolve the package 'animeko_flutter' ... subject_character_row.dart` 或
`Target of URI doesn't exist: 'package:animeko_flutter/ui/subject/subject_character_row.dart'`。

- [ ] **Step 3: 实现 `character_avatar.dart`**

创建 `lib/ui/subject/character_avatar.dart`：

```dart
import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';

/// 圆形角色头像，缺图时退回一个人形占位图标。
///
/// 后端返回的是 `imageMedium` / `imageLarge` 两个字段（不存在 `imageUrl`，
/// 见数据层 Task 3 的说明）。这里优先用 `imageMedium`：行内头像直径只有
/// 64dp，medium 尺寸足够。
///
/// `onBackgroundImageError` 必须给：`CircleAvatar.backgroundImage` 没有
/// `errorBuilder`，不接这个回调时加载失败会把异常抛到 `FlutterError`，
/// 在 widget 测试里会直接把测试判成失败。
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({super.key, required this.character, this.radius = 32});

  final CharacterInfo character;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = character.imageMedium ?? character.imageLarge;
    return CircleAvatar(
      radius: radius,
      backgroundImage: url == null ? null : NetworkImage(url),
      onBackgroundImageError: url == null ? null : (_, _) {},
      child: url == null ? Icon(Icons.person, size: radius) : null,
    );
  }
}
```

- [ ] **Step 4: 实现 `subject_characters_sheet.dart`**

创建 `lib/ui/subject/subject_characters_sheet.dart`：

```dart
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
```

- [ ] **Step 5: 实现 `subject_character_row.dart`**

创建 `lib/ui/subject/subject_character_row.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/subject_models.dart';
import '../../domain/subject/subject_detail_controller.dart';
import 'character_avatar.dart';
import 'subject_characters_sheet.dart';

/// 中栏的「角色」横向头像行：头像 + 角色名 + 声优名。
///
/// 加载中时渲染带标题的外框 + 一个小 spinner（不是整块隐藏），这样数据到
/// 位时页面不会跳动 —— 见设计文档「加载/错误/空态」一节。失败和空列表都
/// 整块静默隐藏：角色不是详情页的主线信息，缺了不该显示报错。
class SubjectCharacterRow extends ConsumerWidget {
  const SubjectCharacterRow({super.key, required this.subjectId});

  /// 行内最多显示多少个角色，其余交给「查看全部」sheet。
  /// 估算值：参考应用一屏显示 8 个，这里给到 12 留一点横向滚动余量；
  /// 全量渲染不可行（BLEACH 千年血战篇有 104 个角色）。
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
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('查看全部 ›'),
                ),
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
```

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/ui/subject/subject_character_row_test.dart`
Expected: PASS，8 个测试全绿。

- [ ] **Step 7: 提交**

```bash
git add lib/ui/subject/character_avatar.dart lib/ui/subject/subject_character_row.dart lib/ui/subject/subject_characters_sheet.dart test/ui/subject/subject_character_row_test.dart
git commit -m "feat(subject): add character row with CV names and full-cast sheet"
```

---

### Task 18: 选集区块（`subject_episodes_section.dart`）+ 精简 `EpisodeNumberGrid`

**Files:**
- Create: `lib/ui/subject/subject_episodes_section.dart`
- Modify: `lib/ui/subject/episode_number_grid.dart:90-137`（删掉内部的「剧集」标题和 `horizontal: 16` 内边距）
- Test: `test/ui/subject/subject_episodes_section_test.dart`

> 为什么要动 `EpisodeNumberGrid`：新的区块自己有「选集」标题行（右侧还要放
> 「连载至 09 · 预定全 11 话」），网格内部再渲染一个「剧集」标题就重复了。
> 内部的 `horizontal: 16` 也要去掉 —— 页面级左右留白由外层 `pagePadding`
> 统一负责，见设计文档「排布数值」一节里去重内边距的要求。
> 已确认 `test/ui/subject/episode_number_grid_test.dart` 没有断言「剧集」
> 这个标题文本，也没有断言任何 `EdgeInsets`，所以改动不会破坏它的测试。

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_episodes_section_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/subject/subject_episodes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const episodes = [
  SubjectEpisode(
    episodeId: 11,
    sort: 1,
    ep: '1',
    type: 'MAIN',
    name: 'One',
    nameCn: '第一话',
    airdate: '2026-07-12',
  ),
  SubjectEpisode(
    episodeId: 12,
    sort: 2,
    ep: '2',
    type: 'MAIN',
    name: 'Two',
    nameCn: '第二话',
    airdate: '2026-07-19',
  ),
  SubjectEpisode(
    episodeId: 13,
    sort: 3,
    ep: '3',
    type: 'MAIN',
    name: 'Three',
    nameCn: '第三话',
    airdate: '2099-01-01',
  ),
];

SubjectDetail detailWith(List<SubjectEpisode>? eps) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-07-12',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: eps,
);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;

  /// 覆盖 `mediaSourcesProvider` 为空列表：这样 `SubjectEpisodesController`
  /// 不会去打真实的爬虫源，网格会稳定落在「无源但可点」的状态。
  late List<Override> overrides;

  setUp(() {
    api = MockSubjectApi();
    overrides = [
      subjectApiProvider.overrideWithValue(api),
      mediaSourcesProvider.overrideWithValue(const <MediaSource>[]),
    ];
  });

  testWidgets('renders the 选集 header with the progress text', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detailWith(episodes.toList()));

    await tester.pumpWidget(
      wrap(
        SubjectEpisodesSection(
          subjectId: 1,
          subjectName: 'A',
          now: DateTime(2026, 7, 20),
        ),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选集'), findsOneWidget);
    expect(find.text('连载至 02 · 预定全 3 话'), findsOneWidget);
  });

  testWidgets('renders one button per episode', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detailWith(episodes.toList()));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('03'), findsOneWidget);
  });

  testWidgets('hides itself when there are no main episodes', (tester) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWith(const []));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选集'), findsNothing);
  });

  testWidgets('shows a retry view when the episode list fails', (tester) async {
    when(() => api.getSubject(1)).thenThrow(Exception('network error'));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('加载剧集列表失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('tapping an episode opens the playback sheet', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detailWith(episodes.toList()));

    await tester.pumpWidget(
      wrap(
        const SubjectEpisodesSection(subjectId: 1, subjectName: 'A'),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();

    expect(find.text('暂无播放源'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_episodes_section_test.dart`
Expected: FAIL，`Target of URI doesn't exist: 'package:animeko_flutter/ui/subject/subject_episodes_section.dart'`。

- [ ] **Step 3: 实现 `subject_episodes_section.dart`**

创建 `lib/ui/subject/subject_episodes_section.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import '../common/error_retry_view.dart';
import 'episode_number_grid.dart';
import 'episode_playback_sheet.dart';
import 'subject_meta_text.dart';

/// 中栏的「选集」区块：标题行（左「选集」，右「连载至 NN · 预定全 NN 话」）
/// + `EpisodeNumberGrid`。
///
/// 标题右侧的进度文案和标题区 meta 行用的是同一个纯函数
/// [formatEpisodeProgress]，不重复实现。
class SubjectEpisodesSection extends ConsumerWidget {
  const SubjectEpisodesSection({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.now,
  });

  final int subjectId;
  final String subjectName;

  /// 仅测试用：固定「今天」，让「连载至 NN」可断言。
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final episodesAsync = ref.watch(
      subjectMainEpisodesControllerProvider(subjectId: subjectId),
    );
    final mergedEpisodesAsync = ref.watch(
      subjectEpisodesControllerProvider(
        subjectId: subjectId,
        subjectName: subjectName,
      ),
    );
    final episodeCount = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value
        ?.episodeCount;

    return episodesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      // 重试要作废「源」provider（详情接口），而不是这个派生 provider ——
      // 剧集数组是从详情响应里算出来的，作废派生的那个不会重新发请求。
      error: (error, _) => ErrorRetryView(
        message: '加载剧集列表失败：$error',
        onRetry: () =>
            ref.invalidate(subjectDetailControllerProvider(subjectId: subjectId)),
      ),
      data: (episodes) {
        if (episodes.isEmpty) return const SizedBox.shrink();
        final progress = formatEpisodeProgress(
          episodes: episodes,
          episodeCount: episodeCount,
          now: now,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('选集', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  if (progress != null)
                    Text(
                      progress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              EpisodeNumberGrid(
                episodes: episodes,
                mergedEpisodesAsync: mergedEpisodesAsync,
                onEpisodeTap: (ordinalIndex, episode) =>
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => EpisodePlaybackSheet(
                        subjectId: subjectId,
                        subjectName: subjectName,
                        ordinalIndex: ordinalIndex,
                        episode: episode,
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 精简 `EpisodeNumberGrid` 的标题和内边距**

编辑 `lib/ui/subject/episode_number_grid.dart`，把 `build` 里 `return Column(` 的
`children:` 整段（原第 93-136 行）替换成：

```dart
      children: [
        if (_chunkCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _chunkCount; i++)
                  ChoiceChip(
                    label: Text(_chunkLabel(i)),
                    selected: i == chunkIndex,
                    onSelected: (_) => setState(() => _chunkIndex = i),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = start; i < end; i++)
              _EpisodeNumberButton(
                episode: widget.episodes[i],
                // sourceIndex == null means either the scraper fetch is
                // still in flight (neutral state, not yet has/no-source)
                // or it settled with an error and no source will ever be
                // found (dimmed, same as an empty match) -- see
                // isStillLoading above.
                hasSource: sourceIndex == null
                    ? (isStillLoading ? null : false)
                    : sourceIndex.matchesAt(i).isNotEmpty,
                onTap: () => widget.onEpisodeTap(i, widget.episodes[i]),
              ),
          ],
        ),
      ],
```

同时把类文档注释里这段：

```dart
/// Compact grid of episode-number buttons (01/02/03/...), replacing the old
/// single "开始观看" button. Tapping a number opens a per-episode
/// source-selection sheet (see `EpisodePlaybackSheet`).
```

改成：

```dart
/// Compact grid of episode-number buttons (01/02/03/...). Tapping a number
/// opens a per-episode source-selection sheet (see `EpisodePlaybackSheet`).
///
/// Renders no section header and no page-level padding of its own: the
/// enclosing `SubjectEpisodesSection` owns the 「选集」 header row and the
/// page's left/right gutter comes from `pagePadding`.
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/ui/subject/subject_episodes_section_test.dart test/ui/subject/episode_number_grid_test.dart`
Expected: PASS，两个文件全绿（新增 5 个 + 原有网格测试）。

- [ ] **Step 6: 提交**

```bash
git add lib/ui/subject/subject_episodes_section.dart lib/ui/subject/episode_number_grid.dart test/ui/subject/subject_episodes_section_test.dart
git commit -m "feat(subject): extract 选集 section with airing progress header"
```

---

### Task 19: 右栏卡片框架 + 评分卡 + 打分对话框

**Files:**
- Create: `lib/ui/subject/subject_side_card.dart`
- Create: `lib/ui/subject/subject_rating_dialog.dart`
- Create: `lib/ui/subject/subject_rating_card.dart`
- Test: `test/ui/subject/subject_rating_card_test.dart`
- Test: `test/ui/subject/subject_rating_dialog_test.dart`

右栏三张卡（评分 / 热门评价 / 制作人员）共用同一个卡片外框，所以先做 `SubjectSideCard`
（Task 20、21 直接复用，不要各自重复一遍 `Card` + 标题行）。

打分表单从旧 `_RatingSection` 搬进对话框：旧版是「左栏里可展开的一段」，新版是「评分卡右上角
`☆ 打分` 按钮 → 弹对话框」。初始分数由调用方（评分卡）算好后通过构造参数传入，
这样对话框自己不需要在 `initState` 里读 provider，测试也更好写。

- [ ] **Step 1: 写 `SubjectSideCard`（无独立测试，由 Task 19-21 的卡片测试覆盖）**

创建 `lib/ui/subject/subject_side_card.dart`：

```dart
// lib/ui/subject/subject_side_card.dart
import 'package:flutter/material.dart';

/// The shared visual frame for the three right-column cards (评分 /
/// 热门评价 / 制作人员) on the subject detail page.
///
/// Reference-app style: a filled rounded surface with a small title on
/// the left of the header row and an optional action (`查看全部 ›` /
/// `☆ 打分`) on the right. Defined once here so the three cards cannot
/// drift apart visually.
///
/// In the narrow (< [subjectDetailThreeColumnBreakpoint]) single-column
/// layout the same cards are reused unchanged -- they just stack full
/// width below the rest of the content.
class SubjectSideCard extends StatelessWidget {
  const SubjectSideCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Optional header-row action, e.g. a `查看全部 ›` [TextButton].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 写失败的评分卡测试**

创建 `test/ui/subject/subject_rating_card_test.dart`：

```dart
import 'dart:async';

import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_rating_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectDetail detail({
  String? score,
  int? rank,
  Map<String, int>? scoreDetails,
  SelfRating selfRating = const SelfRating(
    score: 0,
    tags: [],
    isPrivate: false,
  ),
}) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-07-12',
  tags: const [],
  score: score,
  rank: rank,
  scoreDetails: scoreDetails,
  selfRating: selfRating,
);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUp(() {
    api = MockSubjectApi();
    overrides = [subjectApiProvider.overrideWithValue(api)];
  });

  testWidgets('shows score, rank and summed rating count', (tester) async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detail(
        score: '7.9',
        rank: 325,
        scoreDetails: {'7': 100, '8': 200, '9': 50},
      ),
    );

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('评分'), findsOneWidget);
    expect(find.text('7.9'), findsOneWidget);
    expect(find.text('#325 · 350 人评分'), findsOneWidget);
  });

  testWidgets('renders one histogram bar per score from 1 to 10', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detail(score: '7.9', scoreDetails: {'7': 100, '8': 200}),
    );

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    for (var score = 1; score <= 10; score++) {
      expect(find.text('$score'), findsOneWidget);
    }
  });

  testWidgets('omits the histogram when scoreDetails is empty', (tester) async {
    when(
      () => api.getSubject(1),
    ).thenAnswer((_) async => detail(score: null, scoreDetails: null));

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('评分'), findsOneWidget);
    expect(find.text('暂无评分'), findsOneWidget);
    expect(find.text('10'), findsNothing);
  });

  testWidgets('rating button reads 打分 when not rated yet', (tester) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detail(score: '7.9'));

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('☆ 打分'), findsOneWidget);
  });

  testWidgets('rating button shows my score when already rated', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => detail(
        score: '7.9',
        selfRating: const SelfRating(score: 8, tags: [], isPrivate: false),
      ),
    );

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('☆ 已评 8 分'), findsOneWidget);
  });

  testWidgets('tapping the rating button opens the rating dialog', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenAnswer((_) async => detail(score: '7.9'));

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('☆ 打分'));
    await tester.pumpAndSettle();

    expect(find.text('我的评分'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('renders nothing while the subject is still loading', (
    tester,
  ) async {
    final completer = Completer<SubjectDetail>();
    when(() => api.getSubject(1)).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      wrap(const SubjectRatingCard(subjectId: 1), overrides: overrides),
    );
    await tester.pump();

    expect(find.text('评分'), findsNothing);

    completer.complete(detail(score: '7.9'));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/ui/subject/subject_rating_card_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'animeko_flutter' ... subject_rating_card.dart` /
`Target of URI doesn't exist`

- [ ] **Step 4: 写打分对话框**

创建 `lib/ui/subject/subject_rating_dialog.dart`：

```dart
// lib/ui/subject/subject_rating_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_collection_controller.dart';

/// Opens the 打分 dialog for [subjectId].
///
/// The caller (`SubjectRatingCard`) already watches
/// `subjectCollectionControllerProvider`, so it passes the current
/// self-rating in as the initial form values -- the dialog itself does
/// not read any provider during `initState`.
Future<void> showSubjectRatingDialog(
  BuildContext context, {
  required int subjectId,
  required int initialScore,
  String? initialComment,
  bool initialIsPrivate = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => SubjectRatingDialog(
      subjectId: subjectId,
      initialScore: initialScore,
      initialComment: initialComment,
      initialIsPrivate: initialIsPrivate,
    ),
  );
}

/// The 打分 form: score slider (1-10), optional comment, "private"
/// toggle, submit.
///
/// Ported from the old `_RatingSection` inside `subject_detail_screen.dart`,
/// which rendered the same form inline in the left column. Submission is
/// deliberately NOT optimistic (see `SubjectCollectionController.submitRating`):
/// on failure the dialog stays open with the user's input intact.
class SubjectRatingDialog extends ConsumerStatefulWidget {
  const SubjectRatingDialog({
    super.key,
    required this.subjectId,
    required this.initialScore,
    this.initialComment,
    this.initialIsPrivate = false,
  });

  final int subjectId;
  final int initialScore;
  final String? initialComment;
  final bool initialIsPrivate;

  @override
  ConsumerState<SubjectRatingDialog> createState() =>
      _SubjectRatingDialogState();
}

class _SubjectRatingDialogState extends ConsumerState<SubjectRatingDialog> {
  late int _score = widget.initialScore;
  late bool _isPrivate = widget.initialIsPrivate;
  late final TextEditingController _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
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
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评分已提交')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交评分失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('我的评分'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_score 分', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: _score.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_score',
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _score = value.round()),
            ),
            TextField(
              controller: _commentController,
              enabled: !_busy,
              decoration: const InputDecoration(hintText: '评论（可选）'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('仅自己可见'),
              value: _isPrivate,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _isPrivate = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('提交'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: 写评分卡**

创建 `lib/ui/subject/subject_rating_card.dart`：

```dart
// lib/ui/subject/subject_rating_card.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_collection_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../common/rating_stars.dart';
import 'subject_rating_dialog.dart';
import 'subject_side_card.dart';

/// The 评分 card at the top of the right column: aggregate score, rank,
/// rating count, the 1-10 distribution histogram, and the `☆ 打分`
/// entry point into [showSubjectRatingDialog].
///
/// The histogram was previously `_RatingHistogramSection` in
/// `subject_detail_screen.dart`; the rating form was `_RatingSection` in
/// the left column. Both now live here / in the dialog.
///
/// The backend has no rating-count field, so the count is summed from
/// `scoreDetails` (verified to match Bangumi's own `rating.count`).
class SubjectRatingCard extends ConsumerWidget {
  const SubjectRatingCard({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;
    if (subject == null) return const SizedBox.shrink();

    final selfRating = ref
        .watch(subjectCollectionControllerProvider(subjectId: subjectId))
        .value
        ?.selfRating;
    final myScore = selfRating != null && selfRating.score > 0
        ? selfRating.score
        : null;

    final details = subject.scoreDetails;
    final hasHistogram = details != null && details.isNotEmpty;
    final total = hasHistogram
        ? details.values.fold(0, (sum, count) => sum + count)
        : 0;
    final maxCount = hasHistogram && total > 0 ? details.values.reduce(max) : 0;
    final score = subject.score != null
        ? double.tryParse(subject.score!)
        : null;

    return SubjectSideCard(
      title: '评分',
      trailing: TextButton(
        onPressed: () => showSubjectRatingDialog(
          context,
          subjectId: subjectId,
          initialScore: myScore ?? 5,
          initialComment: selfRating?.comment,
          initialIsPrivate: selfRating?.isPrivate ?? false,
        ),
        child: Text(myScore == null ? '☆ 打分' : '☆ 已评 $myScore 分'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (score == null)
            Text('暂无评分', style: theme.textTheme.bodyMedium)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  subject.score!,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                RatingStars(score: score),
              ],
            ),
          if (subject.rank != null || total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (subject.rank != null) '#${subject.rank}',
                  if (total > 0) '$total 人评分',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (maxCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var score = 1; score <= 10; score++)
                    _HistogramBar(
                      score: score,
                      count: details['$score'] ?? 0,
                      maxCount: maxCount,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One bar of the 1-10 rating distribution. Ported verbatim from
/// `subject_detail_screen.dart`'s `_HistogramBar`.
class _HistogramBar extends StatelessWidget {
  const _HistogramBar({
    required this.score,
    required this.count,
    required this.maxCount,
  });

  final int score;
  final int count;
  final int maxCount;

  static const double _maxBarHeight = 48;
  static const double _minBarHeight = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = count == 0
        ? _minBarHeight
        : max(_minBarHeight, _maxBarHeight * count / maxCount);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 12,
          height: barHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text('$score', style: theme.textTheme.labelSmall),
      ],
    );
  }
}
```

- [ ] **Step 6: 运行评分卡测试确认通过**

Run: `flutter test test/ui/subject/subject_rating_card_test.dart`
Expected: PASS（7 个用例全绿）

- [ ] **Step 7: 写打分对话框的测试**

创建 `test/ui/subject/subject_rating_dialog_test.dart`：

```dart
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_rating_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

final _detail = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: '',
  airDate: '2026-07-12',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUpAll(() {
    registerFallbackValue(
      const SelfRating(score: 5, tags: [], isPrivate: false),
    );
  });

  setUp(() {
    api = MockSubjectApi();
    when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
  });


  testWidgets('starts at the initial score', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SubjectRatingDialog(subjectId: 1, initialScore: 8),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8 分'), findsOneWidget);
    expect(find.text('我的评分'), findsOneWidget);
  });

  testWidgets('prefills the comment and privacy toggle', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SubjectRatingDialog(
          subjectId: 1,
          initialScore: 7,
          initialComment: '好看',
          initialIsPrivate: true,
        ),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('好看'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });

  testWidgets('submitting sends the score and closes the dialog', (
    tester,
  ) async {
    when(
      () => api.updateCollection(1, selfRating: any(named: 'selfRating')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      wrap(
        const SubjectRatingDialog(subjectId: 1, initialScore: 9),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => api.updateCollection(
                1,
                selfRating: captureAny(named: 'selfRating'),
              ),
            ).captured.single
            as SelfRating;
    expect(captured.score, 9);
    expect(find.text('我的评分'), findsNothing);
    expect(find.text('评分已提交'), findsOneWidget);
  });

  testWidgets('keeps the dialog open and shows an error when submit fails', (
    tester,
  ) async {
    when(
      () => api.updateCollection(1, selfRating: any(named: 'selfRating')),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      wrap(
        const SubjectRatingDialog(subjectId: 1, initialScore: 6),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    expect(find.text('我的评分'), findsOneWidget);
    expect(find.textContaining('提交评分失败'), findsOneWidget);
  });

  testWidgets('cancel closes the dialog without calling the api', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showSubjectRatingDialog(context, subjectId: 1, initialScore: 5),
            child: const Text('open'),
          ),
        ),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('我的评分'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('我的评分'), findsNothing);
    verifyNever(
      () => api.updateCollection(1, selfRating: any(named: 'selfRating')),
    );
  });
}
```

- [ ] **Step 8: 运行打分对话框测试确认通过**

Run: `flutter test test/ui/subject/subject_rating_dialog_test.dart`
Expected: PASS（5 个用例全绿）

- [ ] **Step 9: 提交**

```bash
git add lib/ui/subject/subject_side_card.dart lib/ui/subject/subject_rating_dialog.dart lib/ui/subject/subject_rating_card.dart test/ui/subject/subject_rating_card_test.dart test/ui/subject/subject_rating_dialog_test.dart
git commit -m "feat(subject): add rating card with histogram and rating dialog"
```

---

### Task 20: 热门评价卡片 + 全部评价 sheet

**Files:**
- Create: `lib/ui/subject/review_avatar.dart`
- Create: `lib/ui/subject/subject_reviews_sheet.dart`
- Create: `lib/ui/subject/subject_reviews_card.dart`
- Test: `test/ui/subject/subject_reviews_card_test.dart`

依赖：Task 5（`stripBbcode`）、Task 6（`SubjectReview` / `PaginatedReviews` / `getReviews`）、Task 9（`subjectReviewsControllerProvider` + `loadMore`）、Task 19（`SubjectSideCard`）。

和 Task 17 一样，头像单独成文件，避免 card ↔ sheet 循环 import。

- [ ] **Step 1: 写 `review_avatar.dart`**

```dart
// lib/ui/subject/review_avatar.dart
import 'package:flutter/material.dart';

import '../../data/subject/review_models.dart';

/// A commenter's avatar. `avatarUrl` is often present but may 404, so
/// `onBackgroundImageError` is mandatory -- `CircleAvatar.backgroundImage`
/// has no `errorBuilder`, and an unhandled image error fails widget tests
/// (same reasoning as `CharacterAvatar`).
class ReviewAvatar extends StatelessWidget {
  const ReviewAvatar({super.key, required this.author, this.radius = 14});

  final ReviewAuthor author;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = author.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundImage: url == null ? null : NetworkImage(url),
      onBackgroundImageError: url == null ? null : (_, _) {},
      child: url == null ? Icon(Icons.person, size: radius) : null,
    );
  }
}
```

- [ ] **Step 2: 写 `subject_reviews_sheet.dart`**

```dart
// lib/ui/subject/subject_reviews_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/bbcode.dart';
import '../../domain/subject/subject_reviews_controller.dart';
import 'review_avatar.dart';

/// 「查看全部」 target for the 热门评价 card: a scrollable sheet over the
/// same `subjectReviewsControllerProvider` the card already populated, with
/// a 「加载更多」 button driven by `PaginatedReviews.hasMore`.
///
/// The backend's `total` is a `limit + 1` sentinel, NOT a real count, so
/// this sheet never renders a 「共 N 条」 header -- see `PaginatedReviews`.
class SubjectReviewsSheet extends ConsumerWidget {
  const SubjectReviewsSheet({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final provider = subjectReviewsControllerProvider(subjectId: subjectId);
    final async = ref.watch(provider);
    final page = async.value;
    final reviews = page?.items ?? const [];

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
                  Text('全部评价', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: reviews.length + 1,
                itemBuilder: (context, index) {
                  if (index == reviews.length) {
                    if (page == null || !page.hasMore) {
                      return const SizedBox(height: 16);
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: TextButton(
                          onPressed: async.isLoading
                              ? null
                              : () => ref.read(provider.notifier).loadMore(),
                          child: const Text('加载更多'),
                        ),
                      ),
                    );
                  }
                  final review = reviews[index];
                  // `stripBbcode` already trims, and returns '' for an
                  // image-only / mask-only review. Pass `null` rather than
                  // `Text('')` in that case -- an empty `Text` is still a
                  // full line height and pushes `ListTile` into its
                  // two-line layout, leaving a visibly blank second row.
                  final content = stripBbcode(review.contentBbcode ?? '');
                  return ListTile(
                    leading: ReviewAvatar(author: review.author, radius: 18),
                    title: Text(review.author.nickname),
                    subtitle: content.isEmpty ? null : Text(content),
                    trailing: review.rating == null
                        ? null
                        : Text(
                            '${review.rating}',
                            style: theme.textTheme.titleSmall,
                          ),
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
```

- [ ] **Step 3: 写失败的 card 测试**

```dart
// test/ui/subject/subject_reviews_card_test.dart
import 'dart:async';

import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/ui/subject/subject_reviews_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectReview review({
  required String id,
  required String nickname,
  String? content,
  int? rating,
}) => SubjectReview(
  id: id,
  subjectId: 1,
  source: 'bangumi',
  author: ReviewAuthor(id: id, nickname: nickname),
  contentBbcode: content,
  rating: rating,
);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUp(() {
    api = MockSubjectApi();
    overrides = [subjectApiProvider.overrideWithValue(api)];
  });

  void stubReviews(List<SubjectReview> items, {int? total}) {
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          PaginatedReviews(total: total ?? items.length, items: items),
    );
  }

  testWidgets('renders the nickname and BBCode-stripped content', (
    tester,
  ) async {
    stubReviews([
      review(id: 'a', nickname: 'Sparrow', content: '[b]太穷了吧[/b]'),
    ]);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('热门评价'), findsOneWidget);
    expect(find.text('Sparrow'), findsOneWidget);
    expect(find.text('太穷了吧'), findsOneWidget);
    expect(find.text('[b]太穷了吧[/b]'), findsNothing);
  });

  testWidgets('shows at most maxVisible reviews', (tester) async {
    stubReviews([
      for (var i = 0; i < 6; i++)
        review(id: '$i', nickname: 'user$i', content: 'c$i'),
    ]);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('user0'), findsOneWidget);
    expect(
      find.text('user${SubjectReviewsCard.maxVisible - 1}'),
      findsOneWidget,
    );
    expect(find.text('user${SubjectReviewsCard.maxVisible}'), findsNothing);
  });

  testWidgets('hides the whole card when there are no reviews', (
    tester,
  ) async {
    stubReviews(const []);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('热门评价'), findsNothing);
  });

  testWidgets('hides the whole card when the request fails', (tester) async {
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenThrow(Exception('network error'));

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('热门评价'), findsNothing);
  });

  testWidgets('keeps the card frame with a spinner while loading', (
    tester,
  ) async {
    final completer = Completer<PaginatedReviews>();
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pump();

    expect(find.text('热门评价'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const PaginatedReviews(total: 0, items: []));
    await tester.pumpAndSettle();
  });

  testWidgets('tapping 查看全部 opens the full reviews sheet', (tester) async {
    stubReviews([
      review(id: 'a', nickname: 'Sparrow', content: 'good'),
    ], total: 21);

    await tester.pumpWidget(
      wrap(const SubjectReviewsCard(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部 ›'));
    await tester.pumpAndSettle();

    expect(find.text('全部评价'), findsOneWidget);
    expect(find.text('加载更多'), findsOneWidget);
  });
}
```

- [ ] **Step 4: 运行测试，确认失败**

Run: `flutter test test/ui/subject/subject_reviews_card_test.dart`
Expected: FAIL —— `Error: Couldn't resolve the package 'animeko_flutter' ... subject_reviews_card.dart` / `Undefined name 'SubjectReviewsCard'`。

- [ ] **Step 5: 写 `subject_reviews_card.dart`**

```dart
// lib/ui/subject/subject_reviews_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/bbcode.dart';
import '../../data/subject/review_models.dart';
import '../../domain/subject/subject_reviews_controller.dart';
import 'review_avatar.dart';
import 'subject_reviews_card_frame.dart';
import 'subject_reviews_sheet.dart';

/// 热门评价 card for the right column: the first few other-user comments,
/// with 「查看全部 ›」 opening [SubjectReviewsSheet] over the same provider.
///
/// Failure and empty are both silent (the whole card disappears) -- reviews
/// are a nice-to-have, and the reference app's sidebar simply has one fewer
/// card when they're unavailable. Loading keeps the card frame so the
/// right column doesn't jump once the request lands.
class SubjectReviewsCard extends ConsumerWidget {
  const SubjectReviewsCard({super.key, required this.subjectId});

  final int subjectId;

  /// How many reviews the card shows before 「查看全部」. Estimate from the
  /// design doc (the reference screenshot shows 2-3); adjust freely.
  static const int maxVisible = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      subjectReviewsControllerProvider(subjectId: subjectId),
    );
    final page = async.value;

    if (page == null) {
      if (!async.isLoading) return const SizedBox.shrink();
      return const SubjectReviewsCardFrame(
        child: SizedBox(
          height: 64,
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

    if (page.items.isEmpty) return const SizedBox.shrink();

    return SubjectReviewsCardFrame(
      onSeeAll: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SubjectReviewsSheet(subjectId: subjectId),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final review in page.items.take(maxVisible))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReviewItem(review: review),
            ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});

  final SubjectReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `stripBbcode` already trims, so no `.trim()` here. It returns ''
    // for an image-only / mask-only review, which the `isNotEmpty` guard
    // below turns into "render no body line at all".
    final content = stripBbcode(review.contentBbcode ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ReviewAvatar(author: review.author),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                review.author.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: 写 `subject_reviews_card_frame.dart`**

`SubjectReviewsCard` 的 loading 分支和 data 分支要共用同一个卡壳（标题 + 可选「查看全部 ›」），抽成一个薄封装，避免在两个分支里重复写 `SubjectSideCard` 的参数。

```dart
// lib/ui/subject/subject_reviews_card_frame.dart
import 'package:flutter/material.dart';

import 'subject_side_card.dart';

/// The 热门评价 card shell, shared by [SubjectReviewsCard]'s loading and
/// data branches so the frame is identical in both (no layout jump).
class SubjectReviewsCardFrame extends StatelessWidget {
  const SubjectReviewsCardFrame({
    super.key,
    required this.child,
    this.onSeeAll,
  });

  final Widget child;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SubjectSideCard(
      title: '热门评价',
      trailing: onSeeAll == null
          ? null
          : TextButton(onPressed: onSeeAll, child: const Text('查看全部 ›')),
      child: child,
    );
  }
}
```

- [ ] **Step 7: 运行测试，确认通过**

Run: `flutter test test/ui/subject/subject_reviews_card_test.dart`
Expected: PASS（6 个测试）。

- [ ] **Step 8: 提交**

```bash
git add lib/ui/subject/review_avatar.dart lib/ui/subject/subject_reviews_card_frame.dart lib/ui/subject/subject_reviews_card.dart lib/ui/subject/subject_reviews_sheet.dart test/ui/subject/subject_reviews_card_test.dart
git commit -m "feat(subject): add popular reviews card and full reviews sheet"
```

---

### Task 21: 制作人员卡片 + 全部制作人员 sheet（infobox 驱动）

**Files:**
- Create: `lib/ui/subject/subject_staff_sheet.dart`
- Create: `lib/ui/subject/subject_staff_card.dart`
- Test: `test/ui/subject/subject_staff_card_test.dart`

依赖：Task 2（`SubjectDetail.staffFields` + `subjectInfoboxNonStaffKeys`）、Task 4（旧 staff 链已删）、Task 19（`SubjectSideCard`）。

数据来自 `subjectDetailControllerProvider`，**不再有单独的 staff 请求**。

- [ ] **Step 1: 写 `subject_staff_sheet.dart`**

```dart
// lib/ui/subject/subject_staff_sheet.dart
import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';

/// 「查看全部」 target for the 制作人员 card. Takes the already-fetched
/// [InfoboxField] list instead of watching a provider, because the card's
/// data is a plain getter off the subject detail the caller already has.
class SubjectStaffSheet extends StatelessWidget {
  const SubjectStaffSheet({super.key, required this.fields});

  final List<InfoboxField> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  Text('全部制作人员', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${fields.length}',
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
                itemCount: fields.length,
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return ListTile(
                    title: Text(field.key),
                    subtitle: Text(
                      field.values.map((value) => value.v).join('、'),
                    ),
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
```

- [ ] **Step 2: 写失败的测试**

```dart
// test/ui/subject/subject_staff_card_test.dart
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_staff_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectDetail detailWith(SubjectInfobox? infobox) => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 's',
  airDate: '2026-07-12',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  infobox: infobox,
);

InfoboxField field(String key, List<String> values) => InfoboxField(
  key: key,
  values: [for (final value in values) InfoboxValue(v: value)],
);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders one row per staff infobox field', (tester) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          field('原作', ['中村颯希（作家）']),
          field('音乐', ['橋本由香利']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('制作人员'), findsOneWidget);
    expect(find.text('原作'), findsOneWidget);
    expect(find.text('中村颯希（作家）'), findsOneWidget);
    expect(find.text('音乐'), findsOneWidget);
    expect(find.text('橋本由香利'), findsOneWidget);
  });

  testWidgets('joins multiple values of one role', (tester) async {
    final subject = detailWith(
      SubjectInfobox(fields: [field('系列构成', ['田口智久', '平松正樹'])]),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('田口智久、平松正樹'), findsOneWidget);
  });

  testWidgets('excludes non-staff infobox keys', (tester) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [
          field('放送开始', ['2026年7月12日']),
          field('话数', ['11']),
          field('官方网站', ['https://example.com']),
          field('导演', ['佐藤']),
        ],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('导演'), findsOneWidget);
    expect(find.text('放送开始'), findsNothing);
    expect(find.text('话数'), findsNothing);
    expect(find.text('官方网站'), findsNothing);
  });

  testWidgets('keeps unknown roles that are not on the blocklist', (
    tester,
  ) async {
    final subject = detailWith(
      SubjectInfobox(fields: [field('某个没见过的职位', ['某人'])]),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('某个没见过的职位'), findsOneWidget);
    expect(find.text('某人'), findsOneWidget);
  });

  testWidgets('hides the whole card when infobox is null', (tester) async {
    await tester.pumpWidget(wrap(SubjectStaffCard(subject: detailWith(null))));

    expect(find.text('制作人员'), findsNothing);
  });

  testWidgets('hides the whole card when every field is filtered out', (
    tester,
  ) async {
    final subject = detailWith(
      SubjectInfobox(fields: [field('话数', ['11'])]),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('制作人员'), findsNothing);
  });

  testWidgets('shows at most maxVisible rows and opens the sheet', (
    tester,
  ) async {
    final subject = detailWith(
      SubjectInfobox(
        fields: [for (var i = 0; i < 12; i++) field('职位$i', ['人$i'])],
      ),
    );

    await tester.pumpWidget(wrap(SubjectStaffCard(subject: subject)));

    expect(find.text('职位0'), findsOneWidget);
    expect(
      find.text('职位${SubjectStaffCard.maxVisible - 1}'),
      findsOneWidget,
    );
    expect(find.text('职位${SubjectStaffCard.maxVisible}'), findsNothing);

    await tester.tap(find.text('查看全部 ›'));
    await tester.pumpAndSettle();

    expect(find.text('全部制作人员'), findsOneWidget);
    expect(find.text('职位11'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/ui/subject/subject_staff_card_test.dart`
Expected: FAIL —— `Error: Couldn't resolve the package ... subject_staff_card.dart` / `Undefined name 'SubjectStaffCard'`。

- [ ] **Step 4: 写 `subject_staff_card.dart`**

```dart
// lib/ui/subject/subject_staff_card.dart
import 'package:flutter/material.dart';

import '../../data/subject/subject_models.dart';
import 'subject_side_card.dart';
import 'subject_staff_sheet.dart';

/// 制作人员 card for the right column.
///
/// Driven entirely by `SubjectDetail.staffFields` (the subject response's
/// `infobox`), NOT by a `/staff` request. The `/staff` endpoint returns int
/// `position` codes (52 distinct values on one subject) that would need a
/// hand-maintained code -> Chinese label table; `infobox` already carries
/// Chinese role names, so the whole staff API chain was deleted in Task 4.
///
/// Takes the subject as a parameter instead of watching the provider so the
/// widget stays a plain `StatelessWidget` -- the parent pane already has the
/// loaded `SubjectDetail`.
class SubjectStaffCard extends StatelessWidget {
  const SubjectStaffCard({super.key, required this.subject});

  final SubjectDetail subject;

  /// How many roles the card shows before 「查看全部」. Estimate; the
  /// reference screenshot shows ~8 rows in the sidebar.
  static const int maxVisible = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = subject.staffFields;
    if (fields.isEmpty) return const SizedBox.shrink();

    final visible = fields.take(maxVisible).toList();

    return SubjectSideCard(
      title: '制作人员',
      trailing: fields.length <= maxVisible
          ? null
          : TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SubjectStaffSheet(fields: fields),
              ),
              child: const Text('查看全部 ›'),
            ),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        children: [
          for (final field in visible)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 6),
                  child: Text(
                    field.key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    field.values.map((value) => value.v).join('、'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/ui/subject/subject_staff_card_test.dart`
Expected: PASS（7 个测试）。

- [ ] **Step 6: 提交**

```bash
git add lib/ui/subject/subject_staff_card.dart lib/ui/subject/subject_staff_sheet.dart test/ui/subject/subject_staff_card_test.dart
git commit -m "feat(subject): drive staff card from infobox instead of /staff"
```

---

### Task 22: 三个 pane 容器 + 封面组件

**Files:**
- Create: `lib/ui/subject/subject_cover.dart`
- Create: `lib/ui/subject/subject_detail_left_pane.dart`
- Create: `lib/ui/subject/subject_detail_main_pane.dart`
- Create: `lib/ui/subject/subject_detail_side_pane.dart`
- Test: `test/ui/subject/subject_detail_panes_test.dart`

这三个 pane 只做「按顺序摆放子组件」这一件事，不含任何业务逻辑，
所以 Task 23 的 `subject_detail_screen.dart` 只需要在宽/窄两种布局里
摆放这三个 pane（窄屏时左栏内容会被拆开重排，见 Task 23）。

`subject_cover.dart` 单独成文件，因为宽屏左栏（200dp）和窄屏顶部横向
头部（120dp）都要用它，只有宽度不同。

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_detail_panes_test.dart`：

```dart
import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/subject/expandable_summary.dart';
import 'package:animeko_flutter/ui/subject/subject_cover.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_left_pane.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_main_pane.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_side_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const _episode = SubjectEpisode(
  episodeId: 11,
  sort: 1,
  ep: '1',
  type: 'MAIN',
  name: 'EN 1',
  nameCn: '第一集',
  airdate: '2026-07-12',
);

SubjectDetail _detail() => SubjectDetail(
  id: 1,
  name: 'Original Name',
  nameCn: '中文名',
  summary: '这是简介正文。',
  airDate: '2026-07-12',
  tags: const [SubjectTag(name: '奇幻', count: 12)],
  score: '7.9',
  rank: 325,
  collectionType: CollectionType.doing,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  favorite: const SubjectFavorite(
    wish: 1449,
    done: 7781,
    doing: 5959,
    onHold: 12,
    dropped: 3,
  ),
  infobox: const SubjectInfobox(
    fields: [
      InfoboxField(key: '导演', values: [InfoboxValue(v: '某导演')]),
    ],
  ),
  scoreDetails: const {'7': 100},
  episodes: const [_episode],
);

Widget _wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUpAll(() {
    registerFallbackValue(CollectionType.wish);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockSubjectApi();
    when(() => api.getSubject(1)).thenAnswer((_) async => _detail());
    when(() => api.getCharacters(1)).thenAnswer((_) async => []);
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const PaginatedReviews(total: 0, items: []));
    overrides = [
      subjectApiProvider.overrideWithValue(api),
      mediaSourcesProvider.overrideWithValue(const <MediaSource>[]),
    ];
  });

  group('SubjectCover', () {
    testWidgets('renders a placeholder icon when the url is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SubjectCover(imageUrl: null, width: 200)),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(tester.getSize(find.byType(SubjectCover)).width, 200);
    });
  });

  group('SubjectDetailLeftPane', () {
    testWidgets('stacks cover, buttons, stats and the info table', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            child: SubjectDetailLeftPane(
              subjectId: 1,
              subjectName: '中文名',
              imageUrl: null,
            ),
          ),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SubjectCover), findsOneWidget);
      expect(find.text('开始观看'), findsOneWidget);
      expect(find.text('在看'), findsOneWidget);
      expect(find.text('7,781'), findsOneWidget);
      expect(find.text('作品信息'), findsOneWidget);
    });
  });

  group('SubjectDetailMainPane', () {
    testWidgets('stacks title, summary, episodes and characters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SubjectDetailMainPane(subjectId: 1, subjectName: '中文名'),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('中文名'), findsOneWidget);
      expect(find.byType(ExpandableSummary), findsOneWidget);
      expect(find.text('选集'), findsOneWidget);
    });
  });

  group('SubjectDetailSidePane', () {
    testWidgets('stacks the rating card and the staff card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            child: SubjectDetailSidePane(subjectId: 1),
          ),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('评分'), findsOneWidget);
      expect(find.text('制作人员'), findsOneWidget);
      expect(find.text('导演'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/ui/subject/subject_detail_panes_test.dart
```

预期：编译失败，`Error: Couldn't resolve the package 'animeko_flutter' ... subject_cover.dart` 之类的
「找不到文件 / Undefined class 'SubjectCover'」错误。

- [ ] **Step 3: 创建 `lib/ui/subject/subject_cover.dart`**

```dart
// lib/ui/subject/subject_cover.dart
import 'package:flutter/material.dart';

/// The subject cover image, rounded and clipped to the reference app's
/// 849:1200 poster aspect ratio.
///
/// Lives in its own file because two different layouts need it at two
/// different widths: the wide-screen left column (200dp) and the narrow
/// -screen horizontal top header (120dp).
///
/// [imageUrl] is nullable because no subject endpoint returns a cover --
/// it arrives as a route query parameter (see `SubjectDetailScreen`), so
/// deep links without it must still render.
class SubjectCover extends StatelessWidget {
  const SubjectCover({super.key, required this.imageUrl, required this.width});

  /// The reference app's poster ratio (`849:1200`), same value the old
  /// `SubjectBlurredHeader` used for its sharp thumbnail.
  static const double aspectRatio = 849 / 1200;

  final String? imageUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: url == null
              ? _placeholder(context)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(context),
                ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}
```

- [ ] **Step 4: 创建 `lib/ui/subject/subject_detail_left_pane.dart`**

```dart
// lib/ui/subject/subject_detail_left_pane.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_detail_controller.dart';
import 'continue_watching_button.dart';
import 'subject_collection_action_button.dart';
import 'subject_collection_stats.dart';
import 'subject_cover.dart';
import 'subject_info_table.dart';

/// Wide-screen left column: cover, the two primary actions, aggregate
/// collection counts, and the 作品信息 table.
///
/// Pure composition -- no business logic, no width of its own (the parent
/// constrains it to 200dp). The narrow-screen layout does NOT use this
/// widget; it re-arranges the same children into a horizontal header plus
/// a stacked info table (see `SubjectDetailScreen`).
class SubjectDetailLeftPane extends ConsumerWidget {
  const SubjectDetailLeftPane({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.imageUrl,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubjectCover(imageUrl: imageUrl, width: 200),
        const SizedBox(height: 16),
        ContinueWatchingButton(subjectId: subjectId, subjectName: subjectName),
        const SizedBox(height: 8),
        SubjectCollectionActionButton(
          subjectId: subjectId,
          imageUrl: imageUrl,
        ),
        const SizedBox(height: 16),
        SubjectCollectionStats(favorite: subject?.favorite),
        const SizedBox(height: 16),
        if (subject != null) SubjectInfoTable(subject: subject),
      ],
    );
  }
}
```

- [ ] **Step 5: 创建 `lib/ui/subject/subject_detail_main_pane.dart`**

```dart
// lib/ui/subject/subject_detail_main_pane.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_detail_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import 'expandable_summary.dart';
import 'subject_character_row.dart';
import 'subject_episodes_section.dart';
import 'subject_title_block.dart';

/// Middle column: title block, summary, 选集 grid, 角色 row.
///
/// Pure composition. Used unchanged by both the wide and the narrow
/// layout -- only its width differs.
class SubjectDetailMainPane extends ConsumerWidget {
  const SubjectDetailMainPane({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.showTitle = true,
    this.now,
  });

  final int subjectId;
  final String subjectName;

  /// The narrow layout renders [SubjectTitleBlock] inside its horizontal
  /// top header instead (next to the cover), so it passes `false` here to
  /// avoid showing the title twice.
  final bool showTitle;

  /// Test-only override for "today" -- forwarded to the meta line and the
  /// 选集 progress label so tests don't depend on the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;
    final episodes =
        ref
            .watch(subjectMainEpisodesControllerProvider(subjectId: subjectId))
            .value ??
        const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle && subject != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SubjectTitleBlock(
              subject: subject,
              episodes: episodes,
              now: now,
            ),
          ),
        if (subject != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ExpandableSummary(text: subject.summary),
          ),
        SubjectEpisodesSection(
          subjectId: subjectId,
          subjectName: subjectName,
          now: now,
        ),
        SubjectCharacterRow(subjectId: subjectId),
      ],
    );
  }
}
```

- [ ] **Step 6: 创建 `lib/ui/subject/subject_detail_side_pane.dart`**

```dart
// lib/ui/subject/subject_detail_side_pane.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_detail_controller.dart';
import 'subject_rating_card.dart';
import 'subject_reviews_card.dart';
import 'subject_staff_card.dart';

/// Right column: the three cards, top to bottom.
///
/// Pure composition. Each card hides itself when its own data is missing
/// (see the design doc's error-tier table), so this widget has no
/// conditional logic beyond waiting for the subject payload the staff
/// card needs.
class SubjectDetailSidePane extends ConsumerWidget {
  const SubjectDetailSidePane({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubjectRatingCard(subjectId: subjectId),
        SubjectReviewsCard(subjectId: subjectId),
        if (subject != null) SubjectStaffCard(subject: subject),
      ],
    );
  }
}
```

- [ ] **Step 7: 运行测试确认通过**

```bash
flutter test test/ui/subject/subject_detail_panes_test.dart
```

预期：4 个测试全部通过。

- [ ] **Step 8: 提交**

```bash
git add lib/ui/subject/subject_cover.dart lib/ui/subject/subject_detail_left_pane.dart lib/ui/subject/subject_detail_main_pane.dart lib/ui/subject/subject_detail_side_pane.dart test/ui/subject/subject_detail_panes_test.dart
git commit -m "feat(subject): add left/main/side panes and shared cover widget"
```

---

### Task 23: 重写 `subject_detail_screen.dart`（三栏 / 单栏断点）

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart`（整体重写，780 行 → 约 170 行）
- Test: `test/ui/subject/subject_detail_screen_test.dart`（新建）

这个文件重写后**只负责三件事**：`Scaffold` + 无标题 `AppBar`、
主数据的整页 loading / error、以及按 `subjectDetailThreeColumnBreakpoint`
在宽屏 `Row` 和窄屏 `Column` 之间切换。所有区块内容都已在
Task 11–22 里实现，这里只做摆放。

原文件里的 `_ImmersiveHeader` / `_HeaderInfo` / `_CollectionButtons` /
`_WorkInfoSection` / `_SubjectInfoSection` / `_RatingSection` /
`_EpisodesSection` / `_CharacterSection` / `_RatingHistogramSection` /
`_HistogramBar` / `_formatAirDateYearMonth` 全部删除——它们的行为已经分别
搬到了 Task 11–22 的新文件里。

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/subject_detail_screen_test.dart`：

```dart
import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/common/error_retry_view.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_left_pane.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_main_pane.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_screen.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_side_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const _episode = SubjectEpisode(
  episodeId: 11,
  sort: 1,
  ep: '1',
  type: 'MAIN',
  name: 'EN 1',
  nameCn: '第一集',
  airdate: '2026-07-12',
);

SubjectDetail _detail() => SubjectDetail(
  id: 1,
  name: 'Original Name',
  nameCn: '中文名',
  summary: '这是简介正文。',
  airDate: '2026-07-12',
  tags: const [SubjectTag(name: '奇幻', count: 12)],
  score: '7.9',
  rank: 325,
  collectionType: CollectionType.doing,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  favorite: const SubjectFavorite(
    wish: 1449,
    done: 7781,
    doing: 5959,
    onHold: 12,
    dropped: 3,
  ),
  infobox: const SubjectInfobox(
    fields: [
      InfoboxField(key: '导演', values: [InfoboxValue(v: '某导演')]),
    ],
  ),
  scoreDetails: const {'7': 100},
  episodes: const [_episode],
);

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUpAll(() {
    registerFallbackValue(CollectionType.wish);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockSubjectApi();
    when(() => api.getSubject(1)).thenAnswer((_) async => _detail());
    when(() => api.getCharacters(1)).thenAnswer((_) async => []);
    when(
      () => api.getReviews(
        subjectId: any(named: 'subjectId'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const PaginatedReviews(total: 0, items: []));
    overrides = [
      subjectApiProvider.overrideWithValue(api),
      mediaSourcesProvider.overrideWithValue(const <MediaSource>[]),
    ];
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    List<Override>? withOverrides,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: withOverrides ?? overrides,
        child: const MaterialApp(
          home: SubjectDetailScreen(
            subjectId: 1,
            subjectName: '中文名',
            imageUrl: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lays the three panes out side by side at 1400x900', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1400, 900));

    final left = tester.getTopLeft(find.byType(SubjectDetailLeftPane));
    final main = tester.getTopLeft(find.byType(SubjectDetailMainPane));
    final side = tester.getTopLeft(find.byType(SubjectDetailSidePane));

    expect(left.dx, lessThan(main.dx));
    expect(main.dx, lessThan(side.dx));
    expect(tester.getSize(find.byType(SubjectDetailLeftPane)).width, 200);
    expect(tester.getSize(find.byType(SubjectDetailSidePane)).width, 300);
  });

  testWidgets('stacks content in one column at 800x900', (tester) async {
    await pumpAt(tester, const Size(800, 900));

    expect(find.byType(SubjectDetailLeftPane), findsNothing);
    final main = tester.getTopLeft(find.byType(SubjectDetailMainPane));
    final side = tester.getTopLeft(find.byType(SubjectDetailSidePane));
    expect(main.dy, lessThan(side.dy));
    expect(main.dx, equals(side.dx));
  });

  testWidgets('shows the collection stats once in the narrow layout', (
    tester,
  ) async {
    await pumpAt(tester, const Size(800, 900));

    expect(find.text('7,781'), findsOneWidget);
    expect(find.text('中文名'), findsOneWidget);
  });

  testWidgets('shows a whole-page retry when the subject request fails', (
    tester,
  ) async {
    when(() => api.getSubject(1)).thenThrow(Exception('network error'));

    await pumpAt(tester, const Size(1400, 900));

    expect(find.byType(ErrorRetryView), findsOneWidget);
    expect(find.textContaining('加载详情失败'), findsOneWidget);
    expect(find.byType(SubjectDetailMainPane), findsNothing);
  });

  testWidgets('the app bar carries no title', (tester) async {
    await pumpAt(tester, const Size(1400, 900));

    expect(find.descendant(of: find.byType(AppBar), matching: find.byType(Text)), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/ui/subject/subject_detail_screen_test.dart
```

预期：多条失败。至少 `lays the three panes out side by side` 会因为
`SubjectDetailLeftPane` 根本没被旧屏幕用到而报
`Expected: exactly one matching candidate / Actual: _TypeWidgetFinder:<Found 0 widgets>`。

- [ ] **Step 3: 用下面内容整体覆盖 `lib/ui/subject/subject_detail_screen.dart`**

```dart
// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../data/subject/subject_models.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import '../common/error_retry_view.dart';
import 'continue_watching_button.dart';
import 'subject_collection_action_button.dart';
import 'subject_collection_stats.dart';
import 'subject_cover.dart';
import 'subject_detail_left_pane.dart';
import 'subject_detail_main_pane.dart';
import 'subject_detail_side_pane.dart';
import 'subject_info_table.dart';
import 'subject_title_block.dart';

/// The subject detail page.
///
/// This widget owns ONLY three things:
///
/// 1. the `Scaffold` and a deliberately title-less `AppBar` (the title now
///    lives in the middle column, so repeating it in the bar wastes a row
///    and duplicates text -- see the design doc's AppBar decision);
/// 2. the whole-page loading spinner / retry view for the ONE request the
///    whole page depends on (`subjectDetailControllerProvider`); every
///    other data source degrades inside its own section;
/// 3. the wide-vs-narrow layout branch at
///    [subjectDetailThreeColumnBreakpoint].
///
/// All section content lives in the pane widgets and the leaf widgets they
/// compose. Do not add section markup here.
///
/// [imageUrl] arrives as a route query parameter because no subject
/// endpoint returns a cover image (verified against the backend).
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.imageUrl,
    this.now,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  /// Test-only override for "today", forwarded to the meta line and the
  /// 选集 progress label.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      subjectDetailControllerProvider(subjectId: subjectId),
    );

    return Scaffold(
      appBar: AppBar(),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: ErrorRetryView(
            message: '加载详情失败：$error',
            onRetry: () => ref.invalidate(
              subjectDetailControllerProvider(subjectId: subjectId),
            ),
          ),
        ),
        data: (subject) => LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= subjectDetailThreeColumnBreakpoint;
            return SingleChildScrollView(
              padding: EdgeInsets.all(pagePadding(context)),
              child: isWide ? _wide() : _narrow(ref, subject),
            );
          },
        ),
      ),
    );
  }

  Widget _wide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: SubjectDetailLeftPane(
            subjectId: subjectId,
            subjectName: subjectName,
            imageUrl: imageUrl,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: SubjectDetailMainPane(
            subjectId: subjectId,
            subjectName: subjectName,
            now: now,
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 300,
          child: SubjectDetailSidePane(subjectId: subjectId),
        ),
      ],
    );
  }

  /// Narrow layout: the left column's children are re-arranged rather than
  /// reused as a block -- the cover sits beside the title in a horizontal
  /// header (a 200dp poster would eat the whole screen), and the three side
  /// cards move to the bottom.
  Widget _narrow(WidgetRef ref, SubjectDetail subject) {
    final episodes =
        ref
            .watch(subjectMainEpisodesControllerProvider(subjectId: subjectId))
            .value ??
        const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SubjectCover(imageUrl: imageUrl, width: 120),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SubjectTitleBlock(
                    subject: subject,
                    episodes: episodes,
                    now: now,
                  ),
                  const SizedBox(height: 12),
                  ContinueWatchingButton(
                    subjectId: subjectId,
                    subjectName: subjectName,
                  ),
                  const SizedBox(height: 8),
                  SubjectCollectionActionButton(
                    subjectId: subjectId,
                    imageUrl: imageUrl,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SubjectCollectionStats(favorite: subject.favorite),
        const SizedBox(height: 16),
        SubjectInfoTable(subject: subject),
        const SizedBox(height: 16),
        SubjectDetailMainPane(
          subjectId: subjectId,
          subjectName: subjectName,
          showTitle: false,
          now: now,
        ),
        const SizedBox(height: 16),
        SubjectDetailSidePane(subjectId: subjectId),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/ui/subject/subject_detail_screen_test.dart
```

预期：5 个测试全部通过。

如果 `the app bar carries no title` 失败并显示找到了 `Text`，说明
`AppBar()` 在当前 Flutter 版本里仍然渲染了某个隐式 `Text`（例如
`MaterialLocalizations` 的返回按钮 tooltip 变成了 `Text`）。这时把断言
改成更精确的 `expect(find.descendant(of: find.byType(AppBar), matching: find.text('中文名')), findsNothing);`
——真正要保证的是**标题不重复出现在 AppBar 里**。

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/subject_detail_screen.dart test/ui/subject/subject_detail_screen_test.dart
git commit -m "feat(subject): rewrite detail screen as responsive three-column layout"
```

---

### Task 24: 播放时记录「最近播放集数」

**Files:**
- Modify: `lib/ui/subject/episode_playback_sheet.dart`
- Test: `test/ui/subject/episode_playback_sheet_last_played_test.dart`（新建）

Task 7/8 建立的 `LastPlayedEpisodeStorage` + `continueWatchingProvider`
到这一步之前**永远读不到任何记录**，因为还没有人写入。这一步补上写入方。

**为什么写在 `EpisodePlaybackSheet` 而不是 `PlayerScreen`：**
`PlayerScreen` 里的 `_currentEpisode` 是 `MergedEpisode`（scraper 侧的
条目，只有 `sourceId` + `title`，**没有 Bangumi `episodeId`**，见
`PlayerScreen._positionKey` 的注释）。Bangumi 的 `episodeId` 只在
`EpisodePlaybackSheet` 这一层还拿得到（它持有 `SubjectEpisode episode`）。
在这里写入既拿得到 id，又不需要给 `MergedEpisode` 加一条
episodeId↔scraper 的映射。

**已知取舍（必须接受）：** 用户在播放器内部切集（`PlayerScreen` 的
自动连播和右侧抽屉里的 `EpisodeSourceGrid`）不会更新这条记录，因为那两处
只有 `MergedEpisode`。所以「继续观看」指向的是**最后一次从详情页点开的集**，
不是最后一次实际播放的集。这符合设计文档「不做完整的单集观看进度系统」的范围。

- [ ] **Step 1: 写失败测试**

创建 `test/ui/subject/episode_playback_sheet_last_played_test.dart`：

```dart
import 'package:animeko_flutter/data/play/last_played_episode_storage.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/episode_playback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _episode = SubjectEpisode(
  episodeId: 42,
  sort: 1,
  ep: '1',
  type: 'MAIN',
  name: 'EN 1',
  nameCn: '第一集',
  airdate: '2026-07-12',
);

/// `MediaEpisode` is an abstract interface, so tests implement it by hand
/// -- same pattern as `test/ui/subject/episode_playback_sheet_test.dart`.
class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});
  @override
  final String sourceId;
  @override
  final String title;
}

const _merged = MergedEpisode(
  episode: _FakeEpisode(sourceId: 'src', title: '第1话'),
  sourceId: 'src',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tapping 播放 records the episode id and navigates', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: EpisodePlaybackSheet(
              subjectId: 1,
              subjectName: '中文名',
              ordinalIndex: 0,
              episode: _episode,
            ),
          ),
        ),
        GoRoute(
          path: '/subject/:subjectId/play',
          builder: (context, state) =>
              const Scaffold(body: Text('player screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaSourcesProvider.overrideWithValue(const <MediaSource>[]),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: '中文名',
          ).overrideWith(() => _FakeEpisodes()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(LastPlayedEpisodeStorage(prefs).get(1), 42);
    expect(find.text('player screen'), findsOneWidget);
  });
}

class _FakeEpisodes extends SubjectEpisodesController {
  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => const [_merged];
}
```

如果 `MergedEpisode` 的构造参数名与上面不一致，先运行
`rg -n "class MergedEpisode" -A 20 lib/domain/play/subject_episodes_controller.dart`
按真实字段名调整这个 fixture——只改 fixture，不改被测代码。

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/ui/subject/episode_playback_sheet_last_played_test.dart
```

预期：FAIL，`Expected: 42 / Actual: <null>`——因为还没有人写入。

- [ ] **Step 3: 修改 `lib/ui/subject/episode_playback_sheet.dart`**

在 import 区加两行（保持字母序）：

```dart
import '../../data/play/last_played_episode_storage.dart';
import '../../domain/subject/continue_watching_controller.dart';
```

把 `播放` 按钮的 `onPressed` 从

```dart
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/subject/$subjectId/play'
                              '?name=${Uri.encodeComponent(subjectName)}',
                              extra: match,
                            );
                          },
```

改为

```dart
                          onPressed: () async {
                            // Remember which Bangumi episode was opened so
                            // the detail page's 继续观看 button can point
                            // back at it. This is the ONLY place that still
                            // knows the Bangumi `episodeId` -- `PlayerScreen`
                            // only ever sees `MergedEpisode`.
                            final storage = await ref.read(
                              lastPlayedEpisodeStorageProvider.future,
                            );
                            await storage.set(subjectId, episode.episodeId);
                            // `lastPlayedEpisodeStorageProvider` yields a
                            // mutable object, so nothing re-emits on write --
                            // invalidate the derived provider explicitly or
                            // the button keeps its old label.
                            ref.invalidate(
                              continueWatchingProvider(subjectId: subjectId),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            context.push(
                              '/subject/$subjectId/play'
                              '?name=${Uri.encodeComponent(subjectName)}',
                              extra: match,
                            );
                          },
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/ui/subject/episode_playback_sheet_last_played_test.dart test/ui/subject/episode_playback_sheet_test.dart
```

预期：全部通过（新增 1 个 + 原有 3 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/ui/subject/episode_playback_sheet.dart test/ui/subject/episode_playback_sheet_last_played_test.dart
git commit -m "feat(subject): record last played episode when playback starts"
```

---

### Task 25: 删除废弃文件 + 全量回归

**Files:**
- Delete: `lib/ui/subject/subject_blurred_header.dart`
- Delete: `test/ui/subject/subject_blurred_header_test.dart`

- [ ] **Step 1: 确认没有别处引用**

```bash
rg -n "subject_blurred_header|SubjectBlurredHeader" lib test
```

预期：只剩这两个待删文件自身的匹配。如果 `lib/ui/**` 里还有别的引用
（例如某个页面复用了这个头图），**先停下**把那处改掉再删——不要为了让
命令通过而留下一个没人用的文件。

- [ ] **Step 2: 删除**

```bash
git rm lib/ui/subject/subject_blurred_header.dart test/ui/subject/subject_blurred_header_test.dart
```

- [ ] **Step 3: 静态分析**

```bash
flutter analyze
```

预期：`No issues found!`，或只剩项目原有的 info 级提示（本仓库允许 info，
**不允许 error/warning**）。如果出现 `unused_import`，按提示删掉对应
import；如果出现 `Undefined name`，说明某个 Task 的重命名没同步，回到
对应 Task 修正。

- [ ] **Step 4: 全量测试**

```bash
flutter test
```

预期：全部通过。原有 ~359 个测试 + 本计划新增的测试。

若 `test/ui/subject/episode_number_grid_test.dart` 失败，检查 Task 18 里
对 `EpisodeNumberGrid` 的 padding/header 删除是否改动了它断言的文本
（已核实原测试不断言 `剧集` 与 padding，理论上不该失败）。

- [ ] **Step 5: 手动验收（macOS）**

```bash
flutter run -d macos
```

打开任意一部番剧详情页，确认：

1. 宽窗口（> 1000dp）呈现左/中/右三栏；拖窄到 1000dp 以下变成单栏堆叠。
2. 左栏封面、`开始观看`/`继续观看`、`＋ 追番`（或 `★ 在看 ▾` 下拉）、
   收藏统计三个数字、作品信息表格与标签都在。
3. 中栏标题（中文名 + 原名 + meta 行）、简介可展开、选集网格、
   角色横向头像行**有头像也有 CV 名字**（这是本次修掉的 bug #1/#3）。
4. 右栏三张卡片：评分（分数 + 星级 + `#排名 · N 人评分` + 柱状图 + `☆ 打分`）、
   热门评价（3 条，BBCode 已剥离）、制作人员（中文职位名，这是修掉的 bug #2）。
5. 三处 `查看全部 ›` 都能拉起底部弹窗。
6. `☆ 打分` 能拉起评分对话框并提交成功。
7. 点一集播放后返回详情页，左栏按钮变成 `继续观看 第 N 集`。
8. **交叉核对收藏统计语义**（设计文档明确要求的一步）：记下左栏「收藏 / 在看 / 想看」
   三个数字，再用浏览器打开同一部作品的 Bangumi 网页
   （`https://bgm.tv/subject/<subjectId>`），比对右侧的收藏盒统计。
   确认「收藏」对应的是 `favorite.done`（看过），而**不是**五项之和。
   若网页显示的「收藏」等于五项之和，就把 `subject_collection_stats.dart`
   里 `收藏` 一项改成 `wish + done + doing + onHold + dropped`，
   并同步改 `test/ui/subject/subject_collection_stats_test.dart` 的期望值，
   然后在设计文档的「收藏统计字段映射」一节记录这次修正。

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "refactor(subject): remove the superseded blurred header"
```
