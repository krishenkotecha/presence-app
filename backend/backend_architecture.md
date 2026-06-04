# Relationship Intelligence — Backend Architecture (MVP)

*Prototype scope: the smallest backend that lets two humans test whether the core loop works.*

---

## Addendum — Presence v2 contract (current public API)

The backend now conforms to the **Presence v2 frontend contract**. The app talks to exactly two endpoints, and the code in this repo implements them with their exact payload shapes:

- `POST /api/v1/conversations/analyze` — `multipart/form-data` (the success-definition fields + `conversation_audio` as `audio/x-caf`). Returns the **conversation-review** payload (summary, success_definition, metrics, key_moments, unmet_needs, next_time, duration_seconds).
- `GET /api/v1/relationships/work-on` — no query params. Returns the **longitudinal** payload (primary_focus, why_this_matters, relationship_patterns, improving, work_on_areas).

Pipeline for analyze: **audio → transcript (local Whisper via `transcribe.py`, ffmpeg for the CAF) → speaker diarization (`diarize.py`, pyannote) → computed signals (`signals.py`) + LLM (`generate_review`) → contract payload**. Diarization makes `word_balance` and `interruptions` measured rather than guessed, and each `key_moment` is snapped to the transcript turn its quote came from; the response carries `diarized`, `metrics_source`, and a `confidence` that is `medium` when diarized. `work-on` synthesizes across stored reviews (`generate_work_on`). If transcription/diarization or a model isn't installed, or the backend is `mock`, the endpoint returns contract-shaped **demo data** with a `note`, so the app always gets a valid response (mirroring its built-in local-demo fallback). Wire the two URLs into `PresenceApp.swift` (`analyzeURLString`, `workOnURLString`); for a physical device use the Mac's LAN IP, not `localhost`.

The conceptual design below (loop, state model, privacy, validation framing) still holds — the contract just fixes the exact wire format the app expects.

---

## 0. TL;DR

The MVP is an **LLM wrapper with memory**. It implements exactly the "Under the Hood" row of your diagram:

```
User sets success criteria  →  Capture conversation  →  LLM decodes + translates + evaluates
                            →  After-action report (with nudges)  →  History accrues  →  Longitudinal report
```

Everything else (real-time nudges, prosody, heart rate, audio pipeline, auth, multi-tenant) is deferred. The backend is a thin REST API over SQLite, with a single structured LLM call doing the "intelligence." It ships with a **mock mode** so you can exercise the full flow before wiring a key.

The whole point of building this small is to answer the five Steve Blank questions cheaply. The architecture is shaped around *instrumenting those questions*, not around the full vision.

---

## 1. What this MVP is built to prove

You are not building the product yet — you are building the instrument that tells you whether to build it. Every component below earns its place by producing a signal for one of your validation questions.

| Validation question | What the backend captures to answer it |
|---|---|
| Do users perceive communication pain? | Whether they create a conversation at all + the success criteria they write (the criteria *are* the pain, stated in their words) |
| Will users share relationship data? | Capture completion rate; consent acceptance vs. abandonment at the consent gate |
| Are insights actually useful? | `nudge_action` events — did they mark a nudge as acted-on / helpful / dismissed? |
| Does improvement create retention? | Repeat conversations per relationship + trend in relationship-state signals over time |
| Will someone pay? | Out of scope for the API itself, but retention + usefulness are the leading indicators you'll quote |

**North Star instrumentation:** the report ends with a single self-report prompt — *"Did this help you understand the other person better?"* — stored as a 1-tap signal. That is the metric the whole system optimizes for.

---

## 2. Non-negotiable design principles

These come straight from the design doc and are enforced in code (prompt + validation layer), not just documented.

1. **Tentative language only.** Outputs are observations and hypotheses, never verdicts. The system says *"Stress indicators increased"* / *"This may reflect an unmet need for…"*, never *"You are angry"* or *"She doesn't respect you."* Confidence is always labeled, and inferences are tied to the line they came from.
2. **Evidence-linked.** Every emotional theme, need, and translation references the specific utterance it was derived from. No free-floating claims. This is what makes outputs *explainable* and keeps the user in the position of judge.
3. **Privacy-first.** Consent is an explicit gate before any content is sent to the model. Hard delete is a first-class endpoint. Data minimization: we store the transcript, the analysis, and action signals — nothing else.
4. **User agency.** The user defines what success means ("What does success look like for you in this conversation?"). Nudges are suggestions ranked by how light-touch they are — awareness before intervention.
5. **Not an engagement product.** No notification machinery, no streaks-for-streaks'-sake, no screen-time optimization. The only loop we reinforce is *insight → small action → felt closeness → wanting more insight.*

---

## 3. System components

