"""
frontend_contract_check.py — test the front end without Xcode.

The iOS app decodes every backend response into strict Swift models. If a required
field is missing or the wrong type, the decode throws and the app SILENTLY falls
back to on-device demo data — so the screen looks fine but isn't real. This script
sends the exact same requests the app's PresenceV2BackendClient sends, then checks
each response against what the Swift models require, so you can see whether the app
would render real insight or quietly degrade to the demo.

Stdlib only. Point it at a running backend:
    uvicorn main:app --reload        # in another terminal
    python frontend_contract_check.py
    python frontend_contract_check.py --base http://192.168.1.20:8000

It reuses mic_test.wav (from mic_check.py) if present, otherwise generates a short
silent WAV so the multipart upload matches the app.
"""

import argparse
import json
import os
import struct
import sys
import urllib.request
import uuid
import wave
from datetime import datetime, timezone, timedelta

# --------------------------------------------------------------------------- #
# What the Swift models REQUIRE (missing => the app throws => demo fallback).
# Mirrors the CodingKeys in PresenceApp.swift. "[]" marks a list whose items
# each carry the listed required keys.
# --------------------------------------------------------------------------- #
ANALYZE_REQUIRED = {
    "session_id": str, "status": str, "duration_seconds": int,
    "summary": {"headline": str, "subheadline": str},
    "success_definition": {"participant_one": str, "participant_two": str, "shared": str},
    "metrics": {
        "word_balance": {"participant_one_percent": int, "participant_two_percent": int, "label": str},
        "interruptions": {"total": int, "participant_one": int, "participant_two": int, "label": str},
        "connection_score": {"score": int, "delta_label": str},
        "repair_attempts": {"total": int, "label": str},
    },
    "key_moments": [{"title": str, "quote": str, "speaker": str, "explanation": str}],
    "unmet_needs": [{"person": str, "need": str}],
    "next_time": [{"person": str, "try": str}],
}


def _check(node, schema, path=""):
    """Return a list of human-readable problems; empty list == app would decode it."""
    problems = []
    if isinstance(schema, dict):
        if not isinstance(node, dict):
            return [f"{path or '<root>'}: expected object, got {type(node).__name__}"]
        for key, sub in schema.items():
            p = f"{path}.{key}" if path else key
            if key not in node:
                problems.append(f"MISSING {p}")
            else:
                problems += _check(node[key], sub, p)
    elif isinstance(schema, list):
        if not isinstance(node, list):
            return [f"{path}: expected array, got {type(node).__name__}"]
        if not node:
            problems.append(f"EMPTY {path} (app shows an empty section)")
        for i, item in enumerate(node):
            problems += _check(item, schema[0], f"{path}[{i}]")
    else:  # leaf type
        if schema is int and isinstance(node, bool):
            problems.append(f"WRONG-TYPE {path}: bool where int expected")
        elif not isinstance(node, schema):
            problems.append(f"WRONG-TYPE {path}: {type(node).__name__} where {schema.__name__} expected")
    return problems


# --------------------------------------------------------------------------- #
# HTTP helpers (stdlib only)
# --------------------------------------------------------------------------- #
def _get(url):
    with urllib.request.urlopen(url, timeout=180) as r:
        return r.status, json.loads(r.read().decode())


