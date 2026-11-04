# Activity Forecast Constitution

## Core Principles

### I. Full Swift Concurrency Safety

- All targets MUST build in the Swift 6 language mode with complete strict concurrency checking
  and zero concurrency warnings.
- UI state and view models MUST be isolated to `@MainActor`. Types crossing isolation domains
  MUST be `Sendable` by construction (value types, actors, or immutable final classes).
- `@unchecked Sendable`, `nonisolated(unsafe)` and `@preconcurrency` MUST NOT appear in
  production code. In test support they are allowed only with an inline comment that states
  the invariant making them safe (e.g. a lock or `.serialized` suite).
- Async work MUST use structured concurrency (`async`/`await`, `.task`, task groups). Cancellation
  MUST propagate as `CancellationError` and never surface as a user-facing error, and a stale
  result MUST NOT overwrite a newer one.

Rationale: data races are the hardest bugs to reproduce on device; the compiler can rule them
out only if no escape hatches are used.

### II. Latest Swift Toolchain

- The project MUST build with the Swift 6.4 toolchain (Xcode 27 or later), the latest stable
  release, enforced by `swift-tools-version: 6.4` in the package manifest.
- All targets MUST use the Swift 6 language mode (`SWIFT_VERSION = 6.0` in Xcode, the default
  for tools version 6.x). `SWIFT_VERSION` selects a language mode, not a compiler release.
- New code MAY use Swift 6.4 language features. The iOS deployment target stays at iOS 18
  until a constitution amendment changes it; APIs newer than the deployment target MUST be
  guarded with `if #available`.
- This principle supersedes the earlier constraint that the project build on Xcode 16.

Rationale: current language features and diagnostics, especially for concurrency, outweigh
compatibility with older Xcode releases.

### III. Adaptive Layout: iPhone, iPhone Duo and iPad

- Every screen MUST render correctly on all supported iPhones, on both displays of the foldable
  iPhone Duo (the compact outer display and the larger inner display), and on iPad.
- On iPad the app MUST run natively, not in iPhone compatibility mode, and MUST support every
  window size: full screen in portrait and landscape, Split View, Slide Over and Stage Manager
  resizing.
- Layout MUST adapt to the available size (size classes and container size), never to device
  model checks or hard-coded screen dimensions.
- Folding, unfolding and window resizing MUST preserve app state: current search, selected
  place, loaded forecast and any open sheet.
- Dynamic Type, VoiceOver labels, and Light/Dark appearance MUST work on every display and
  window size.

Rationale: a fold or an iPad window resize changes the available size at runtime; size-driven
layouts are the only approach that handles both, and future form factors, without per-device
code.

### IV. Test-First Domain Logic

- Every behaviour in `ForecastKit` (models, scoring, service, view models) MUST start as a
  failing Swift Testing test (red), then the minimum code to pass (green), then refactor.
- Commit history MUST show the pair: `test: … (red)` followed by `feat:`/`fix: … (green)`.
- SwiftUI view bodies, assets and the composition root are exempt. They are verified by
  previews, the build and the feature's manual quickstart checks.

Rationale: the scoring model is a heuristic; tests pinned to reference weeks are what keep it
honest as it changes.

### V. Focused Scope and Layered Simplicity

- Dependencies point one way: `App → ForecastKit → Foundation`. `App` holds views only. Domain
  types MUST NOT import UI frameworks or know about networking.
- No third-party runtime dependencies. Developer tools that are not linked into the app
  (e.g. SwiftLint) are allowed.
- Build only what a spec's requirements need. No speculative abstractions, configuration for
  fixed values, or single-implementation protocols without a test or preview double.

Rationale: a small, legible codebase is the product being reviewed; every added layer must
earn its place.

## Platform & Tooling Constraints

- Platform: iOS, universal: iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`), iOS 18.0
  deployment target.
- Toolchain: Xcode 27+ / Swift 6.4 (`swift-tools-version: 6.4`), Swift 6 language mode
  (Principle II).
- Data: Open-Meteo Geocoding and Forecast APIs only, called directly. No backend, no API key,
  no persistence beyond the session.
- Lint: SwiftLint, configured by a checked-in `.swiftlint.yml` at the repository root.

## Development Workflow & Quality Gates

- Work is spec-driven: spec → clarify → plan → tasks → implement, with artifacts under
  `specs/<NNN-feature>/`. Each plan's Constitution Check MUST evaluate every principle above.
- Before any pull request is opened, all of the following MUST pass locally, and the PR
  description MUST record the results:
  1. `swiftlint lint --strict` with zero violations.
  2. `swift test --package-path Packages/ForecastKit` with all tests passing.
  3. A clean simulator build of the `ActivityForecast` scheme with zero warnings from project
     code.
- A PR that fails any gate MUST NOT be merged. Gates MUST NOT be bypassed by disabling rules or
  skipping tests; a disabled lint rule needs a justification in `.swiftlint.yml` or inline.
- Changes that affect layout MUST record, in the PR, a check on the iPhone Duo outer and inner
  displays and on iPad (full screen plus at least one Split View size), on simulator or device.

## Governance

- This constitution supersedes other project practices. Where `README.md`, `CLAUDE.md` or a
  feature plan conflicts with it, the constitution wins and the other document MUST be updated.
- Amendments are made with `/speckit-constitution`, reviewed in a pull request, and MUST state
  the version bump and rationale.
- Versioning follows semantic versioning: MAJOR for removing or redefining a principle, MINOR
  for adding a principle or materially expanding guidance, PATCH for wording and clarifications.
- Compliance is reviewed in every plan's Constitution Check and in every PR against the Quality
  Gates. Any justified exception MUST be recorded in the plan's Complexity Tracking table.

## Clarifications

### Session 2026-11-04

- Q: What level of iPad support should the constitution require? → A: Native iPad, all window
  sizes (universal app; Split View, Slide Over, Stage Manager; both orientations).
- Q: How is "Swift 6.4" enforced, given `SWIFT_VERSION` only offers language modes 5 and 6?
  → A: `swift-tools-version: 6.4` pins the toolchain (Xcode 27+); targets use Swift 6 language
  mode (1.1.1).

**Version**: 1.1.1 | **Ratified**: 2026-11-04 | **Last Amended**: 2026-11-04
