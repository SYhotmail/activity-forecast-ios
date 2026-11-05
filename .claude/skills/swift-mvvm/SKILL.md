---
name: swift-mvvm
description: Swift iOS MVVM guidance and playbooks, with Coordinator for navigation flows. Use when designing, implementing, refactoring, or reviewing MVVM architecture of a SwiftUI or UIKit feature, module, or codebase.
license: MIT
---

# Swift MVVM Skill

## Overview

Use this skill to apply the MVVM playbook (and the Coordinator playbook for navigation flows) to the user's SwiftUI/UIKit task.

## Fast Path

Before giving guidance, capture:
- task type (new feature, refactor, PR review, debugging)
- UI stack (SwiftUI, UIKit, or mixed)
- minimum deployment target (iOS 17+ enables `@Observable`; iOS 16 requires `ObservableObject`)
- scope (single screen, multi-screen, app-wide)
- state and effect complexity
- existing conventions to preserve (read the project's CLAUDE.md or architecture docs first when present)

Then:
- run a fit check: MVVM fits screen-level state with moderate effect complexity
- if navigation spans multiple screens, reusable flows, or deep links, use MVVM as the **primary** playbook and Coordinator as the **secondary** for navigation only
- choose **Quick Recommendation Mode** for single-feature guidance with clear constraints
- choose **Deep Refactor Mode** for migrations or module boundary changes

## Quick Recommendation Mode

Use this mode when:
- the scope is one feature or screen
- the user mainly needs a recommendation, scaffold, or review checklist

Deliver:
- fit result (`fit` or `mismatch`)
- 1-2 reasons grounded in the request
- concrete structure, state, dependency, async, and testing guidance scoped to the feature

## Deep Refactor Mode

Use this mode when:
- the request spans multiple modules or screens
- the codebase is migrating toward MVVM (from MVC, MVP, or `ObservableObject` to `@Observable`)

Deliver:
- current-state assessment
- target MVVM structure with fit or mismatch result
- incremental migration path with boundary changes called out
- risks, trade-offs, and verification points for the transition

## References

- `references/mvvm.md`: the MVVM playbook (screen-level state with lightweight binding); always load
- `references/coordinator.md`: navigation flows and deep linking; load when navigation spans screens or flows

Shared references (load when relevant):
- `references/concurrency.md`: cancellation, stale-response guards, and the `userMessage(for:)` error-mapping convention used by playbook snippets; load when writing or reviewing async code
- `references/observation.md`: `@Observable` vs `ObservableObject` by deployment target; load when wiring SwiftUI state

When pairing MVVM with Coordinator, state which owns each boundary (MVVM: screen state and effects; Coordinator: flow and routing) before giving file structure or code.

If MVVM is a mismatch (for example, deterministic state machines or complex effect orchestration dominate), say so with the reason and one trade-off; if the user still wants MVVM, proceed with a risk-mitigated plan and state the risks up front.

## Analyze Existing Codebase (When Applicable)

When code already exists:
- detect current ViewModel style (`@Observable` vs `ObservableObject`) and DI style
- note concurrency model (async/await, Combine, GCD, mixed) and default actor isolation
- align recommendations to local conventions; the project's own rules win over playbook snippets

## Guardrails

- Do not force a restructure for a small feature when the current local pattern is still a reasonable fit.
- Preserve existing conventions unless the mismatch is severe enough to justify change.
- Do not introduce new framework dependencies unless the user explicitly accepts that trade-off or the codebase already uses them.
- Prefer the smallest change that solves the request cleanly.
- Keep Coordinator scoped to navigation; do not move screen state or effects into it.

## Produce Concrete Deliverables

Read `references/mvvm.md` (and `references/coordinator.md` when relevant) and convert its guidance into deliverables tailored to the request:

- **File and module structure**: directory layout with file names specific to the feature
- **State and dependency boundaries**: concrete types, protocols at real boundaries, and injection points
- **Async strategy**: cancellation, actor isolation, and error paths
- **Testing strategy**: what to test, how to stub dependencies, and example test structure
- **Migration path** (for refactors): incremental steps from current to target structure
- **UI stack adaptation**: where SwiftUI and UIKit guidance differ

## Output Requirements

- Keep recommendations scoped to the requested feature or review task.
- Prefer explicit state modeling; inject dependencies, using protocols where a boundary needs a test double.
- Flag anti-patterns found in existing code and provide direct fixes.
- Include cancellation and error handling in all async flows.
- When writing code, include only the patterns relevant to the task — do not dump entire playbooks.
- Treat reference snippets as illustrative by default; add full compile scaffolding only if the user asks for runnable code.
- Ask only minimum blocking questions; otherwise proceed with explicit assumptions stated up front.
- When reviewing PRs, use the PR review checklist and call out specific violations with line-level fixes.

## Verification Checklist

Before finalizing:

1. confirm MVVM (plus Coordinator, if used) matches the user's constraints and stack
2. confirm dependency injection, state ownership, effects, and testing strategy are covered
3. call out migration risk explicitly when recommending a structural change
4. end with the PR review checklist from `references/mvvm.md` (and `references/coordinator.md` if used) adapted to the feature

## Documentation QA Checklist

When updating references, validate:

1. section structure remains consistent (default path, advanced variants, migration notes, testing section with a minimum bar, PR review checklist)
2. snippets are internally consistent and compile-plausible
3. links point only to files in `references/`
