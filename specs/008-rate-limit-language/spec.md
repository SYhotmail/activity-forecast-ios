# Feature Specification: Rate Limiting and Unknown Language Codes

**Feature Branch**: `008-rate-limit-language`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Add support of Rate Limiter for both API & add support of unknown language code (i.e. bad parameter)."

## Context

Open-Meteo's free tier allows 600 requests a minute, 5,000 an hour and 10,000 a day (the forecast API states the minutely limit in `X-RateLimit-*` headers) and answers over-limit requests with HTTP 429. The client sent requests unthrottled and mapped 429 to the generic "service isn't responding". The geocoding `language` came from the app (specs/007) and went to the API unchecked; Open-Meteo answers bad parameters with HTTP 400 and `{"error":true,"reason":"..."}` (verified live 2026-11-05).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The app stays within the service's limits (Priority: P1)

Bursts of searches or forecast loads are spread out instead of being rejected; if the service still refuses for too many requests, the user is told to wait and retry.

**Acceptance Scenarios**:

1. **Given** the per-API limit has been used in the current window, **When** another request starts, **Then** it waits for a free slot and is still cancellable.
2. **Given** the search limit is used up, **When** a forecast is requested, **Then** it is not delayed (each API has its own limit).
3. **Given** the service answers 429, **When** a search or forecast fails, **Then** the error is `rateLimited`, shown with its own message, the time to wait and a retry.
4. **Given** a 429 from an API, **When** that API is called again before the reset time, **Then** `rateLimited` is thrown without sending a request; after the reset, requests go out again.

### User Story 2 - A bad language code never breaks search (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a language like `be-BY`, `BE` or `be_BY`, **When** searching, **Then** `language=be` is sent.
2. **Given** a value that is not a known ISO 639 code (`klingon`, `1`, empty, `xx`), **When** searching, **Then** no `language` is sent (the API default, English).
3. **Given** the service rejects a search with 400 while a language was sent, **When** searching, **Then** the search is retried once without the language and its results are returned.

### Edge Cases

- A well-formed but unknown code (`xx`) would be accepted by the service (200) and matched like English, so it is not sent at all (research R2).
- A cancelled wait for a rate-limit slot still counts toward the window (the limit is never exceeded).
- A 429 without reset headers (geocoding sends none) cools down for 60 s, the shortest service window.
- A 429 from one API does not cool down the other.

## Requirements *(mandatory)*

- **FR-001**: Geocoding and forecast requests MUST each pass through their own sliding-window rate limiter of 600 requests per 60 seconds.
- **FR-002**: A request over the limit MUST wait for a slot; the wait MUST end with `CancellationError` when the task is cancelled.
- **FR-003**: HTTP 429 MUST map to `UserFacingError.rateLimited`; other 4xx/5xx stay `serviceUnavailable`.
- **FR-004**: The app MUST show a distinct message for `rateLimited`, with retry (specs/001 FR-011).
- **FR-005**: The client MUST send `language` only as a lower-case ISO 639 code Foundation knows (`Locale.LanguageCode.isoLanguageCodes`), taking the primary subtag of a region form; anything else, and `en`, MUST be left out.
- **FR-006**: A search rejected with HTTP 400 while sending `language` MUST be retried once without it.
- **FR-007**: HTTP 429 MUST start a cooldown for that API until `Retry-After` (seconds), else `X-RateLimit-Reset` (Unix seconds), else 60 s from now.
- **FR-008**: During a cooldown, calls to that API MUST throw `rateLimited` at once, without a request.
- **FR-009**: `rateLimited` MUST carry the cooldown's end, and the app MUST show the time left ("Try again in 42 seconds").

## Success Criteria *(mandatory)*

- **SC-001**: The acceptance scenarios pass as automated tests (package and app).
- **SC-002**: All quality gates pass.
