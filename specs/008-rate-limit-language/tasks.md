# Tasks: Rate Limiting and Unknown Language Codes

- [X] T001 Spec artifacts.
- [X] T002 [red] `RateLimiterTests`; client: 429 → `rateLimited`, language normalised or dropped, 400 retry without language, per-API limiter; `DisplayTextTests` message.
- [X] T003 [green] `RateLimiter`, client changes, `UserFacingError.rateLimited` and its message.
- [X] T004 Docs: specs/001 contract, CLAUDE.md; all gates.
- [X] T005 Unknown but well-formed codes (`xx`) are not sent: known ISO 639 codes only (red, then green).
