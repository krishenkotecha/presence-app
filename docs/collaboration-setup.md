# Presence collaboration setup

This is set up now so the iOS app and the backend can move in parallel without tripping over each other.

## current state

- Frontend app: SwiftUI iPhone prototype
- Product track: v2 relationship-focused flow
- Speech capture: live on-device microphone + transcription
- Backend handoff: in `docs/v2-backend-contract.md`
- Upload path: frontend packages the conversation audio plus both partners' success definitions
- Longitudinal page: frontend now also calls a dedicated `What should we work on?` backend surface

## what the frontend needs from the backend

At minimum, the backend should expose:

- one analyze endpoint for a single conversation review
- one longitudinal endpoint for `What should we work on?`

The analyze endpoint takes:

- the conversation audio file
- `participant_one_success_definition`
- `participant_two_success_definition`
- `shared_success_definition`
- session timing metadata

The recommended request and response shapes are documented here:

- `docs/v2-backend-contract.md`

There are now two contract surfaces to support:

- per-conversation review analysis
- longitudinal relationship coaching for `What should we work on?`

## current app behavior

The app already builds the conversation submission payload and is ready to send it.

Right now, if no backend URL is configured, the app falls back to local demo analysis so the flow stays testable.

That fallback now applies to both:

- the review page
- the `What should we work on?` page

## repo

The repo is already connected now, so this part is mostly historical. But from the project root the commands are still:

```bash
git remote add origin <your-repo-url>
git push -u origin main
```

Your codeveloper can clone it and work directly against the contract doc.

## suggested split

### Frontend

- capture both spoken success definitions
- record conversation audio
- upload packaged session to backend
- render returned analysis
- call the longitudinal relationship endpoint
- handle loading / retry / error states

### Backend

- receive multipart upload
- store audio if needed
- run transcription / analysis pipeline
- return structured response matching `v2-backend-contract.md`
- return a second aggregated relationship response for longitudinal coaching

## next thing to configure

The frontend still needs the real backend URLs filled into the app config once your cofounder has the endpoints ready.
