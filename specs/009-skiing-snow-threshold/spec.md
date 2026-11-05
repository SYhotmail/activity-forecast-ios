# Feature Specification: Skiing Needs Enough Snow

**Feature Branch**: `009-skiing-snow-threshold`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User report: "Skiing has value 13 [in Minsk], but snow depth is 0 cm." Agreed fix: options A and B from the review (cap on too little snow to ski, and a cap of 0 instead of 10).

**Amended** 2026-11-05 (bug `skiing-falling-snow-zero`): "if some snow is falling [the] rater shouldn't classify such case as 0". A day with no snow at all stays 0; a day with some snow, falling or lying, that is too little to ski is capped at 10 (FR-002, scenarios 2 and 4).

## Context

Skiing was capped at 10 only when snowfall and snow depth were both exactly 0 (specs/001 research R9, live fix T034). Live Minsk week (2026-11-05): six snowless days at the cap of 10, and one day with a dusting (0.21 cm snowfall, 1 cm depth, 3.5 °C, gusts 28 km/h, 1.6 mm rain) that escaped the cap and scored ≈32 from cold, gusts and rain alone, while the snow factor gave ≈1.5 of its 50 points. Weekly: (6 × 10 + 32) / 7 ≈ 13, for a place where no one can ski.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No skiing score without skiable snow (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a day with no snowfall and no snow depth, **When** it is scored, **Then** Skiing is 0 with the reason "No snow on the ground", whatever the temperature.
2. **Given** a day with a dusting (snow depth under 10 cm and snowfall under 2 cm, e.g. 1 cm and 0.21 cm), **When** it is scored, **Then** Skiing is at most 10 (Poor) with the reason "Too little snow to ski" and the depth.
3. **Given** snow depth of at least 10 cm, or snowfall of at least 2 cm, **When** it is scored, **Then** Skiing is scored from its factors as before.
4. **Given** the live Minsk week above, **When** it is ranked, **Then** the weekly Skiing score is 1 (six days at 0, the dusting at 10) and no best day is starred.

### Edge Cases

- The thresholds hold in any unit: 0.1 m or the equivalent in feet of depth counts as 10 cm (specs/006).
- Capped days are scored (0, or at most 10 with some snow), not "No data": they still count in the weekly average (specs/001 FR-013 is unchanged).

## Requirements *(mandatory)*

- **FR-001**: A day is skiable when snow depth is at least 10 cm or snowfall is at least 2 cm.
- **FR-002**: A day that is not skiable MUST score 0 for Skiing when it has no snow at all (snowfall and depth both 0), and at most 10 when it has some (amended; replaces the single cap of 0).
- **FR-003**: The cap's reason MUST be "No snow on the ground" when both are 0, else "Too little snow to ski" with the snow depth.
- **FR-004**: Scores of skiable days and the four reference weeks (specs/001 SC-003) are unchanged.

## Success Criteria *(mandatory)*

- **SC-001**: The acceptance scenarios pass as automated tests (scorer, ranker, display text).
- **SC-002**: All quality gates pass.
