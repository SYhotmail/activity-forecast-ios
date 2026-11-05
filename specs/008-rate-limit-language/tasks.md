# Tasks: Rate Limiting and Unknown Language Codes

- [X] T001 Spec artifacts.
- [X] T002 [red] `RateLimiterTests`; client: 429 → `rateLimited`, language normalised or dropped, 400 retry without language, per-API limiter; `DisplayTextTests` message.
- [X] T003 [green] `RateLimiter`, client changes, `UserFacingError.rateLimited` and its message.
- [X] T004 Docs: specs/001 contract, CLAUDE.md; all gates.
- [X] T005 Unknown but well-formed codes (`xx`) are not sent: known ISO 639 codes only (red, then green).
- [X] T006 [red] Cooldown after 429 (`RateLimiterTests`, `OpenMeteoClientLimitsTests` with response headers); `rateLimited(until:)` message with time left (`DisplayTextTests`).
- [X] T007 [green] `RateLimiter.coolDown(until:)`/`cooldownEnd(at:)`, client reset parsing and fail-fast, `UserFacingError.rateLimited(until:)`, app message.
- [X] T008 Docs: specs/001 contract, CLAUDE.md; all gates.
