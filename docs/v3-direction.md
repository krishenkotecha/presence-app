# Presence v3 — Anchored on the Core Pain

v2 proved the loop and added the solo on-ramp, but it still spreads across modes,
metrics, and a coaching dashboard. v3 collapses everything onto **one pain** and cuts
the rest. This doc is the anchor: if a feature doesn't make that pain's resolution
clearer, it's a candidate for removal.

Builds on `v2-frontend-redesign.md`, `v2-pivot-options.md`, `v2-solo-experience.md`,
and `v2-strategy-7-powers.md`.

---

## 1. The core pain

> **When it matters most with someone I love, I react to what was *said* instead of what
> was *meant* — so we miss each other, I don't know how to respond, and the same hurt
> keeps repeating.**

Two layers, one root:

- **Acute (the entry pain):** a specific charged moment — *"What did that actually mean,
  and what do I say back without making it worse?"* Felt right now, frequent, and solvable
  alone.
- **Chronic (the retention pain):** the misreadings compound — *"Why do we keep ending up
  in the same place?"*

Both come from the same thing: **a missing, accurate model of the other person's need
beneath their words.** That is the entire product to build and sell around.

---

## 2. The value unit

Everything ladders to one move:

> **what was said → what may have been meant → the need underneath → a response you can
> actually use.**

The acute pain is resolved by the *response*; the chronic pain is resolved by surfacing the
*recurring need*. Same engine, two time horizons.

