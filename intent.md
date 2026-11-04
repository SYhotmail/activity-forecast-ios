# Intent: Activity Forecast Ranking

## 1. Goal
A native mobile app where a user searches for a city or town and sees how suitable each of the **next 7 days** is for four activities:
- Skiing
- Surfing
- Outdoor sightseeing
- Indoor sightseeing

## 2. Hard constraints (from the brief)
- **One platform**: the brief allows iOS (Swift) or Android (Kotlin). **Chosen: iOS (Swift).**
- **Weather data**: Open-Meteo **Geocoding API** (place search) and **Forecast API** (7-day weather).
- **No backend**: the app calls Open-Meteo directly.
- **Deliverable**: a public GitHub repository that builds and runs locally.
- **README** (short): what was built, how to run it, assumptions made.

## 3. Open by design (decisions we make and justify)
- How suitability is determined (scoring model).
- App structure / architecture and state management.
- How information is presented.
- Frameworks, libraries and testing approach.

Where a PM or designer would normally be asked, write down the chosen assumption and move on.

## 4. What reviewers value (in this order)
1. **How we worked**: planning notes, AI conversations, commit history, design decisions, assumptions, trade-offs. They care about the reasoning more than polished docs.
2. **The application** itself.

- Focus beats feature volume. A smaller, well-reasoned, maintainable solution wins.
- AI use is allowed. Weak verification of AI output is not.

## 5. Interpretation and committed assumptions
- **"Rank" means** a score for every activity on every day (0–100, mapped to Poor / Fair / Good / Excellent). Activities are ordered by how suitable the whole week is, and each activity's best day is highlighted.
- **7 days** = today + 6, using the selected location's own time zone.
- **Explainability**: each daily score shows the main weather factors behind it (temperature, precipitation, snow, wind) and a short plain-language reason.
- **Skiing**: scores higher with snowfall or snow cover, cold temperatures, low wind and good visibility. Near zero when there is no snow and it is above freezing.
- **Surfing**: the Forecast API has no wave or swell data, so surfing is scored from weather proxies only (wind, temperature, no storms). The UI says so.
- **Outdoor sightseeing**: scores higher when it is dry, comfortable (~15–25 °C), calm and sunny.
- **Indoor sightseeing**: always possible, so it has a baseline score that rises as outdoor conditions get worse.
- **Search**: results show name, region and country so places with the same name can be told apart. Older responses never overwrite newer ones while the user is typing.
- **States**: loading, empty results, offline and service errors are all shown, with a retry.
- Metric units, English only, internet required. No accounts, favourites, history or offline cache.
- Basic accessibility: scalable text and screen-reader labels.

## 6. Non-goals
- A backend, authentication or user data.
- Persistence beyond the current session.
- Marine/swell data sources outside the two named APIs.
- Android, or any platform other than iOS.

## 7. Definition of done
- [ ] The app builds and runs by following the README steps.
- [ ] Search → select place → ranked 7-day view works end to end.
- [ ] Loading, empty and error states work, with retry.
- [ ] Scoring logic is deterministic and unit-tested against reference forecasts (snowy alpine, rainy city, sunny coast, hot and dry), each producing the expected top activity.
- [ ] The README lists assumptions. A decisions/trade-offs log and planning notes are committed. Commit history shows incremental progress.

## 8. Open questions for planning
- **Platform**: decided, iOS (Swift). The UI framework, minimum iOS version and test framework still need to be confirmed in the plan. The project's tooling points to SwiftUI, Swift Concurrency and Swift Testing.
- **Scoring weights and thresholds** for each activity, to be fixed and documented in the plan.
