"""
Presence v2 backend — implements the app's contract.

  POST /api/v1/conversations/analyze   (multipart/form-data)  -> review payload
  GET  /api/v1/relationships/work-on                          -> longitudinal payload

Put these URLs into PresenceApp.swift:
  PresenceV2BackendConfig.analyzeURLString = "http://<host>:8000/api/v1/conversations/analyze"
  PresenceV2BackendConfig.workOnURLString  = "http://<host>:8000/api/v1/relationships/work-on"
(For a real device, <host> is your Mac's LAN IP, not localhost.)

Run:  uvicorn main:app --reload  (or --host 0.0.0.0 for device testing)
"""

import os
import re
import json
import uuid
import sqlite3
from datetime import datetime, timezone, timedelta
from contextlib import contextmanager
from typing import Optional

from fastapi import FastAPI, Form, File, UploadFile, HTTPException
from pydantic import BaseModel

import analysis
import transcribe
import diarize
import signals
import resources
import graph

DB_PATH = os.environ.get("RELINT_DB", "relint.db")
DEFAULT_RELATIONSHIP = os.environ.get("RELINT_RELATIONSHIP_ID", "rel_default")
TIME_WINDOW = os.environ.get("RELINT_TIME_WINDOW", "90d")

app = FastAPI(title="Presence v2 backend", version="0.2.0")


def now():
    return datetime.now(timezone.utc).isoformat()


def _window_cutoff_iso(window):
    """Translate a window like '90d', '12w', '24h' into an ISO cutoff timestamp.
    Returns None when the window is empty/'all'/unparseable, meaning "no filter".
    created_at is stored as ISO8601 UTC, so lexical >= comparison in SQL is valid."""
    if not window:
        return None
    w = str(window).strip().lower()
    if w in ("all", "0", "none"):
        return None
    m = re.fullmatch(r"(\d+)\s*([dwh])", w)
    if not m:
        # Bare integer is treated as days; anything else => no filter (fail open).
        if w.isdigit():
            value, unit = int(w), "d"
        else:
            return None
    else:
        value, unit = int(m.group(1)), m.group(2)
    delta = {"d": timedelta(days=value),
             "w": timedelta(weeks=value),
             "h": timedelta(hours=value)}[unit]
    return (datetime.now(timezone.utc) - delta).isoformat()


def _resolve_duration(duration_seconds, started_at, ended_at):
    if duration_seconds and duration_seconds > 0:
        return duration_seconds
    try:
        s = datetime.fromisoformat(started_at.replace("Z", "+00:00"))
        e = datetime.fromisoformat(ended_at.replace("Z", "+00:00"))
        return max(0, int((e - s).total_seconds()))
    except Exception:
        return duration_seconds or 0


