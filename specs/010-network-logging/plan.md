# Implementation Plan: Network Logging

**Branch**: `010-network-logging` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

1. ForecastKit `OpenMeteoClient`: `logger: Logger` in both initialisers; `static func curlCommand(for:)`; log in `fetch` (curl before sending; status, duration, size, `X-RateLimit-Remaining` after; failures, cooldown, retry, decoding).
2. App `ActivityForecastApp`: passes `Logger(subsystem:category: "network")`.
3. Tests: `Logger.disabled` in test support; client constructions pass it. `curlCommand` is debug output only, so it has no tests of its own.
4. Docs: CLAUDE.md.

## Constitution Check (v2.3.0)

| Principle | Status |
|---|---|
| I. Concurrency safety | ✅ `Logger` is `Sendable`; logged from inside the client's existing async calls; no new isolation or escape hatches. Cancellation is logged at debug and still surfaces as `CancellationError` |
| II. Toolchain | ✅ OSLog `Logger` is available on iOS 14+, under the iOS 18 floor; no `#available` |
| III. Adaptive layout | ✅ Not applicable: no UI change |
| IV. Test-first | ✅ Logger injection is red → green (T002/T003): client tests build the client with `Logger.disabled`. Log text, level and the `curl` format are exempt (diagnostic logging, 2.3.0) and checked in [quickstart.md](./quickstart.md) |
| V. Layered simplicity | ✅ OSLog is a system framework, so no new dependency. ForecastKit gets the logger from its creator and holds no bundle id; only the composition root picks subsystem/category. No protocol or wrapper around `Logger` |

## Complexity Tracking

No violations. Nothing to justify.
