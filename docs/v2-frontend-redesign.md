# Presence v2 — Frontend Redesign & Joy Loop Plan

A synthesis of two moves that pull in the same direction: **subtract to sharpen** (make
the app cleaner, simpler, and a truer test of the core idea) and **design a joy loop**
(more interaction creates more joy — sourced from the relationship, not the screen).

The two reinforce each other. Every subtraction frees attention and engineering budget;
we spend it on the one or two additions that actually make a couple feel closer.

---

## 1. Guiding principle

The product's north star is *"did two humans understand each other better afterward?"* — not
screen time, engagement, or retention for its own sake. The brief explicitly rejects
engagement mechanics (notifications, streaks, surveillance).

So the design rule that keeps a "more interaction = more joy" loop both effective and honest:

> **The joy comes from the relationship getting better. The app is a mirror and a ritual;
> the payoff happens between the two people.** Done right, the loop encourages *less* time
> in-app and more presence with each other — and they return not because they're hooked,
> but because last time it helped.

Everything below is held to that line.

---

## 2. The redesigned core loop

Today the app spreads across two product loops (single-conversation review *and* a
longitudinal coaching dashboard) and pads the core one with a metrics grid and a
volume-driven "mood" gradient that measures nothing.

The redesign collapses it to **one honest loop**:

> Each of you says what you want from this talk → Presence listens and offers **one** nudge
> → you get a short, quoted, human mirror → it remembers what you tried → next time it
> notices you did it.

Mapped to the brief's joy-loop stages:

| Joy-loop stage | Where it lives in the redesign |
|---|---|
| Interaction | The conversation (one calm listening screen, one nudge) |
| Insight | The review (hero insight + quoted moments) |
| Small action | One "try next time" per person |
| Better interaction | Next conversation |
| Feel closer | "You tried it, and it worked" callback + a remembered moment |
| Want more | A gentle forward thread, never a push notification |

---

## 2.5 Strategic alignment (7 Powers)

See `v2-strategy-7-powers.md`. The strategy changes what we prioritize, in two specific ways:

**The moat is the memory, not the dashboard.** Switching Costs are Presence's primary power,
and they live in the couple's *accumulated relational memory*. The original redesign cut the
longitudinal loop for simplicity and deferred the moments timeline to "later." The strategy
corrects that: cut the **analytical coaching dashboard** (it's the analytics feel we don't
want), but **bring the relational memory forward** in its warm, lightweight form — the
moments timeline and the "you tried it, and it worked" callback. Those are the joy loop *and*
the switching-cost engine at once. Memory is promoted; analytics stays cut.

**Privacy is a power, not compliance.** A consent + on-device/"don't upload audio" surface
isn't just ethics — it's the **Counter-Positioning** wedge (ad/data incumbents can't copy it
without cannibalizing themselves) and the foundation of the trust that underpins **Branding**
and the **Cornered Resource** dataset. It is promoted from a hygiene item to a first-class,
strategic part of the redesign.

Which edit builds which power:

| Edit | Power it builds |
|---|---|
| Relational memory / moments timeline | **Switching Costs** (primary) |
| "You tried it, and it worked" callback | **Switching Costs** + joy |
| Consent + on-device privacy surface | **Counter-Positioning** + **Branding** |
| Two-sided, non-judgmental, no-fabrication review | **Branding** (trust) |
| North-star usefulness question (consented signal) | **Cornered Resource** (dataset seed) |
| One listening nudge | the *invention* — no invention, no power |
| Subtractions (v1, monolith, one-button, demote metrics) | enabling + brand honesty |

---

## 3. Part A — Subtract (cleaner & simpler)

These are pure removals and re-rankings. Low risk, instantly simpler, and they make the
real flow legible.

**Delete the dead v1 track.** Remove `RootView.swift` (~2,121 lines), the Motion / Swing /
Calibration golf features, and the `PrototypeTrack` / `activeTrack` switch. Commit to v2.
(~4,500 lines of cognitive load gone.)

**Split the monolith.** Break the ~2,400-line `PresenceApp.swift` into
`Sources/V2/{Views, Models, Networking, Audio}`. This is also what the docs already claim
exists.

