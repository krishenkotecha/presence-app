"""
mic_check.py — prove the microphone works, end to end, outside the iOS app.

It records from your default input device, shows a LIVE input-level meter so you
can watch the bars move while you talk, saves a WAV, and (if the backend's Whisper
stack is installed) prints what it heard.

Install (one time):
    pip install sounddevice numpy      # PortAudio wheels ship with the Mac build
    # transcription is optional and reuses the backend: pip install faster-whisper + ffmpeg

Run:
    python mic_check.py                # 6-second test
    python mic_check.py --seconds 10   # longer
    python mic_check.py --list         # just list input devices and exit
    python mic_check.py --device 1     # pick a specific input device index

On first run macOS will prompt for microphone permission for your terminal app —
allow it, then run again.
"""

import argparse
import sys
import wave

try:
    import numpy as np
    import sounddevice as sd
except ImportError:
    sys.exit("Missing deps. Run:  pip install sounddevice numpy")

SAMPLE_RATE = 16000      # matches what the backend transcribes at
CHANNELS = 1
OUT_PATH = "mic_test.wav"


def list_devices():
    print("Input devices:")
    for i, d in enumerate(sd.query_devices()):
        if d["max_input_channels"] > 0:
            default = " (default)" if i == sd.default.device[0] else ""
            print(f"  [{i}] {d['name']}{default}")


def meter(rms, width=40):
    # rms ~0.0–0.3 for speech; scale to a bar so movement is visible.
    level = min(1.0, rms * 12)
    filled = int(level * width)
    return "[" + "#" * filled + "-" * (width - filled) + f"] {rms:5.3f}"


def record(seconds, device):
    print(f"\nRecording {seconds}s — talk now. Watch the bar move:\n")
    frames = []
    peak = 0.0
    blocksize = int(SAMPLE_RATE * 0.1)  # 100 ms updates

    with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS,
                        device=device, blocksize=blocksize, dtype="float32") as stream:
        total_blocks = int(seconds * 10)
        for _ in range(total_blocks):
            block, overflowed = stream.read(blocksize)
            mono = block[:, 0]
            rms = float(np.sqrt(np.mean(mono ** 2)))
            peak = max(peak, rms)
            frames.append(mono.copy())
            print("\r" + meter(rms), end="", flush=True)

    print("\n")
    audio = np.concatenate(frames)
    return audio, peak


def save_wav(audio, path):
    pcm16 = np.clip(audio, -1.0, 1.0)
    pcm16 = (pcm16 * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(CHANNELS)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm16.tobytes())


def try_transcribe(path):
    try:
        import transcribe  # the backend module, run this from backend/
    except Exception:
        return None
    if not transcribe.available():
        return None
    with open(path, "rb") as f:
        text, _segments = transcribe.transcribe(f.read(), suffix=".wav")
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=int, default=6)
    ap.add_argument("--device", type=int, default=None, help="input device index (see --list)")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    if args.list:
        list_devices()
        return

    list_devices()
    audio, peak = record(args.seconds, args.device)

    if peak < 0.005:
        print("⚠️  Almost no signal detected (peak %.4f)." % peak)
        print("   Check: mic permission for your terminal, the right --device, and that you spoke.")
    else:
        print("✅ Microphone is capturing audio (peak level %.3f)." % peak)

    save_wav(audio, OUT_PATH)
    print(f"💾 Saved {OUT_PATH} — play it back to confirm: afplay {OUT_PATH}")

    text = try_transcribe(OUT_PATH)
    if text:
        print(f"\n🗣️  Whisper heard:\n   \"{text}\"")
    else:
        print("\n(ℹ️  Transcription skipped — run from backend/ with faster-whisper + ffmpeg "
              "installed to also see a transcript.)")


if __name__ == "__main__":
    main()
