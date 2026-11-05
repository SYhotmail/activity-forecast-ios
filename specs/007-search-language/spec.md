# Feature Specification: Search in the Query's Language

**Feature Branch**: `007-search-language`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Do geocoding search providing a specific language code, from the keyboard being used." Agreed approach: detect the language from the query, hinted by the user's keyboards and preferred languages (the active keyboard is not exposed by SwiftUI's search field).

## Context

The geocoding request always sent `language=en`. Open-Meteo's `language` decides which names a query is matched against, not only the language of the results (verified live 2026-11-05):

| Query | `language=en` | Query's language |
|---|---|---|
| Мінск | nothing | Мінск, Беларусь (`be`) |
| Минск | Minskoye, Kostroma Oblast (wrong place) | Минск, Беларусь (`ru`) |
| 北京 | nothing | 北京, 中国 (`zh`) |
| Київ | (with `ru`: nothing) | Київ, Україна (`uk`) |
| Minsk, Paris | match in any language; only the result language changes | |

So a user typing in a non-Latin script found nothing or the wrong city.

## Clarifications

### Session 2026-11-05

- Q: Read the active keyboard, or detect from the query? → A: Detect from the query (`NLLanguageRecognizer`, on device), hinted by the enabled keyboards and preferred languages. Reading the keyboard needs a UIKit search field in place of `.searchable` (specs/003 layout risk), and pasted text or dictation would not match it anyway (research R1).
- Q: What language for Latin-script queries? → A: English, the API default (simplified on review; first draft used the user's preferred language). Latin names match in any language, so this only means results are shown in English (R2).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A query in another script finds the place (Priority: P1)

A user types a city name in Cyrillic or Chinese characters and the place is found, with names in that language.

**Independent Test**: with Belarusian or Russian among the user's languages, "Мінск" is searched with `language=be` and "Минск" with `language=ru`; "北京" with `zh`.

**Acceptance Scenarios**:

1. **Given** keyboards English and Belarusian, **When** the user types "Мінск", **Then** the search request carries `language=be`.
2. **Given** an English-only user, **When** they type "Минск" or "Москва", **Then** the request carries `language=ru`.
3. **Given** any user, **When** they type "Paris", **Then** the request carries no `language` (the API default, English).

### Edge Cases

- No recognisable script (digits, symbols): English.
- Keyboard identifiers such as `emoji` or `dictation` are not languages and are ignored.
- Kanji-only Japanese (東京) may only match with `zh` on Open-Meteo; accepted limitation (R3).

## Requirements *(mandatory)*

- **FR-001**: `WeatherService.searchPlaces` MUST take an optional language code (lower-case ISO 639); `nil` means the API default.
- **FR-002**: The geocoding request MUST send `language` only when the code is present and not `en` (the default).
- **FR-003**: Queries made only of Latin letters, or with no recognisable language, MUST be searched in English (no `language` parameter).
- **FR-004**: Other queries MUST use, in order: the language `NLLanguageRecognizer` finds when it is one of the user's languages; else the user's first language written in the query's script; else the script's most likely language (CLDR likely subtags, e.g. Cyrillic → `ru`).
- **FR-005**: Candidates MUST be language codes only, preferred languages first, deduplicated.
- **FR-006**: The search view model MUST pass the detected code with each search; debounce, cancellation and stale-result rules (specs/001 FR-012) are unchanged.

## Success Criteria *(mandatory)*

- **SC-001**: The acceptance scenarios pass as automated tests (detector and view model, with fixed candidates).
- **SC-002**: All quality gates pass.
