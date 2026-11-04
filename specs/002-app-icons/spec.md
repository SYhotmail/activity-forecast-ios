# Feature Specification: App Icons

**Feature Branch**: `002-app-icons`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "add icons for the app"

## Context

The app currently ships with an empty app-icon slot, so it shows the system's blank placeholder on the Home Screen, in Settings, in Spotlight and in the app switcher. Inside the app, the four activity sections (Skiing, Surfing, Outdoor sightseeing, Indoor sightseeing) are identified by text alone.

## Clarifications

### Session 2026-11-04

- Q: Should the feature include in-app activity icons or only the Home Screen app icon? → A: Both. Activity icons (one per activity, in forecast section headers and the day detail sheet) are in scope alongside the app icon.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recognisable app on the Home Screen (Priority: P1)

A person installs the app and wants to find it again among their other apps. They see a distinctive icon that suggests "weather for activities", not a blank placeholder.

**Why this priority**: A blank icon makes the app look unfinished and hard to find. Reviewers notice it as soon as they install the app. It is the minimum for the app to look complete.

**Independent Test**: Install the app on a simulator or device and look at the Home Screen, Spotlight search, Settings and the app switcher. A custom icon appears in each one.

**Acceptance Scenarios**:

1. **Given** the app is installed, **When** the user views the Home Screen, **Then** the app shows its custom icon, not the blank placeholder.
2. **Given** the Home Screen is set to Dark appearance, **When** the user views the app icon, **Then** a dark variant is shown that stays legible and on-brand.
3. **Given** the Home Screen is set to Tinted appearance, **When** the user views the app icon, **Then** the icon's motif stays recognisable as a single-tone glyph.
4. **Given** the user searches for "Activity Forecast" in Spotlight or opens Settings, **When** the app appears in the list, **Then** it shows the same icon at the smaller size, and the motif can still be made out.

---

### User Story 2 - Activities identifiable at a glance (Priority: P2)

On the forecast screen, a person scanning the ranked list can tell which section is which activity from an icon next to its name, without reading the label.

**Why this priority**: It makes the ranked list quicker to scan, but the screen already works with text labels.

**Independent Test**: Open the forecast for any place. Each of the four activity section headers shows a distinct icon next to the activity name. The same icon appears in that activity's day detail sheet.

**Acceptance Scenarios**:

1. **Given** a loaded forecast, **When** the user views the activity sections, **Then** each activity has its own icon, and no two activities share one.
2. **Given** VoiceOver is on, **When** focus reaches a section header, **Then** the activity name is read once, with no extra announcement for the icon.
3. **Given** the largest accessibility text size, **When** the user views a section header, **Then** the icon scales with the text and nothing is cut off or overlaps.

---

### Edge Cases

- Smallest system sizes (Settings and Spotlight lists): the motif must stay recognisable, so it cannot depend on fine detail or text inside the icon.
- Dark and Tinted Home Screen modes: the icon must not turn into an unreadable block or lose contrast.
- Light and Dark app appearance: activity icons must keep enough contrast against the section background in both.
- Activity icons must not be confused with the existing status icons in the app: the ★ best-day mark, the search, "no places" and warning symbols.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST provide a custom app icon that replaces the blank placeholder everywhere the system shows the app icon (Home Screen, Spotlight, Settings, app switcher, notifications).
- **FR-002**: The app icon MUST provide Default (light), Dark and Tinted appearance variants that share one motif.
- **FR-003**: The app icon motif MUST suggest weather and outdoor activity, MUST contain no text, and MUST stay recognisable at the smallest size the system displays.
- **FR-004**: The app icon MUST be original artwork owned by the project, with no third-party logos, trademarks or licence-restricted assets.
- **FR-005**: Each of the four activities MUST have a distinct icon shown next to its name in the forecast section header and in the day detail sheet.
- **FR-006**: Activity icons MUST be decorative to assistive technologies. The activity name stays the only spoken label, and the existing VoiceOver phrasing for day cells MUST NOT change.
- **FR-007**: Activity icons MUST scale with the user's text size and MUST keep sufficient contrast in both Light and Dark appearance.

### Key Entities

- **App icon**: one motif delivered in three appearance variants (Default, Dark, Tinted).
- **Activity icon**: one visual symbol per activity (Skiing, Surfing, Outdoor sightseeing, Indoor sightseeing). The mapping is fixed, and every activity has exactly one icon.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a fresh install, the custom icon appears in 100% of the system places where the app icon is shown (Home Screen, Spotlight, Settings, app switcher). The blank placeholder appears nowhere.
- **SC-002**: The icon is visually checked in all 3 Home Screen appearances (Default, Dark, Tinted), and its motif is recognisable in each.
- **SC-003**: In a quick check, a viewer correctly matches all 4 activity icons to their activity names without reading the labels.
- **SC-004**: With VoiceOver on, the spoken output for section headers and day cells is word-for-word unchanged from before this feature.
- **SC-005**: At the largest accessibility text size, no section header shows truncated or overlapping content.

## Assumptions

- Scope is both the Home Screen app icon (P1) and in-app activity icons (P2), confirmed in Clarifications. Activity icons are a scanning aid only and carry no information beyond the activity name.
- The app icon artwork is created within the project (no commissioned designer, no paid icon packs), consistent with the project's no-third-party-assets stance.
- Activity icons can use the platform's built-in symbol set, which is free to use in apps on that platform and matches the system look. This does not count as a third-party asset.
- Only iPhone is in scope, following the existing project scope (portrait-first, iOS 18 minimum). No iPad, watch, Mac or alternate user-selectable icons.
- Marketing or App Store artwork beyond the icon itself is out of scope.
