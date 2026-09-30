# Playable Episode Types Design

## Goal

Let SPECIAL-type episodes (which is where theatrical movies/剧场版, extra
specials, etc. are tagged by the backend) appear and play in the subject
detail episode grid, merged and sorted together with MAIN episodes. OP/ED
remain excluded — they're theme songs, not watchable content.

## Background

`SubjectMainEpisodesController` currently filters the subject's episode list
down to `type == 'MAIN'` only before it reaches `EpisodeNumberGrid`. Any
episode tagged `SPECIAL` (the only bucket a movie/剧场版 entry can land in,
since the backend's `type` enum has no dedicated movie value) is silently
dropped — not shown disabled, just absent from the list and therefore
unplayable.

## Scope

- `lib/data/subject/subject_episode_models.dart`: add `SubjectEpisode.isPlayable`,
  true for `type == 'MAIN' || type == 'SPECIAL'`. Keep `isMain` unchanged
  (still true only for `MAIN`) since it's used elsewhere for a distinct
  purpose (see Non-goals).
- `lib/domain/subject/subject_main_episodes_controller.dart`: filter by
  `episode.isPlayable` instead of `episode.isMain`, then sort by `sort` as
  today. Update the class/method doc comments to describe the new MAIN+SPECIAL
  behavior instead of "MAIN only".
- No changes to `EpisodeNumberGrid` or any other widget.

## Data Flow / Why No UI Changes Are Needed

`SubjectEpisode.sort` is already documented as "Ordering key across *all*
episode types" — a single global ordering value spanning MAIN and SPECIAL
entries, not a per-type counter. `EpisodeNumberGrid`'s cell labels are
generated purely from `episode.sort` (see `episode_number_grid.dart:173-175`),
never from `type` or `ep`. So once `SubjectMainEpisodesController` stops
dropping SPECIAL episodes, they fall into their correct chronological
position automatically and get a normal sequential label — e.g. if a series'
MAIN episodes sort 1..1084, a bundled movie/special sorting at 1085 shows up
as episode "1085" right after them, exactly matching the requested "merge
into the main list, sorted together" behavior. No grouping, badge, or
secondary section is introduced.

## Error Handling

Unchanged. `_sortFromJson` already falls back to `0` rather than throwing on
a malformed `sort` value (existing defensive behavior, not touched by this
fix).

## Tests

- `test/data/subject/subject_episode_models_test.dart`: add cases for
  `isPlayable` — `true` for `MAIN`, `true` for `SPECIAL`, `false` for `OP`,
  `false` for `ED`, `false` for an absent/empty `type`.
- `test/domain/subject/subject_main_episodes_controller_test.dart`:
  - Rename/rewrite the existing `'keeps only MAIN episodes, dropping
    SPECIAL/OP/ED'` case to `'keeps MAIN and SPECIAL episodes, dropping
    OP/ED'`, adding a SPECIAL-typed episode to the fixture and asserting it
    appears in the result at its correct sorted position.
  - Rewrite the existing `'returns an empty list when every episode is a
    non-MAIN type'` case to use an all-OP/ED fixture instead of an arbitrary
    non-MAIN one, since SPECIAL alone no longer produces an empty result.

## Non-goals

- Do not change `SubjectDetail.episodeCount` (`subject_models.dart:264`, the
  "话数" line), which continues to filter on `isMain` only. That's a distinct
  concept (count of proper main-story episodes) from "what's playable in the
  grid," and the user did not ask to change it.
- Do not include OP/ED in the playable set.
- Do not add a separate "other episodes" section, a settings toggle, or any
  UI distinction between MAIN and SPECIAL entries in the grid — per the
  chosen approach, they are fully merged.
- Do not touch the original Kotlin/Compose Animeko repo
  (`/Users/portz/js/animeko`) — this fix is scoped to animeko-flutter only.