```
                ┌─────────────────────────────────────────────────────┐
                │                    REST API (FastAPI)                 │
                └─────────────────────────────────────────────────────┘
                      │              │                │            │
                      ▼              ▼                ▼            ▼
              ┌─────────────┐ ┌────────────┐ ┌──────────────┐ ┌───────────────┐
              │ Relationship│ │  Capture   │ │  Analysis    │ │ Longitudinal  │
              │  registry   │ │  service   │ │  engine      │ │  aggregator   │
              │             │ │ (consent + │ │ (LLM wrapper)│ │ (trend over   │
              │             │ │  content)  │ │              │ │  snapshots)   │
              └─────────────┘ └────────────┘ └──────┬───────┘ └───────┬───────┘
                      │              │              │                 │
                      └──────────────┴──────────────┴─────────────────┘
                                          │
                                   ┌──────▼───────┐        ┌──────────────────┐
                                   │   SQLite     │        │  Anthropic API   │
                                   │  (storage)   │        │ (Decode/Translate│
                                   └──────────────┘        │  /Suggest call)  │
                                                            └──────────────────┘
```

**Capture service** — accepts text content for a conversation, records the explicit consent flag, marks the conversation ready for analysis. (Audio is a V2 transcription stub.)

**Analysis engine** — the heart. Assembles a prompt from the behavioral framework + the user's success criteria + the transcript, calls the model once, validates the returned JSON against a fixed schema, persists it. This single call performs the doc's Decode → Translate → Connection Builder → Relationship State steps.

**Longitudinal aggregator** — reads the relationship-state snapshots across all analyzed conversations for a relationship and returns per-dimension trends. This is the "History → Longitudinal Report" loop in your top diagram.

---

## 4. The two loops from your diagram

**Single-conversation loop** (top-left of the block diagram):
```
POST /relationships/{id}/conversations   (set success criteria — "I'm Listening")
POST /conversations/{id}/capture          (attach transcript + consent)
POST /conversations/{id}/analyze          (LLM → report)
GET  /conversations/{id}/report           (after-action report with nudges)
POST /conversations/{id}/nudges/{i}/act   (user acts → usefulness signal → loop again)
```

**Longitudinal loop** (top-left "History → Longitudinal Report"):
```
GET /relationships/{id}/longitudinal      (trend across all snapshots)
```

---

## 5. Data model

Four tables. Deliberately flat — the analysis payload is stored as JSON so the schema can evolve without migrations during validation.

**relationships**
| field | type | notes |
|---|---|---|
| id | uuid | |
| label | text | user's name for it ("Me & Sam", "1:1 with Priya") |
| rel_type | text | `romantic` \| `professional` |
| counterpart | text | the other person's name/handle |
| created_at | datetime | |

**conversations**
| field | type | notes |
|---|---|---|
| id | uuid | |
| relationship_id | fk | |
| success_criteria | text | *"What does success look like for you in this conversation?"* |
| channel | text | `text` (now) \| `audio` (V2) |
| consent | bool | must be true before analyze |
| content | text | the transcript |
| status | text | `draft` → `captured` → `analyzed` |
| created_at | datetime | |

**analyses**
| field | type | notes |
|---|---|---|
| id | uuid | |
| conversation_id | fk | |
| model | text | model string used (or `mock`) |
| payload_json | json | full structured analysis (schema in §6) |
| created_at | datetime | |

**nudge_actions** — the usefulness/retention signal
| field | type | notes |
|---|---|---|
| id | uuid | |
| conversation_id | fk | |
| nudge_index | int | index into `payload.nudges` |
| outcome | text | `acted` \| `helpful` \| `dismissed` |
| note | text | optional free text |
| created_at | datetime | |

---

## 6. Analysis engine — the LLM wrapper (core of the system)

### Contract

**Input to the model:**
- A **system prompt** encoding the behavioral frameworks (Gottman, NVC/Rosenberg, Perel, Johnson/attachment) and the hard constraints (tentative language, evidence-linking).
- A **user message** containing: relationship type, counterpart name, the user's success criteria, and the transcript.

**Output from the model:** strict JSON, validated server-side. Closely mirrors the design doc's Decode/Translate/Connection-Builder/State sections:

