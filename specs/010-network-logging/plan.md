# Implementation Plan: Network Logging

**Branch**: `010-network-logging` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

1. ForecastKit `OpenMeteoClient`: `logger: Logger` in both initialisers; `static func curlCommand(for:)`; log in `fetch` (curl before sending; status, duration, size, `X-RateLimit-Remaining` after; failures, cooldown, retry, decoding).
2. App `ActivityForecastApp`: passes `Logger(subsystem:category: "network")`.
3. Tests: `Logger.disabled` in test support; client constructions pass it; `curlCommand` tests.
4. Docs: CLAUDE.md.
