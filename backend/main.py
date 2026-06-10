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
        # Migrate older DBs: tie each usefulness signal to the model + confidence
        # that produced the insight, so we can learn what actually helps.
        existing = {r["name"] for r in conn.execute("PRAGMA table_info(nudge_actions)")}
        if "model" not in existing:
            conn.execute("ALTER TABLE nudge_actions ADD COLUMN model TEXT")
        if "confidence" not in existing:
            conn.execute("ALTER TABLE nudge_actions ADD COLUMN confidence TEXT")


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
        ],
    }
