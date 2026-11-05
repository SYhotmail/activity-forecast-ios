# Quickstart: Validating Network Logging

## Prerequisites
- Xcode 27+, an iPhone 16 simulator, SwiftLint.

## Automated checks (constitution Quality Gates)
1. `swiftlint lint --strict` → 0 violations.
2. `swift test --package-path Packages/ForecastKit` → all pass.
3. `xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast -destination 'platform=iOS Simulator,name=iPhone 16'` → all pass.
4. Clean simulator build, with 0 warnings from project code.

## Tests log nowhere (FR-002, FR-006, SC-001)
`grep -rn "logger:" Packages/ForecastKit/Tests AppTests App/Features` → every client and `BrowseViewModel` construction outside the composition root passes `.disabled`. The existing client tests pass unchanged with it, so logging changes no result (constitution 2.3.0 Principle IV).

## Console check (FR-003…FR-005)
Log text, level and format are diagnostic logging, exempt from tests (constitution 2.3.0 Principle IV); check them here. Run the Debug app on the iPhone 16 simulator and watch Xcode's console, or Console.app filtered by subsystem = the bundle id and category `network`, with Info and Debug messages shown.

1. Search "Zermatt": a debug `curl …` line, then an info `200 /v1/search in N ms, B bytes, rate limit remaining X`.
2. Paste the `curl` line into Terminal: HTTP 200 with the same JSON shape.
3. Select a place: the same two lines for `/v1/forecast`.
4. Type, pause about 0.5 s so the search request goes out, then type again while it is in flight: a debug `/v1/search cancelled` line and no error. On a fast network the request may finish first and nothing is logged; that is fine. Keystrokes inside the 300 ms debounce send no request, so they log nothing.
5. Turn the Mac's network off and retry: an error line `/v1/forecast failed: …`, and the app shows the offline error.
6. Privacy (FR-004): in logs collected without a debugger attached (e.g. `log show --predicate 'category == "network"'`), the `curl` line and transport errors read `<private>`; status, path, duration, size and rate-limit budget stay visible.

## Browse lifecycle (FR-006)
Filter by category `browse` (Info shown). Launching the app logs `BrowseVM will appear`. Sending it to the background doesn't log anything, because SwiftUI doesn't call `onDisappear` for the root scene. Any `will disappear` line you see should match a matching `will appear`.
