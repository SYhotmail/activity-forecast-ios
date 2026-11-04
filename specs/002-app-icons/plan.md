# Implementation Plan: App Icons

**Branch**: `002-app-icons` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-app-icons/spec.md`

## Summary

Two independent slices, both in the app target only (`ForecastKit` is untouched):

1. **App icon (P1)**: original artwork drawn once in code by a Swift script (CoreGraphics, since removed: see [research.md](./research.md) D1). It wrote three 1024×1024 PNGs (Default, Dark, Tinted) into the existing, currently empty `AppIcon.appiconset`, plus its `Contents.json` with the luminosity appearances. The motif is a sun over a snow-capped mountain and a wave: weather plus outdoor activity, no text, readable at small sizes. See [research.md](./research.md) D1–D3.
2. **Activity icons (P2)**: one SF Symbol per activity, mapped in a presentation extension `Activity.symbolName` next to the existing `SuitabilityLabel.color` extension in `App/Shared/Formatting.swift`. Shown with `Label` in the section header (`ActivitySection`) and the day detail sheet title (`DayDetailView`). `Label` scales with Dynamic Type and VoiceOver reads only its title, so spoken output is unchanged (FR-006, SC-004). See D4–D6.

## Technical Context

**Language/Version**: Swift 6 (language mode 6). Xcode 16 or later.

**Primary Dependencies**: SwiftUI (activity icons). CoreGraphics / ImageIO via a one-off macOS script (app icon; since removed). No third-party packages, fonts or artwork.

**Storage**: N/A. Static assets in `App/Resources/Assets.xcassets`.

**Testing**: No new logic in `ForecastKit`, so no new unit tests. The symbol mapping is an exhaustive `switch` (the compiler guarantees every activity has an icon); distinctness is checked by review and previews. The icon is verified by building, the asset catalog compile step (fails on wrong sizes/appearances), and simulator screenshots. The full `swift test` suite must stay green (92 tests). See [quickstart.md](./quickstart.md).

**Target Platform**: iOS 18.0+ iPhone. Dark and Tinted icon appearances exist from iOS 18, so the minimum is unchanged.

**Project Type**: mobile app (iOS), no backend.

**Performance Goals**: N/A. Static assets; SF Symbols render natively.

**Constraints**: Must build on Xcode 16 (no Icon Composer `.icon` files, which need Xcode 26). SF Symbols may not be used in the app icon (Apple's symbol licence excludes app icons and logos), so the app icon is drawn from plain shapes. Activity icons must not reuse the status symbols already in the app (★, magnifying glass, `mappin.slash`, warning triangle, thumbs, octagon).

**Scale/Scope**: 1 icon set (3 PNGs), 3 view files touched.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template. As in feature 001, the plan applies the project's stated values:

| Gate | Status |
|---|---|
| Focused scope: only the spec's FRs | ✅ No alternate icons, no iPad/Mac sizes, no marketing art |
| No speculative abstractions or dependencies | ✅ One computed property. No icon "theme" type, no asset generator package |
| Layering `App → ForecastKit → Foundation` | ✅ Symbol names are presentation, so they live in the App target, not in the domain `Activity` type |
| Verification over trust | ✅ Asset catalog compile + simulator screenshots in all available appearances; VoiceOver wording checked unchanged |
| TDD for `ForecastKit` logic | ✅ Not applicable: no `ForecastKit` change. View and asset work is exempt per feature 001's plan, verified by build + quickstart |
| Original, owned artwork (FR-004) | ✅ Drawn from shapes by a script (in git history, commit `2bdeee8`); the committed PNGs are the source of truth |

**Post-design re-check (after Phase 1)**: still passes. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-app-icons/
├── plan.md              # This file
├── research.md          # Phase 0: decisions D1–D6
├── data-model.md        # Phase 1: icon assets and the activity → symbol mapping
├── quickstart.md        # Phase 1: build, generate, manual checks
├── contracts/ui.md      # Phase 1: what changes on screen and for VoiceOver
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
App/
├── Resources/Assets.xcassets/AppIcon.appiconset/
│   ├── Contents.json                       # CHANGED: Default + Dark + Tinted entries with filenames
│   ├── AppIcon.png                         # NEW (generated)
│   ├── AppIcon-Dark.png                    # NEW (generated)
│   └── AppIcon-Tinted.png                  # NEW (generated)
├── Shared/Formatting.swift                 # CHANGED: extension Activity { var symbolName }
├── Forecast/ActivitySection.swift          # CHANGED: header Text → Label with the activity symbol
└── Forecast/DayDetailView.swift            # CHANGED: principal toolbar Label (icon + title)
README.md                                   # CHANGED: one line on where the icon lives
```

**Structure Decision**: no new targets or modules.

## Complexity Tracking

No violations. Nothing to justify.
