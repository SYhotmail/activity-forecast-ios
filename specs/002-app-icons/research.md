# Research: App Icons

Decisions for [plan.md](./plan.md). Format: Decision / Rationale / Alternatives considered.

## D1. How the app icon artwork is produced
- **Decision**: a checked-in Swift script, `scripts/make-app-icon.swift`, draws the icon with CoreGraphics and writes PNGs with ImageIO. Run with `swift scripts/make-app-icon.swift` on macOS; the generated PNGs are committed.
- **Rationale**: the project has no designer and no third-party assets (FR-004). Drawing from shapes in code makes the artwork original, reviewable as a text diff and reproducible. Committing the PNGs means building the app never depends on running the script.
- **Alternatives**: hand-made PNG in an image editor (not reproducible, binary-only review); Icon Composer `.icon` (needs Xcode 26, breaks the Xcode 16 constraint); rasterising an SF Symbol (not allowed: the SF Symbols licence excludes app icons and logos); stock/AI-generated art (licence uncertainty).

## D2. Icon variants and catalog format
- **Decision**: single-size 1024×1024 iOS icon with three appearances in `AppIcon.appiconset/Contents.json`: Default (no `appearances`), Dark (`luminosity: dark`), Tinted (`luminosity: tinted`).
  - Default: opaque, full-colour background.
  - Dark: same motif on a transparent background, so iOS supplies its dark backdrop.
  - Tinted: grayscale motif (luminance only) on a transparent background, so iOS applies the user's tint.
- **Rationale**: matches Apple's iOS 18 icon appearances (FR-002) and is supported by Xcode 16 asset catalogs. The app already targets iOS 18, so no fallback is needed.
- **Alternatives**: Default only (fails FR-002; iOS auto-darkens poorly); per-size PNGs (unnecessary since Xcode 14's single-size icons).

## D3. Motif
- **Decision**: a large sun behind a snow-capped mountain, with a wave across the bottom. Sky-blue to deep-blue gradient background (Default). Shapes only, no text, at least ~8% of the canvas for the smallest feature so it survives the 29–40 pt Settings/Spotlight sizes (FR-003).
- **Rationale**: one image covers weather (sun), skiing (snowy peak) and surfing (wave), the app's main ideas. Few large flat shapes stay legible when small and convert cleanly to the grayscale tinted variant.
- **Alternatives**: a single weather glyph (says "weather app", not "activities"); four activity glyphs in a grid (too busy at small sizes).

## D4. Activity symbols
- **Decision**:

  | Activity | SF Symbol |
  |---|---|
  | Skiing | `figure.skiing.downhill` |
  | Surfing | `figure.surfing` |
  | Outdoor sightseeing | `figure.hiking` |
  | Indoor sightseeing | `building.columns` |

- **Rationale**: built-in, free to use in-app, match the system look, all available since iOS 16 (minimum is 18). Three "figure" glyphs read as a family; the museum columns signal "indoor". None overlap with the existing status symbols (`star.fill`, `magnifyingglass`, `mappin.slash`, `exclamationmark.triangle`, `hand.thumbsup/down`, `exclamationmark.octagon`).
- **Alternatives**: `binoculars` for outdoor (too close to the search magnifying glass); `camera` (suggests photo features); custom drawn icons (more work, no benefit).

## D5. Where the mapping lives
- **Decision**: `extension Activity { var symbolName: String }` in `App/Shared/Formatting.swift`, next to the existing `extension SuitabilityLabel { var color }`.
- **Rationale**: a symbol name is presentation, like the rating colour. Keeping it in the App target preserves `App → ForecastKit → Foundation` and keeps the domain free of UI strings. An exhaustive `switch` means a new activity cannot compile without an icon.
- **Alternatives**: a property on `Activity` in `ForecastKit` (leaks UI into the domain); a dictionary (loses the exhaustiveness check).

## D6. Rendering and accessibility
- **Decision**: section header becomes `Label(Formatting.sectionHeader(ranking), systemImage: ranking.activity.symbolName)` with the existing font and styling. The day detail sheet keeps `.navigationTitle(day.activity.title)` and adds a `.principal` toolbar item showing `Label(day.activity.title, systemImage: …)`.
- **Rationale**: SF Symbols in a `Label` scale with the label's text style (FR-007) and inherit its foreground style, so contrast follows the text in Light and Dark. VoiceOver reads a `Label` by its title only, so header announcements and the day-cell labels stay word-for-word the same (FR-006, SC-004). Keeping `navigationTitle` preserves the back-stack/accessibility title.
- **Alternatives**: `Image` + `Text` in an `HStack` (needs manual `.accessibilityHidden` and scaling); icons inside each day cell (repeats the same icon 7 times, adds noise, not in the spec).
