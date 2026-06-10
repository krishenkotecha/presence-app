# Presence v2 — Backend Redesign (through the 7 Powers)

Companion to `v2-frontend-redesign.md` and `v2-strategy-7-powers.md`. The original backend
audit (`IMPROVEMENT_PLAN.md`) ranked work by reliability and hygiene. The strategy re-ranks
it: the backend's job is no longer "analyze a conversation well" (rentable, copyable) — it is
**to accumulate and protect the couple's relational memory and the consented dataset that
make Presence defensible.** Two items the audit treated as mid-list hygiene become the top of
the backend roadmap, because they *are* the moat.

---

## What changed vs. the audit

| Backend area | Audit framing | Strategy framing |
|---|---|---|
| Relationship identity & longitudinal store | "single `rel_default`, no auth — fine for pilot" | **Switching Costs (primary moat) — top priority** |
| Feedback signal (`nudge_actions`) | "nice north-star instrumentation" | **Cornered Resource — the proprietary dataset seed** |
| Transcripts in plaintext SQLite, deletion | "privacy hygiene" | **Counter-Positioning + Branding — existential trust** |
| Diarization (measured metrics) | "optional, heavy" | **Branding — measured, non-fabricated = credible** |
| Async jobs, size limits, WAL, tests | reliability | enabling (unblocks takeoff; not itself a power) |

---

## 1. Relational memory & identity — *Switching Costs (primary)*

The moat is the couple's accumulated memory, so the backend must hold it durably and per
relationship — not in one global bucket.

- **Replace the hardcoded `rel_default` with real per-relationship identity** (account or
  paired-device). Every analysis, moment, and feedback row keys to *this couple*.
- **A durable longitudinal store**, not just a list of payloads: the couple's recurring
  patterns, **remembered moments**, and prior `next_time` suggestions — the substrate the
  frontend's moments timeline and "you tried it, and it worked" callback read from.
- **"Tried it / it landed" detection:** persist each conversation's `next_time` items and,
  on the next session, detect when one reappears in the new transcript. This single signal
  powers the highest-joy, highest-stickiness frontend moment — so it belongs server-side,
  computed and stored, not re-derived ad hoc.
- Schema sketch: `relationships`, `conversations` (already ~`analyses`), `moments`
  (quote, valence, timestamp, "worth remembering"), `suggestions` (text, status:
  open/reappeared), all foreign-keyed to `relationship_id`.

> Why it's #1: every quarter this corpus compounds, a competitor's head start shrinks
> relative to it, and the cost of a couple leaving rises. That's the definition of a
> switching cost — and it's pure backend.

## 2. The consented dataset — *Cornered Resource*

The feedback already captured (`nudge_actions`: outcome × model × confidence) is the seed of
an asset no competitor can ethically acquire: real, consented, **outcome-labeled** couple
conversations.

- **Treat it as a first-class dataset, not a metric.** Add explicit **consent flags** and a
  data-rights record per relationship; structure outcomes so they're trainable.
- **Aggregation/eval endpoint:** report usefulness by model + confidence (and eventually by
  nudge type) — both the north-star instrument *and* the labeling pipeline.
- **Export path** for model improvement, gated by consent. The flywheel — consented data →
  better relational model → stronger brand → more consented data — lives here.

> Barrier check (Helmer): this is only a Cornered Resource while access stays genuinely hard.
> Keep the consent/privacy bar high enough that the data can't be commoditized. The barrier
> *is* the trust the privacy work below creates.

## 3. Privacy as moat protection — *Counter-Positioning + Branding*

Trust is the load-bearing wall under three of the four powers. In the audit this was hygiene;
in the strategy it's existential, because a single breach can collapse switching costs, the
cornered resource, and the brand at once.

- **On-device / "don't upload audio" mode as a real, advertised path.** The `device_transcript`
  fallback already exists — promote it to a user-chosen privacy mode. This *is* the
  Counter-Positioning move: ad/data incumbents can't credibly match it.
- **Encrypt transcripts at rest; add a retention / auto-delete policy.** Don't keep intimate
  text indefinitely in plaintext SQLite.
- **Wire the existing `DELETE` endpoints** to a real in-app "delete this / delete everything"
  control, and confirm **audio is never persisted** server-side (formalize + document it).
- Make data handling **transparent and explainable** — the brand promise is "safe and
  non-creepy," and the backend has to be able to back it up.

## 4. Measured, honest metrics — *Branding (credibility)*

The brand promise is "honest, not fabricated." We already softened the invented
`connection_score` deltas; the backend should move the genuinely measurable signals from
estimate to measurement.

- **Make diarization first-class** in the deployment we test with (WhisperX consolidates
  faster-whisper + pyannote + alignment), so word balance and interruptions — the *listening*
  metrics — are computed, not guessed.
- Keep `metrics_source` provenance and never present an estimate as a measurement.

## 5. Reliability — *enabling (not a power, but unblocks takeoff)*

These don't create power, but Power must be banked *before* competitive intensity rises, so
the platform has to survive growth.

- **Async analysis job + polling** (the `status` field already exists; make it real) so
  long transcription/diarization/LLM runs don't block the request or time out.
- **Upload size limits / stream to disk**; **WAL** (done) and **`signals.py` tests** (done).

---

## Sequencing (mapped to Helmer's stages)

**Origination (now):** stand up per-relationship identity (§1 foundation), the on-device
privacy mode + deletion (§3), and the consent flags on the feedback seed (§2). These are the
powers you can only establish early and cheaply.

**Takeoff:** build out the longitudinal memory store + "tried it/landed" detection (§1), the
eval/aggregation + export pipeline (§2), measured diarization (§4), and async jobs (§5).
Compound the switching-cost corpus *before* competitors arrive.

**Stability:** turn the consented corpus into a continually improving relational model, and
the safe-nudge pipeline into Process Power.

---

## The one line

The backend's strategic job is not better analysis — it is to be the **durable, private
keeper of each couple's relational memory** (switching costs) and the **steward of a
consented, outcome-labeled dataset** (cornered resource), both defended by **privacy as
counter-position**. Reliability and hygiene serve that; they aren't the point.