**Cut the longitudinal "What should we work on?" loop from the MVP.** It is effectively a
second product. It depends on history a first-time tester doesn't have, so it greets new
users with demo/empty states that make real and placeholder indistinguishable —
*actively undermining the test.* Removing `PresenceV2WorkOnView` + its model deletes ~400
lines and halves the home screen. (Its joyful replacement returns later as a *moments
timeline*, not a dashboard — see §4 and §5.)

**One-button home.** Drop the backend-dependent "Last result" row and the "what this
version is for" marketing copy. The home is one action — *Start a conversation* — with
nothing competing for attention.

**Demote the metrics grid on the review.** The four-metric dashboard (word balance,
interruptions, connection score, repair attempts) is exactly the "analytics" feel
`v2-review-page.md` warns against, and `connection_score` is a fabricated number. Move it
into a collapsed "details" section, or cut it from the MVP. The quoted turning points — not
the dashboard — are the payoff.

---

## 4. Part B — Add (the joy loop)

A small number of deliberate additions. Each is held to the §1 principle.

**Close the loop visibly — "you tried it, and it worked."** *(highest joy, low effort)*
The single most rewarding thing we can build. The backend already stores each conversation's
`next_time` suggestions; on the next session, detect when a prior suggestion actually shows
up in the new transcript and open the review with it: *"Last time you wanted to reflect back
more — and you did, right here,"* with the quote. This is Action → Better Interaction → Feel
Closer made tangible.

**Replace the score with a moment.** A fabricated `connection_score: 78` is a hollow
number-go-up. A *quoted real moment* of the two of them being good to each other — *"When you
said 'I can see why that felt lonely,' something softened"* — is honest and genuinely warming.
Lead the payoff with that.

**End on warmth, not homework.** Today the review closes on feedback buttons and a to-do
list — it feels like being graded. End instead on appreciation: one moment from today worth
keeping, with an optional *"send your partner the moment that stood out to you."* That turns
in-app insight into a real-world gesture.

**Relational progress, never streaks.** The existing "What's improving" instinct is right.
Celebrate *the relationship* ("you're recovering from tension faster than a month ago"),
never *app usage*. The moment progress rewards opening the app, the joy loop becomes the
engagement trap the brief forbids.

**Two-sided by design.** Joy compounds only when *both* feel seen, and dies the instant one
feels blamed. Content rule: every review gives each person both a "what you were reaching
for" and a moment where they were good to the other. This is load-bearing, not chrome.

**Rituals, not notifications.** The ethical engine for repetition is a *chosen* ritual,
rewarded with warmth — e.g. an optional 20-second "before a hard talk" priming card. Never a
push that demands attention.

**A gentle forward thread.** The loop's last beat — "want more" — done with curiosity, not
FOMO: *"Next time, I'll watch whether naming the feeling first helps."*

---

## 5. Part C — The core bet (the actual hypothesis)

Everything else subtracts; this one adds — intentionally. We spend the simplicity gained
everywhere else to fund the feature that actually tests *presence via nudges*.

**Replace the mood gradient with one honest live screen + one nudge.** The current
`conversationPulse` tri-color state is driven purely by microphone volume — a placebo that
*looks* like the core idea but measures nothing (laughter reads as "time to reset"). Replace
with:

- a calm, single "we're listening" state (drop the fake emotional readout), and
- **one** content-grounded nudge from signals already captured on-device — e.g. a gentle
  *"want to reflect back what you heard?"* after a long one-sided stretch or a burst of
  back-to-back interruptions.

That one nudge *is* the hypothesis. Keep it dismissible, rate-limited (≈1 per few minutes),
and never judgmental — "during: small interventions only."

---

## 6. Screen-by-screen redesign ideas

**Home.** One warm line + one button (*Start a conversation*). Optionally a single
remembered moment from last time, as a quiet reminder of why this is worth doing — not a
stats row.

**Success definition.** Keep it — grounding analysis in the couple's own goal is core. Two
quick spoken answers, manual fallback already handled. Soften the chrome; this is a moment of
intention, so let it breathe.

