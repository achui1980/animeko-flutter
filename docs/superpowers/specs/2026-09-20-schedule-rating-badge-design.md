# Schedule Rating Badge Design

## Goal

Show each scheduled anime's Bangumi aggregate score as an unobtrusive but
prominent badge at the bottom-right of its cover, without delaying the
schedule page's existing episode and local-airing-time content.

## Scope

- Fetch a scheduled subject's aggregate Bangumi score from the existing
  `GET /v2/subjects/{subjectId}` endpoint.
- Show a valid score only on a schedule card's cover, as a bottom-right badge
  such as `7.8`.
- Keep `第{episode}话 · HH:mm` below the title exactly as it is today.
- Hide the badge for an unavailable, invalid, zero, or failed score request.
- Leave Home, Search, and My Collection cards visually and behaviorally
  unchanged.

## Data Flow

`GET /v1/schedule/airing` remains the only source of date, title, cover,
episode, and airing-time data. It does not contain a score.

Add a family Riverpod provider keyed by `subjectId`. It calls the existing
`SubjectApi.getSubject(subjectId)` endpoint and exposes only a nullable,
display-ready score. `ScheduleScreen` watches this provider for each schedule
card after it has rendered the primary schedule data.

Riverpod caches one provider instance per subject ID, so repeated appearances
of the same subject reuse the same request/result. This keeps score enrichment
out of `ScheduleController`: that controller can continue to resolve the
schedule immediately rather than wait for all subject-detail requests.

The score provider accepts only a finite numeric value greater than zero. It
formats valid numeric input with at most one decimal place, removing a trailing
`.0` (for example, `8.0` becomes `8`, while `7.8` remains `7.8`). A null,
blank, non-numeric, non-finite, zero, or negative source value resolves to
null.

## Presentation

Extend `AnimeCoverCard` with an optional score-badge value. When supplied,
the cover image is placed in a `Stack`; the badge is positioned at the
bottom-right inside the image bounds.

The badge contains only the formatted numeric score. It uses a dark,
semi-transparent surface with rounded corners and light text so it remains
legible over varied artwork. It must not change the card's cover aspect ratio,
title/subtitle spacing, or the schedule row height.

Only `ScheduleScreen` supplies this value. While an individual score is
loading or unavailable, the card renders normally without a placeholder,
spinner, blank badge, or layout shift outside the cover overlay.

## Error Handling

A subject-detail score request is supplementary. Failure of one request is
isolated to its one badge: the card remains tappable and continues to show its
cover, title, episode number, and airing time. A score-request failure must
not fail the schedule page or cause a schedule retry.

The existing subject-detail endpoint can return user collection data as well
as aggregate score. The schedule score provider reads only `SubjectDetail.score`
and does not expose or display collection state.

## Tests

- Add unit coverage for score parsing and display formatting, including valid
  integer and decimal scores and null, blank, malformed, non-finite, zero,
  and negative values.
- Add provider/controller coverage that the subject-detail API is called once
  per subject ID and that a failed detail request resolves to no badge rather
  than failing the schedule state.
- Add `AnimeCoverCard` widget coverage for rendering a supplied bottom-right
  score badge and omitting it when no score is provided.
- Update the schedule-screen widget test to verify that a resolved score is
  passed to the schedule card while existing episode/time subtitle behavior is
  retained.

## Non-goals

- Change the schedule endpoint or its generated models.
- Add bulk score support to the backend.
- Display score badges on cards outside the schedule page.
- Show rating count, rank, stars, or the user's own Bangumi rating.
- Persist scores locally or introduce a new cache beyond Riverpod's in-memory
  provider lifecycle.
