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
import json
import uuid
import sqlite3
from datetime import datetime, timezone
from contextlib import contextmanager
from typing import Optional

from fastapi import FastAPI, Form, File, UploadFile, HTTPException

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
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db():
    with db() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS analyses (
                   session_id TEXT PRIMARY KEY,
                   relationship_id TEXT,
                   created_at TEXT,
                   payload_json TEXT
               )"""
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
            note = ("audio received but local transcription is unavailable "
                    "(install ffmpeg + faster-whisper) — returned demo review")
        else:
            spans = diarize.diarize(audio_bytes)  # None if pyannote/HF token absent
            turns, diarized, label_map = signals.build_turns_from_audio(
                segments, spans, participant_one_label, participant_two_label)

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
    metrics_source = {"word_balance": "estimated", "interruptions": "estimated"}
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
    with db() as conn:
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

    return {"relationship_id": DEFAULT_RELATIONSHIP, "time_window": TIME_WINDOW, **body}


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
        ],
    }
