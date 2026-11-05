# Implementation Plan: Skiing Needs Enough Snow

**Branch**: `009-skiing-snow-threshold` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

1. ForecastKit `Scoring/ActivityScorer.skiing`: `isSkiable` (depth ≥ 10 cm or snowfall ≥ 2 cm, in converted units); cap `maximum: 0` when not skiable, reason `.noSnowOnGround` (both 0) or new `.tooLittleSnow(depth)`.
2. `Models/Suitability.swift`: `Reason.Detail.tooLittleSnow(Length)` with the caps.
3. App `Extensions/Reason+Display.swift`: "Too little snow to ski <depth>".
4. Docs: specs/001 FR-004 (Skiing) and research R9 table, CLAUDE.md Scoring line.

Testing: `ActivityScorerTests` (cap 0, thresholds, Minsk dusting), `WeeklyRankerTests` (capped days 0, Minsk week 0 with no best day), `UnitIndependenceTests` (threshold in metres and feet), `ActivityScorerReasonsTests` (reason), `DisplayTextTests`. Reference weeks unchanged. Red then green.
