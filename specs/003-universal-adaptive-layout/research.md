# Research: Universal App with Adaptive Layouts

Decisions for [plan.md](./plan.md). Format: Decision / Rationale / Alternatives considered.

## R1. Layout container
- **Decision**: replace the root `NavigationStack` with a two-column `NavigationSplitView`: sidebar = search, detail = forecast or a "Pick a place" placeholder. Use the default `.automatic` column visibility and style.
- **Rationale**: the system collapses a split view into a single stack in compact width. That gives the narrow behaviour (FR-005) on iPhone, the iPhone Duo outer display, Slide Over and narrow Split View or Stage Manager windows. It switches back to two columns in regular width (FR-006). The choice comes from the window's size class, not the device (FR-004), and one hierarchy means nothing is rebuilt from scratch on a fold.
- **Correction (2026-11-04)**: the detail column must not wrap the forecast in its own `NavigationStack`. A nested stack hid the Back button once the split view collapsed (folded iPhone Duo); the detail column's own navigation bar is enough.
- **Alternatives**: branching on `horizontalSizeClass` between a `NavigationStack` tree and an `HStack` tree. That duplicates navigation, loses state on every switch and needs manual back handling. A three-column split view was rejected by the FR-012 clarification (detail stays a sheet).

## R2. Who owns navigation state
- **Decision**: a new `@MainActor @Observable public final class BrowseModel` in `ForecastKit/Features` owns `search: SearchModel`, `selectedPlace: Place?` and `forecast: ForecastModel?`. The open day moves into `ForecastModel.selectedDay: DaySuitability?`. `ActivityForecastApp` creates one `BrowseModel` and the views only read from it and call its methods.
- **Rationale**: on collapse and expand, SwiftUI may rebuild the detail column. Today `ForecastView` creates its `ForecastModel` and day selection in `@State`, so a rebuild would lose the forecast and sheet and fetch again (breaks FR-007). Keeping the state in a long-lived model means a rebuilt view reattaches to the same objects. In `ForecastKit` it is testable without a simulator (Principle IV).
- **Alternatives**: `@SceneStorage` / `NavigationPath` restoration only restores identifiers, so the forecast would still be fetched again. An App-target observable would be untestable with `swift test` and would put logic in `App` (Principle V).

## R3. Avoid refetching on rebuild
- **Decision**: add `ForecastModel.loadIfNeeded()`, which returns immediately when `state` is `.loaded` and otherwise calls `load()`. `ForecastView` uses it in `.task`. `retry()` still always reloads.
- **Rationale**: `.task` runs again whenever a view reappears, which a collapse/expand can trigger. If a load is cancelled mid-flight by a rebuild, `load()` already discards the cancelled result and leaves `.loading`, so the next `loadIfNeeded()` restarts it once. No result is lost or duplicated (spec Edge Cases).
- **Search too**: `SearchView` runs `search()` from `.task(id: query)`, which also reruns when a resize rebuilds the sidebar. `search()` is therefore idempotent for an unchanged query: it remembers the trimmed query of the last applied `.loaded`/`.empty` result and makes no request when asked again for it. `retry()` always searches.
- **Alternatives**: a stored "has started" flag (would wedge in `.loading` after a cancellation); moving loading into `BrowseModel.select` (couples fetching to selection and loses the view-scoped cancellation the app relies on).

## R4. Selection UI and input
- **Decision**: the sidebar uses `List(selection:)` bound to `BrowseModel.selectedPlace`, with each row a `NavigationLink(value: place)`. Selection changes call `BrowseModel.select(_:)`.
- **Correction (2026-11-04)**: the first version used plain rows with `.tag(place)`. On the folded iPhone Duo (compact width) tapping a row did nothing, because a collapsed split view's list only selects plain rows in edit mode. Value links set the selection in regular width and push the detail in compact width.
- **Rationale**: a selection-bound list in a split view gives highlight, arrow-key and pointer selection on iPad for free (FR-008). In compact width it pushes the detail like a `NavigationLink`. `Place` is already `Hashable`.
- **Alternatives**: keep `NavigationLink(value:)` plus `navigationDestination`. That doesn't drive the detail column of a split view and has no persistent selection highlight.