@contextmanager
def db():
    conn = sqlite3.connect(DB_PATH, timeout=5.0)
    conn.row_factory = sqlite3.Row
    # Wait rather than immediately erroring if another connection holds a write
    # lock (matters once analysis polling adds concurrent reads).
    conn.execute("PRAGMA busy_timeout=5000")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db():
    with db() as conn:
        # WAL lets reads proceed concurrently with a writer; persists on the DB file.
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute(
            """CREATE TABLE IF NOT EXISTS analyses (
                   session_id TEXT PRIMARY KEY,
                   relationship_id TEXT,
                   created_at TEXT,
                   payload_json TEXT
               )"""
        )
        conn.execute(
            """CREATE TABLE IF NOT EXISTS nudge_actions (
                   id TEXT PRIMARY KEY,
                   session_id TEXT,
                   outcome TEXT,
                   created_at TEXT
               )"""
        )
        # Solo (single-user) reflections — keyed by user_id, the per-individual
        # identity that begins the relational-memory corpus (see v2-solo-experience.md).
        conn.execute(
            """CREATE TABLE IF NOT EXISTS reflections (
                   reflection_id TEXT PRIMARY KEY,
                   user_id TEXT,
                   relationship_id TEXT,
                   mode TEXT,
                   created_at TEXT,
                   payload_json TEXT
               )"""
        )
        # One-tap signals for the MVP feature tests (see v3-mvp-feature-tests.md):
        # helped, true_about_them, tried_it, went_better, response_use, rings_true,
        # had_real_conversation, paywall_intent. Cheap, continuous behaviour-change telemetry.
        conn.execute(
            """CREATE TABLE IF NOT EXISTS events (
                   id TEXT PRIMARY KEY,
                   user_id TEXT,
                   reflection_id TEXT,
                   kind TEXT,
                   value TEXT,
                   created_at TEXT
               )"""
        )
        # Migrate older DBs: tie each usefulness signal to the model + confidence
        # that produced the insight, so we can learn what actually helps.
        existing = {r["name"] for r in conn.execute("PRAGMA table_info(nudge_actions)")}
        if "model" not in existing:
            conn.execute("ALTER TABLE nudge_actions ADD COLUMN model TEXT")
        if "confidence" not in existing:
            conn.execute("ALTER TABLE nudge_actions ADD COLUMN confidence TEXT")

        # Deeper telemetry: arbitrary properties + conversation-thread context on events.
        ev = {r["name"] for r in conn.execute("PRAGMA table_info(events)")}
        if "metadata" not in ev:
            conn.execute("ALTER TABLE events ADD COLUMN metadata TEXT")
        if "thread_id" not in ev:
            conn.execute("ALTER TABLE events ADD COLUMN thread_id TEXT")

        # Conversation graph (git-like): threads hold a tree of nodes; branching = a node
        # whose parent forks an earlier point. See docs/v3-conversation-infra.md.
        conn.execute(
            """CREATE TABLE IF NOT EXISTS threads (
                   thread_id TEXT PRIMARY KEY,
                   user_id TEXT,
                   relationship_id TEXT,
                   title TEXT,
                   created_at TEXT
               )"""
        )
        conn.execute(
            """CREATE TABLE IF NOT EXISTS nodes (
                   node_id TEXT PRIMARY KEY,
                   thread_id TEXT,
                   parent_id TEXT,
                   branch TEXT,
                   ref_kind TEXT,
                   ref_id TEXT,
                   summary TEXT,
                   created_at TEXT
               )"""
        )

        # Discovery resources (videos, talks, articles, exercises) + topic tags.
        conn.execute(
            """CREATE TABLE IF NOT EXISTS resources (
                   id TEXT PRIMARY KEY,
                   title TEXT,
                   creator TEXT,
                   kind TEXT,
                   url TEXT,
                   topics TEXT,
                   axis TEXT,
                   description TEXT,
                   verified INTEGER DEFAULT 0,
                   created_at TEXT
               )"""
        )
        # Context graph (internal): self/relationship/conversation/theme nodes + edges.
        # A private "Wikipedia" of a person's social life. See docs/v3-context-graph.md.
        conn.execute(
            """CREATE TABLE IF NOT EXISTS graph_nodes (
                   node_id TEXT PRIMARY KEY,
                   user_id TEXT,
                   type TEXT,
                   label TEXT,
                   created_at TEXT
               )"""
        )
        conn.execute(
            """CREATE TABLE IF NOT EXISTS graph_edges (
                   edge_id TEXT PRIMARY KEY,
                   user_id TEXT,
                   src_id TEXT,
                   dst_id TEXT,
                   type TEXT,
                   created_at TEXT
               )"""
        )
        # Spatio-temporal: when a conversation actually happened (vs when ingested) — drives
        # cadence, gaps, connection points and nudge points over time.
        gn = {r["name"] for r in conn.execute("PRAGMA table_info(graph_nodes)")}
        if "occurred_at" not in gn:
            conn.execute("ALTER TABLE graph_nodes ADD COLUMN occurred_at TEXT")
        ge = {r["name"] for r in conn.execute("PRAGMA table_info(graph_edges)")}
        if "perspective" not in ge:   # self (internal) vs other (between-people) on why/how edges
            conn.execute("ALTER TABLE graph_edges ADD COLUMN perspective TEXT")
        # Within-conversation moments/turns — each its own who/what/why/how at a point in time.
        conn.execute(
            """CREATE TABLE IF NOT EXISTS moments (
                   moment_id TEXT PRIMARY KEY,
                   user_id TEXT,
                   conversation_id TEXT,
                   seq INTEGER,
                   offset_ms INTEGER,
                   speaker TEXT,
                   text TEXT,
                   valence TEXT,
                   created_at TEXT
               )"""
        )

        # Seed the starter catalog once.
        if conn.execute("SELECT COUNT(*) FROM resources").fetchone()[0] == 0:
            for r in resources.SEED:
                conn.execute(
                    "INSERT INTO resources (id,title,creator,kind,url,topics,axis,description,verified,created_at) "
                    "VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (uuid.uuid4().hex[:12], r["title"], r["creator"], r["kind"], r["url"],
                     ",".join(r["topics"]), r["axis"], r["description"], r["verified"], now()),
                )


init_db()


# --------------------------------------------------------------------------- #
# 1. Conversation review
# --------------------------------------------------------------------------- #

