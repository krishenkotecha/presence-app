# Presence v2 starter

This repo now includes a separate v2 starter shell so we can explore a simpler version of the product without tearing apart the existing v1 prototype.

## where it lives

- App switch: `/Users/krishen/Documents/Playground/presence/Sources/PresenceApp.swift`
- v2 shell: `/Users/krishen/Documents/Playground/presence/Sources/V2/PresenceV2StarterRootView.swift`

## current behavior

The app is currently pointed at `v2Starter`.

To switch back to the original prototype:

```swift
private let activeTrack: PrototypeTrack = .v1
```

## why this exists

The first prototype became a fairly complete communication-mirror product. For v2, we wanted:

- a simpler place to start
- a way to rethink the core loop
- a safe way to preserve v1 while building something narrower

## what’s scaffolded now

- relationship-only v2 home
- two actions total:
  - `Start a conversation`
  - `What should we work on?`
- two-partner spoken success-definition step
- real microphone + speech transcription in setup and listening
- review page shaped around relationship-specific insight

## current product focus

The next major areas of work are:

- the review page for a single conversation
- the longitudinal `What should we work on?` page

That maps to two very different user loops:

- `we're about to talk, let's start a conversation`
- `let's step back and look at what our patterns have been lately`

The review page should:

- borrow some structural ideas from v1
- stay emotionally simple and relationship-first
- show quoted turning points from the conversation
- connect the analysis back to both partners' stated definition of success

Reference:

- `/Users/krishen/Documents/Playground/presence/docs/v2-review-page.md`

The `What should we work on?` page should:

- focus on relationship-level patterns over time
- surface one main area worth working on now
- support that recommendation with longitudinal signals
- show what is improving so the product does not feel punitive

Backend reference:

- `/Users/krishen/Documents/Playground/presence/docs/v2-backend-contract.md`

## backend handoff

The current frontend/backend contract lives here:

- `/Users/krishen/Documents/Playground/presence/docs/v2-backend-contract.md`

The current frontend already supports:

- a review endpoint for one recorded conversation
- a longitudinal endpoint for `What should we work on?`

Until those URLs are configured, both screens fall back to local demo data.

## best next step

Wire the frontend upload flow against the backend contract:

1. package conversation audio + both spoken success definitions
2. send to backend
3. render backend results on the review page
4. add a backend-powered longitudinal response for `What should we work on?`
