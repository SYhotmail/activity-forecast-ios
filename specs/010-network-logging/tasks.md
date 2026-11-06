# Tasks: Network Logging

- [X] T001 Spec artifacts.
- [X] T002 [red] `curlCommand(for:)` tests; client tests construct the client with a disabled logger (`curlCommand` tests removed in T005).
- [X] T003 [green] Logger injection, `curlCommand`, logging in `fetch`; composition root passes the app logger.
- [X] T004 Docs: CLAUDE.md; all gates.
- [X] T005 Remove the `curlCommand` tests: the command is debug output only.
- [X] T006 Constitution 2.3.0: diagnostic logging exempt from Principle IV; plan Constitution Check; FR-005 levels; quickstart.md.
- [X] T007 Browse lifecycle logging (FR-006): `BrowseViewModel(service:logger:)` without a default, `onAppear`/`onDisappear` called from `BrowseView`; `App/Shared/Logger+Category.swift`; previews and `AppTests/BrowseViewModelTests.swift` pass `.disabled`; spec, plan, quickstart, CLAUDE.md.
- [X] T008 Log the service's error `reason` with each non-2xx response (private, FR-004; `ErrorResponseDTO`); spec, quickstart, contracts/open-meteo.md, CLAUDE.md.