```json
{
  "summary": "neutral 2-3 sentence recap",
  "topics": ["..."],
  "emotional_themes": [
    { "theme": "...", "evidence": "quoted line", "confidence": "low|medium" }
  ],
  "possible_needs": [
    { "speaker": "user|counterpart", "need": "...", "framework": "NVC|attachment", "evidence": "..." }
  ],
  "translations": [
    { "surface": "what was said", "possible_meaning": "what may have been meant", "evidence": "..." }
  ],
  "conflict_areas": [
    { "area": "...", "pattern": "e.g. criticism→defensiveness loop", "evidence": "..." }
  ],
  "repair": {
    "attempts_made": [ { "by": "...", "attempt": "...", "received": "yes|no|unclear" } ],
    "missed_opportunities": [ { "where": "...", "suggested_repair": "..." } ]
  },
  "connection_moments": [ { "moment": "...", "evidence": "..." } ],
  "unresolved_loops": ["..."],
  "relationship_state_signals": {
    "trust":          { "signal_0_100": 0, "rationale": "..." },
    "understanding":  { "signal_0_100": 0, "rationale": "..." },
    "responsiveness": { "signal_0_100": 0, "rationale": "..." },
    "repair_capacity":{ "signal_0_100": 0, "rationale": "..." },
    "shared_meaning": { "signal_0_100": 0, "rationale": "..." },
    "safety":         { "signal_0_100": 0, "rationale": "..." }
  },
  "success_evaluation": {
    "user_criteria": "echoed back",
    "assessment": "...",
    "met": "yes|partially|no|unclear"
  },
  "nudges": [
    { "type": "regulation|understanding|connection|repair|growth",
      "tier": "awareness|reflection|suggestion|intervention",
      "nudge": "...",
      "rationale": "..." }
  ],
  "next_steps": ["one concrete, small action"]
}
```

### Why one big call (for now)

For an MVP LLM wrapper, a single structured call is the right call: it's cheap to build, easy to evaluate, and the whole pipeline (Decode → Translate → Suggest) is coherent in one context window. You split it into a chain (separate decode/translate/nudge calls, retrieval over past conversations, a classifier guardrail) only *after* validation tells you the insight quality justifies the cost. Don't pre-optimize the pipeline before you know the insights land.

### Validation layer

After the model returns, the server:
1. Parses JSON (strips any code fences, retries once on malformed output).
2. Checks required keys exist; fills missing optional arrays with `[]`.
3. Runs a light **language guard** — flags any state rationale containing certainty verbs ("is angry", "hates", "always") so you can monitor adherence to the tentative-language rule during testing.

---

## 7. Relationship State model

From the doc: `Quality = Trust + Understanding + Responsiveness + Repair Capacity + Shared Meaning + Safety`.

Each dimension is scored 0–100 **by the model, per conversation, as a low-confidence signal** — explicitly a reading of *this interaction*, not a verdict on the relationship. The longitudinal aggregator stores each conversation's six numbers as a snapshot and returns the trend (first vs. latest, direction per dimension). The "chart with nudge points" in your User Flow row is a frontend rendering of these snapshots plus the nudges attached to each conversation.

---

## 8. Privacy, consent, deletion

- **Consent gate:** `/analyze` refuses unless `consent == true` on the conversation. The consent copy must disclose that the transcript is sent to the LLM provider for processing.
- **Hard delete:** `DELETE /conversations/{id}` and `DELETE /relationships/{id}` remove content, analyses, and action rows. No soft-delete, no archival.
- **Minimization:** no analytics SDK, no third-party tracking, no storage of anything beyond transcript + analysis + action signals.
- **Explainability:** every insight carries its evidence line, so a user can always ask "why did it say that?" and get the answer from the payload itself.

---

## 9. Explicitly out of scope (V2+)

Deferred until the core loop is validated: audio capture + transcription, real-time/"during" interventions, prosody / speech-speed / interruption / silence / speaking-balance analysis, heart-rate or any biosignal, authentication & multi-user accounts, multi-device sync, RAG over conversation history, fine-tuned guardrail classifiers, and any notification system.

---

## 10. Prototype tech stack

| Concern | Choice | Why |
|---|---|---|
| API | FastAPI + Uvicorn | fast to write, auto OpenAPI docs at `/docs` for hand-testing |
| Storage | SQLite (stdlib `sqlite3`) | zero infra, persists across restarts, mirrors the data model |
| LLM | Anthropic Python SDK, `claude-sonnet-4-6` default | balanced quality/cost for the analysis call; configurable via env |
| Validation | Pydantic | request/response shapes, gives you typed contracts for the frontend |
| Mock mode | built in | run the full flow with no API key to see the data shapes immediately |

Model string and SDK pattern verified against current Anthropic docs (June 2026). Swap to `claude-haiku-4-5-20251001` for cheaper/faster eval runs, or `claude-opus-4-8` for the highest-quality insights when judging output quality.

---

## 11. How to run

See `README.md`. In short: `pip install -r requirements.txt`, then `uvicorn main:app --reload`, then open `http://127.0.0.1:8000/docs`. With no `ANTHROPIC_API_KEY` set, the analysis engine returns a realistic mock so you can click through the entire capture → report → longitudinal loop before spending a token.

---

## 12. Suggested first experiment

1. Run in mock mode, click through `/docs`, confirm the report shape feels useful *to you*.
2. Add a key, paste 3–4 real (consented) transcripts from one relationship.
3. Read the reports cold. Ask the human North Star question yourself: *did this help me understand the other person better?*
4. If yes for ~3 of 4, you've cleared "insights are useful" — then put it in front of 5 strangers and watch whether they (a) accept the consent gate and (b) come back for a second conversation. Those two behaviors are your real validation, not the analysis quality in isolation.
