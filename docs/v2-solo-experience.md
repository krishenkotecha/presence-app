# Presence v2 — Solo (Single-User) Experience: Build Spec

Implementation spec for the single-player on-ramp from `v2-pivot-options.md`. It is written to
be executed on a dedicated branch: it lists the exact files to add, edit, reuse, and avoid,
the backend contract, the prompt design, and a commit plan.

> **Why solo:** it removes the two-player cold start (the biggest adoption *and* power risk),
> delivers value in session one with no recording, and lets Brand + the consented dataset
> begin accruing from one motivated partner before the second ever joins.

Related: `v2-pivot-options.md` (rationale), `v2-strategy-7-powers.md` (why this strengthens
the moat), `v2-frontend-redesign.md` / `v2-backend-redesign.md` (the surrounding plan).

---

## 0. Branch plan

The repo has `main` and `feature`. Create the solo work off `main`:

```bash
# run locally (git is not reliable from the Cowork sandbox)
git switch main
git switch -c feature/solo-experience
```

Suggested commit sequence (each is independently testable):

1. `backend: add reflections analyze endpoint + generate_reflection + demo fallback`
2. `backend: introduce user_id identity + reflections table (replaces hardcoded rel_default for solo)`
3. `backend: extend frontend_contract_check.py with a solo contract test`
4. `ios: add Solo models + reflect() client method`
5. `ios: add SoloInputView (text + dictation + intent chips)`
6. `ios: add SoloResultView (translation + one next move; no metrics)`
7. `ios: reframe Home — solo as primary entry, couples mode secondary`
8. `ios: local solo history cache`

Open a PR `feature/solo-experience → main`; the backend commits are verifiable in CI/sandbox,
the iOS commits compile in Xcode.

---

## 1. The solo flow

Three screens, no two-partner step, no live recording:

1. **Input** — a text field + optional dictation, and a 3-way **intent** chip:
   - **Decode** — "They said *X* — what did they mean, and how do I respond?"
   - **Prep** — "I need to talk about *Y* — help me go in well."
   - **Reflect** — "Here's what just happened — help me process it."
2. **Processing** — reuse the existing held-breath processing screen.
3. **Result** — translation + one constructive next move (no metrics dashboard).

Voice is transcribed **on-device** (`SFSpeechRecognizer`) and only text is sent — no audio
leaves the phone. This is both the lowest-friction path and the Counter-Positioning privacy
posture.

---

## 2. Backend contract (new)

### Request
`POST /api/v1/reflections/analyze` — **JSON** (no multipart, no audio):

```json
{
  "reflection_id": "uuid",
  "user_id": "device-or-account-id",
  "mode": "decode" | "prep" | "reflect",
  "text": "free-text recount of the situation",
  "quote": "optional: the exact thing they said (decode mode)",
  "relationship_id": "optional: links solo entries to a couple later"
}
```

### Response

```json
{
  "reflection_id": "uuid",
  "status": "completed",
  "mode": "decode",
  "summary": { "headline": "string" },
  "translation": {
    "what_they_may_have_meant": "string",
    "their_possible_need": "string"
  },
  "your_part": "string (gentle, optional — may be empty)",
  "suggested_next": "string (a soft response, a prep opener, or a repair move)",
  "reframe": "string (optional)",
  "confidence": "low" | "medium",
  "model": "string",
  "note": "string (present only on demo/fallback)"
}
```

Notes:
- The app ignores unknown keys (same tolerance as the couples path), so extra provenance
  fields are safe.
- No `word_balance` / `interruptions` / `connection_score` — those need two speakers and are
  meaningless solo. **Do not** include a metrics block.
- Demo fallback (`demo_reflection`) returns this shape in mock mode so the app works with no
  model configured, exactly like `/conversations/analyze` today.

---

## 3. Backend changes (file-by-file)

### `analysis.py`
- Add `SOLO_SYSTEM = FRAMEWORK + …` — reuse the existing framework preamble (Gottman / NVC /
  attachment, tentative language, evidence-linked, non-judgmental). Append solo-specific
  rules (see §6) and the JSON shape from §2.
- Add `SOLO_SCHEMA` (mirror §2) and `generate_reflection(mode, text, quote=None)`:
  builds a mode-specific user message, calls `_generate(SOLO_SYSTEM, user, SOLO_SCHEMA)`,
  runs `_coerce` + a `_fill_reflection_defaults` (same defensive pattern as
  `_fill_review_defaults`).
- Add `demo_reflection(mode)` returning a contract-shaped example per mode.
- Mode → prompt variation:
  - **decode:** translate the quote → likely meaning + unmet need; suggest a soft,
    non-escalating response.
  - **prep:** surface what *you* may need and what *they* may need; produce a soft start-up
    opener + one pitfall to avoid.
  - **reflect:** name the need under your reaction + their likely need; suggest one repair or
    reconnection move.

### `main.py`
- Add `POST /api/v1/reflections/analyze` (JSON body via a Pydantic model or `Body(...)`),
  dispatching to `demo_reflection` in mock mode else `generate_reflection`, then persisting.
