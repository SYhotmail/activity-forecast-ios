---
description: "Task list for App Icons"
---

# Tasks: App Icons

**Input**: Design documents from `/specs/002-app-icons/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui.md, quickstart.md

**Tests**: no new unit tests. This feature adds no `ForecastKit` logic (plan.md › Constitution Check), so the TDD rule from feature 001 does not apply. Verification is the build (the asset catalog compile step fails on a malformed icon set), the unchanged `swift test` suite (92 tests), SwiftUI previews and the manual checks in quickstart.md.

**Delivery**: one branch (`002-app-icons`), one PR. US1 and US2 are independent and may land as separate commits.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: US1 / US2 from spec.md
- Paths are relative to the repository root

---

## Phase 1: Setup

- [X] T001 Confirm the baseline on branch `002-app-icons`: `swift test --package-path Packages/ForecastKit` passes (92 tests) and `xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'generic/platform=iOS Simulator' build` succeeds

No foundational phase: US1 and US2 share no code.

---

## Phase 2: User Story 1 — Recognisable app on the Home Screen (P1) 🎯 MVP

**Goal**: replace the blank placeholder with an original icon in Default, Dark and Tinted appearances (FR-001…FR-004).

**Independent test**: install the app; the custom icon shows on the Home Screen, Spotlight, Settings and the app switcher, and in Dark and Tinted Home Screen modes (quickstart.md checks 1–4).

- [X] T002 [US1] Create `scripts/make-app-icon.swift`: a standalone macOS script (`#!/usr/bin/env swift`, imports Foundation, CoreGraphics, ImageIO, UniformTypeIdentifiers; no third-party code, no SF Symbols, no text). It draws the motif from research.md D3 with plain shapes on a 1024×1024 canvas: a large sun circle upper-right, a mountain triangle with a white snow cap in front of it, and a wave band across the bottom; the smallest feature at least ~80 px. It writes three PNGs into `App/Resources/Assets.xcassets/AppIcon.appiconset/`, resolving that path relative to the script's own location so it works from any directory:
  - `AppIcon.png`: opaque sky-blue → deep-blue vertical gradient background, full colour, no alpha channel (App Store requires an opaque Default icon)
  - `AppIcon-Dark.png`: the same motif in colour on a **transparent** background
  - `AppIcon-Tinted.png`: the same motif as **grayscale** (luminance only, white = strongest) on a **transparent** background
- [X] T003 [US1] Run `swift scripts/make-app-icon.swift`; open the three PNGs and confirm each is 1024×1024 (`sips -g pixelWidth -g pixelHeight -g hasAlpha <file>`), Default has `hasAlpha: no`, and the motif matches across all three
- [X] T004 [US1] Rewrite `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` with three `"idiom": "universal", "platform": "ios", "size": "1024x1024"` images: `AppIcon.png` (no `appearances`), `AppIcon-Dark.png` with `"appearances": [{"appearance": "luminosity", "value": "dark"}]`, `AppIcon-Tinted.png` with `"appearances": [{"appearance": "luminosity", "value": "tinted"}]`; keep `"info": {"author": "xcode", "version": 1}`
- [X] T005 [US1] Build for the simulator (command in T001); expect `BUILD SUCCEEDED` with no `actool`/asset catalog warnings about AppIcon. Install on a booted iOS 18 simulator, go to the Home Screen and take a screenshot (`xcrun simctl io booted screenshot`) to confirm the custom icon; repeat after `xcrun simctl ui booted appearance dark` (quickstart.md checks 1–2)
  - Result: Home Screen shows the custom icon. `assetutil` on the built `Assets.car` lists AppIcon in Default, `UIAppearanceDark` and `ISAppearanceTintable`. `simctl ui appearance dark` does not switch the simulator Home Screen icon style, so the Dark and Tinted visuals are confirmed by hand in T011 (quickstart checks 2–3)

**Checkpoint**: the app has a real icon in all three appearances. Shippable on its own.

---

