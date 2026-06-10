# Presence — Conversation Infrastructure, Telemetry & Discovery Resources

Three buildouts, all implemented and tested in the backend:

1. **A git-like conversation graph** — branchable, trackable conversation threads.
2. **Deeper telemetry** — a behaviour-change funnel + usage/time-series, on top of the
   feature-test events.
3. **Discovery resources** — a curated catalog (videos, talks, articles, exercises) with
   topic-based contextual recommendation.

The relational self-model (`v3-synthesis.md`) gets richer when conversations are *versioned*
(you can branch and revisit), instrumented (you can see what actually changes behaviour), and
connected to the wider world of help (resources that aid discovery of self and others).

---

## 1. Conversation graph (git for conversations)

A conversation is a **tree of nodes**, exactly like a git history: each node is a "commit"
(a turn, a reflection, a note); a **branch** is a node that forks from an earlier point so you
can explore an alternative line ("what if I'd led with the need?") without losing the original.

**Model**
- `threads(thread_id, user_id, relationship_id, title, created_at)`
- `nodes(node_id, thread_id, parent_id, branch, ref_kind, ref_id, summary, created_at)` —
  `ref_kind`/`ref_id` optionally link a node to a reflection or a recorded conversation.

**Endpoints**

| Verb | Path | Git analogue |
|---|---|---|
| POST | `/api/v1/threads` | `git init` (creates thread + root node) |
| POST | `/api/v1/threads/{id}/commit` | `git commit` (append to a branch tip) |
| POST | `/api/v1/threads/{id}/branch` | `git branch` (fork from a node) |
| GET | `/api/v1/threads/{id}` | `git log` / tree (nodes + branch labels) |
| GET | `/api/v1/threads?user_id=` | list threads |

Each branch's tip is just "the latest node on that branch," so `commit` appends to the right
place automatically and `branch` forks from any node by id. The client renders the tree from
`parent_id` and the branch list.

**What it unlocks (product):** revisit and *track how a hard conversation evolved* over time;
explore alternative responses as branches before committing to one; tie a couple's recurring
topic into one long-lived thread (the switching-cost memory, now structured).

---

## 2. Deeper telemetry

On top of the one-tap feature-test events (`v3-mvp-feature-tests.md`), events now carry
optional `metadata` (arbitrary JSON) and `thread_id` (conversation context), and there's a
roll-up endpoint:

`GET /api/v1/metrics/telemetry?days=14` returns:
- **funnel** — `reflected → tried_it → went_better` (the behaviour-change spine).
- **reflections_per_mode** — decode / prep / reflect usage.
- **events_by_kind** — every signal, counted.
- **reflections_daily** — a daily time-series (last `days`).
- **threads_total / branches_total** — conversation-graph activity.
- **resources_opened** — discovery engagement.

This is the operational dashboard; the feature-test endpoint stays the product read-out, and
the RCT (`v3-validation-plan.md`) is still the confirmatory verdict.

---

## 3. Discovery resources

A catalog that aids discovery of **self** and **others**, surfaced for what the user keeps
reaching for.

**Model:** `resources(id, title, creator, kind, url, topics, axis, description, verified)`,
where `kind` ∈ video/talk/article/exercise and `axis` ∈ self/other/both. Seeded on first run
with a starter set (Brené Brown on empathy, Esther Perel on desire, Gottman's Four Horsemen /
repair / bids, Rosenberg's NVC, Sue Johnson's pursue–withdraw, Kristin Neff's self-compassion,
Tara Brach's RAIN).

**Endpoints**
- `GET /api/v1/resources?topic=&axis=&kind=` — browse/filter.
- `GET /api/v1/resources/recommend?user_id=&axis=` — **contextual**: infers topics from the
  needs/headlines in the user's recent reflections (`resources.topics_for_text`) and ranks the
  catalog by topic overlap (`resources.rank`), falling back to a gentle starter set when there's
  no signal.
- `POST /api/v1/resources` — curation (add a resource).
- Opening a resource logs a `resource_opened` event (feeds telemetry).

**Honesty note on the seed:** each seed `url` points to a *search* for the exact title+creator
(so links always resolve) and is flagged `verified=0`. The durable asset is the **matching
engine**, not the seed — the team should replace each row with the canonical URL during
editorial curation (via `POST /resources`).

---

## 4. Guardrails (consistent with `v3-synthesis.md`)

- Resources **point outward** to real help and real people — they must never become a content
  feed to maximise time-in-app (the engagement trap). Recommend sparingly and contextually.
- Branching is for the user's *own* exploration and memory, never a dossier surfaced to a
  partner.
- Telemetry serves learning and the north star — not vanity engagement metrics.

---

## 5. Frontend status

Backend is built and tested. The iOS side needs (flagged, compile in Xcode):
- a **Resources** surface that calls `/resources/recommend` and logs `resource_opened`
  (a starter version is scaffolded in `PresenceApp.swift`);
- optional **thread/branch** UI later (the graph is infrastructural for now — the model is
  ready when a "revisit / explore an alternative" feature is designed).