- **Identity + storage:** add a `reflections` table keyed by `user_id` (and optional
  `relationship_id`):
  ```sql
  CREATE TABLE IF NOT EXISTS reflections (
    reflection_id TEXT PRIMARY KEY,
    user_id TEXT,
    relationship_id TEXT,
    mode TEXT,
    created_at TEXT,
    payload_json TEXT
  );
  ```
  This is the moment to introduce the per-user identity the backend-redesign doc calls for —
  solo memory keys to the individual; the couple is stitched in later via `relationship_id`.
- Reuse the existing `nudge_actions` feedback table for solo usefulness signals (the
  consented dataset seed works single-user unchanged).
- Add `GET /api/v1/reflections/latest?user_id=…` and ensure the existing `DELETE` patterns
  cover reflections (privacy).

### `signals.py`
- No change. Speaker-attributed metrics don't apply to solo.

---

## 4. Frontend changes (file-by-file, `PresenceApp.swift` → ideally split per redesign)

**Add**
- `PresenceSoloResponse` (Decodable) mirroring §2 — tolerant decoding like the existing
  models.
- `PresenceV2BackendClient.reflect(_ submission:) async -> Result<PresenceSoloResponse, Error>`
  — JSON POST (not multipart); reuse the retry + `userMessage(for:)` plumbing.
- `PresenceSoloInputView` — text field + mic (reuse `PresenceSpeechCaptureManager` for
  dictation only; no live pulse, no `ConversationMonitor`) + the 3 intent chips.
- `PresenceSoloResultView` — cards for *what they may have meant / their possible need*,
  *your part* (optional, gentle), and *suggested next*; reuse the source banner + the
  usefulness feedback control. **No metric grid.**
- A lightweight on-device solo **history** cache (the memory corpus starts here).

**Reuse**
- `PresenceSpeechCaptureManager`, theme, button styles, `InsightBackdrop`, source banner,
  usefulness feedback, processing screen, backend-client retry/error mapping.

**Reframe**
- `PresenceV2HomeView`: make solo the **primary** entry (one input/CTA), demote "Start a
  conversation" (live couples mode) to a secondary action.

**Do not use for solo**
- The two-partner success-definition step, `PresenceV2ConversationView` / pulse /
  `PresenceV2ConversationMonitor`, multipart audio upload, and any
  word-balance/interruptions/connection-score UI.

---

## 5. Privacy & identity

- **Text-only, on-device transcription.** Dictation is transcribed locally; only text is
  POSTed. No audio upload, no server-side Whisper needed for solo. (Lowest friction +
  strongest privacy = the Counter-Positioning wedge.)
- **`user_id`** is an anonymous device/account identifier — the foundation that replaces the
  hardcoded `rel_default` and lets the memory corpus (Switching Costs) begin per individual.
- Wire deletion for reflections from day one (transparent deletion is a brand promise).

---

## 6. Content & safety rules (bake into `SOLO_SYSTEM`)

- **Translate toward understanding, never toward winning.** Solo mode helps one person show
  up better; it must never arm one partner against the other. Orient every output to the
  *other person's likely unmet need* and the user's own possible contribution.
- **Tentative language only** ("may", "it seems") — never assert the absent partner's
  internal state as fact. They aren't here to consent or correct, so the bar for humility is
  higher than in the couples path.
- **Non-judgmental and hopeful**; one small, doable next move, not a verdict.
- If the text suggests abuse or danger, do not coach "communication" — surface support
  resources. (Define this guard explicitly before launch.)

These protect the never-blame Brand that the whole moat rests on.

---

## 7. Verification & acceptance

- **Backend:** extend `frontend_contract_check.py` with a `--solo` path that POSTs each mode
  to `/reflections/analyze` and validates the response against the §2 required keys (same
  "would the app render real data or silently fall back" check). Runnable in the sandbox.
- **Unit:** add a `generate_reflection` shape test (mock/demo path) and a
  `_fill_reflection_defaults` test alongside `tests/test_signals.py`.
- **iOS:** manual pass on the three modes; confirm no audio leaves the device (network
  inspector shows JSON only).
- **Acceptance (north star, unchanged):** does the solo output help the user understand the
  other person better? Capture it with the existing usefulness signal, now also keyed to
  `mode`.

---

## 8. Out of scope for this branch

- The live couples "presence" listening + in-conversation nudge (stays as the expand-stage
  payoff).
- Partner invitation / stitching solo `user_id`s into a shared `relationship_id` (next
  branch — design the IDs now so it's clean later).
- The moments timeline / longitudinal view (separate branch; the solo `reflections` table is
  its first data source).

---

## 9. The one line

A solo, text-first companion — **decode, prep, reflect** — that one partner adopts with almost
no friction and no audio ever leaving the phone. It reuses the framework, the speech manager,
and the client plumbing already built; it adds one JSON endpoint and three light screens; and
it turns the hardest part of the product (two people, recording a fight) into the *last* step
instead of the first.