@app.post("/api/v1/conversations/analyze")
async def analyze_conversation(
    session_id: str = Form(...),
    started_at: Optional[str] = Form(None),
    ended_at: Optional[str] = Form(None),
    duration_seconds: int = Form(0),
    participant_one_label: str = Form("You"),
    participant_two_label: str = Form("Your partner"),
    participant_one_success_definition: str = Form(""),
    participant_two_success_definition: str = Form(""),
    prototype_track: str = Form("v2"),
    conversation_audio: Optional[UploadFile] = File(None),
    transcript: Optional[str] = Form(None),  # dev/testing only; the app sends audio
    device_transcript: Optional[str] = Form(None),  # live on-device transcript (fallback)
):
    meta = {
        "p1_label": participant_one_label, "p2_label": participant_two_label,
        "p1_def": participant_one_success_definition,
        "p2_def": participant_two_success_definition,
        "duration": duration_seconds,
    }

    # ----- Resolve transcript + speaker turns -------------------------------
    # Priority: explicit dev `transcript` field > audio (transcribe + diarize).
    turns, diarized, label_map, spans = [], False, {}, None
    text = (transcript or "").strip() or None
    note = None

    if text is not None:
        # Dev/testing path: parse "Name: line" turns (no timing -> no interruptions).
        turns = signals.parse_labeled_transcript(text, participant_one_label, participant_two_label)
        label_map, _ = signals.speaker_label_map(turns, participant_one_label, participant_two_label)
    elif conversation_audio is not None:
        audio_bytes = await conversation_audio.read()
        text, segments = transcribe.transcribe(audio_bytes)
        if text is None:
            # Server-side Whisper unavailable — fall back to the transcript the app
            # captured live on-device, so we still analyze the real conversation
            # (no speaker separation, so metrics stay estimated).
            device_text = (device_transcript or "").strip()
            if device_text:
                text = device_text
                note = ("server transcription unavailable — analyzed the on-device "
                        "transcript instead (no speaker separation, metrics estimated)")
            else:
                note = ("audio received but local transcription is unavailable "
                        "(install ffmpeg + faster-whisper) — returned demo review")
        else:
            spans = diarize.diarize(audio_bytes)  # None if pyannote/HF token absent
            turns, diarized, label_map = signals.build_turns_from_audio(
                segments, spans, participant_one_label, participant_two_label)
    elif (device_transcript or "").strip():
        # No audio uploaded, but the app sent its live transcript.
        text = device_transcript.strip()
        note = ("analyzed the on-device transcript (no audio uploaded); "
                "metrics estimated without speaker separation")

    # Text presented to the LLM: speaker-labeled + timestamped when we have it.
    llm_transcript = signals.render_transcript(turns, label_map) if turns else text

    # ----- Qualitative analysis (LLM) or demo fallback ----------------------
    if analysis.BACKEND == "mock" or text is None:
        if note is None and analysis.BACKEND == "mock":
            note = "mock backend — demo review (set RELINT_BACKEND=local + Ollama for real analysis)"
        body = analysis.demo_review(
            participant_one_label, participant_two_label,
            participant_one_success_definition, participant_two_success_definition,
        )
        model_label = "demo"
    else:
        try:
            body = analysis.generate_review(meta, llm_transcript, segments=None)
        except Exception as e:  # noqa: BLE001
            raise HTTPException(502, f"analysis backend error: {e}")
        model_label = analysis.MODEL

    # ----- Computed signals override LLM/demo guesses where possible --------
    # connection_score and repair_attempts are always model-estimated; word_balance
    # and interruptions are upgraded to "computed" below when diarization is available.
    metrics_source = {"word_balance": "estimated", "interruptions": "estimated",
                      "connection_score": "estimated", "repair_attempts": "estimated"}
    computed_wb = signals.word_balance(turns, participant_one_label, participant_two_label)
    if computed_wb:
        body["metrics"]["word_balance"] = computed_wb
        metrics_source["word_balance"] = "computed"
    computed_int = signals.interruptions(spans, participant_one_label, participant_two_label)
    if computed_int:
        body["metrics"]["interruptions"] = computed_int
        metrics_source["interruptions"] = "computed"

    # Snap key-moment timestamps + speakers to the real transcript turns.
    body["key_moments"] = signals.ground_key_moments(body.get("key_moments", []), turns, label_map)

    confidence = "medium" if diarized else body.get("confidence", "low")

    payload = {
        "session_id": session_id,
        "status": "completed",
        "summary": body["summary"],
        "success_definition": {
            "participant_one": participant_one_success_definition,
            "participant_two": participant_two_success_definition,
            "shared": body.get("shared_success", ""),
        },
        "metrics": body["metrics"],
        "key_moments": body["key_moments"],
        "unmet_needs": body["unmet_needs"],
        "next_time": body["next_time"],
        "duration_seconds": _resolve_duration(duration_seconds, started_at, ended_at),
        # extra fields (the app ignores unknown keys)
        "analysis_id": uuid.uuid4().hex[:12],
        "created_at": now(),
        "confidence": confidence,
        "model": model_label,
        "diarized": diarized,
        "metrics_source": metrics_source,
    }
    if text is not None:
        payload["transcript"] = text
    if note:
        payload["note"] = note

    with db() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO analyses VALUES (?,?,?,?)",
            (session_id, DEFAULT_RELATIONSHIP, now(), json.dumps(payload)),
        )
    return payload


# --------------------------------------------------------------------------- #
# 2. What should we work on?
# --------------------------------------------------------------------------- #

@app.get("/api/v1/relationships/work-on")
def work_on():
    # Enforce the advertised time window (default 90d) instead of silently
    # analyzing all history. cutoff is None => no filter ("all").
    cutoff = _window_cutoff_iso(TIME_WINDOW)
    with db() as conn:
        if cutoff:
            rows = conn.execute(
                "SELECT payload_json FROM analyses WHERE relationship_id=? AND created_at>=? "
                "ORDER BY created_at ASC",
                (DEFAULT_RELATIONSHIP, cutoff),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT payload_json FROM analyses WHERE relationship_id=? ORDER BY created_at ASC",
                (DEFAULT_RELATIONSHIP,),
            ).fetchall()

    # Demo when there's no history or no model configured.
    if analysis.BACKEND == "mock" or not rows:
        body = analysis.demo_work_on()
    else:
        history = []
        for r in rows:
            p = json.loads(r["payload_json"])
            history.append({
                "headline": p.get("summary", {}).get("headline"),
                "shared_success": p.get("success_definition", {}).get("shared"),
                "connection_score": p.get("metrics", {}).get("connection_score", {}).get("score"),
                "interruptions_total": p.get("metrics", {}).get("interruptions", {}).get("total"),
                "unmet_needs": p.get("unmet_needs", []),
                "key_moment_titles": [m.get("title") for m in p.get("key_moments", [])],
            })
        try:
            body = analysis.generate_work_on(history)
        except Exception as e:  # noqa: BLE001
            raise HTTPException(502, f"analysis backend error: {e}")

    with db() as conn:
        if cutoff:
            count = conn.execute(
                "SELECT COUNT(*) FROM analyses WHERE relationship_id=? AND created_at>=?",
                (DEFAULT_RELATIONSHIP, cutoff),
            ).fetchone()[0]
        else:
            count = conn.execute(
                "SELECT COUNT(*) FROM analyses WHERE relationship_id=?",
                (DEFAULT_RELATIONSHIP,),
            ).fetchone()[0]

    return {
        "relationship_id": DEFAULT_RELATIONSHIP,
        "time_window": TIME_WINDOW,
        "session_count": count,
        **body,
    }


