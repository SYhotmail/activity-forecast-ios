# Contract: UI changes for App Icons

Extends [001 contracts/ui.md](../../001-activity-forecast-ranking/contracts/ui.md). Only the items below change; every other screen, state and string is unchanged.

## System surfaces
The app shows its custom icon on the Home Screen, in Spotlight, Settings, the app switcher and notifications, in Default, Dark and Tinted Home Screen appearances (FR-001, FR-002).

## Forecast › activity section header
Before: `1 · Skiing — Excellent 86`
After: `[skier icon] 1 · Skiing — Excellent 86`. Same text, font and colour; the icon precedes it and scales with it.

## Day detail sheet › title
Before: inline title `Skiing`
After: inline title `[skier icon] Skiing`.

## Accessibility (unchanged wording)
- VoiceOver reads the header text and the sheet title exactly as before. Icons are not announced.
- Day cell labels are unchanged: "{Activity}, {Weekday day Month}, {Label}, {score}{, best day}".
- Icons scale with Dynamic Type; nothing truncates at the largest accessibility size.
