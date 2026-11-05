# Implementation Plan: Rate Limiting and Unknown Language Codes

**Branch**: `008-rate-limit-language` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

1. ForecastKit `Service/RateLimiter.swift`: actor, `acquire()` and the pure `reserve(at:)` it uses.
2. `OpenMeteoClient`: one limiter per API (internal init takes the limit for tests); `fetch` acquires before sending; 429 → `.rateLimited`; `searchRequest` sends `languageCode(_:)` only; search retries once without language on 400.
3. `UserFacingError.rateLimited`; app message in `App/Extensions/UserFacingError+Display.swift`.
4. Docs: specs/001 contract error mapping, CLAUDE.md.

Testing: `RateLimiterTests` (deterministic reservations, cancellation), client tests (429, normalised and dropped language codes, 400 retry, per-API limiter), `DisplayTextTests`. No new dependencies; red then green.
