# Presence — The Context Graph & Scouting Report (internal)

An **internal, not-user-facing** knowledge graph of a person's social life, and its
human-readable projection: a **baseball card / scouting report** — *good at X, needs work on Y.*

> Think of it as a private Wikipedia for one person: every relationship is an article, every
> conversation links to the relationship it's about and the themes it touches, and **themes are
> hub articles that link conversations across relationships over time.** The "self" is the hub
> all relationships connect to.

```
self ──part_of── relationship ──about── conversation ──touches── theme   (what)
                                              │  │  │  └──at──── place      (where)
                                              │  │  └──why───── need        (why · self|other)
                                              │  └──how──────── manner      (how · self|other)
                                              └ occurred_at                 (when)
```

It tracks the full **who / what / where / when / why / how** of each conversation — and, because
why/how carry a **perspective** (`self` = internal, `other` = between-people), the same engine
answers all four scopes the brief asks for:

- **within a conversation** — *moments/turns* (the `moments` table): each turn has its own
  who (speaker), when (offset), what, why, how, valence. A moment's facets roll up into the
  conversation graph, with perspective set by the speaker (you → self, them → other).
- **between conversations** — a `continues` link (this conversation continues an earlier one)
  plus shared-facet links (other conversations that share the same who/what/where/why/how).
- **between people** — `other`-perspective facets + cross-relationship signature themes.
- **internally** — `other`'s mirror: `self`-perspective facets — how *you* tend to show up and
  what *you* tend to need (`/graph/internal`).

| Dimension | Modelled as | Scope it serves |
|---|---|---|
| **who** | relationship (other) + self | between people / internal |
| **what** | themes | within + between conversations |
| **where** | place node (`at`) | spatial patterns |
| **when** | `occurred_at` | temporal cadence |
| **why** | need node (`why`, perspective self/other) | their unmet needs vs your own |
| **how** | manner node (`how`, perspective self/other) | how you show up vs how they do |

Built and tested in `backend/graph.py` + `main.py`. Stored as a lightweight property graph in
SQLite (`graph_nodes`, `graph_edges`) — node ids are deterministic natural keys, so ingestion
is idempotent.

---

## What it captures

- **self** — the ego (one per `user_id`), the hub.
- **relationship** — each important person in their life (partner, mom, coworker…). An article.
- **conversation** — each reflection/conversation, linked `about` a relationship.
- **theme** — topics (needs, repair, attachment, self-awareness, conflict…), linked from
  conversations via `touches`. Themes that appear in conversations across *different*
  relationships are the **signature patterns** — the personal (not relationship-specific) ones.

The interesting structure is the cross-link: when "feeling unseen" shows up with both *partner*
and *mom*, that's a property of the person, and the graph surfaces it.

---

## How it's populated