**Live conversation.** A held, calm surface — think breath, not dashboard. No fake mood
colors. One nudge appears gently when earned, then recedes. The honest message is "we're
here, listening," not "you're at 0.4 tension."

**Review (the payoff).** Re-ranked for emotional legibility:
1. Hero insight (one true sentence)
2. A remembered/quoted **moment** of connection (replaces the score)
3. Quoted turning points (the "this saw something true about us" beat)
4. One "try next time" per person
5. The north-star question — *"Did this help you understand each other better?"* —
   unmissable, not buried
6. *(collapsed)* metrics & transcript for the curious

Processing screen: a held breath, a soft haptic on completion — emotional craft in the small
moments. Use the sage/terracotta palette already in the theme.

**Moments timeline (bring forward — it's the moat).** The joyful replacement for the cut
coaching dashboard: a warm highlight reel of remembered moments and relationship wins over
time — proof of growth, not a scorecard. Strategically this is the Switching-Costs engine
(the couple's irreplaceable memory), so it earns a P1 slot, not "someday" — just keep it
warm and lightweight, never an analytics view.

---

## 7. Prioritization

Sequenced so subtraction comes first (it de-risks and funds everything after), the joy loop
next (highest reward per unit effort), and the core product bet last (deliberate, because
it's the real experiment).

| Tier | Item | Builds (Power) | Effort |
|---|---|---|---|
| **P0 — Subtract** | Delete v1 track + `PrototypeTrack` switch | enabling | S |
| **P0** | Split `PresenceApp.swift` into modules | enabling | M |
| **P0** | One-button home | focus / brand | S |
| **P0** | Cut the *analytical* longitudinal dashboard | simplicity / brand | S |
| **P0** | Demote metrics grid; drop fabricated score | **Branding** (honesty) | S |
| **P1 — Moat + joy** | "You tried it, and it worked" callback | **Switching Costs** | M |
| **P1** | Relational memory + moments timeline (lightweight) | **Switching Costs** (primary) | M |
| **P1** | Consent + on-device privacy surface | **Counter-Positioning** + **Branding** | M |
| **P1** | Moment-not-score payoff on review | **Branding** + joy | S |
| **P1** | End-on-warmth (remembered moment + optional share) | **Switching Costs** + **Branding** | M |
| **P1** | Elevate the north-star usefulness question (consented) | **Cornered Resource** (seed) | S |
| **P2 — Core bet** | One honest live screen + one listening nudge | the *invention* | L |
| **P3 — Craft** | Emotional motion / haptics / sound; pre-talk ritual | **Branding** | M |

Changed by the strategy: the **moments timeline moved P3 → P1** (it's the primary moat, not
a "later" delight), and a **consent + on-device privacy surface was added at P1** (it's the
Counter-Positioning wedge, not hygiene). Both still ship in their *lightweight, warm* form —
memory and trust, never a dashboard.

Dependency note: P0 (subtract) before P2 (the nudge). You spend the simplicity you gain
everywhere else to fund the invention (the nudge) and the moat (the memory).

---

## 8. Guardrails — what NOT to build

State these so they don't quietly erode:

- No streaks-to-maintain, no re-engagement or guilt notifications.
- No comparison, leaderboards, or partner-vs-partner scoring.
- No metric that rewards *opening the app* (reward the relationship changing).
- No fabricated precision presented as measurement (no invented numbers/deltas).
- Never let one partner feel singled out or blamed — balance is a content requirement.

Every reward should be sourced from the relationship, and should ideally point the couple
back at each other rather than at the screen.

---

## 9. How we'll know it's working

- **North star:** the usefulness signal (*yes / somewhat / no*), already captured and tied to
  model + confidence. Make it prominent and watch it.
- **Joy-loop proof:** the rate at which a prior "try next time" actually reappears in a later
  conversation — i.e. the couple changed something and it stuck. This is the truest evidence
  the loop is creating real-world value, not just app sessions.
- **Anti-metric:** we are *not* trying to maximize session length or frequency. A couple who
  needs us less over time is a success, not churn.
