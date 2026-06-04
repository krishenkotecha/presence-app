"""
Local audio transcription for the analyze endpoint.

iOS sends audio/x-caf. We convert to 16k mono wav with ffmpeg, then transcribe
with a local Whisper backend (faster-whisper preferred, openai-whisper fallback).
Everything stays on the machine.

If ffmpeg or a Whisper backend isn't installed, transcribe() returns (None, None)
and the caller falls back to demo data — so the app keeps working either way.

To enable, install one of:
    pip install faster-whisper        # lighter, recommended
    pip install openai-whisper        # alternative
and make sure `ffmpeg` is on PATH (brew install ffmpeg / apt install ffmpeg).

Pick model size with:  export RELINT_WHISPER_MODEL=base   (tiny|base|small|medium)
"""

import os
import shutil
import subprocess
import tempfile

WHISPER_MODEL = os.environ.get("RELINT_WHISPER_MODEL", "base")


def _whisper_backend():
    try:
        import faster_whisper  # noqa: F401
        return "faster_whisper"
    except Exception:
        pass
    try:
        import whisper  # noqa: F401
        return "whisper"
    except Exception:
        return None


def available():
    return shutil.which("ffmpeg") is not None and _whisper_backend() is not None


def status():
    return {
        "ffmpeg": shutil.which("ffmpeg") is not None,
        "whisper_backend": _whisper_backend(),
        "model": WHISPER_MODEL,
        "ready": available(),
    }


def transcribe(audio_bytes, suffix=".caf"):
    """Returns (text, segments) where segments is [{start_ms,end_ms,text}], or (None, None)."""
    if shutil.which("ffmpeg") is None:
        return None, None
    backend = _whisper_backend()
    if backend is None or not audio_bytes:
        return None, None

    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "in" + suffix)
        wav = os.path.join(d, "out.wav")
        with open(src, "wb") as f:
            f.write(audio_bytes)
        try:
            subprocess.run(
                ["ffmpeg", "-y", "-i", src, "-ar", "16000", "-ac", "1", wav],
                check=True, capture_output=True,
            )
        except Exception:
            return None, None

        try:
            if backend == "faster_whisper":
                from faster_whisper import WhisperModel
                model = WhisperModel(WHISPER_MODEL, compute_type="int8")
                segs, _info = model.transcribe(wav)
                segments = [{"start_ms": int(s.start * 1000),
                             "end_ms": int(s.end * 1000),
                             "text": s.text.strip()} for s in segs]
            else:
                import whisper
                model = whisper.load_model(WHISPER_MODEL)
                res = model.transcribe(wav)
                segments = [{"start_ms": int(s["start"] * 1000),
                             "end_ms": int(s["end"] * 1000),
                             "text": s["text"].strip()} for s in res.get("segments", [])]
        except Exception:
            return None, None

    text = "\n".join(s["text"] for s in segments if s["text"]).strip()
    return (text or None), (segments or None)
