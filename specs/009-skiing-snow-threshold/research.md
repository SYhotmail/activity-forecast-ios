# Research: Skiing Needs Enough Snow

## R1 — Thresholds

**Decision**: skiable when snow depth ≥ 10 cm or snowfall ≥ 2 cm.

**Rationale**: about 10 cm of cover is the least on which skiing is possible at all (cross-country tracks; alpine pistes want far more, which the snow factor still rewards up to 100 cm). Open-Meteo's daily snow depth is the day's hourly maximum, so it already includes most of the day's fall; the 2 cm snowfall branch keeps a day of real snowfall over a melting or not-yet-modelled cover from being zeroed. A dusting (Minsk: 0.21 cm falling, 1 cm lying) is below both.

## R2 — Cap of 0

**Decision**: a day that is not skiable scores 0, not 10.

**Rationale**: with the cap at 10, a snowless week averaged 10 and any dusting day pulled it higher, suggesting a little skiing where there is none. Every other factor (cold, light gusts, no rain) describes weather that is only good for skiing when there is snow, so without skiable snow the score is 0. Capped days stay scored (0), not "No data", so they still weigh in the weekly average.

**Alternative rejected**: snow scaling the whole score (option C): it would change every skiing score and its reasons for little gain over a threshold.

**Amendment** (2026-11-05, bug `skiing-falling-snow-zero`): no snow at all stays 0, but some snow that is too little to ski is capped at 10, not 0. A day with snow falling or lying is closer to skiing than a bare one, and the user wants that to show. 10 matches the thunderstorm cap ("possible but bad") and stays under Fair (25), so such a day is never the best day. Live Minsk becomes 1 for the week (the dusting at 10), not the 13 that started specs/009. A cap that grows with the snow was rejected: a dusting would get about 1, too little to read as "some".
