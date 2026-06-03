# Presence

SwiftUI iPhone prototype for a guided conversation-coaching product.

## Prototype Goal

Current prototype goal:

- feel the full Presence product loop end to end
- validate the setup, recording, check-in, and reflection flow
- use seeded example conversations before building the real analysis engine

## v1 Scope

- iPhone only
- tappable prototype flow
- seeded example session history
- setup with relationship type, conversation type, and goal
- simulated recording session
- post-conversation ratings
- structured reflection output

## Non-Goals

- live transcript streaming
- production analysis rubric
- persistent backend
- final visual polish

## v2 Starter

This repo also includes a separate v2 starter shell for a simpler second direction.

- App switch: `/Users/krishen/Documents/Playground/presence/Sources/PresenceApp.swift`
- Starter shell: `/Users/krishen/Documents/Playground/presence/Sources/V2/PresenceV2StarterRootView.swift`
- Notes: `/Users/krishen/Documents/Playground/presence/docs/v2-start-here.md`

The app is currently pointed at the v2 starter so we can begin shaping the next concept without disturbing the fuller v1 prototype.

Current v2 backend contract:

- [v2-backend-contract.md](/Users/krishen/Documents/Playground/presence/docs/v2-backend-contract.md)
- [v2-review-page.md](/Users/krishen/Documents/Playground/presence/docs/v2-review-page.md)
- [collaboration-setup.md](/Users/krishen/Documents/Playground/presence/docs/collaboration-setup.md)

The current v2 product now has two output surfaces:

- a per-conversation review page
- a longitudinal `What should we work on?` page

It also has two user loops:

- a conversation loop: start a conversation, define success, listen, review
- a longitudinal loop: come back later, review your patterns, and see what to work on

## Workflow Setup

### 1. Install Apple Tools

You need full Xcode from the Mac App Store. The command line tools on this machine are not enough for iPhone app development.

Recommended extras:

- Xcode
- an iPhone for on-device testing
- optionally `XcodeGen` for generating the project from `project.yml`

### 2. Open the Project

You have two paths:

1. Preferred: generate the project from `project.yml` with `XcodeGen`, then open `Presence.xcodeproj`.
2. Fallback: create a new SwiftUI iOS app in Xcode named `Presence`, then copy the files from `Sources/` into the app target and `Tests/` into the test target.

### 3. Configure Signing

Inside Xcode:

1. Select the app target.
2. Open `Signing & Capabilities`.
3. Choose your Apple account team.
4. Replace the bundle identifier if needed.

### 4. Run On Device

The current prototype can be explored in Simulator, though a real iPhone is still useful later once audio capture becomes part of the flow.

## What We Need To Build

1. A guided home screen with seeded session history.
2. A lightweight setup flow before recording.
3. A simulated recording experience with clear consent language.
4. A post-conversation check-in for training signals.
5. A structured reflection screen with believable example output.
6. A path to swap seeded scenarios for real transcript analysis later.

## Recommended First Build Order

1. Tappable flow
2. Seeded sample data
3. Reflection quality
4. Real recording integration
5. Analysis pipeline
6. Longitudinal memory

## Hardware Recommendation

## Tooling Note

This repo includes a SwiftUI prototype structure in `Sources/`, a small test target in `Tests/`, and an `XcodeGen` spec in `project.yml`. Full Xcode is still required to run it.
