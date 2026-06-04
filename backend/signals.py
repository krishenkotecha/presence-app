"""
Computed signals derived from speaker-attributed turns.

These replace LLM guesses for the metrics that genuinely depend on "who said what":
  - word_balance  (per-speaker share of words)
  - interruptions (overlapping speech, attributed to the interrupter)
and ground each key moment's timestamp + speaker to the real transcript.

Turn shape: {"speaker": <id or label or None>, "start_ms": int|None, "end_ms": int|None, "text": str}
"""

import re

# --------------------------------------------------------------------------- #
# Turn construction
# --------------------------------------------------------------------------- #

def parse_labeled_transcript(text, p1_label, p2_label):
    """Parse 'Name: line' text into turns (used for the dev transcript path)."""
    if not text:
        return []
    alias = {p1_label.lower(): p1_label, p2_label.lower(): p2_label,
             "you": p1_label, "me": p1_label,
             "your partner": p2_label, "partner": p2_label}
    turns = []
    for line in text.splitlines():
        m = re.match(r"\s*([A-Za-z][\w '\-]{0,40}?)\s*:\s*(.+)", line)
        if not m:
            if turns and line.strip():
                turns[-1]["text"] += " " + line.strip()
            continue
        name = m.group(1).strip()
        speaker = alias.get(name.lower(), name)  # unknown names kept as-is
        turns.append({"speaker": speaker, "start_ms": None, "end_ms": None,
                      "text": m.group(2).strip()})
    return turns


def build_turns_from_audio(segments, spans, p1_label, p2_label):
    """Combine Whisper segments with diarization spans into speaker turns.
    Returns (turns, diarized: bool, label_map: {raw_speaker: label})."""
    if not segments:
        return [], False, {}
    if not spans:
        turns = [{"speaker": None, "start_ms": s["start_ms"], "end_ms": s["end_ms"],
                  "text": s["text"]} for s in segments]
        return turns, False, {}

    for seg in segments:
        best, best_overlap = None, 0
        for sp in spans:
            overlap = min(seg["end_ms"], sp["end_ms"]) - max(seg["start_ms"], sp["start_ms"])
            if overlap > best_overlap:
                best_overlap, best = overlap, sp["speaker"]
        seg["speaker"] = best

    turns = []
    for seg in segments:
        if turns and turns[-1]["speaker"] == seg["speaker"]:
            turns[-1]["text"] += " " + seg["text"]
            turns[-1]["end_ms"] = seg["end_ms"]
        else:
            turns.append({"speaker": seg["speaker"], "start_ms": seg["start_ms"],
                          "end_ms": seg["end_ms"], "text": seg["text"]})
    label_map, _ = speaker_label_map(turns, p1_label, p2_label)
    return turns, True, label_map


def speaker_label_map(turns, p1_label, p2_label):
    """Map the first two speakers (by first appearance) to participant labels."""
    order = []
    for t in turns:
        s = t["speaker"]
        if s is not None and s not in order:
            order.append(s)
    if not order:
        return {}, order
    if len(order) == 1:
        return {order[0]: p1_label}, order
    return {order[0]: p1_label, order[1]: p2_label}, order


def render_transcript(turns, label_map=None):
    """Render turns for the LLM, with speaker labels + timestamps when available."""
    lines = []
    for t in turns:
        ts = f"[{t['start_ms']}ms] " if t.get("start_ms") is not None else ""
        spk = label_map.get(t["speaker"]) if label_map else (
            t["speaker"] if isinstance(t["speaker"], str) else None)
        prefix = f"{spk}: " if spk else ""
        lines.append(f"{ts}{prefix}{t['text']}")
    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# Metrics
# --------------------------------------------------------------------------- #

def word_balance(turns, p1_label, p2_label):
    label_map, order = speaker_label_map(turns, p1_label, p2_label)
    if len(label_map) < 2:
        return None
    counts = {p1_label: 0, p2_label: 0}
    for t in turns:
        lbl = label_map.get(t["speaker"])
        if lbl in counts:
            counts[lbl] += len((t["text"] or "").split())
    total = counts[p1_label] + counts[p2_label]
    if total == 0:
        return None
    p1pct = round(100 * counts[p1_label] / total)
    return {"participant_one_percent": p1pct,
            "participant_two_percent": 100 - p1pct,
            "label": _balance_label(p1pct, 100 - p1pct, p1_label, p2_label)}


def interruptions(spans, p1_label, p2_label):
    """An interruption = a speaker starting while a different speaker is still talking;
    attributed to the one who started (the interrupter). Needs timed spans."""
    if not spans:
        return None
    order = []
    for s in spans:
        if s["speaker"] not in order:
            order.append(s["speaker"])
    if len(order) < 2:
        return None
    label_map = {order[0]: p1_label, order[1]: p2_label}
    counts = {p1_label: 0, p2_label: 0}
    for cur in spans:
        for other in spans:
            if other is cur or other["speaker"] == cur["speaker"]:
                continue
            if other["start_ms"] < cur["start_ms"] < other["end_ms"]:
                lbl = label_map.get(cur["speaker"])
                if lbl in counts:
                    counts[lbl] += 1
                break
    total = counts[p1_label] + counts[p2_label]
    return {"total": total,
            "participant_one": counts[p1_label],
            "participant_two": counts[p2_label],
            "label": _interruption_label(total, counts[p1_label], counts[p2_label], p1_label, p2_label)}


def ground_key_moments(moments, turns, label_map=None):
    """Snap each key moment's timestamp + speaker to the transcript turn its quote came from."""
    cleaned = [(_clean(t.get("text", "")), t) for t in turns]
    for mo in moments or []:
        q = _clean(mo.get("quote", ""))
        if not q:
            continue
        probe = q[:24]
        for ctext, t in cleaned:
            if probe and probe in ctext:
                if t.get("start_ms") is not None:
                    mo["timestamp_ms"] = t["start_ms"]
                spk = label_map.get(t["speaker"]) if label_map else (
                    t["speaker"] if isinstance(t["speaker"], str) else None)
                if spk:
                    mo["speaker"] = spk
                break
    return moments


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def _clean(s):
    return re.sub(r"[^a-z0-9 ]", "", (s or "").lower()).strip()


def _balance_label(a, b, p1, p2):
    if abs(a - b) <= 10:
        return "Fairly even"
    return f"Mostly {p1}" if a > b else f"Mostly {p2}"


def _interruption_label(total, c1, c2, p1, p2):
    if total == 0:
        return "No interruptions"
    if c1 == c2:
        return "Evenly split"
    leader = p1 if c1 > c2 else p2
    return f"Mostly from {leader.lower()}"