## Phase 3: User Story 2 — Activities identifiable at a glance (P2)

**Goal**: a distinct, decorative, Dynamic-Type-scaling icon next to each activity name in the forecast section header and the day detail sheet (FR-005…FR-007).

**Independent test**: open any forecast; each section header shows its own icon and the day detail sheet title shows the same one; VoiceOver output is unchanged (quickstart.md checks 5–9).

- [X] T006 [P] [US2] In `App/Shared/Formatting.swift`, add next to `extension SuitabilityLabel` an `extension Activity { var symbolName: String }` with an exhaustive `switch` (no `default`): `.skiing` → `"figure.skiing.downhill"`, `.surfing` → `"figure.surfing"`, `.outdoorSightseeing` → `"figure.hiking"`, `.indoorSightseeing` → `"building.columns"` (research.md D4). Doc comment: presentation only, kept in the App target so `ForecastKit` stays UI-free (D5)
- [X] T007 [US2] In `App/Forecast/ActivitySection.swift`, change the section `header:` from `Text(Formatting.sectionHeader(ranking))` to `Label(Formatting.sectionHeader(ranking), systemImage: ranking.activity.symbolName)`, keeping `.font(.headline)`, `.foregroundStyle(.primary)` and `.textCase(nil)`. Header text must be unchanged (contracts/ui.md). Depends on T006
- [X] T008 [US2] In `App/Forecast/DayDetailView.swift`, keep `.navigationTitle(day.activity.title)` and `.navigationBarTitleDisplayMode(.inline)`, and add `ToolbarItem(placement: .principal) { Label(day.activity.title, systemImage: day.activity.symbolName).labelStyle(.titleAndIcon).font(.headline) }` alongside the existing Done button. Depends on T006
- [x] T009 [US2] Check the existing previews (`ForecastView`, `DayDetailView` "Rainy outdoor day", "Surfing, thunderstorm", "No data") render with icons in Light and Dark and at the largest accessibility text size; confirm the four icons are distinct and none matches a status symbol (`star.fill`, `magnifyingglass`, `mappin.slash`, `exclamationmark.triangle`, thumbs, octagon). Build for the simulator (command in T001)

**Checkpoint**: activity icons visible on both screens; VoiceOver wording identical to before.

---

## Phase 4: Polish

- [X] T010 [P] In `README.md`, add one line under "Run it" (or a short "App icon" note): the icon is drawn by `scripts/make-app-icon.swift`; regenerate with `swift scripts/make-app-icon.swift` after changing it. Update the screenshot `docs/screenshots/01-search-idle.png` only if it shows the Home Screen (it does not today, so normally no change)
- [X] T011 Run `swift test --package-path Packages/ForecastKit` (still 92 passing) and the simulator build. Walk through quickstart.md checks 1–9 (manual checks that need taps — 3, 4, 6, 7, 8 — by the author) and record the results in the PR
- [X] T012 Mark completed tasks `[X]` in this file; confirm no files outside plan.md › Project Structure were added (`git status`)

---

## Dependencies & Execution Order

- T001 → {Phase 2 (US1) ∥ Phase 3 (US2)} → Phase 4
- US1: T002 → T003 → T004 → T005 (sequential: same asset folder, each step consumes the previous output)
- US2: T006 → {T007 ∥ T008} → T009 (T007 and T008 touch different files but both need T006)
- T010 can run any time after T001

## Parallel opportunities

- US1 and US2 touch disjoint files (`scripts/`, `AppIcon.appiconset/` vs `Formatting.swift`, `ActivitySection.swift`, `DayDetailView.swift`) and can be built concurrently.
- Within US2: T007 ∥ T008 after T006.
- T010 (README) ∥ any story task.

## Implementation strategy

1. **MVP**: T001 → US1 (T002–T005). The blank icon is the visible gap; this alone makes the app look finished.
2. **Increment**: US2 (T006–T009).
3. **Finish**: Polish (T010–T012), one PR with the quickstart results.
