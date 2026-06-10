# Presence — Validation Plan: The Sharpest Test

A concrete, runnable design for the one experiment that de-risks the invention:

> A randomized comparison where the **partner** rates whether they felt more understood, **and**
> the user demonstrably **did something different** in the next real conversation — product arm
> vs control. Two-sided, behavioral, randomized. If the delta is real and durable, the invention
> is de-risked. If not, you've learned it cheaply.

This isolates the claim from everything that fakes it (placebo, attention, self-report bias,
selection, regression to the mean) by combining four design choices: **randomized**, **active
control**, **dyadic (two-sided) measurement**, and **blind-coded behavior** over self-report.

---

## 1. Hypotheses & endpoints

**H1 (perceptual, primary).** Partners of treatment users report a larger increase in *felt
understood* than partners of control users.

**H2 (behavioral, co-primary).** Treatment users show a larger increase in *target listening
behaviors* in a real conversation (blind-coded) than control users.

**H3 (durability).** The H1/H2 advantages persist at a delayed follow-up with no further heavy
intervention (tests transfer, not just in-app crutch).

| Endpoint | Type | Measure | Source |
|---|---|---|---|
| **Primary** | Perceptual | Δ felt-understood (validated item/scale) | Partner-rated, both directions |
| **Co-primary** | Behavioral | Δ target behaviors (paraphrase, soft start-up, repair, fewer interruptions, "feeling before fixing") | Blind coders |
| Secondary | Accuracy | Δ empathic accuracy (predict partner's feeling/need vs their actual report) | Two-sided |
| Secondary | Outcome | Relationship satisfaction; "this went better than usual" | Both partners |
| Secondary | Self-understanding | Decline in the user's recurring theme over time | App memory |
| Durability | All above | Same measures at T2 | Both partners / coders |

Two signals must move *together* — the user's quote requires both *felt more understood* (H1)
**and** *did something different* (H2). Perception without behavior, or behavior without
felt-understanding, is a partial result, not a pass.

---

## 2. Design

- **Type:** parallel-group randomized controlled trial.
- **Unit of randomization:** the **couple (dyad)** — randomize couples, not individuals, to
  avoid within-couple contamination.
- **Blocking/stratification:** balance arms on baseline relationship satisfaction and conflict
  frequency (block randomization).
- **Active control, not nothing:** the control arm must equalize attention, reflection, and
  expectancy so the test isolates the *specific* ingredient (said→meant→need + behavior
  scaffolding), not "used an app / journaled / felt hopeful."

**The behavioral paradigm (how "did something different" becomes observable):** a standard
recorded **conflict-conversation task** at baseline and follow-up. Each couple discusses a real
ongoing disagreement for ~10–15 minutes (video, can be self-recorded at home). Treatment couples
use Presence in between (real life + at least one prepped/decoded conversation); control uses the
placebo. The T0→T1 change in blind-coded behavior is the behavioral endpoint.

---

## 3. Arms

| Arm | What they get |
|---|---|
| **Treatment** | The real product: solo decode/prep/reflect **plus** the behavior-change scaffolding — one concrete next move, an *implementation intention* ("when X, I'll Y"), regulation beat, and the "did it land?" follow-up. |
| **Active control** | A credible placebo with equal touchpoints: generic, reputable relationship tips + a journaling/reflection prompt for the same conversation, same cadence, same recorded-conversation tasks — but **no** personalized said→meant→need translation and no implementation-intention scaffolding. |

A later 3-arm variant can add **scaffold vs script** (the dialectic's master test); keep this
first study to 2 arms for power and clarity.

---

## 4. Measures

- **Felt-understood (primary):** a short validated perceived-understanding / perceived-partner-
  responsiveness measure, completed by **each** partner after each recorded conversation.
- **Empathic accuracy:** immediately after, each partner writes what they think the *other* was
  feeling/needing; compared to the other's own report. Scored 0–1 by blind raters.
- **Behavioral coding (co-primary):** trained coders, **blind to arm and timepoint**, score the
  recorded conversations on a fixed rubric — reflective paraphrase, soft start-up, repair
  attempts, interruptions (reverse), "names feeling before solving." Double-code a subset for
  inter-rater reliability (target κ ≥ 0.7).
- **Outcome:** brief relationship-satisfaction measure + single "did this go better than usual?"
- **Self-understanding (app-native):** whether the user's recurring theme diminishes over the
  study (free, from the `reflections` memory).

---

## 5. Procedure & timeline

| Phase | When | What |
|---|---|---|
| Screen + consent | Day 0 | Eligibility, consent, baseline surveys |
| **T0 baseline** | Week 0 | Recorded conflict conversation + post-survey (both partners), empathic-accuracy task |
| Randomize | Week 0 | Couple → treatment or active control (blocked) |
| Intervention | Weeks 1–3 | Real-life use of assigned app; ≥1 prepped/decoded conversation |
| **T1 follow-up** | Week 4 | Recorded conflict conversation + post-survey + accuracy task |
| **T2 durability** | Week 8 | Same measures, **no** heavy intervention in between |

---

## 6. Sample size

- **Pilot (first):** ~20–30 couples/arm. Purpose: feasibility, coding reliability, and an
  **effect-size estimate** — not a verdict.
- **Confirmatory (powered):** for a medium between-groups effect (d ≈ 0.5) at 80% power, α .05,
  ≈ 64 couples/arm (~128 total); inflate for attrition (~150–170). Final n should be set by a
  statistician using the pilot effect and dyadic clustering.
- Dyadic data are non-independent — analyze with multilevel / actor–partner models, not
  partner-averaged t-tests.

---

## 7. Analysis (pre-register before unblinding)

- **Difference-in-differences:** change scores (T1−T0, and T2−T0), treatment vs control.
- **Models:** multilevel / actor–partner interdependence models for dyadic non-independence;
  **intention-to-treat** primary, per-protocol secondary.
- **Pre-registration:** lock primary endpoint, analysis, and the success/kill criteria below
  *before* data collection — this is itself a de-risking step (prevents post-hoc rationalization).

---

## 8. Pre-registered success / kill criteria

**Pass (invention de-risked) requires all three:**
1. **H1:** treatment beats control on Δ felt-understood by a pre-set margin (e.g., ≥ 0.4 SD),
   significant.
2. **H2:** treatment shows a significantly larger increase in blind-coded target behavior.
3. **H3:** the advantage is still present at T2 (durable, not novelty).

**Soft signal (iterate):** H1 holds but H2 doesn't → understanding moves but behavior doesn't;
strengthen the action mechanisms (implementation intentions, in-moment cue, reinforcement).

**Kill / pivot:** neither H1 nor H2 beats control → the diagnosis is likely wrong (e.g., the gap
is regulation, not interpretation). Re-diagnose before building more.

**Red flag even on a "pass":** if H2 is driven by users sending AI-scripted lines and felt-
understanding *drops* at T2 (the dependency/script failure), treat as a fail — measure
transfer, i.e., behavior change *without* leaning on the app.

---

## 9. The lean version (run this first, in weeks)

You don't need a lab. A scrappy-but-valid version:
- Recruit 40–60 couples online; everything remote and self-administered.
- Conversations recorded over video at home (T0/T1); store for coding.
- Randomize via a **backend arm flag**; serve real product vs placebo content accordingly.
- Two-sided surveys delivered in-app right after each task (reuse the existing feedback
  instrumentation).
- Two trained coders score a blinded sample against the rubric.
- Cost is mostly recruitment + a few weeks of coding. Goal: a believable effect-size estimate
  and a go/no-go on the powered study.

---

## 10. Confounds & safeguards

| Threat | Safeguard |
|---|---|
| Placebo / attention / expectancy | Active control with equal touchpoints |
| Self-report / demand characteristics | Partner-rated + blind-coded behavior over self-report |
| Selection (motivated users improve anyway) | Randomization + control arm |
| Regression to the mean | Control arm (affects both equally) |
| Coder bias | Blind to arm/timepoint; inter-rater reliability |
| Novelty fade | T2 durability follow-up |
| "AI scripted it" ≠ user changed | Measure transfer (behavior without the app) |

---

## 11. Ethics & safety

Informed consent (incl. recording); **exclude couples with abuse/IPV or acute crisis** and route
to resources; privacy-protected storage of conversations with explicit deletion; an independent
clinical advisor and IRB review if run with an academic partner (which also deepens the brand and
cornered-resource credibility from `v2-strategy-7-powers.md`).

---

## 12. How it plugs into the product

The build already has most of the instrumentation:
- **Arm assignment:** a flag on the user/couple record; the backend serves treatment vs placebo.
- **Two-sided ratings:** extend the feedback capture to store partner-rated felt-understood +
  accuracy, keyed to timepoint and arm.
- **Behavior signal:** the recorded conversations feed coding; longer term, the same target
  behaviors can be auto-detected from transcripts (the couples analysis pipeline).
- **Self-understanding:** the `reflections` recurring-theme decline is logged for free.

So the experiment isn't a separate effort bolted on — it's the product's own telemetry, turned
into a controlled study. Build the arm flag + two-sided capture once, and you can keep running
this test continuously.

---

## The one line

Randomize couples, measure the **partner's** felt-understanding and the user's **blind-coded
behavior** before/after against an **active control**, and check it **lasts**. That single delta
is the foundation the whole billion-dollar plan rests on — prove it small and cheap before
spending big.