One caveat from stress-testing (§10): a **regulation beat** ("you sound flooded — reset
first") often has to precede interpretation, because in a charged moment the gap is usually
staying calm enough to care, not decoding.

---

## 3. What v3 keeps

- The solo **decode / prep / reflect** flow (it is the value unit, single-player).
- The **Just me / With my partner** mode toggle (one focused path at a time).
- **Privacy-first, text-first, no audio required** (the on-ramp and the counter-position).
- **Never-blame, two-sided, tentative** content rules (the brand).

---

## 4. Add (each directly closes the said↔meant gap)

1. **Make the *response* the hero — as scaffold, not script.** Lead the result with a clear
   *direction* and a draft the user is explicitly told to make their own ("here's the move:
   name the feeling before you explain"), plus a one-tap tone control. Coach toward the
   user's own voice; never a send-this-verbatim line. Success = they felt more like
   themselves and understood better — **heavy verbatim reliance is a yellow flag, not a win**
   (see §10).
2. **"Why does this keep happening?" recurring-theme thread.** After a few reflections, name
   the repeating need ("'feeling unseen' has come up three times"). This is the bridge from
   the acute moment to the chronic pattern — and the real retention hook. Built on the
   per-user `reflections` memory already in the backend.
3. **A "did it land?" follow-up.** Later: *"You tried saying X — how did it go?"* Closes the
   loop, teaches, and generates the outcome data that is the moat.
4. **A "how they might have heard *you*" angle.** Let the user see their own contribution to
   the gap, not only decode the other person — builds the self-model and keeps it fair.

---

## 5. Remove / cut (they don't serve the pain; they dilute focus)

1. **Cut the *fabricated* precision (the invented connection score) — not all measurement.**
   The made-up score risks the honesty the brand rests on; remove it and the word-count grid.
   But keep one or two *honestly measured* signals (e.g., real interruptions when diarization
   is on) as a credibility anchor, so insight feels true rather than horoscope-like (§10).
2. **The "What should we work on?" coaching dashboard.** Replace with the recurring-theme
   thread (#4.2) — same chronic pain, served specifically instead of as generic analytics.
3. **The volume-driven "mood" color** on the live couples screen. A color from loudness says
   nothing about whether you're missing each other, and can mislead.
4. **Audio recording as a *requirement*.** Keep it only for the advanced couples mode; the
   acute pain is fully solvable from one typed line.

---

## 6. Improve (clarity)

- **Lead with the pain in the user's words.** Replace "Understand each other better" on entry
  with the felt problem — *"Not sure what they meant, or how to respond?"* — so someone in
  that moment instantly knows it's for them.
- **Foreground the *need* on every screen.** The need under the words is the spine; the quote
  and the reply are support.
- **Minimize time-to-value.** Useful output from a single short input (the quote alone). One
  line in → a real response out; never make them write an essay first.

---

## 7. Prioritization

| Tier | Change | Why now |
|---|---|---|
| **P0 — cut** | Remove the *fabricated* connection score (keep honest measured signals) | Honesty without losing the credibility anchor |
| **P0 — cut** | Drop the "work on" dashboard | Replaced by the recurring-theme thread |
| **P0 — copy** | Re-lead entry + results with the pain and the *need* | Clarity, no engineering risk |
| **P1 — add** | Regulation beat before decode (reset / prep) | The gap is often calm, not decoding |
| **P1 — add** | Response-as-*scaffold* + tone control | Acute pain; coach the voice, don't script it |
| **P1 — add** | Recurring-theme thread (uses `reflections` memory) | The chronic pain + retention + moat |
| **P2 — add** | "Did it land?" follow-up | Closes the loop; outcome data |
| **P2 — add** | "How they might have heard you" angle | Self-model; fairness |
| **P3 — later** | Remove/replace live mood color (couples) | Overlaps the honest-live-signal bet |

Sequence: cut and re-copy first (P0, no risk, instantly clearer), then the response-as-hero
and recurring-theme thread (P1, the two highest-value adds), then the loop-closers.

---

## 8. How it maps to the moat

- **Response-as-hero** = the value unit delivered well → word-of-mouth → **Brand**.
- **Recurring-theme thread + "did it land?"** = compounding per-user memory and consented
  **outcome** labels → **Switching Costs** + **Cornered Resource**.
- **Cutting metrics/dashboards** protects the honesty the whole moat rests on.

Easier-to-grasp value and a stronger moat are, again, the same move.

---

## 9. The line, and what not to lose

> **Presence helps you hear what they actually meant, and respond in a way that brings you
> closer.**

The one thing never to trade away in any simplification is the translation from
**words → need → usable response**. Everything that doesn't make that moment clearer or that
response better is a candidate for cutting.

**North star (unchanged):** did two humans understand each other better? **Disconfirming
test (revised — see §10):** the master test is whether the usefulness signal correlates with
retention *and* with "the next conversation went better." Watch the inverse failure too: if
users send the suggested reply *verbatim* and feel less like themselves, response-as-hero is
defeating the mission, not serving it.

---

## 10. Stress test & revisions

A dialectic on the §1–§2 thesis. The strongest objections, and what they change.

**Antithesis (the strongest objections):**

- **Script corrodes intimacy.** Handing over words optimizes "good line sent," not "understood
  each other"; it risks outsourcing the user's voice and feeling managed/scripted to the partner.
- **Misdiagnosis.** In charged moments the gap is usually *regulation* (flooding, defensiveness),
  not interpretation — a decode tool may fix the wrong layer.
- **One-sidedness.** A read built only on the user's account validates their frame and confidently
  characterizes an absent person who can't correct it; the chronic memory can feel like a
  partner-dossier.
- **Commodity.** The acute decode is already a general-chatbot habit with no moat; the durable
  value is the longitudinal memory.
- **Lost anchor.** Cutting *all* measurement leaves pure narrative that drifts toward Barnum
  statements; an honest measured signal is what makes insight feel true.

**Revisions adopted (now reflected above):**

1. **Regulation before interpretation** — a reset/prep beat precedes decode (§2, §7).
2. **Scaffold, not script** — coach toward the user's own words; invert the metric so heavy
   verbatim reliance is a failure signal (§4.1, §9).
3. **Keep honest measurement** — cut only fabricated precision; keep one or two measured signals
   as the credibility anchor (§5.1).
4. **Honest one-sidedness** — make the self-implicating angle mandatory, state "one read, your
   side only," and frame the chronic memory as the user's own growth — transparent and deletable.
5. **Decode = wedge, not moat** — the acute decode acquires; the longitudinal memory defends.

**The tests that decide it:**

- **Pain diagnosis interview:** code each recounted breakdown as "didn't know what they meant" vs
  "couldn't stay regulated." If regulation dominates, re-layer the product.
- **Script vs scaffold A/B (the single most important):** ready-to-send reply vs understanding +
  "write your own." Measure send-as-is rate, 48h closeness, and "did it feel like you?"
- **North-star correlation:** usefulness ↔ retention ↔ "next conversation went better." If insight
  rises but outcomes don't, it's a horoscope.
- **Commodity check:** how many already use a general chatbot for this (validates whether the wedge's
  real job is trust/memory, not the decode).
- **Timing check:** do reflections cluster in the *aftermath* rather than mid-moment? If so, design
  for processing + prep, not "in the moment."
- **Creepiness check:** partner-needs vs your-own-growth framing of the memory thread — comfort, and
  willingness to let the partner see it.

**Master test:** the script-vs-scaffold A/B — the thesis's most attractive feature is also its most
plausible way of quietly defeating the mission.
