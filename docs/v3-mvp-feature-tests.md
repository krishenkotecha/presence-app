# Presence — MVP Feature Tests

Tactics: turn the strategy (`v3-synthesis.md`) into *features* with *one in-product signal*
and *one pass bar* each. These are the cheap, continuous, in-product version of the RCT in
`v3-validation-plan.md` — leading proxies you can read every day. Same constructs, lower rigor;
the RCT is the verdict, these tell you fast whether to keep going.

**Instrumentation is built.** All signals are one-tap `POST /api/v1/events` rows; the live
read-out is `GET /api/v1/metrics/feature-tests`. Event `kind`s:
`helped · true_about_them · tried_it · went_better · response_use · rings_true ·
had_real_conversation · paywall_intent`.

---

## Priority 1 — the three make-or-break tests

### Test 1 — Value unit: does the decode help *in the moment*?
- **Feature:** solo decode (recount/paste a hard message → what they meant + the need + a
  suggested move).
- **Signals:** completion (input→result viewed); `helped` (yes/somewhat/no); `true_about_them`
  (yes/somewhat/no).
- **Pass bar:** ≥50% `helped=yes` **and** ≥40% `true_about_them=yes`, on non-demo results.
- **Decides:** the acute pain is real and the value unit lands. If this fails, stop — nothing
  downstream matters.

### Test 2 — Behaviour change: does it cause action that goes *better*? (+ scaffold-not-script)
- **Feature:** the suggested move + a 24–48h follow-up (`GET /reflections/followups` surfaces
  due ones) asking "Did you try it? How'd it go?" + "Used as-is or in your own words?"
- **Signals:** `tried_it` (yes/no); `went_better` (yes/somewhat/no); `response_use`
  (own_words/verbatim).
- **Pass bar:** ≥30% `tried_it=yes`; ≥60% of those `went_better=yes`; **majority `own_words`**.
- **Decides:** the invention changes behaviour *and* it's a scaffold.
- **Red flag (fail even if usage is high):** high `verbatim` + low `went_better` = the script
  trap.

### Test 3 — Retention / recurring theme: do they return, and does the pattern resonate?
- **Feature:** the recurring-theme thread (`GET /reflections/themes`, needs ≥3 reflections) +
  "Does this pattern ring true?"
- **Signals:** D7/D30 return; reflections-per-user; `rings_true` (yes/no); (longer) whether the
  theme's recurrence declines.
- **Pass bar:** ≥30% return and log ≥3; ≥50% `rings_true=yes`.
- **Decides:** the being-known / self-evolution surface and the switching-cost moat are real.

---

## Priority 2 — guardrail tests (catch the failures that *look like* success)

### Test 4 — Outward, not rumination
- **Signal (computed):** share of reflections that lead to a reported real-world action
  (`tried_it=yes`) vs none; flag high-frequency users with no actions.
- **Pass:** most reflections → action; rumination users are rare.
- **Decides:** self-reflection drives action/connection, not loops.

### Test 5 — Companion-drift (the inverted master metric)
- **Signal:** `had_real_conversation` (yes/no) vs app usage.
- **Pass:** usage correlates with real conversations happening.
- **Red flag:** heavy use, few real conversations = becoming the counterfeit.

---

## Priority 3 — adoption & willingness

### Test 6 — Single-player activation (cold-start escape)
- **Signal (computed):** % of new users completing a first solo reflection in session 1, no
  partner required.
- **Pass:** ≥40%.
- **Decides:** the solo wedge removes the two-player cold start.

### Test 7 — Painkiller, not vitamin
- **Feature:** a fake-door price probe ("Unlock your patterns / unlimited — $X/mo").
- **Signal:** `paywall_intent` (clicked/dismissed).
- **Pass:** ≥10–15% `clicked`.
- **Decides:** pain intensity + monetization.

---

## The dashboard

`GET /api/v1/metrics/feature-tests` returns, per test, `{n, rate, breakdown}` plus
`reflections_total` and `users_total`. Read it daily; each rate maps 1:1 to a test above.

```
test1_helped / test1_true_about_them      → Test 1
test2_tried_it / went_better / scaffold_own_words → Test 2
test3_rings_true                          → Test 3
test5_real_conversation                   → Test 5
test7_paywall_intent                      → Test 7
(tests 4 & 6 are computed from reflection/event counts)
```

---

## How each test maps to the thesis

| Test | De-risks (from `v3-synthesis.md`) |
|---|---|
| 1 Value unit | The acute pain + the value unit (rung 1–2 entry) |
| 2 Behaviour change | **The master risk** + the scaffold-not-script guardrail |
| 3 Recurring theme | Being-known + self-evolution (rung 2–3); the switching-cost moat |
| 4 Rumination | The "outward, not rumination" guardrail |
| 5 Companion-drift | The inverted master metric; mission integrity |
| 6 Activation | The single-player cold-start escape (adoption thesis) |
| 7 WTP | Painkiller-not-vitamin; the monetization base of the scale thesis |

---

## Sequencing

Ship and instrument **Tests 1–3 first.** If the decode doesn't help (1), people don't act or it
doesn't help (2), or they don't come back (3), the core is falsified cheaply — fix the value
unit or the diagnosis (maybe the gap is regulation, not interpretation) **before** building the
connection/matchmaking layers on top. Tests 4–7 run alongside as guardrails and go/no-go
signals. When the leading proxies look good, escalate to the confirmatory RCT
(`v3-validation-plan.md`).

**Frontend work still needed** (backend is built and tested): the one-tap controls on the
result screen (`helped`, `true_about_them`, `response_use`), the 24–48h follow-up prompt that
reads `/reflections/followups` and posts `tried_it`/`went_better`, the themes view that reads
`/reflections/themes` with the `rings_true` tap, the `had_real_conversation` prompt, and the
fake-door price probe posting `paywall_intent`.
