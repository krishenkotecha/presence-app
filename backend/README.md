# Presence v2 — backend

Implements the app's backend contract:

- `POST /api/v1/conversations/analyze` (multipart) → **conversation-review** payload
- `GET /api/v1/relationships/work-on` → **longitudinal "work on"** payload

Pipeline: **audio (`audio/x-caf`) → local Whisper transcript → speaker diarization → local LLM → contract payload.**
Speaker diarization lets the backend **compute** `word_balance` and `interruptions` and ground each
`key_moment`'s timestamp + speaker to the real transcript, instead of having the model guess them.
If transcription/diarization or a model isn't set up, endpoints return contract-shaped **demo** data
with a `note`, so the app keeps working (matching its built-in fallback).

> **Running it locally with Ollama?** Follow **`QUICKSTART_OLLAMA.md`** — step-by-step, with the
> exact URLs to paste into `PresenceApp.swift`.

## Install & run
```bash
pip install -r requirements.txt

# fastest: see both endpoints run end-to-end (no server, no audio needed)
python demo_flow.py

# real server for the app:
export RELINT_BACKEND=local RELINT_MODEL=qwen3      # needs Ollama + `ollama pull qwen3`
uvicorn main:app --reload --host 0.0.0.0
```

Set these in **`PresenceApp.swift`** (LAN IP for a device, `127.0.0.1` for the simulator):
```swift
PresenceV2BackendConfig.analyzeURLString = "http://<host>:8000/api/v1/conversations/analyze"
PresenceV2BackendConfig.workOnURLString  = "http://<host>:8000/api/v1/relationships/work-on"
```

## Backends
| Goal | Env |
|---|---|
| Local model (private) | `RELINT_BACKEND=local` + `RELINT_LOCAL_BASE_URL` (default Ollama) + `RELINT_MODEL` |
| Anthropic API | `ANTHROPIC_API_KEY=...` (auto) |
| No model (demo data) | nothing set → mock |

Audio transcription (optional): `brew install ffmpeg` + `pip install faster-whisper`, then
`RELINT_WHISPER_MODEL=base`.

Speaker diarization (optional, enables **computed** `word_balance` + `interruptions`):
```bash
pip install pyannote.audio
# accept terms at huggingface.co/pyannote/speaker-diarization-3.1
export RELINT_HF_TOKEN=hf_xxx
```
Check readiness for all three at `GET /` (`llm`, `transcription`, `diarization`).

### How metrics are produced
- `word_balance`, `interruptions` — **computed** from diarized speaker turns when diarization is
  available; otherwise estimated by the LLM. Each response includes `metrics_source` and a `diarized`
  flag, and `confidence` is `medium` when diarized, `low` otherwise.
- `key_moments[].timestamp_ms` / `.speaker` — snapped to the transcript turn the quote came from.
- `connection_score`, `repair_attempts` — qualitative, from the LLM.
- Two diarized speakers map to participant one/two by **order of first appearance**.

## The analyze request (what the app sends)
`multipart/form-data` with: `session_id`, `started_at`, `ended_at`, `duration_seconds`,
`participant_one_label`, `participant_two_label`, `participant_one_success_definition`,
`participant_two_success_definition`, `prototype_track`,
and `conversation_audio` (`audio/x-caf`). The `shared` line in the response is synthesized
from the two individual definitions (no `shared_success_definition` input).

For local testing without recording audio, the endpoint also accepts an optional `transcript`
text field (the app never sends it). Example:
```bash
curl -s http://127.0.0.1:8000/api/v1/conversations/analyze \
  -F session_id=S1 -F duration_seconds=808 \
  -F participant_one_label=You -F participant_two_label="Your partner" \
  -F participant_one_success_definition="stay calm and feel understood" \
  -F participant_two_success_definition="feel heard, then a clear plan" \
  -F transcript=$'You: ...\nYour partner: ...' | python3 -m json.tool

curl -s http://127.0.0.1:8000/api/v1/relationships/work-on | python3 -m json.tool
```
With real audio, drop `transcript` and send `-F conversation_audio=@rec.caf;type=audio/x-caf`.

## Files
- `QUICKSTART_OLLAMA.md` — paste-and-go local setup
- `main.py` — FastAPI app: the two contract endpoints + storage
- `analysis.py` — LLM wrapper: review + work-on prompts/schemas, local/Anthropic/mock backends
- `transcribe.py` — local CAF→text (ffmpeg + Whisper), graceful fallback
- `diarize.py` — speaker diarization (pyannote), graceful fallback
- `signals.py` — computed word_balance / interruptions + key-moment grounding
- `try_it.py` — paste your own transcript, get a review (local, no server)
- `demo_flow.py` — one-command end-to-end over both endpoints
- `backend_architecture.md` — architecture (Presence v2 addendum at top)

## Environment variables
| Var | Default | Purpose |
|---|---|---|
| `RELINT_BACKEND` | auto | `local` / `anthropic` / `mock` |
| `RELINT_LOCAL_BASE_URL` | `http://localhost:11434/v1` | OpenAI-compatible local endpoint |
| `RELINT_MODEL` | per-backend | model name |
| `RELINT_WHISPER_MODEL` | `base` | Whisper size for transcription |
| `RELINT_HF_TOKEN` | – | Hugging Face token for pyannote diarization |
| `RELINT_DIARIZE_PIPELINE` | `pyannote/speaker-diarization-3.1` | diarization model |
| `RELINT_DB` | `relint.db` | SQLite path |
| `RELINT_TIME_WINDOW` | `90d` | reported in work-on payload |

## Notes / limits
- No auth and unencrypted SQLite — fine for local single-couple testing, first thing to harden before real users.
- Diarization assumes two main speakers (a couple); extra speakers beyond the first two are ignored for metrics.
- `connection_score` / `repair_attempts` are LLM judgments and stay tentative by design (never "high" confidence).