## R5. Day detail presentation
- **Decision**: keep `.sheet(item:)`, now bound to `forecast.selectedDay` through a small `Identifiable` wrapper as today.
- **Rationale**: FR-012 (clarified). On regular width the system shows it as a centred form sheet automatically. Because the selection lives in the model, the same day stays open across resize (US3-3).
- **Animation (2026-11-04)**: on regular width the sheet uses iOS 18's zoom transition (`.navigationTransition(.zoom(sourceID:in:))` on the sheet, `.matchedTransitionSource(id:in:)` on each day cell, keyed by the `DaySuitability`). Compact width keeps the default sheet. The choice comes from `horizontalSizeClass`, not the device (FR-004).
  - Rationale: built in, no custom animation code, and the system falls back to a cross-fade with Reduce Motion on. It ties the sheet visually to the day it describes.
  - Alternatives: a spring scale/fade inside the sheet (the sheet itself still slides up, so there's less connection to the cell); a popover anchored to the cell (rejected: reverses the FR-012 clarification that the detail is a sheet on every width).

## R6. Project settings for iPad
- **Decision**: `TARGETED_DEVICE_FAMILY = "1,2"`; add `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` = portrait, portrait upside-down, landscape left and right; do not set `UIRequiresFullScreen`.
- **Rationale**: iPad multitasking (Split View, Slide Over, Stage Manager) requires every orientation and no full-screen requirement (FR-002, FR-003). The single-size app icon from feature 002 already covers iPad.

## R7. Day cells on narrow and wide windows
- **Decision**: keep the horizontal scrolling row of seven day cells in each activity section on every width.
- **Rationale**: it already fits the narrowest Slide Over width and scales with Dynamic Type. On wide windows the row simply has room to show all seven. A grid would be a visual redesign with no requirement behind it (Principle V).

## R8. SwiftLint gate
- **Decision**: add `.swiftlint.yml` at the root, using SwiftLint's default rules plus:
  - `line_length` warning at 120, error at 160;
  - `identifier_name` minimum length 1 for idiomatic names (`id`, `x`, loop indices);
  - excluded paths: `.build`, `DerivedData`, `.claude`.

  The rest of the current violations (nesting, multiple trailing closures, `static_over_final_class`, function parameter count, file length, cyclomatic complexity) are fixed in code. Any rule kept off gets a one-line justification in the file.
- **Rationale**: the constitution requires `swiftlint lint --strict` to pass before any PR and forbids silencing rules without a reason. The baseline on the default rules is 58 violations: `line_length` 32, `identifier_name` 14, `nesting` 3, `multiple_closures_with_trailing_closure` 3, `static_over_final_class` 2, `function_parameter_count` 2, `file_length` 1, `cyclomatic_complexity` 1.
- **Alternatives**: a separate lint feature first (the user chose to include it here); disabling the noisy rules wholesale (breaks the constitution's no-bypass rule).

## R9. Toolchain version
- **Decision**: set `// swift-tools-version: 6.4` in `Packages/ForecastKit/Package.swift`, keep the Swift 6 language mode, and leave the Xcode `SWIFT_VERSION = 6.0` setting unchanged.
- **Rationale**: constitution Principle II requires the Swift 6.4 toolchain. The tools version is what pins a package to a compiler, so 6.4 makes Xcode 27 / Swift 6.4 a hard requirement. `SWIFT_VERSION` selects a language mode (5 or 6), not a compiler release, so "6.4" is not a valid value. Swift 6 mode already means complete strict concurrency (Principle I).
- **Constitution**: Principle II was reworded to match in v1.1.1 ("Swift 6.4 toolchain via `swift-tools-version: 6.4`, Xcode 27+; Swift 6 language mode").
- **Alternatives**: keep 6.0 and record an exception (the user chose to fix it here); a separate toolchain feature (one-line change, not worth its own PR).

## Verification environment
- Simulators available in Xcode 27.2: **iPhone Duo** (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`), iPad Pro 11"/13", iPad Air, iPad mini, iPhone 16. Duo outer and inner displays are verified on the Duo simulator, not on matching iPad widths.
