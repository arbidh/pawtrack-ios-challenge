# PawTrack iOS Challenge

## The Scenario

You're building **PawTrack**, a mobile app for pet sitters. Sitters receive daily visit assignments, check in and out of visits, and capture photos as proof of service. Connectivity can be unreliable at client homes.

A previous developer started this project but left. You're picking it up. **Complete the required features, fix anything that looks wrong, and document your decisions.**

## Time Limit

**2 hours.** We value quality over quantity — a well-architected partial solution is better than a rushed complete one.

## Getting Started

1. Clone this repository
2. Generate the Xcode project (requires [XcodeGen](https://github.com/yonaskolb/XcodeGen)):
   ```bash
   brew install xcodegen   # if not already installed
   xcodegen generate
   ```
3. Open `PawTrack.xcodeproj`
4. Review the existing code in `PawTrack/` — models, services, and view models have been started
5. Mock data is provided in `MockData/` — use it in place of a real API
6. Build the required features below
7. Fill in `DECISIONS.md` with your reasoning

## Required Features

### 1. Visit List
Display today's assigned visits in a scrollable list. Each row should show:
- Pet name
- Address
- Scheduled time window
- Status badge (color-coded)

The list should support pull-to-refresh. Handle loading, empty, and error states appropriately.

### 2. Visit Detail + Status Transitions
Tapping a visit opens a detail view showing all visit information. The sitter can transition the visit through these statuses:

```
upcoming → en_route → in_progress → completed
```

- Transitions must be sequential (no skipping steps)
- Each transition should record a timestamp
- The UI should clearly indicate which transitions are available

### 3. Photo Capture
From the detail view, the sitter can capture a photo (camera or photo library):
- Photos are associated with the visit
- Captured photos display in the detail view
- Handle camera permission denial gracefully (direct user to Settings)

## Bonus Features (if time permits — pick one or both)

### A. Offline Persistence
Visits and captured photos persist locally so the app works after relaunch without network. If you implement this, describe your storage choice and sync strategy in `DECISIONS.md`.

### B. Filter & Search
Filter visits by status and search by pet name or address. Filter state should survive navigation (going into detail and back).

## What We're Evaluating

- **Architecture & code organization** — How you structure the app
- **iOS fundamentals** — Memory management, threading, lifecycle
- **Data handling** — How you model and validate data
- **UI/UX polish** — Loading states, error handling, attention to detail
- **Decision making** — Your reasoning in `DECISIONS.md`

## Submission

1. Fill in `DECISIONS.md` completely
2. Ensure the project builds and runs on the latest Xcode (26+) / iOS 26+
3. Submit via [instructions will be provided]

## Tech Requirements

- **Swift 5.9+**
- **iOS 26+** deployment target
- **SwiftUI** preferred for the UI layer (UIKit is acceptable where it makes sense)
- No third-party dependencies required (you may use them if you feel strongly, but document why in `DECISIONS.md`)
