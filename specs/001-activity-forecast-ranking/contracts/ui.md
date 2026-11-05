# Contract: UI screens and states (exposed to the user)

Three screens in one `NavigationStack`. Every state on every screen is listed here; there are no others.

## 1. Search (root)
Search field (`.searchable`, prompt "Search a city or town") and a result list.

| State | Shows |
|---|---|
| idle (< 2 chars) | Hint: "Type at least 2 letters to search" |
| loading | Progress indicator |
| loaded | Rows: **name** on the first line, "region, country" as secondary text (FR-002). Tap → Forecast |
| empty | "No places found for '{query}'" |
| failed | Error message + **Retry** |

## 2. Forecast (pushed)
Title = place name, subtitle = region, country. One section per activity, **in rank order** (FR-006).

Each activity section has:
- A header: rank number, activity name, weekly label and score (e.g. "1 · Skiing — Excellent 86").
- A row of 7 day cells, each showing a short weekday, a colour + label + score, or "No data" (FR-013). The best day is marked with a ★ badge and the "Best day" accessibility trait/label. If no day scores 25 or more, there is no badge and the caption reads "No suitable day this week" (FR-007).
- Surfing only: a footnote, "Based on weather only — wave conditions not included." (FR-010).

| State | Shows |
|---|---|
| loading | Progress indicator |
| loaded | Ranked sections as above |
| failed | Error message + **Retry** (search results stay on the previous screen) |

## 3. Day detail (sheet from a day cell)
Activity, date, label + score, then reasons (cap/negative/positive), then the weather factors: min/max temperature, precipitation (+ probability %), snowfall, snow depth, wind / gusts, sunshine hours, each in the user's locale units, e.g. °C/mm/cm/km/h or °F/in/mph (FR-008, FR-016). A missing value is shown as "—".

## Accessibility (FR-015)
- Only Dynamic Type text styles. Day cells wrap or scroll horizontally at large sizes. Nothing is truncated.
- Day cell label: "{Activity}, {Weekday day Month}, {Label}, {score}{, best day}".
- Colour is never the only carrier of meaning.