# --------------------------------------------------------------------------- #
# 3. Solo reflection (single-user on-ramp) — text only, no audio
# --------------------------------------------------------------------------- #

class ReflectionRequest(BaseModel):
    reflection_id: Optional[str] = None
    user_id: str = "anon"
    mode: str = "decode"            # decode | prep | reflect
    text: str = ""
    quote: Optional[str] = None
    relationship_id: Optional[str] = None
    subject: Optional[str] = None   # who the reflection is about (e.g. "partner", "mom") — feeds the context graph
    location: Optional[str] = None  # where it happened (e.g. "kitchen", "on a walk") — the spatial tag


VALID_MODES = {"decode", "prep", "reflect"}


@app.post("/api/v1/reflections/analyze")
def analyze_reflection(req: ReflectionRequest):
    mode = (req.mode or "decode").lower()
    if mode not in VALID_MODES:
        raise HTTPException(422, f"mode must be one of {sorted(VALID_MODES)}")

    text = (req.text or "").strip()
    quote = (req.quote or "").strip()
    if not text and not quote:
        raise HTTPException(422, "provide 'text' and/or 'quote'")

    note = None
    if analysis.BACKEND == "mock":
        body = analysis.demo_reflection(mode)
        model_label = "demo"
        note = "mock backend — demo reflection (set RELINT_BACKEND=local + Ollama for real analysis)"
    else:
        try:
            body = analysis.generate_reflection(mode, text, quote=quote)
            model_label = analysis.MODEL
        except Exception as e:  # noqa: BLE001 — degrade gracefully so the app still works
            body = analysis.demo_reflection(mode)
            model_label = "demo"
            note = f"analysis backend error, returned demo reflection: {e}"

    reflection_id = req.reflection_id or uuid.uuid4().hex
    payload = {
        "reflection_id": reflection_id,
        "status": "completed",
        "mode": mode,
        "summary": body["summary"],
        "translation": body["translation"],
        "your_part": body.get("your_part", ""),
        "suggested_next": body.get("suggested_next", ""),
        "reframe": body.get("reframe", ""),
        "confidence": body.get("confidence", "low"),
        "model": model_label,
        "created_at": now(),
    }
    if note:
        payload["note"] = note

    with db() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO reflections VALUES (?,?,?,?,?,?)",
            (reflection_id, req.user_id, req.relationship_id, mode, now(), json.dumps(payload)),
        )
        # Quietly grow the user's context graph (internal, not surfaced) when we know who
        # the reflection is about.
        if req.subject:
            # who=subject, what/how from the user's words, why (the other's need) from the
            # translation, where=location, when=now.
            graph.ingest(conn, req.user_id, reflection_id, req.subject,
                         f"{text} {quote}".strip(), location=req.location,
                         need_text=body.get("translation", {}).get("their_possible_need", ""),
                         self_need_text=f"{text} {quote}".strip())
    return payload


@app.get("/api/v1/reflections/latest")
def latest_reflection(user_id: str = "anon"):
    with db() as conn:
        row = conn.execute(
            "SELECT payload_json FROM reflections WHERE user_id=? ORDER BY created_at DESC LIMIT 1",
            (user_id,),
        ).fetchone()
    if not row:
        raise HTTPException(404, "no reflections recorded yet")
    return json.loads(row["payload_json"])


@app.delete("/api/v1/reflections/{reflection_id}")
def delete_reflection(reflection_id: str):
    with db() as conn:
        conn.execute("DELETE FROM reflections WHERE reflection_id=?", (reflection_id,))
    return {"deleted": reflection_id}


@app.get("/api/v1/reflections/themes")
def reflection_themes(user_id: str = "anon"):
    """The recurring-theme thread: what keeps coming up across a user's reflections.
    Needs >= 3 reflections; otherwise returns needs_more so the app shows an honest empty state."""
    with db() as conn:
        rows = conn.execute(
            "SELECT mode, payload_json FROM reflections WHERE user_id=? ORDER BY created_at ASC",
            (user_id,),
        ).fetchall()
    count = len(rows)
    if count < 3:
        return {"user_id": user_id, "session_count": count, "needs_more": True,
                "message": "After a few reflections, Presence will surface what keeps coming up."}

    history = []
    for r in rows:
        p = json.loads(r["payload_json"])
        history.append({
            "mode": r["mode"],
            "headline": p.get("summary", {}).get("headline"),
            "need": p.get("translation", {}).get("their_possible_need"),
        })

    if analysis.BACKEND == "mock":
        body, model_label = analysis.demo_themes(), "demo"
    else:
        try:
            body, model_label = analysis.generate_themes(history), analysis.MODEL
        except Exception:  # noqa: BLE001 — degrade to demo so the view still works
            body, model_label = analysis.demo_themes(), "demo"

    return {"user_id": user_id, "session_count": count, "needs_more": False,
            "model": model_label, **body}


