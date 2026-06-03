# Presence v2 Backend Contract

This document defines the frontend/backend contract for the simpler relationship-focused v2 product.

The goal is to make one loop real:

1. Two partners define success out loud
2. Presence records the conversation
3. The app uploads the packaged audio + metadata
4. The backend analyzes it
5. The app renders a results page

## Product framing

Presence is not sending "a voice memo."

It is sending:

- a shared success definition from both partners
- the conversation audio itself
- enough metadata to let the backend interpret the session correctly

The backend should return:

- a high-confidence relationship debrief
- specific evidence moments
- structured fields for the results UI

## Frontend flow

### 1. Start a conversation

The user chooses:

- `Start a conversation`

### 2. Success definition capture

The app captures two short spoken responses:

- `You`
- `Your partner`

These are stored as:

- transcript text
- audio file URL or recorded file reference if needed later

The frontend combines those responses into one shared success definition for display, but it should also send the per-speaker raw fields to the backend.

### 3. Conversation capture

The app records:

- full conversation audio
- start time
- end time
- elapsed duration
- optional live transcript fragments if we choose to send them later

### 4. Processing

The app uploads one request to the backend and waits for one structured response.

## Recommended request shape

Use `multipart/form-data` for the first version.

That keeps the audio upload simple and avoids base64 overhead.

### Endpoint

Suggested:

`POST /api/v1/conversations/analyze`

### Multipart fields

#### Required text fields

- `session_id`
- `started_at`
- `ended_at`
- `duration_seconds`
- `participant_one_label`
- `participant_two_label`
- `participant_one_success_definition`
- `participant_two_success_definition`
- `shared_success_definition`

#### Optional text fields

- `app_version`
- `ios_version`
- `device_model`
- `locale`
- `timezone`
- `prototype_track`

#### Required file field

- `conversation_audio`

Suggested accepted content types:

- `audio/m4a`
- `audio/wav`
- `audio/x-caf`

### Example request fields

```text
session_id=2C20D5D0-0D99-4B5E-9A0B-8D2F8A13E5B3
started_at=2026-06-03T22:15:14Z
ended_at=2026-06-03T22:28:42Z
duration_seconds=808
participant_one_label=You
participant_two_label=Your partner
participant_one_success_definition=I want us to stay calm and actually feel understood before we solve anything.
participant_two_success_definition=I want to feel heard first, then leave with a clear plan we both believe in.
shared_success_definition=You: I want us to stay calm and actually feel understood before we solve anything.

Your partner: I want to feel heard first, then leave with a clear plan we both believe in.
prototype_track=v2
```

## Alternate JSON-first shape

If the backend prefers pre-signed uploads, use a two-step flow:

1. frontend uploads audio to storage
2. frontend sends JSON with `audio_url`

Suggested JSON body:

```json
{
  "session_id": "2C20D5D0-0D99-4B5E-9A0B-8D2F8A13E5B3",
  "started_at": "2026-06-03T22:15:14Z",
  "ended_at": "2026-06-03T22:28:42Z",
  "duration_seconds": 808,
  "participants": [
    {
      "id": "p1",
      "label": "You",
      "success_definition": "I want us to stay calm and actually feel understood before we solve anything."
    },
    {
      "id": "p2",
      "label": "Your partner",
      "success_definition": "I want to feel heard first, then leave with a clear plan we both believe in."
    }
  ],
  "shared_success_definition": "You: I want us to stay calm and actually feel understood before we solve anything.\n\nYour partner: I want to feel heard first, then leave with a clear plan we both believe in.",
  "audio": {
    "url": "https://...",
    "content_type": "audio/x-caf"
  },
  "client": {
    "app_version": "1.0",
    "prototype_track": "v2"
  }
}
```

## Recommended response shape

The results page should be driven by one stable response object.

Suggested:

```json
{
  "analysis_id": "a_01J7YF7TQJX2M1Q3W9R5Z1A9AB",
  "session_id": "2C20D5D0-0D99-4B5E-9A0B-8D2F8A13E5B3",
  "status": "completed",
  "summary": {
    "headline": "You were closest to success when the conversation stayed balanced instead of sliding into explanation.",
    "subheadline": "The biggest shift happened once the emotional point landed before either of you tried to solve it."
  },
  "success_definition": {
    "participant_one": "I want us to stay calm and actually feel understood before we solve anything.",
    "participant_two": "I want to feel heard first, then leave with a clear plan we both believe in.",
    "shared": "You both wanted understanding before problem-solving."
  },
  "metrics": {
    "word_balance": {
      "participant_one_percent": 54,
      "participant_two_percent": 46,
      "label": "Fairly even"
    },
    "interruptions": {
      "total": 7,
      "participant_one": 5,
      "participant_two": 2,
      "label": "Mostly from you"
    },
    "connection_score": {
      "score": 78,
      "delta_label": "+9 once you slowed down"
    },
    "repair_attempts": {
      "total": 3,
      "label": "Two landed well"
    }
  },
  "key_moments": [
    {
      "timestamp_ms": 190000,
      "type": "negative",
      "title": "Tension rose",
      "quote": "Yeah, but that’s not what I meant.",
      "speaker": "You",
      "explanation": "This shifted the conversation from impact to intent, which made your partner feel less met in the emotional part."
    },
    {
      "timestamp_ms": 525000,
      "type": "positive",
      "title": "Connection improved",
      "quote": "I can see why that felt lonely.",
      "speaker": "You",
      "explanation": "This was the first moment the feeling landed before the problem got solved, and the conversation softened immediately."
    }
  ],
  "unmet_needs": [
    {
      "person": "You",
      "need": "Reassurance that the conversation wasn’t becoming a character judgment."
    },
    {
      "person": "Your partner",
      "need": "A clearer sign that the emotional part landed before the problem-solving started."
    }
  ],
  "next_time": [
    {
      "person": "You",
      "try": "Before explaining your intent, reflect back the feeling you think you heard in one sentence."
    },
    {
      "person": "Your partner",
      "try": "Name the underlying need earlier, before the conversation gets pulled into logistics."
    }
  ]
}
```

## Minimum response fields for v1 backend

If your cofounder wants to move fast, these are the minimum useful fields:

- `summary.headline`
- `metrics.word_balance`
- `metrics.interruptions`
- `metrics.connection_score`
- `key_moments[]`
- `unmet_needs[]`
- `next_time[]`

Everything else can be filled in later.

## Error states

The backend should return predictable errors so the frontend can render calm recovery states.

Suggested:

```json
{
  "status": "error",
  "code": "AUDIO_TOO_SHORT",
  "message": "The conversation was too short to analyze meaningfully."
}
```

Suggested error codes:

- `UNAUTHORIZED`
- `INVALID_AUDIO_FORMAT`
- `AUDIO_TOO_SHORT`
- `TRANSCRIPTION_FAILED`
- `ANALYSIS_FAILED`
- `RATE_LIMITED`
- `INTERNAL_ERROR`

## Frontend handling expectations

The app should be prepared for:

- upload in progress
- analysis in progress
- partial failure
- successful result

Suggested polling fallback if the analysis is async:

1. `POST /api/v1/conversations/analyze`
2. receive `analysis_id` and `status: processing`
3. poll `GET /api/v1/conversations/analyze/:analysis_id`
4. navigate to results when `status: completed`

If the backend can return the full result synchronously for now, that is simpler for the prototype.

## Recommendation

Best first backend contract:

- `multipart/form-data`
- one audio file
- both success-definition transcripts as text fields
- one structured synchronous JSON response

That is the fastest way to make the full loop real without overdesigning the transport.