def _post_empty(url):
    req = urllib.request.Request(url, data=b"", method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status, json.loads(r.read().decode())


def _post_json(url, obj):
    data = json.dumps(obj).encode()
    req = urllib.request.Request(
        url, data=data, method="POST", headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.status, json.loads(r.read().decode())


def _post_multipart(url, fields, filename, filedata):
    boundary = "Boundary-" + uuid.uuid4().hex
    body = b""
    for name, value in fields.items():
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        body += f"{value}\r\n".encode()
    body += f"--{boundary}\r\n".encode()
    body += (f'Content-Disposition: form-data; name="conversation_audio"; '
             f'filename="{filename}"\r\n').encode()
    body += b"Content-Type: audio/wav\r\n\r\n" + filedata + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.status, json.loads(r.read().decode())


def _audio_bytes():
    if os.path.exists("mic_test.wav"):
        with open("mic_test.wav", "rb") as f:
            return f.read(), "mic_test.wav"
    # generate ~1s of silence so the multipart matches the app
    buf = "frontend_check.wav"
    with wave.open(buf, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
        w.writeframes(struct.pack("<16000h", *([0] * 16000)))
    with open(buf, "rb") as f:
        data = f.read()
    os.remove(buf)
    return data, "conversation.wav"


# What the iOS PresenceSoloResponse decoder requires (reframe is optional).
SOLO_REQUIRED = {
    "reflection_id": str, "status": str, "mode": str,
    "summary": {"headline": str},
    "translation": {"what_they_may_have_meant": str, "their_possible_need": str},
    "your_part": str, "suggested_next": str, "confidence": str,
}


def _report(name, problems):
    if not problems:
        print(f"  ✅ {name}: app would render REAL data (all required fields present)")
        return True
    print(f"  ❌ {name}: app would FALL BACK TO DEMO — {len(problems)} issue(s):")
    for p in problems[:12]:
        print(f"       - {p}")
    return False


# --------------------------------------------------------------------------- #
def check_solo(api):
    """Exercise the solo single-user reflection endpoint for all three modes."""
    ok = True
    user_id = "contractcheck-" + uuid.uuid4().hex[:8]
    cases = {
        "decode": {"quote": "Fine, do whatever you want.",
                   "text": "We were deciding on holiday plans and they shut down."},
        "prep": {"text": "I want to talk about splitting chores more evenly without it becoming a fight."},
        "reflect": {"text": "I snapped at them about the dishes and now it's tense."},
    }
    print("\nTesting SOLO reflection endpoint (single-user on-ramp).\n")
    for i, (mode, body) in enumerate(cases.items(), start=1):
        print(f"{i}) POST /reflections/analyze  mode={mode}")
        try:
            req = {"user_id": user_id, "mode": mode, **body}
            status, payload = _post_json(api + "/reflections/analyze", req)
            print(f"   HTTP {status} • model={payload.get('model')} • confidence={payload.get('confidence')}"
                  + (f" • note={payload.get('note')}" if payload.get("note") else ""))
            print(f"   headline: {payload.get('summary', {}).get('headline','')!r}")
            print(f"   suggested_next: {payload.get('suggested_next','')!r}")
            ok &= _report(f"{mode} result page", _check(payload, SOLO_REQUIRED))
        except Exception as e:  # noqa: BLE001
            ok = False
            print(f"   ❌ request failed: {e}\n   (is uvicorn running at --base?)")

    print("\n4) GET /reflections/latest  (home 'last reflection' row)")
    try:
        status, payload = _get(api + f"/reflections/latest?user_id={user_id}")
        ok &= _report("latest reflection", _check(payload, SOLO_REQUIRED))
    except Exception as e:  # noqa: BLE001
        ok = False
        print(f"   ❌ {e}")

    print("\n" + ("✅ PASS — the solo front end would render real backend data."
                  if ok else
                  "❌ FAIL — a solo screen would fall back to demo data (see above)."))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8000")
    ap.add_argument("--solo", action="store_true", help="test the solo reflection endpoint instead")
    args = ap.parse_args()
    api = args.base.rstrip("/") + "/api/v1"
    ok = True

    if args.solo:
        sys.exit(0 if check_solo(api) else 1)

    print(f"\nTesting backend at {args.base} as the iOS app would.\n")

    # 1) analyze — the multipart upload the app sends after a conversation
    print("1) POST /conversations/analyze  (Start a conversation → review page)")
    audio, filename = _audio_bytes()
    now = datetime.now(timezone.utc)
    session_id = uuid.uuid4().hex
    fields = {
        "session_id": session_id,
        "started_at": (now - timedelta(minutes=8)).isoformat(),
        "ended_at": now.isoformat(),
        "duration_seconds": "480",
        "participant_one_label": "You",
        "participant_two_label": "Your partner",
        "participant_one_success_definition": "I want us to feel heard before we fix anything.",
        "participant_two_success_definition": "I want to leave with a plan we both believe in.",
        "prototype_track": "v2",
        "device_transcript": ("You: I felt alone when plans changed.\n"
                              "Your partner: I can see why that felt lonely.\n"
                              "You: thank you, that helps."),
    }
    try:
        status, payload = _post_multipart(api + "/conversations/analyze", fields, filename, audio)
        print(f"   HTTP {status} • model={payload.get('model')} • confidence={payload.get('confidence')}"
              + (f" • note={payload.get('note')}" if payload.get("note") else ""))
        ok &= _report("review page", _check(payload, ANALYZE_REQUIRED))
    except Exception as e:  # noqa: BLE001
        ok = False
        print(f"   ❌ request failed: {e}\n   (is uvicorn running at --base?)")

    # 2) latest — home screen "Last result" row
    print("\n2) GET /conversations/latest  (home 'Last result' row)")
    try:
        status, payload = _get(api + "/conversations/latest")
        ok &= _report("home last-result", _check(payload, ANALYZE_REQUIRED))
    except Exception as e:  # noqa: BLE001
        print(f"   ⚠️  {e} (expected 404 only if no sessions stored yet)")

    # 3) work-on — longitudinal page (Swift decoder is lenient, so just sanity-check)
    print("\n3) GET /relationships/work-on  (What should we work on?)")
    try:
        status, payload = _get(api + "/relationships/work-on")
        pf = payload.get("primary_focus", {})
        has_core = bool(pf.get("title")) and "session_count" in payload
        print(f"   HTTP {status} • session_count={payload.get('session_count')} "
              f"• time_window={payload.get('time_window')}")
        print("   ✅ work-on: primary focus + session_count present"
              if has_core else "   ⚠️  work-on: thin payload; app will pad with its built-in copy")
        ok &= has_core
    except Exception as e:  # noqa: BLE001
        ok = False
        print(f"   ❌ {e}")

    # 4) feedback — the usefulness tap on the review page (north-star signal)
    print("\n4) POST /conversations/<id>/feedback  (Did this help you understand each other?)")
    try:
        status, payload = _post_empty(api + f"/conversations/{session_id}/feedback?outcome=yes&model=demo")
        print(f"   ✅ recorded={payload.get('recorded')} outcome={payload.get('outcome')}")
    except Exception as e:  # noqa: BLE001
        ok = False
        print(f"   ❌ {e}")

    print("\n" + ("✅ PASS — the front end would render real backend data on every screen."
                  if ok else
                  "❌ FAIL — at least one screen would silently fall back to demo data (see above)."))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