@app.get("/api/v1/reflections/followups")
def reflection_followups(user_id: str = "anon", older_than_hours: int = 24):
    """Reflections old enough to ask 'did you try it?' that don't yet have a tried_it event.
    Drives the 24-48h behaviour-change follow-up (feature test 2)."""
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=older_than_hours)).isoformat()
    with db() as conn:
        rows = conn.execute(
            """SELECT reflection_id, mode, created_at, payload_json
                 FROM reflections r
                WHERE r.user_id=? AND r.created_at <= ?
                  AND NOT EXISTS (
                      SELECT 1 FROM events e
                       WHERE e.reflection_id = r.reflection_id AND e.kind = 'tried_it')
                ORDER BY r.created_at DESC LIMIT 10""",
            (user_id, cutoff),
        ).fetchall()
    due = []
    for r in rows:
        p = json.loads(r["payload_json"])
        due.append({"reflection_id": r["reflection_id"], "mode": r["mode"],
                    "created_at": r["created_at"],
                    "headline": p.get("summary", {}).get("headline", ""),
                    "suggested_next": p.get("suggested_next", "")})
    return {"user_id": user_id, "due": due}


# --------------------------------------------------------------------------- #
# Feature-test telemetry (see v3-mvp-feature-tests.md)
# --------------------------------------------------------------------------- #

EVENT_KINDS = {
    "helped", "true_about_them", "tried_it", "went_better",
    "response_use", "rings_true", "had_real_conversation", "paywall_intent",
    "resource_opened",
}


class EventRequest(BaseModel):
    user_id: str = "anon"
    reflection_id: Optional[str] = None
    kind: str
    value: Optional[str] = None     # e.g. yes|somewhat|no, own_words|verbatim, clicked|dismissed
    thread_id: Optional[str] = None
    metadata: Optional[dict] = None  # arbitrary properties for deeper telemetry


@app.post("/api/v1/events")
def log_event(req: EventRequest):
    if req.kind not in EVENT_KINDS:
        raise HTTPException(422, f"kind must be one of {sorted(EVENT_KINDS)}")
    eid = uuid.uuid4().hex[:12]
    with db() as conn:
        conn.execute(
            "INSERT INTO events (id, user_id, reflection_id, kind, value, created_at, metadata, thread_id) "
            "VALUES (?,?,?,?,?,?,?,?)",
            (eid, req.user_id, req.reflection_id, req.kind, req.value, now(),
             json.dumps(req.metadata) if req.metadata else None, req.thread_id),
        )
    return {"recorded": True, "id": eid, "kind": req.kind, "value": req.value}


@app.get("/api/v1/metrics/feature-tests")
def feature_test_metrics():
    """Live read-out of the MVP feature tests. Leading proxies; the RCT (v3-validation-plan.md)
    is the confirmatory version."""
    with db() as conn:
        def rate(kind, positive):
            rows = conn.execute(
                "SELECT value, COUNT(*) AS c FROM events WHERE kind=? GROUP BY value", (kind,)
            ).fetchall()
            total = sum(r["c"] for r in rows)
            pos = sum(r["c"] for r in rows if r["value"] in positive)
            return {"n": total,
                    "rate": round(pos / total, 3) if total else None,
                    "breakdown": {r["value"]: r["c"] for r in rows}}

        reflections = conn.execute("SELECT COUNT(*) FROM reflections").fetchone()[0]
        users = conn.execute("SELECT COUNT(DISTINCT user_id) FROM reflections").fetchone()[0]

        return {
            "reflections_total": reflections,
            "users_total": users,
            # test 1 — value unit
            "test1_helped": rate("helped", {"yes"}),
            "test1_true_about_them": rate("true_about_them", {"yes"}),
            # test 2 — behaviour change + scaffold-not-script
            "test2_tried_it": rate("tried_it", {"yes"}),
            "test2_went_better": rate("went_better", {"yes"}),
            "test2_scaffold_own_words": rate("response_use", {"own_words"}),
            # test 3 — recurring-theme resonance
            "test3_rings_true": rate("rings_true", {"yes"}),
            # test 5 — companion-drift guardrail (want real conversations happening)
            "test5_real_conversation": rate("had_real_conversation", {"yes"}),
            # test 7 — painkiller-not-vitamin
            "test7_paywall_intent": rate("paywall_intent", {"clicked"}),
        }


@app.get("/api/v1/metrics/telemetry")
def telemetry(days: int = 14):
    """Deeper telemetry: the behaviour-change funnel, per-mode usage, events by kind,
    and a daily reflection time-series."""
    since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    with db() as conn:
        def count_kind(kind, value=None):
            if value is None:
                return conn.execute("SELECT COUNT(*) FROM events WHERE kind=?", (kind,)).fetchone()[0]
            return conn.execute("SELECT COUNT(*) FROM events WHERE kind=? AND value=?",
                                (kind, value)).fetchone()[0]

        reflections = conn.execute("SELECT COUNT(*) FROM reflections").fetchone()[0]
        # Funnel: reflected -> tried it -> it went better.
        funnel = {
            "reflected": reflections,
            "tried_it": count_kind("tried_it", "yes"),
            "went_better": count_kind("went_better", "yes"),
        }
        per_mode = {r["mode"]: r["c"] for r in conn.execute(
            "SELECT mode, COUNT(*) AS c FROM reflections GROUP BY mode")}
        events_by_kind = {r["kind"]: r["c"] for r in conn.execute(
            "SELECT kind, COUNT(*) AS c FROM events GROUP BY kind")}
        daily = {r["d"]: r["c"] for r in conn.execute(
            "SELECT substr(created_at,1,10) AS d, COUNT(*) AS c FROM reflections "
            "WHERE created_at >= ? GROUP BY d ORDER BY d", (since,))}
        threads_total = conn.execute("SELECT COUNT(*) FROM threads").fetchone()[0]
        branches_total = conn.execute(
            "SELECT COUNT(DISTINCT thread_id || ':' || branch) FROM nodes WHERE branch != 'main'"
        ).fetchone()[0]
        resources_opened = count_kind("resource_opened")

    return {
        "window_days": days,
        "funnel": funnel,
        "reflections_per_mode": per_mode,
        "events_by_kind": events_by_kind,
        "reflections_daily": daily,
        "threads_total": threads_total,
        "branches_total": branches_total,
        "resources_opened": resources_opened,
    }


