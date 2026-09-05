# App Icon Design

## Motivation

The macOS app icon at `macos/Runner/Assets.xcassets/AppIcon.appiconset/` is still
the unmodified default Flutter placeholder (the blue angular Flutter logo on a
white rounded square). The app needs a real icon that reflects its identity as
an anime-tracking/streaming app ("Animeko"/"Ani", Bangumi-backed).

## Process

Explored iteratively via the brainstorming skill's visual companion (browser
mockups at `http://localhost:52697`, screens `icon-concepts.html` through
`icon-concepts-v6.html`). Six rounds of mockups were shown; the design evolved
significantly from the original brief based on user feedback at each step.

### Locked-in decisions, in order

1. Color: match the app's Material seed color `kSeedColor = Color(0xFF4F378B)`
   (deep purple/wisteria, from `lib/app/theme/app_theme.dart`), as a gradient.
2. No reference to the original Kotlin/Compose Animeko app's actual icon —
   fully original design.
3. Overall style: gradient/glassy depth (not flat, not line-art) — a rounded
   squircle with a soft highlight and drop shadow.
4. **Rejected**: pure play-button-centric concepts (round 1). Read as "generic
   media player," didn't convey 追番 (anime-tracking) at all.
5. **Rejected**: the Chinese character "番" combined with a play button
   (round 2). User liked the *direction* enough to ask for a cartoon element on
   top, but ultimately chose to **replace 番 entirely** with a minimal cartoon
   element rather than combine both.
6. Cartoon element: cat/beast-ear silhouette (猫耳/兽耳轮廓), inspired by
   researching Bilibili's "小电视" (Little TV) mascot — a rounded TV/screen
   body with two small ear-like nubs on top and a simple screen-face
   expression. This is used only as creative inspiration; the final design
   does not copy Bilibili's actual mascot or branding.
7. Composition: TV-shaped body + ears, with a cute face (big eyes, blush,
   smile) drawn on the screen — the play-button motif was dropped entirely in
   favor of this cartoon face.
8. Face style: two big oval eyes + blush dots + a thin upward-curve smile
   (chosen over dot-eyes+smile-curve and squint-eyes+round-mouth variants).
9. Proportions: after user feedback that the face "only filled half the TV
   screen," both the face elements and the TV body/screen were enlarged and
   re-centered (approved variant "方案 B") so the composition fills the icon
   without empty margins.

## Final Approved Design

A cute, minimal, Bilibili-Little-TV-inspired mascot face: a white
rounded-rectangle "TV" with two small purple-tinted ear nubs on top, a deep
purple inset "screen" containing two big white eyes, two pink blush dots, and
a small white smile — rendered on a deep-purple gradient glass squircle
matching the app's brand color.

### Exact visual specification (CSS reference values at 160px canvas)

**Outer squircle:**
- Size: 160×160 reference (scale proportionally for all export sizes)
- `border-radius: 36px` (~22.5% of size)
- Background: `linear-gradient(160deg, #7B5FCB 0%, #4F378B 55%, #2E1F5E 100%)`
- Glass highlight overlay (top layer, semi-transparent white gradient +
  blurred radial highlight in the upper area)
- Drop shadow: `0 8px 24px rgba(79,55,139,0.35)` + inner highlight
  `inset 0 1px 1px rgba(255,255,255,0.4)`

**Ears** (2×, mirrored left/right):
- Size: 22px × 30px, `border-radius: 40% 40% 10% 10%`
- Position: `top: 18px`, `left/right: 34px`
- Rotation: ±18deg outward (splayed)
- Color: white, with drop shadow `0 1px 2px rgba(0,0,0,0.25)`
- Inner tint: 10px × 16px, same border-radius, `#4F378B` at 55% opacity,
  offset `top: 7px; left: 6px` within the ear

**TV body:**
- Size: 116px × 96px, `top: 44px`, horizontally centered
- `border-radius: 22px`, white, `box-shadow: 0 3px 8px rgba(0,0,0,0.25)`

**TV screen** (inset within body):
- `inset: 7px`, `background: #4F378B`, `border-radius: 16px`, flex-centered

**Face** (within the screen):
- Eyes (2×): 15px × 21px white ovals, `border-radius: 50%`, `top: 19px`,
  `left/right: 14px` from screen edges
- Blush (2×): 11px × 7px pink (`#FF9EC4`) ovals at 80% opacity, `top: 43px`,
  `left/right: 6px`
- Mouth: 16px × 8px, `border-bottom: 3px solid #fff`,
  `border-radius: 0 0 14px 14px` (upward smile curve), horizontally centered,
  `top: 46px`

### Rejected alternatives (for context, not carried forward)

- Pure play-button icon (triangle alone, triangle-in-screen-outline,
  triangle-in-film-ring) — too generic, no anime-tracking signal.
- "番" character combined with a play button (embedded, badged, or
  background-texture variants) — better direction but superseded by the
  cartoon-face approach once the user asked for cartoon elements.
- Two smaller/less-filled proportion variants of the final TV+face
  composition, before the "enlarge and fill" adjustment.

## Non-Goals

- No literal copy of Bilibili's actual "小电视" mascot or brand assets —
  inspiration only, original shapes/proportions.
- No "番" character in the final design.
- No play-button iconography in the final design (fully superseded by the
  cartoon face).
- No animated/interactive icon — a single static image exported to the
  standard macOS icon sizes.

## Scope

This spec covers only the visual design of the icon. Implementation is a
direct asset-generation task, not a multi-step code change:

1. Render the approved design (as specified above) at high resolution
   (≥1024×1024) as a master image.
2. Resize/export to the 7 sizes already present in
   `macos/Runner/Assets.xcassets/AppIcon.appiconset/`: 16, 32, 64, 128, 256,
   512, 1024 px.
3. Overwrite `app_icon_16.png` through `app_icon_1024.png` in place.
4. Verify `Contents.json` still correctly maps filenames to sizes/scale
   factors (no changes expected, since filenames/sizes are unchanged).

No `writing-plans`/`subagent-driven-development` workflow is needed for this
follow-up — it's a single asset-replacement change with no branching logic,
appropriately done as a direct implementation task after this spec is
approved.

## Spec Self-Review

- **Placeholder scan**: no TBD/TODO; all CSS values are concrete numbers
  carried over from the approved mockup (`icon-concepts-v6.html`, 方案 B).
- **Internal consistency**: the "Final Approved Design" section's values match
  the round-6 mockup's 方案 B variant exactly (enlarged face + enlarged TV
  body/screen, as approved by the user's "可以，用B" reply).
- **Scope check**: appropriately narrow — one static image, one target
  directory, no code logic. Does not attempt to also fix the outstanding
  Task 9 QA / final review items from the unrelated player-redesign feature.
- **Ambiguity check**: the only previously-vague point ("proportions feel
  unbalanced") was resolved by the user's explicit diagnosis ("五官感觉只有整
  个电视机的一半") and the subsequent approved fix (方案 B) — no remaining
  ambiguity in the final spec.
