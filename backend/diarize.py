"""
Speaker diarization — answers "who spoke when", which the contract's word_balance
and interruptions metrics actually depend on.

Uses pyannote.audio (the standard). It's optional and heavy: if pyannote isn't
installed, there's no Hugging Face token, or anything fails, diarize() returns None
and the pipeline falls back to a single-speaker transcript (metrics get estimated
by the LLM instead, with low confidence).

To enable:
    pip install pyannote.audio
    # accept terms for the model at huggingface.co/pyannote/speaker-diarization-3.1
    export RELINT_HF_TOKEN=hf_xxx
(ffmpeg must also be on PATH.)

Alternative: WhisperX bundles faster-whisper + pyannote + word alignment in one pass.
"""

import os
import shutil
import subprocess
import tempfile

HF_TOKEN = os.environ.get("RELINT_HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN")
PIPELINE_NAME = os.environ.get("RELINT_DIARIZE_PIPELINE", "pyannote/speaker-diarization-3.1")

_PIPELINE = None


def _has_pyannote():
    try:
        import pyannote.audio  # noqa: F401
        return True
    except Exception:
        return False


def available():
    return shutil.which("ffmpeg") is not None and _has_pyannote() and bool(HF_TOKEN)


def status():
    return {
        "pyannote": _has_pyannote(),
        "hf_token": bool(HF_TOKEN),
        "ffmpeg": shutil.which("ffmpeg") is not None,
        "pipeline": PIPELINE_NAME,
        "ready": available(),
    }


def _load():
    global _PIPELINE
    if _PIPELINE is None:
        from pyannote.audio import Pipeline
        _PIPELINE = Pipeline.from_pretrained(PIPELINE_NAME, use_auth_token=HF_TOKEN)
    return _PIPELINE


def diarize(audio_bytes, suffix=".caf"):
    """Returns [{speaker, start_ms, end_ms}] sorted by start, or None if unavailable."""
    if not available() or not audio_bytes:
        return None
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "in" + suffix)
        wav = os.path.join(d, "out.wav")
        with open(src, "wb") as f:
            f.write(audio_bytes)
        try:
            subprocess.run(["ffmpeg", "-y", "-i", src, "-ar", "16000", "-ac", "1", wav],
                           check=True, capture_output=True)
        except Exception:
            return None
        try:
            annotation = _load()(wav)
            spans = [{"speaker": speaker,
                      "start_ms": int(turn.start * 1000),
                      "end_ms": int(turn.end * 1000)}
                     for turn, _, speaker in annotation.itertracks(yield_label=True)]
        except Exception:
            return None
    spans.sort(key=lambda s: s["start_ms"])
    return spans or None