# --------------------------------------------------------------------------- #
# Conversation graph — git-like threads / nodes / branches
# (see docs/v3-conversation-infra.md)
# --------------------------------------------------------------------------- #

class ThreadCreate(BaseModel):
    user_id: str = "anon"
    relationship_id: Optional[str] = None
    title: str = "Conversation"
    summary: str = ""


class NodeCommit(BaseModel):
    summary: str = ""
    branch: str = "main"
    parent_id: Optional[str] = None      # defaults to the tip of `branch`
    ref_kind: Optional[str] = None       # reflection | conversation | note
    ref_id: Optional[str] = None


class NodeBranch(BaseModel):
    from_node_id: str
    branch: str
    summary: str = ""
    ref_kind: Optional[str] = None
    ref_id: Optional[str] = None


def _branch_tip(conn, thread_id, branch):
    row = conn.execute(
        "SELECT node_id FROM nodes WHERE thread_id=? AND branch=? ORDER BY created_at DESC LIMIT 1",
        (thread_id, branch),
    ).fetchone()
    return row["node_id"] if row else None


def _insert_node(conn, thread_id, parent_id, branch, summary, ref_kind, ref_id):
    nid = uuid.uuid4().hex[:12]
    conn.execute(
        "INSERT INTO nodes (node_id,thread_id,parent_id,branch,ref_kind,ref_id,summary,created_at) "
        "VALUES (?,?,?,?,?,?,?,?)",
        (nid, thread_id, parent_id, branch, ref_kind, ref_id, summary, now()),
    )
    return nid


@app.post("/api/v1/threads")
def create_thread(req: ThreadCreate):
    tid = uuid.uuid4().hex[:12]
    with db() as conn:
        conn.execute("INSERT INTO threads (thread_id,user_id,relationship_id,title,created_at) "
                     "VALUES (?,?,?,?,?)",
                     (tid, req.user_id, req.relationship_id, req.title, now()))
        root = _insert_node(conn, tid, None, "main", req.summary or req.title, "note", None)
    return {"thread_id": tid, "root_node_id": root, "title": req.title}


@app.post("/api/v1/threads/{thread_id}/commit")
def commit_node(thread_id: str, req: NodeCommit):
    with db() as conn:
        if not conn.execute("SELECT 1 FROM threads WHERE thread_id=?", (thread_id,)).fetchone():
            raise HTTPException(404, "thread not found")
        parent = req.parent_id or _branch_tip(conn, thread_id, req.branch)
        nid = _insert_node(conn, thread_id, parent, req.branch, req.summary, req.ref_kind, req.ref_id)
    return {"thread_id": thread_id, "node_id": nid, "branch": req.branch, "parent_id": parent}


@app.post("/api/v1/threads/{thread_id}/branch")
def branch_node(thread_id: str, req: NodeBranch):
    with db() as conn:
        if not conn.execute("SELECT 1 FROM nodes WHERE node_id=? AND thread_id=?",
                            (req.from_node_id, thread_id)).fetchone():
            raise HTTPException(404, "fork node not found in thread")
        nid = _insert_node(conn, thread_id, req.from_node_id, req.branch, req.summary,
                           req.ref_kind, req.ref_id)
    return {"thread_id": thread_id, "node_id": nid, "branch": req.branch,
            "forked_from": req.from_node_id}


@app.get("/api/v1/threads")
def list_threads(user_id: str = "anon"):
    with db() as conn:
        rows = conn.execute(
            "SELECT thread_id, title, created_at FROM threads WHERE user_id=? ORDER BY created_at DESC",
            (user_id,),
        ).fetchall()
    return {"user_id": user_id, "threads": [dict(r) for r in rows]}


@app.get("/api/v1/threads/{thread_id}")
def get_thread(thread_id: str):
    """Returns the thread + its full node list (with parent/branch) — the 'log'. The client
    can render the tree from parent_id, and branches from the distinct branch labels."""
    with db() as conn:
        t = conn.execute("SELECT * FROM threads WHERE thread_id=?", (thread_id,)).fetchone()
        if not t:
            raise HTTPException(404, "thread not found")
        nodes = conn.execute(
            "SELECT node_id, parent_id, branch, ref_kind, ref_id, summary, created_at "
            "FROM nodes WHERE thread_id=? ORDER BY created_at ASC", (thread_id,)
        ).fetchall()
        branches = [r["branch"] for r in conn.execute(
            "SELECT DISTINCT branch FROM nodes WHERE thread_id=?", (thread_id,))]
    return {"thread": dict(t), "branches": branches, "nodes": [dict(n) for n in nodes]}


