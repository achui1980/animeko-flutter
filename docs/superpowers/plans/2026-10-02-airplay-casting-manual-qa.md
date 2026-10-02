# AirPlay Casting — Manual QA Checklist

Run on a real Mac with a real AirPlay receiver (Apple TV or AirPlay-capable
smart TV) available on the same network. None of this is automatable (no
physical receiver in CI/dev-sandbox environments) — see
`docs/superpowers/specs/2026-10-02-airplay-casting-design.md` §9.

Build and run first: `flutter build macos --release` (or `flutter run -d macos`),
then for each item below, play an episode from the relevant source and tap the
AirPlay icon in the player's top bar.

## Castable sources — verify casting works

- [ ] **xifan**: cast starts, video plays on the receiver, no error.
- [ ] **agedm**: cast starts, video plays on the receiver, no error.
- [ ] **omofun**: cast starts, video plays on the receiver, no error.
- [ ] **yinghua**: cast starts and plays (best-effort — if it fails with a
      403/hotlink error, that confirms the Referer header is in fact required
      and the graceful-failure path below is what should be observed instead).
- [ ] **dilidili**: same as yinghua above.

## Placeholder page controls (while casting, for any one source above)

- [ ] The local window switches to the "正在投屏到 <device name>" placeholder;
      the device name shown matches the real receiver's name.
- [ ] Tapping play/pause on the placeholder pauses/resumes playback on the
      receiver (not on the (hidden) local player).
- [ ] Dragging the placeholder's progress slider seeks playback on the
      receiver.

## Graceful failure (yinghua or dilidili, if either fails to play on the receiver)

- [ ] A SnackBar with an error message appears ("投屏失败，该来源可能不支持投屏，
      可尝试切换片源" or the native failure reason).
- [ ] Local playback automatically resumes after the failure (window returns
      to the normal video view, not stuck on the placeholder).

## Hidden-button sources — verify the button is absent, not disabled

- [ ] **anime1**: no AirPlay icon appears in the top bar at all.
- [ ] **BT/Mikan** source: no AirPlay icon appears in the top bar at all.
- [ ] **Downloaded local file** playback: no AirPlay icon appears in the top
      bar at all.

## Disconnect / navigation recovery

- [ ] While casting, open the system AirPlay menu and disconnect (select
      "此 Mac") — local playback resumes automatically from the position the
      receiver had reached.
- [ ] While casting, physically turn off/disconnect the receiver from the
      network — the app does not get stuck on the placeholder page (same
      automatic local-resume behavior as the explicit disconnect above).
- [ ] While casting, navigate back out of the player screen (tap the back
      button) — the native floating AirPlay button does not remain visible
      as an orphaned overlay over the rest of the app.