- **Automatically** when a solo reflection is created *with a `subject`* (who it's about):
  `POST /reflections/analyze {…, "subject": "partner"}` → the conversation, its relationship,
  and its themes (inferred via `resources.topics_for_text`) are upserted into the graph.
- **Explicitly / for backfill or couples convos:** `POST /api/v1/graph/ingest`
  `{user_id, conversation_id, subject, text, themes?}`.

---

## Spatio-temporal layer

The graph models **who · what theme · when · where.** Conversations carry an `occurred_at`
(time) and a `location` (place); places are first-class nodes (`conversation ──at── place`), so
a place is its own article that links the conversations held there.

**Temporal** (each conversation's `occurred_at`):
- **Cadence & gaps per relationship** — first/last contact, days-since-last, average cadence,
  recent gap. The literal *"I talked with X ~8 months ago, then ~2 months ago"* timeline.
- **Connection points** — conversations the user reported went better (`went_better=yes`),
  now annotated with *where* they happened.
- **Temporal nudges** — **reconnect** (gone quiet past ~2 months), **cadence** (talking less
  than you used to), **recurring** (a theme that keeps surfacing in a relationship).

**Spatial** (each conversation's `location`):
- **Per-place summary** — how many conversations happen there, how often they go well
  (connection rate), the top themes, and who with.
- **Spatial nudges** — the *settings* that help or hurt:
  - "Conversations **on a walk** tend to go well — a good setting for the harder ones." (high
    connection rate)
  - "Hard moments tend to happen **in the kitchen** — a different setting might help." (a
    hard theme dominates there)

Both feed the scouting report (per-relationship cadence + a `places` section) and the nudges
endpoint.

## Endpoints (internal)

| Verb | Path | Returns |
|---|---|---|
| POST | `/api/v1/graph/ingest` | add a conversation (optional `occurred_at` for history) |
| GET | `/api/v1/graph?user_id=` | raw nodes + edges (debug; not surfaced) |
| GET | `/api/v1/graph/conversation/{id}?user_id=` | one conversation's full **5W1H** (who/what/where/when/why/how) |
| POST | `/api/v1/graph/conversation/{id}/moment` | add a moment/turn **within** a conversation |
| GET | `/api/v1/graph/conversation/{id}/moments` | the **within-conversation** timeline — each moment's 5W1H |
| GET | `/api/v1/graph/conversation/{id}/links` | **between conversations** — continuation + shared facets |
| GET | `/api/v1/graph/internal?user_id=` | the **internal** map — how you show up, what you need |
| GET | `/api/v1/graph/relationship?user_id=&label=` | one relationship's "article": conversations + themes |
| GET | `/api/v1/graph/timeline?user_id=&label=` | a relationship's conversations over time (cadence, gaps, connection points) |
| GET | `/api/v1/graph/places?user_id=` | where conversations happen — per place: count, connection rate, themes, who with |
| GET | `/api/v1/graph/nudges?user_id=` | reconnect / cadence / recurring / **setting** nudges + connection points (with place) |
| GET | `/api/v1/graph/scouting-report?user_id=` | the baseball card (below), now incl. per-relationship cadence + nudges |

---

## The scouting report (baseball card)

`GET /graph/scouting-report` projects the graph + behavioural events into:

- **summary** — one line ("Good at X; working on Y").
- **strengths** — derived from outcome signals in the event log (acts on what they learn,
  follow-through that lands, self-aware, speaks in their own voice, takes it to the real
  relationship), each with evidence (e.g. "100% across N check-ins").
- **growth_areas** — from the **signature themes** (recurring, cross-relationship), phrased
  constructively ("Pausing to notice your own reaction first"), with evidence ("came up in 3
  conversations, across 2 relationships").
- **signature_themes** — the themes ranked by cross-relationship spread then frequency, each
  with the relationships it spans. This is the heart of the "context graph for a social life."
- **relationships** — per-relationship conversation counts + top themes (the article index).

Example (abbreviated, from the test run): *self-awareness* and *connection* recurring across
both *partner* and *mom*; strengths "acts on what they learn / follow-through lands / self-
aware"; growth "pausing to notice your own reaction first."

It degrades honestly: with no conversations it returns *"Not enough conversations yet to
scout."*

---

## Guardrails (consistent with `v3-synthesis.md`)

- **Internal by default.** The raw graph is infrastructure; only the scouting report is a
  candidate for (careful, opt-in) surfacing later. Never expose a partner-dossier view.
- **Trajectory, not type.** The card is "good at X / working on Y over recent conversations" —
  a developmental snapshot that changes as the person grows, never a fixed label or diagnosis.
- **Self-first framing.** Growth areas are phrased as the user's own next step, not blame; the
  card is about *them*, built from their own reflections.

---

## Why it matters strategically

This is the **relational self-model** from `v3-synthesis.md` made concrete and queryable — the
deepest cornered resource (a structured, longitudinal map of a person's social world) and the
substrate that powers everything downstream: better recommendations (`resources/recommend`
already reads recent themes; it can read the graph next), better matchmaking (compatibility on
the real model), and the "what keeps coming up" thread. The baseball card is the first legible
window onto it.

---

## Frontend status

Backend only, by design (internal). No UI is wired. If/when surfaced, the scouting report — not
the raw graph — is the projection to show, opt-in, framed as growth.