# --------------------------------------------------------------------------- #
# Discovery resources (videos, talks, articles, exercises)
# --------------------------------------------------------------------------- #

def _resource_row(r):
    d = dict(r)
    d["topics"] = d["topics"].split(",") if d.get("topics") else []
    d["verified"] = bool(d.get("verified"))
    return d


class ResourceCreate(BaseModel):
    title: str
    creator: str = ""
    kind: str = "article"
    url: str
    topics: list[str] = []
    axis: str = "both"
    description: str = ""
    verified: bool = True


@app.get("/api/v1/resources")
def list_resources(topic: Optional[str] = None, axis: Optional[str] = None,
                   kind: Optional[str] = None):
    with db() as conn:
        rows = [_resource_row(r) for r in conn.execute("SELECT * FROM resources")]
    out = []
    for r in rows:
        if topic and topic not in r["topics"]:
            continue
        if axis and r["axis"] not in (axis, "both"):
            continue
        if kind and r["kind"] != kind:
            continue
        out.append(r)
    return {"resources": out}


@app.get("/api/v1/resources/recommend")
def recommend_resources(user_id: str = "anon", axis: Optional[str] = None, limit: int = 5):
    """Surface resources for what the user keeps reaching for — inferred from the needs/
    headlines in their recent reflections."""
    with db() as conn:
        rows = conn.execute(
            "SELECT payload_json FROM reflections WHERE user_id=? ORDER BY created_at DESC LIMIT 20",
            (user_id,),
        ).fetchall()
        catalog = [_resource_row(r) for r in conn.execute("SELECT * FROM resources")]

    text_parts = []
    for r in rows:
        p = json.loads(r["payload_json"])
        text_parts.append(p.get("summary", {}).get("headline", ""))
        text_parts.append(p.get("translation", {}).get("their_possible_need", ""))
        text_parts.append(p.get("suggested_next", ""))
    wanted = resources.topics_for_text(" ".join(text_parts))
    picks = resources.rank(catalog, wanted, axis=axis, limit=limit)
    return {"user_id": user_id, "matched_topics": sorted(wanted), "resources": picks}


@app.post("/api/v1/resources")
def add_resource(req: ResourceCreate):
    rid = uuid.uuid4().hex[:12]
    with db() as conn:
        conn.execute(
            "INSERT INTO resources (id,title,creator,kind,url,topics,axis,description,verified,created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?)",
            (rid, req.title, req.creator, req.kind, req.url, ",".join(req.topics),
             req.axis, req.description, 1 if req.verified else 0, now()),
        )
    return {"id": rid, "added": True}


# --------------------------------------------------------------------------- #
# Context graph (internal) + scouting report (see docs/v3-context-graph.md)
# --------------------------------------------------------------------------- #

class GraphIngest(BaseModel):
    user_id: str = "anon"
    conversation_id: str
    subject: str                      # the relationship the conversation is about
    text: str = ""
    themes: Optional[list[str]] = None
    occurred_at: Optional[str] = None  # when it actually happened (ISO); enables backfill/history
    location: Optional[str] = None     # where it happened (the spatial tag)
    manner_text: Optional[str] = None  # how you showed up (defaults to text)
    need_text: Optional[str] = None    # the why — the other's need (defaults to text)
    self_need_text: Optional[str] = None  # the why — your own need (internal)
    continues: Optional[str] = None    # prior conversation_id this one continues (between-convo link)


@app.post("/api/v1/graph/ingest")
def graph_ingest(req: GraphIngest):
    with db() as conn:
        res = graph.ingest(conn, req.user_id, req.conversation_id, req.subject,
                           req.text, themes=req.themes, occurred_at=req.occurred_at,
                           location=req.location, manner_text=req.manner_text,
                           need_text=req.need_text, self_need_text=req.self_need_text,
                           continues=req.continues)
    return {"ingested": True, **res}


class MomentRequest(BaseModel):
    user_id: str = "anon"
    text: str
    seq: int = 0
    offset_ms: Optional[int] = None
    speaker: str = "you"               # who spoke (you | them | a name)
    valence: str = "neutral"           # positive | negative | neutral


@app.post("/api/v1/graph/conversation/{conversation_id}/moment")
def graph_add_moment(conversation_id: str, req: MomentRequest):
    """Add a moment/turn inside a conversation (within-conversation 5W1H)."""
    with db() as conn:
        res = graph.add_moment(conn, req.user_id, conversation_id, req.text, seq=req.seq,
                               offset_ms=req.offset_ms, speaker=req.speaker, valence=req.valence)
    return {"added": True, **res}


@app.get("/api/v1/graph/conversation/{conversation_id}/moments")
def graph_conversation_moments(conversation_id: str, user_id: str = "anon"):
    """The within-conversation timeline — each moment's who/what/when/why/how."""
    with db() as conn:
        return graph.conversation_moments(conn, user_id, conversation_id)


@app.get("/api/v1/graph/conversation/{conversation_id}/links")
def graph_conversation_links(conversation_id: str, user_id: str = "anon"):
    """How this conversation connects to others: continuation + shared who/what/where/why/how."""
    with db() as conn:
        return graph.conversation_links(conn, user_id, conversation_id)


