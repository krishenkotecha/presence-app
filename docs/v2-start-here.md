# Presence v2 Starter

This repo now includes a separate v2 starter shell so we can explore a simpler version of the product without tearing apart the existing v1 prototype.

## Where it lives

- App switch: `/Users/krishen/Documents/Playground/presence/Sources/PresenceApp.swift`
- v2 shell: `/Users/krishen/Documents/Playground/presence/Sources/V2/PresenceV2StarterRootView.swift`

## Current behavior

The app is currently pointed at `v2Starter`.

To switch back to the original prototype:

```swift
private let activeTrack: PrototypeTrack = .v1
```

## Why this exists

The first prototype became a fairly complete communication-mirror product. For v2, we wanted:

- a simpler place to start
- a way to rethink the core loop
- a safe way to preserve v1 while building something narrower

## What’s scaffolded now

- relationship-only v2 home
- two actions total:
  - `Start a conversation`
  - `What should we work on?`
- two-partner spoken success-definition step
- real microphone + speech transcription in setup and listening
- results page shaped around relationship-specific insight

## Backend handoff

The current frontend/backend contract draft lives here:

- `/Users/krishen/Documents/Playground/presence/docs/v2-backend-contract.md`

## Best next step

Wire the frontend upload flow against the backend contract:

1. package conversation audio + both spoken success definitions
2. send to backend
3. render backend results on the existing insight page
