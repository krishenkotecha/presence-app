# Presence v2 Review Page

This page is the payoff moment for the simpler relationship-focused product.

The app is not trying to show a dense transcript or a generic analytics report. It should help a couple feel:

- `this saw something true about us`
- `this can point to why the conversation changed`
- `this gives us one or two clear things to try next time`

## Review page goal

The review page should feel like a relationship debrief, not a dashboard.

It can borrow some structure from v1, but the v2 tone should be:

- simpler
- more emotionally legible
- more specific to two people
- less like a coaching app for one user

## Core sections

### 1. Hero insight

One short, high-signal sentence that captures what happened.

Examples:

- `You lost each other when the conversation shifted from feeling to fixing.`
- `This conversation improved when the emotional point landed before either of you tried to solve it.`
- `You were closest to what you wanted when the conversation stayed honest instead of procedural.`

### 2. Shared success definition

Brief reminder of what success looked like for this conversation.

This keeps the analysis grounded in the couple's stated intention.

### 3. Turning points

This is one of the most important parts of the page.

Each turning point should include:

- timestamp
- positive or negative state
- specific quoted line from the conversation
- one sentence explaining why it changed the conversation

Positive moments should use a soft sage treatment.
Negative moments should use a muted terracotta treatment.

### 4. What each person needed

This should be framed humanely.

Better framing than "what they didn't get":

- `What each of you was reaching for`
- `What each person needed in that moment`

This section should help both people feel understood without sounding clinical.

### 5. What to try next time

One suggestion per person.

The suggestions should be:

- short
- specific
- directly tied to the turning points
- clearly different for each person when appropriate

### 6. Supporting metrics

Metrics support the insight rather than lead it.

Keep these compact:

- balance of words
- interruptions
- connection score
- optional repair attempts

## What we can borrow from v1

Useful carryovers from the first prototype:

- clear section hierarchy
- compact metric presentation
- evidence-backed moment cards
- calm editorial spacing

Things not to carry over too directly:

- dashboard feel
- one-user coaching voice
- too many equal-weight modules

## Backend implications

The backend response needs to support:

- one primary summary insight
- quoted turning points
- per-person unmet needs
- per-person next-step suggestions
- supporting metrics

The response shape in `docs/v2-backend-contract.md` should be treated as the source of truth for implementation.
