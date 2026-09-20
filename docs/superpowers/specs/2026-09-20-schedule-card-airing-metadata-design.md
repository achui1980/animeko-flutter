# Schedule Card Airing Metadata Design

## Goal

Make the schedule page consistent with the app's Chinese UI and let users see
which episode releases at what local time without opening a subject detail
page.

## Scope

- Change the schedule page AppBar title from `Schedule` to `追番日历`.
- On schedule cards only, show `第{episode}话 · HH:mm` below the subject title.
- Use the API's existing per-item `episode.sort` and UTC `airingTime` values.
- Leave Home, Search, and Collection card layouts unchanged.

## Data Flow

`GET /v1/schedule/airing` already deserializes each list item as a
`ScheduledAnimeEpisode`, including `episode.sort` and `airingTime`. The
schedule controller currently maps only its subject into `SubjectCard`, which
discards both values.

Add optional `episodeSort` and `airingTime` fields to `SubjectCard`. Extend
`SubjectCard.fromScheduledSubject` with matching optional arguments, then pass
the API values while mapping schedule days in `ScheduleController`. Other
`SubjectCard` factories and consumers do not provide these values and remain
unchanged.

## Presentation

Extend the shared `AnimeCoverCard` with an optional `subtitle` parameter. A
non-empty subtitle appears as one smaller, subdued line beneath the title.
Only `ScheduleScreen` supplies it; its horizontal card row height increases
enough to contain the added line without clipping.

The schedule screen formats the metadata as follows:

- Render an integer episode sort without a trailing `.0`; preserve a decimal
  sort such as `3.5`.
- Parse the ISO-8601 UTC `airingTime`, convert it to the device's local time,
  and display a zero-padded `HH:mm` clock value.
- Combine them as `第1话 · 22:00`.
- Omit the subtitle entirely if required metadata is absent or the timestamp
  cannot be parsed. Never render empty separators or a blank metadata line.

The existing pure `formatEpisodeNumber` helper is reused for episode-number
formatting so schedule and subject-detail text use the same convention.

## Error Handling

The schedule API contract remains unchanged. Invalid or incomplete optional
display data affects only that card's metadata line: the card continues to
show its cover and title and remains tappable.

## Tests

- Update `SubjectCard` unit tests for the optional schedule metadata fields.
- Update schedule-controller tests to verify episode sort and airing time
  survive API-to-domain mapping.
- Add widget coverage that `AnimeCoverCard` renders a supplied subtitle and
  continues to render normally without one.
- Add pure formatting tests for local-time conversion, episode formatting, and
  malformed or missing metadata omission.

## Non-goals

- Add a general localization framework; this codebase currently uses direct
  Chinese string literals for its UI.
- Show schedule metadata on cards outside the schedule page.
- Change the schedule endpoint, its generated JSON serialization, or subject
  detail's broadcast information.
