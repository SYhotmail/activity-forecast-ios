# Implementation Plan: Search in the Query's Language

**Branch**: `007-search-language` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

1. ForecastKit: `WeatherService.searchPlaces(matching:language:)`; `OpenMeteoClient.searchRequest` sends `language` only when present and not `en`.
2. App: `App/Features/Search/QueryLanguage.swift`: candidates (preferred languages, then keyboards, normalised to language codes) and `code(for:)` (Latin → first candidate; else `NLLanguageRecognizer` with hints; `en` → `nil`).
3. `SearchViewModel(service:language:)` passes `language.code(for:)` with each search; `BrowseViewModel` uses the default `.user` detector. `StubWeatherService.search` receives the language.

Testing: client request tests (package); `QueryLanguageTests` and a `SearchViewModelTests` case (app). Constitution: no dependencies (NaturalLanguage is a system framework), red then green.
