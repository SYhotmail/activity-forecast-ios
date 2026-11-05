# Feature Specification: Network Logging

**Feature Branch**: `010-network-logging`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Add logging to the app: OSLog (for testing use a disabled one). For the web API print curl commands and some response status codes, so I can track changes."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Follow every API call in the console (Priority: P1)

A developer running the app sees, for each Open-Meteo request, a `curl` command they can paste into a terminal, then the response status, how long it took and how much rate-limit budget is left.

**Acceptance Scenarios**:

1. **Given** a search or forecast, **When** the request is sent, **Then** a `curl` command reproducing it (method, headers, URL) is logged.
2. **Given** a response, **When** it arrives, **Then** its status code, duration, size and `X-RateLimit-Remaining` (when sent) are logged; a non-2xx status at error level.
3. **Given** a transport failure, a 429 cooldown, a 400 retry without language, a decoding failure or a call refused during a cooldown, **When** it happens, **Then** it is logged with its cause.
4. **Given** the tests, **When** they run, **Then** the client logs to a disabled logger.

## Requirements *(mandatory)*

- **FR-001**: Logging MUST use OSLog `Logger`; the client MUST receive it from its creator, and the composition root MUST pass the app's logger (subsystem = bundle identifier, category `network`).
- **FR-002**: Tests MUST pass a disabled logger (`Logger(OSLog.disabled)`).
- **FR-003**: The `curl` command MUST reproduce the request: method when not GET, every header, and the URL, single-quoted for a POSIX shell.
- **FR-004**: The `curl` command MUST be logged as private (it carries the search text); status, path, durations and sizes as public.
- **FR-005**: Levels: `curl` debug; 2xx info; non-2xx, transport and decoding failures error; cancellation debug.

## Success Criteria *(mandatory)*

- **SC-001**: Client tests run with a disabled logger. The `curl` command is debug output only and is checked by reading the console, not by tests.
- **SC-002**: All quality gates pass.
