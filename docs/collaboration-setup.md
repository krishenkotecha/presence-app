# Presence Collaboration Setup

This project is now structured so the iOS prototype and backend can move in parallel.

## Current state

- Frontend app: SwiftUI iPhone prototype
- Product track: v2 relationship-focused flow
- Speech capture: live on-device microphone + transcription
- Backend handoff: documented in `docs/v2-backend-contract.md`
- Upload path: frontend packages the conversation audio plus both partners' success definitions

## What the frontend needs from the backend

At minimum, the backend should expose one analyze endpoint that accepts:

- the conversation audio file
- `participant_one_success_definition`
- `participant_two_success_definition`
- `shared_success_definition`
- session timing metadata

The recommended request and response shapes are documented here:

- `docs/v2-backend-contract.md`

## Current app behavior

The app already builds the submission payload and is ready to send it.

Right now, if no backend URL is configured, the app falls back to local demo analysis so the flow stays testable.

## To connect a shared repo

1. Create a GitHub repo, for example `presence-ios`.
2. From this project root:

```bash
git remote add origin <your-repo-url>
git push -u origin main
```

3. Your cofounder can then clone it and work against the contract doc.

## Suggested collaboration split

### Frontend

- capture both spoken success definitions
- record conversation audio
- upload packaged session to backend
- render returned analysis
- handle loading / retry / error states

### Backend

- receive multipart upload
- store audio if needed
- run transcription / analysis pipeline
- return structured response matching `v2-backend-contract.md`

## One thing to configure next

The frontend still needs the real backend URL filled into the app config once your cofounder has the endpoint ready.
