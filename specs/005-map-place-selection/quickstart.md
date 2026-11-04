# Quickstart: Select a Place on a Map

Validation guide for [spec.md](./spec.md). Contracts: [ui.md](./contracts/ui.md), [place-locating.md](./contracts/place-locating.md).

## Gates (constitution Quality Gates)
```bash
swiftlint lint --strict                                  # Q-G1: 0 violations
swift test --package-path Packages/ForecastKit           # Q-G2: incl. MapSelectionTests
xcodebuild test -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'platform=iOS Simulator,name=iPhone 16'   # Q-G3: incl. MapPickerModelTests, BrowseModelTests
xcodebuild -project ActivityForecast.xcodeproj -scheme ActivityForecast \
  -destination 'generic/platform=iOS Simulator' build    # Q-G4: 0 warnings from project code (incl. no CLGeocoder deprecation)
```
Release fixture check: build Release and run `nm` on the binary. It must contain no `StubPlaceLocator`, `StubWeatherService` or `PreviewData` symbols.

## Manual checks (simulator, internet on)
| # | Steps | Expected |
|---|---|---|
| Q-1 | Launch with an empty search (device region United Kingdom) | Map on the UK; no location prompt |
| Q-2 | iPad full screen: tap Chamonix village | Marker "Locating…", then "Chamonix-Mont-Blanc"; detail shows its week (skiing ranked high in winter) |
| Q-3 | Tap the mid-Atlantic (e.g. 40° N, 35° W) | Marker named "40.00° N, 35.00° W"-style; forecast still loads |
| Q-4 | Network off (Network Link Conditioner 100% loss), tap the map | Marker shows coordinates; forecast shows the offline error with Retry |
| Q-5 | Tap the current marker | No change, no reload |
| Q-6 | Tap three points quickly | Only the last point is marked and named |
| Q-7 | iPhone 16: tap Biarritz | Callout "Biarritz / Nouvelle-Aquitaine, France" + **Show forecast**; nothing pushed. Tap the button → forecast pushed; Back → map unchanged |
| Q-8 | Type "Paris", pick Paris, France, clear the text | Map centred on Paris with its marker |
| Q-9 | Type "a" | The existing "Type at least 2 letters" hint, not the map |
| Q-10 | iPhone Duo: select via the map folded, unfold, fold again; iPad: resize Split View. Also: folded, tap a point (callout shown, no Show forecast), then unfold | Camera, marker and forecast kept; no refetch. The unshown named pin is selected on unfolding and the detail shows its week |
| Q-11 | VoiceOver on the marker; largest Dynamic Type; Dark mode | Label "Selected place, <name>"; callout text scales; map readable |
| Q-12 | Device region set to "World" | Map starts on the whole world |
| Q-13 | iPad, normal Wi-Fi: tap 20 different land points, timing from tap to name with a stopwatch or screen recording | At least 19 of 20 named within 2 s (SC-002) |

Also re-run the 001 and 003 quickstart checklists (SC-005).
