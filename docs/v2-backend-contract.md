# Presence v2 backend contract

This is where the app is right now.

There are really two backend jobs:

1. analyze one conversation
2. look across conversations and tell the couple what to work on

The app is already wired for both.

There are also really two user loops:

1. `we're about to have a conversation, let's use Presence`
2. `what have we been like lately, and what should we work on?`

If no backend URLs are configured yet, both flows fall back to local demo data so the app still works.

The two empty config values in `/Users/krishen/Documents/Playground/presence/Sources/PresenceApp.swift` are:

- `PresenceV2BackendConfig.analyzeURLString`
- `PresenceV2BackendConfig.workOnURLString`

## 1. conversation review

This is the flow behind `Start a conversation`.

The loop is:

1. both people say what success looks like
2. Presence listens
3. the app uploads the audio plus that success definition
4. the backend returns a relationship debrief
5. the app shows the review page

This is the in-the-moment loop.

### what the app sends today

Right now the app sends `multipart/form-data`.

Suggested endpoint:

`POST /api/v1/conversations/analyze`

Fields the frontend already sends:

- `session_id`
- `started_at`
- `ended_at`
- `duration_seconds`
- `participant_one_label`
- `participant_two_label`
- `participant_one_success_definition`
- `participant_two_success_definition`
- `shared_success_definition`
- `prototype_track`
- `conversation_audio`

Current audio content type:

- `audio/x-caf`

Example:

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

If you want to do pre-signed upload later, that’s fine. But the app is currently built for one simple multipart request.

### what the backend should return

The review page is not supposed to feel like analytics. It should feel like:

- here’s what happened
- here’s where it changed
- here’s what each person needed
- here’s what to try next time

So the response needs to support:

- one headline insight
- the shared success definition
- balance of words
- interruptions
- connection score
- key moments with quotes and timestamps
- what each person needed
- one next step per person

This is the shape the frontend is decoding right now:

```json
{
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
      "person": "For you",
      "try": "Before explaining your intent, reflect back the feeling you think you heard in one sentence."
    },
    {
      "person": "For your partner",
      "try": "Name the underlying need earlier, before the conversation gets pulled into logistics."
    }
  ],
  "duration_seconds": 808
}
```

The frontend is fine with extra fields too. So if the backend wants to include things like:

- `analysis_id`
- `created_at`
- `confidence`
- `transcript`
- `speaker_segments`

that won’t break anything.

If you want the minimum useful version, this is enough:

- `summary.headline`
- `success_definition.shared`
- `metrics.word_balance`
- `metrics.interruptions`
- `metrics.connection_score`
- `key_moments[]`
- `unmet_needs[]`
- `next_time[]`
- `duration_seconds`

## 2. what should we work on?

This is the longitudinal relationship page.

This is the come-back-later loop.

It is not:

- what happened in this conversation

It is:

- what tends to happen between us over time
- how are we showing up together lately
- what is actually worth working on right now

This page should feel like:

- here’s the one thing most worth working on now
- here’s why
- here are the recurring patterns
- here’s what’s getting better too

### what the app calls today

The frontend is currently set up to call:

`GET /api/v1/relationships/work-on`

Right now it does not send query params from the app.

So the easiest backend implementation is:

- infer the current relationship from auth or session context, or
- just return one demo/default relationship payload for now

Later we can add:

- `relationship_id`
- `time_window`
- `topics`
- `conversation_types`

But the app does not need that yet.

### what the backend should return

The frontend is decoding this shape right now:

```json
{
  "relationship_id": "rel_01J7ZF4M1M0P2X3A1Y4V9B",
  "time_window": "90d",
  "primary_focus": {
    "title": "Stay with the feeling before moving into solutions.",
    "summary": "The two of you tend to reconnect when the emotional part lands first. When one of you starts fixing too early, the conversation becomes more procedural and less connected.",
    "frequency_label": "6 of your last 10 conversations",
    "context_label": "Especially true in money and planning"
  },
  "why_this_matters": [
    {
      "title": "Connection is stronger when you slow down first",
      "detail": "When feelings are named before logistics, your connection score is about 14 points higher than usual."
    },
    {
      "title": "This pattern shows up in harder conversations",
      "detail": "It appears most often in discussions about money, planning, and chores, especially when you are both already tired."
    }
  ],
  "relationship_patterns": [
    {
      "title": "One of you tends to want reassurance while the other wants clarity",
      "detail": "The most productive conversations happen when both needs are made visible early instead of competing under the surface."
    },
    {
      "title": "Money conversations become more efficient and less curious",
      "detail": "You both speak more directly and ask fewer follow-up questions when the topic turns to budgets or planning."
    }
  ],
  "improving": [
    {
      "title": "Interruptions are down this month",
      "detail": "You are both leaving more space before jumping in, especially in shorter check-in conversations."
    },
    {
      "title": "You are recovering from tension faster",
      "detail": "Even when conversations get sharp, you are finding your way back sooner than you were a few weeks ago."
    }
  ],
  "work_on_areas": [
    {
      "title": "Name the feeling underneath the logistics",
      "detail": "Try to say the emotional point out loud before discussing what the plan should be."
    },
    {
      "title": "Catch the first defensive response",
      "detail": "The moment one of you starts explaining instead of reflecting is usually the moment the conversation turns."
    },
    {
      "title": "Define success together earlier",
      "detail": "A simple shared goal at the start tends to keep the conversation from drifting into old patterns."
    }
  ]
}
```

Minimum useful version here is:

- `primary_focus`
- `why_this_matters[]`
- `relationship_patterns[]`
- `improving[]`
- `work_on_areas[]`

## shortest possible backend version

If your codeveloper wants the fastest path:

### endpoint 1

`POST /api/v1/conversations/analyze`

Accept multipart audio + success definition fields.
Return the review-page payload above.

### endpoint 2

`GET /api/v1/relationships/work-on`

Return the longitudinal payload above.

## current fallback behavior

Until the URLs are filled in:

- `PresenceV2BackendConfig.analyzeURLString`
- `PresenceV2BackendConfig.workOnURLString`

the app will keep using local demo data for both surfaces.
