# Run Presence locally (Ollama + FastAPI + iOS)

Everything runs on your machine. No conversation data leaves your laptop.

The system has three parts:

1. **Ollama** — the local LLM that writes the analysis (default model `qwen3`).
2. **FastAPI backend** (`backend/`) — takes audio + the success definition, transcribes, optionally separates speakers, asks Ollama, returns the review.
3. **iOS app** (`Sources/`) — records the conversation, uploads it, and renders the result.

There are two tiers of setup. **Tier 1** gets you real Ollama analysis in ~5 minutes. **Tier 2** adds real audio transcription and measured metrics.

---

## Tier 1 — minimum: real Ollama analysis

### 1. Install + start Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh   # or download the app from ollama.com
ollama pull qwen3                                # ~5 GB; serves at http://localhost:11434
```

Bigger/better if your hardware allows: `ollama pull qwen3:30b` (≥24 GB RAM) or `ollama pull gpt-oss:20b`.

### 2. Install backend dependencies

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate     # optional but recommended
pip install -r requirements.txt
```

### 3. Point the backend at Ollama and run it

```bash
export RELINT_BACKEND=local
export RELINT_MODEL=qwen3
uvicorn main:app --reload --host 0.0.0.0      # 0.0.0.0 so a real phone on your wifi can reach it
```

Windows PowerShell:

```powershell
$env:RELINT_BACKEND="local"; $env:RELINT_MODEL="qwen3"
uvicorn main:app --reload --host 0.0.0.0
```

### 4. Confirm it's live

Open <http://127.0.0.1:8000/> — you should see the active backend and model:

```json
{ "service": "presence-v2-backend",
  "llm": { "backend": "local", "model": "qwen3", "local_base_url": "http://localhost:11434/v1" },
  "transcription": { "ready": false }, "diarization": { ... } }
```

`<http://127.0.0.1:8000/docs>` is the interactive API.

> **Even with `transcription.ready: false`, you still get real Ollama analysis.** The app
> sends its live on-device transcript as a fallback (`device_transcript`), so the backend
> analyzes the actual conversation and returns a `note` explaining metrics are estimated
> (no speaker separation). Tier 2 removes that limitation.

---

## Tier 2 — optional: real audio transcription + measured metrics

### 4a. Server-side transcription (Whisper)

```bash
brew install ffmpeg            # macOS  (Linux: sudo apt install ffmpeg)
pip install faster-whisper
export RELINT_WHISPER_MODEL=base   # tiny | base | small | medium
```

Now the uploaded audio is transcribed on the server instead of relying on the device transcript.

### 4b. Speaker separation (diarization) → measured metrics

This is what turns `word_balance` and `interruptions` from *estimated* into *measured*:

```bash
pip install pyannote.audio
# in a browser, accept the terms at huggingface.co/pyannote/speaker-diarization-3.1
export RELINT_HF_TOKEN=hf_xxx
```

With diarization on, responses show `"diarized": true`, `metrics_source` flips to `computed`,
and confidence rises to `medium`. The app's results page reflects all of this in its source banner.

---

## 5. Run the iOS app

### 5a. Set the backend URL (one place now)

In `Sources/PresenceApp.swift`, set the single base URL:

```swift
private enum PresenceV2BackendConfig {
    static let baseURLString = "http://127.0.0.1:8000"   // simulator
    // Physical device on the same wifi: use your Mac's LAN IP, e.g.
    // static let baseURLString = "http://192.168.1.20:8000"
}
```

Find your Mac's LAN IP with `ipconfig getifaddr en0`. Leave `baseURLString = ""` to force the on-device demo everywhere.

> Plain-HTTP local networking is already allowed via `NSAllowsLocalNetworking` in `Config/Info.plist`.
> The simulator can reach `127.0.0.1`; a real device needs the Mac's LAN IP and the same wifi.

### 5b. Build and run

If the project uses XcodeGen (there's a `project.yml`):

```bash
brew install xcodegen      # first time only
xcodegen generate          # regenerates Presence.xcodeproj
```

Then:

```bash
open Presence.xcodeproj
```

In Xcode: pick a Simulator (or your connected iPhone) and press **Run** (⌘R). Grant microphone +
speech-recognition permission on first launch.

### 5c. Use it

1. **Start a conversation** → each partner speaks their definition of success.
2. **Start listening** → have the conversation, then **Stop and analyze**.
3. The results page shows the headline + subheadline, a **source banner** (real model vs demo,
   confidence, measured vs estimated metrics), key moments, unmet needs, next steps, the transcript
   Presence heard, and the usefulness question.
4. **What should we work on?** appears once you have 2+ recorded sessions.

---

## Try the backend without the app

```bash
cd backend
source .venv/bin/activate
export RELINT_BACKEND=local RELINT_MODEL=qwen3

python demo_flow.py        # posts two conversations + the work-on view, prints both payloads
python try_it.py           # paste your own transcript, Ctrl-D to analyze (or: python try_it.py chat.txt)
```

---

## What the integration now does (changed in this pass)

- **No more silent demo swaps.** A `neutral` key moment (allowed by the contract) used to crash
  the app's JSON decode and silently substitute demo data; it's now handled.
- **Ollama output is visible.** The results page surfaces `subheadline`, `model`, `confidence`,
  `diarized`, `metrics_source`, the `note`, and the analyzed transcript — so you can tell real
  analysis from fallback at a glance.
- **Honest errors.** Failures distinguish *not configured* vs *can't reach server* vs *bad
  response format*, and the real error is logged to the Xcode console (`[Presence] ...`).
- **Works without Whisper.** The live on-device transcript is sent as a fallback.
- **Robust to thin model output.** Backend fills any missing review fields; the app tolerates
  missing longitudinal sections instead of collapsing to mock.
- **Smaller uploads.** Audio is recorded as AAC/`.m4a` instead of uncompressed CAF.
- **Feedback is attributable.** The usefulness signal is stored with the `model` + `confidence`
  that produced the insight.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Results banner says "Demo analysis" | Backend unreachable or `baseURLString` empty/wrong. Check <http://127.0.0.1:8000/> and the Xcode console for `[Presence] ...`. |
| `local LLM call failed` | Ollama isn't running (`ollama serve`) or the model isn't pulled (`ollama pull qwen3`); make `RELINT_MODEL` match what you have. |
| First analysis is slow | Cold Ollama load. The app waits up to 120s and retries transient failures. |
| iPhone can't connect | Run uvicorn with `--host 0.0.0.0`, use the Mac's LAN IP in `baseURLString`, and confirm both are on the same wifi. |
| Metrics show "estimated" | Expected without diarization. Do Tier 2 step 4b for measured values. |
| Confirm backend from a shell | `python -c "import analysis; print(analysis.current_backend())"` |
