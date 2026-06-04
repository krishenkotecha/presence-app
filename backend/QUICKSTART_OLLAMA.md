# Quickstart — run the Presence v2 backend locally with Ollama

Everything runs on your machine. No conversation data leaves your laptop.

You paste in only two places: your **terminal** (commands) and the **`try_it.py` prompt**
(your conversation). Cheat sheet at the bottom.

---

## 1. Install Ollama
Paste into your **terminal**:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```
(or get the app from https://ollama.com)

## 2. Pull a model
```bash
ollama pull qwen3
```
Alternatives by hardware: `ollama pull gpt-oss:20b` (~16 GB) · `ollama pull qwen3:30b` (≥24 GB, better quality).
Ollama serves automatically at `http://localhost:11434`.

## 3. Install Python deps (from the project folder)
```bash
pip install -r requirements.txt
```

## 4. (Optional) enable real audio transcription
The app uploads `audio/x-caf`. To transcribe locally:
```bash
brew install ffmpeg          # or: sudo apt install ffmpeg
pip install faster-whisper
export RELINT_WHISPER_MODEL=base   # tiny|base|small|medium
```
Without this, the analyze endpoint still works — it returns contract-shaped **demo** data with a `note`.

## 4b. (Optional) enable speaker diarization → real metrics
This is what makes `word_balance` and `interruptions` **measured** instead of guessed:
```bash
pip install pyannote.audio
# in a browser: accept the terms at huggingface.co/pyannote/speaker-diarization-3.1
export RELINT_HF_TOKEN=hf_xxx
```
With diarization on, the response shows `"diarized": true`, `metrics_source` becomes `computed`,
and `confidence` rises to `medium`.

## 5. Point the app at Ollama
macOS/Linux:
```bash
export RELINT_BACKEND=local
export RELINT_MODEL=qwen3
```
Windows PowerShell:
```powershell
$env:RELINT_BACKEND="local"; $env:RELINT_MODEL="qwen3"
```

---

## See the whole thing run
```bash
python demo_flow.py
```
Posts two conversations through `POST /api/v1/conversations/analyze`, then calls
`GET /api/v1/relationships/work-on`, and prints both payloads.

## Test YOUR OWN conversation
```bash
python try_it.py
```
Answer the short prompts, then **paste your transcript** at:
```
Paste the transcript (one line per turn, name first).
When done: Ctrl-D (Mac/Linux) or Ctrl-Z then Enter (Windows).
```
Press **Ctrl-D** to get the review. Or from a file: `python try_it.py mychat.txt`.

## Run the real server for the app to hit
```bash
export RELINT_BACKEND=local RELINT_MODEL=qwen3
uvicorn main:app --reload --host 0.0.0.0   # 0.0.0.0 so a device on your wifi can reach it
```
Then in **`PresenceApp.swift`** set:
```swift
PresenceV2BackendConfig.analyzeURLString = "http://<your-mac-ip>:8000/api/v1/conversations/analyze"
PresenceV2BackendConfig.workOnURLString  = "http://<your-mac-ip>:8000/api/v1/relationships/work-on"
```
(Use `127.0.0.1` for the simulator; your Mac's LAN IP, e.g. `192.168.x.x`, for a real iPhone.)
Visit `http://127.0.0.1:8000/` to confirm the active backend + whether transcription is ready,
or `http://127.0.0.1:8000/docs` for the interactive API.

---

## Where to paste each thing — cheat sheet

| You want to paste… | Paste it here |
|---|---|
| install / pull / `export` / `python …` / `uvicorn …` commands | your **terminal**, inside the project folder |
| your actual conversation transcript | at the `try_it.py` **"Paste the transcript"** prompt, then Ctrl-D |
| a saved transcript file | nowhere — run `python try_it.py yourfile.txt` |
| the backend URLs | into **`PresenceApp.swift`** (`analyzeURLString`, `workOnURLString`) |
| a different model | the `export RELINT_MODEL=...` command before running |

## Troubleshooting
- **"Can't reach a local LLM server"** → Ollama isn't running. Open the app or run `ollama serve`.
- **"'qwen3' not pulled"** → `ollama pull qwen3` (or match `RELINT_MODEL` to what you have).
- **analyze returns a `note` about transcription** → expected until you do step 4; the data is demo.
- **iPhone can't connect** → run uvicorn with `--host 0.0.0.0` and use the Mac's LAN IP in Swift.
- **Confirm backend** → `python -c "import analysis; print(analysis.current_backend())"`.