@app.get("/api/v1/graph/internal")
def graph_internal(user_id: str = "anon"):
    """The intrapersonal map: how you tend to show up, what you tend to need, your pattern."""
    with db() as conn:
        return graph.internal_map(conn, user_id)


@app.get("/api/v1/graph")
def graph_dump(user_id: str = "anon"):
    """Raw nodes + edges. Internal/debug — not surfaced to users."""
    with db() as conn:
        return {"user_id": user_id, **graph.dump(conn, user_id)}


@app.get("/api/v1/graph/relationship")
def graph_relationship(user_id: str = "anon", label: str = ""):
    """The 'Wikipedia article' for one relationship: its conversations + recurring themes."""
    with db() as conn:
        return graph.relationship_article(conn, user_id, label)


@app.get("/api/v1/graph/scouting-report")
def graph_scouting_report(user_id: str = "anon"):
    """The baseball card: good at X, needs work on Y — projected from the context graph."""
    with db() as conn:
        return graph.scouting_report(conn, user_id)


@app.get("/api/v1/graph/timeline")
def graph_timeline(user_id: str = "anon", label: str = ""):
    """A relationship's conversations over time — cadence, gaps, connection points."""
    with db() as conn:
        return graph.timeline(conn, user_id, label)


@app.get("/api/v1/graph/nudges")
def graph_nudges(user_id: str = "anon"):
    """Where to attend now: drift/reconnect, dropping cadence, recurring themes, and the
    settings (places) that help or hurt; plus connection points worth reinforcing."""
    with db() as conn:
        return graph.nudges(conn, user_id)


@app.get("/api/v1/graph/places")
def graph_places(user_id: str = "anon"):
    """Where conversations happen — per place: count, how often they went well, top themes,
    who with. The spatial dimension of the context graph."""
    with db() as conn:
        return graph.places(conn, user_id)


@app.get("/api/v1/graph/conversation/{conversation_id}")
def graph_conversation(conversation_id: str, user_id: str = "anon"):
    """The full 5W1H of one conversation: who / what / where / when / why / how."""
    with db() as conn:
        return graph.conversation_facets(conn, user_id, conversation_id)


# --------------------------------------------------------------------------- #
# Usefulness feedback
# --------------------------------------------------------------------------- #

@app.post("/api/v1/conversations/{session_id}/feedback")
def submit_feedback(session_id: str, outcome: str = "yes",
                    model: Optional[str] = None, confidence: Optional[str] = None):
    """
    outcome: "yes" | "somewhat" | "no"
    model/confidence: which model + confidence produced the rated insight (optional).
    Called from the insight page after the user taps the usefulness signal.
    """
    valid = {"yes", "somewhat", "no"}
    if outcome not in valid:
        raise HTTPException(422, f"outcome must be one of {valid}")
    with db() as conn:
        conn.execute(
            "INSERT INTO nudge_actions (id, session_id, outcome, created_at, model, confidence) "
            "VALUES (?,?,?,?,?,?)",
            (uuid.uuid4().hex[:12], session_id, outcome, now(), model, confidence),
        )
    return {"session_id": session_id, "outcome": outcome,
            "model": model, "confidence": confidence, "recorded": True}


# --------------------------------------------------------------------------- #
# Latest session (for home-screen "Review last result" flow)
# --------------------------------------------------------------------------- #

@app.get("/api/v1/conversations/latest")
def latest_conversation():
    """Returns the most recently stored analysis payload."""
    with db() as conn:
        row = conn.execute(
            "SELECT payload_json FROM analyses WHERE relationship_id=? ORDER BY created_at DESC LIMIT 1",
            (DEFAULT_RELATIONSHIP,),
        ).fetchone()
    if not row:
        raise HTTPException(404, "no sessions recorded yet")
    return json.loads(row["payload_json"])


# --------------------------------------------------------------------------- #
# Privacy / housekeeping
# --------------------------------------------------------------------------- #

@app.delete("/api/v1/conversations/{session_id}")
def delete_conversation(session_id: str):
    with db() as conn:
        conn.execute("DELETE FROM analyses WHERE session_id=?", (session_id,))
    return {"deleted": session_id}


@app.delete("/api/v1/relationships/{relationship_id}")
def delete_relationship(relationship_id: str):
    with db() as conn:
        n = conn.execute("DELETE FROM analyses WHERE relationship_id=?", (relationship_id,)).rowcount
    return {"deleted": relationship_id, "conversations_removed": n}


@app.get("/")
def root():
    return {
        "service": "presence-v2-backend",
        "docs": "/docs",
        "llm": analysis.current_backend(),
        "transcription": transcribe.status(),
        "diarization": diarize.status(),
        "endpoints": [
            "POST /api/v1/conversations/analyze",
            "GET /api/v1/relationships/work-on",
            "POST /api/v1/reflections/analyze",
            "GET /api/v1/reflections/latest",
            "GET /api/v1/reflections/themes",
            "GET /api/v1/reflections/followups",
            "POST /api/v1/events",
            "GET /api/v1/metrics/feature-tests",
            "GET /api/v1/metrics/telemetry",
            "POST /api/v1/threads  (+ /commit, /branch)",
            "GET /api/v1/threads/{id}",
            "GET /api/v1/resources  (+ /recommend)",
            "POST /api/v1/graph/ingest",
            "GET /api/v1/graph/scouting-report  (+ /conversation/{id} 5W1H +/moments +/links, /internal, /timeline, /places, /nudges)",
        ],
    }
