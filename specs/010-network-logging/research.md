# Research: Network Logging

## R1 — Where the logger comes from

**Decision**: `OpenMeteoClient` takes a `Logger` (no default); `ActivityForecastApp` passes `Logger(subsystem: bundle identifier, category: "network")`, tests `Logger(OSLog.disabled)`.

**Rationale**: the composition root already chooses the live service, so it chooses its logging too, and ForecastKit holds no app identity. Without a default, no creator can forget it silently, and tests say explicitly that they log nowhere. OSLog is a system framework (no dependency), and a disabled `OSLog` makes every call a no-op.

## R2 — Privacy

The URL carries the user's search text and the chosen place's coordinates, so the `curl` line is `.private`: Xcode's console shows it while debugging, and logs collected from a device redact it. Status, path, timings, sizes and rate-limit budget carry nothing about the user and are `.public`. Nothing is sent anywhere, so the privacy manifest (specs/PR #60) is unchanged.
