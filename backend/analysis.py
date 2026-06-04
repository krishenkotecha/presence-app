"""
Analysis engine — produces the two Presence v2 payloads.

  generate_review(meta, transcript, segments)  -> conversation-review body
  generate_work_on(history)                     -> longitudinal "work on" body
  demo_review(...) / demo_work_on()             -> contract-shaped demo data

Backends (RELINT_BACKEND): local (OpenAI-compatible / Ollama), anthropic, mock.
"""

import os
import re
import json

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #

def _detect_backend():
    b = os.environ.get("RELINT_BACKEND")
    if b:
        return b.lower()
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("RELINT_LOCAL_BASE_URL"):
        return "local"
    return "mock"


BACKEND = _detect_backend()
LOCAL_BASE_URL = os.environ.get("RELINT_LOCAL_BASE_URL", "http://localhost:11434/v1")
LOCAL_API_KEY = os.environ.get("RELINT_LOCAL_API_KEY", "not-needed")


def _default_model():
    if BACKEND == "anthropic":
        return os.environ.get("RELINT_MODEL", "claude-sonnet-4-6")
    if BACKEND == "local":
        return os.environ.get("RELINT_MODEL", "qwen3")
    return os.environ.get("RELINT_MODEL", "mock")


MODEL = _default_model()


def current_backend():
    info = {"backend": BACKEND, "model": MODEL}
    if BACKEND == "local":
        info["local_base_url"] = LOCAL_BASE_URL
    return info


# --------------------------------------------------------------------------- #
# Shared framework / constraint preamble
# --------------------------------------------------------------------------- #

FRAMEWORK = """You are Presence, a relationship intelligence analyst. You help two people \
understand each other better, repair faster, and connect more.

Draw on, without name-dropping: Gottman (bids for connection, repair attempts, the \
criticism/defensiveness/contempt/stonewalling patterns, soft vs harsh start-ups); \
Marshall Rosenberg / NVC (translate statements into underlying feelings and unmet needs); \
Esther Perel (autonomy, identity, meaning); Sue Johnson / attachment (pursue-withdraw cycles, \
the emotional need beneath the reaction).

HARD CONSTRAINTS (never violate):
1. TENTATIVE LANGUAGE. Never assert someone's internal state as fact. Prefer "this may reflect", \
"it seems", "stress indicators appear to rise here". Never "you are angry", "she doesn't care", "he always".
2. EVIDENCE-LINKED. Any quoted moment must use a line that actually appears in the transcript.
3. NON-JUDGMENTAL & HOPEFUL. You are not grading the people or taking sides. Surface patterns and \
small, doable next moves. This is NOT analytics; it should feel human and encouraging.
4. RESPECT THEIR GOAL. Evaluate against what each person said success looks like, first."""


# --------------------------------------------------------------------------- #
# Review (single conversation) — prompt + schema
# --------------------------------------------------------------------------- #

REVIEW_SYSTEM = FRAMEWORK + """

You are producing a CONVERSATION REVIEW for one conversation. Output ONLY a JSON object \
(no prose, no markdown fences, no <think> block) with this exact shape:
{
  "summary": {"headline": str, "subheadline": str},
  "shared_success": str,
  "metrics": {
    "word_balance": {"participant_one_percent": int, "participant_two_percent": int, "label": str},
    "interruptions": {"total": int, "participant_one": int, "participant_two": int, "label": str},
    "connection_score": {"score": int, "delta_label": str},
    "repair_attempts": {"total": int, "label": str}
  },
  "key_moments": [{"timestamp_ms": int, "type": "positive"|"negative"|"neutral",
                   "title": str, "quote": str, "speaker": str, "explanation": str}],
  "unmet_needs": [{"person": str, "need": str}],
  "next_time": [{"person": str, "try": str}],
  "confidence": "low"|"medium"
}

Rules:
- Use the two participant labels given in the user message exactly (for "speaker" and "person").
- For "next_time", write person as "For <label>".
- metrics are BEST-EFFORT ESTIMATES from the transcript. If you cannot reliably tell the speakers \
apart, estimate and set "confidence" to "low". connection_score is 0-100. (word_balance and \
interruptions may be replaced by measured values when speaker diarization is available — still \
provide your best estimate.)
- key_moments: 2-4 moments. timestamp_ms must fall within the conversation; use the provided segment \
timestamps when available, otherwise estimate between 0 and duration*1000.
- shared_success: one warm sentence naming the goal both people shared."""


def _titled_list_schema():
    return {"type": "array", "items": {
        "type": "object",
        "properties": {"title": {"type": "string"}, "detail": {"type": "string"}},
        "required": ["title", "detail"]}}


REVIEW_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "object",
                    "properties": {"headline": {"type": "string"}, "subheadline": {"type": "string"}},
                    "required": ["headline", "subheadline"]},
        "shared_success": {"type": "string"},
        "metrics": {"type": "object", "properties": {
            "word_balance": {"type": "object", "properties": {
                "participant_one_percent": {"type": "integer"},
                "participant_two_percent": {"type": "integer"},
                "label": {"type": "string"}},
                "required": ["participant_one_percent", "participant_two_percent", "label"]},
            "interruptions": {"type": "object", "properties": {
                "total": {"type": "integer"}, "participant_one": {"type": "integer"},
                "participant_two": {"type": "integer"}, "label": {"type": "string"}},
                "required": ["total", "participant_one", "participant_two", "label"]},
            "connection_score": {"type": "object", "properties": {
                "score": {"type": "integer"}, "delta_label": {"type": "string"}},
                "required": ["score", "delta_label"]},
            "repair_attempts": {"type": "object", "properties": {
                "total": {"type": "integer"}, "label": {"type": "string"}},
                "required": ["total", "label"]},
        }, "required": ["word_balance", "interruptions", "connection_score", "repair_attempts"]},
        "key_moments": {"type": "array", "items": {"type": "object", "properties": {
            "timestamp_ms": {"type": "integer"},
            "type": {"type": "string", "enum": ["positive", "negative", "neutral"]},
            "title": {"type": "string"}, "quote": {"type": "string"},
            "speaker": {"type": "string"}, "explanation": {"type": "string"}},
            "required": ["timestamp_ms", "type", "title", "quote", "speaker", "explanation"]}},
        "unmet_needs": {"type": "array", "items": {"type": "object", "properties": {
            "person": {"type": "string"}, "need": {"type": "string"}},
            "required": ["person", "need"]}},
        "next_time": {"type": "array", "items": {"type": "object", "properties": {
            "person": {"type": "string"}, "try": {"type": "string"}},
            "required": ["person", "try"]}},
        "confidence": {"type": "string", "enum": ["low", "medium"]},
    },
    "required": ["summary", "shared_success", "metrics", "key_moments",
                 "unmet_needs", "next_time", "confidence"],
}
REVIEW_REQUIRED = list(REVIEW_SCHEMA["required"])


def _review_user_msg(meta, transcript, segments):
    if segments:
        body = "\n".join(f"[{s['start_ms']}ms] {s['text']}" for s in segments)
    else:
        body = transcript
    return (
        f"Participant one label: {meta['p1_label']}\n"
        f"Participant one success definition: {meta['p1_def']}\n"
        f"Participant two label: {meta['p2_label']}\n"
        f"Participant two success definition: {meta['p2_def']}\n"
        f"Duration (seconds): {meta.get('duration', 0)}\n\n"
        f'Transcript:\n"""\n{body}\n"""\n\n'
        "Produce the conversation-review JSON."
    )


def generate_review(meta, transcript, segments=None):
    user = _review_user_msg(meta, transcript, segments)
    d = _generate(REVIEW_SYSTEM, user, REVIEW_SCHEMA)
    return _coerce(d, REVIEW_REQUIRED)


# --------------------------------------------------------------------------- #
# Work-on (longitudinal) — prompt + schema
# --------------------------------------------------------------------------- #

WORKON_SYSTEM = FRAMEWORK + """

You are producing a LONGITUDINAL "what should we work on" view across MANY past conversations \
for the same couple. This is NOT about a single conversation — it is about what tends to happen \
between them over time, how they show up together lately, and what is most worth working on now. \
Output ONLY a JSON object with this exact shape:
{
  "primary_focus": {"title": str, "summary": str, "frequency_label": str, "context_label": str},
  "why_this_matters": [{"title": str, "detail": str}],
  "relationship_patterns": [{"title": str, "detail": str}],
  "improving": [{"title": str, "detail": str}],
  "work_on_areas": [{"title": str, "detail": str}]
}
Ground every claim in the history provided. If the history is thin, stay appropriately tentative. \
primary_focus is the single most worth-it thing right now. Always include something in "improving" \
— name what is getting better, not only what is wrong."""

WORKON_SCHEMA = {
    "type": "object",
    "properties": {
        "primary_focus": {"type": "object", "properties": {
            "title": {"type": "string"}, "summary": {"type": "string"},
            "frequency_label": {"type": "string"}, "context_label": {"type": "string"}},
            "required": ["title", "summary", "frequency_label", "context_label"]},
        "why_this_matters": _titled_list_schema(),
        "relationship_patterns": _titled_list_schema(),
        "improving": _titled_list_schema(),
        "work_on_areas": _titled_list_schema(),
    },
    "required": ["primary_focus", "why_this_matters", "relationship_patterns",
                 "improving", "work_on_areas"],
}
WORKON_REQUIRED = list(WORKON_SCHEMA["required"])


def generate_work_on(history):
    """history: list of compact dicts summarizing past reviews."""
    user = ("Past conversation reviews (most recent last):\n"
            + json.dumps(history, indent=2)
            + "\n\nProduce the longitudinal work-on JSON.")
    d = _generate(WORKON_SYSTEM, user, WORKON_SCHEMA)
    return _coerce(d, WORKON_REQUIRED)


# --------------------------------------------------------------------------- #
# Backend dispatch
# --------------------------------------------------------------------------- #

def _generate(system, user, schema):
    if BACKEND == "anthropic":
        return _anthropic_generate(system, user)
    if BACKEND == "local":
        return _local_generate(system, user, schema)
    raise RuntimeError("LLM generate called while backend is 'mock'")


def _anthropic_generate(system, user):
    import anthropic
    client = anthropic.Anthropic()
    resp = client.messages.create(
        model=MODEL, max_tokens=4096, system=system,
        messages=[{"role": "user", "content": user}],
    )
    raw = "".join(b.text for b in resp.content if getattr(b, "type", None) == "text")
    return _extract_json(raw)


def _local_generate(system, user, schema):
    from openai import OpenAI
    client = OpenAI(base_url=LOCAL_BASE_URL, api_key=LOCAL_API_KEY)
    messages = [{"role": "system", "content": system}, {"role": "user", "content": user}]
    formats = [
        {"type": "json_schema",
         "json_schema": {"name": "presence", "schema": schema, "strict": False}},
        {"type": "json_object"},
        None,
    ]
    last_err = None
    for fmt in formats:
        try:
            kwargs = dict(model=MODEL, messages=messages, temperature=0.4, max_tokens=4096)
            if fmt is not None:
                kwargs["response_format"] = fmt
            resp = client.chat.completions.create(**kwargs)
            return _extract_json(resp.choices[0].message.content)
        except Exception as e:  # noqa: BLE001 - degrade across server/model capabilities
            last_err = e
            continue
    raise RuntimeError(
        f"local LLM call failed via {LOCAL_BASE_URL} (model '{MODEL}'). "
        f"Is the server running and the model pulled? Last error: {last_err}"
    )


# --------------------------------------------------------------------------- #
# JSON helpers
# --------------------------------------------------------------------------- #

def _extract_json(text):
    if not text:
        raise ValueError("empty model response")
    t = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
    t = re.sub(r"```(?:json)?", "", t).strip()
    try:
        return json.loads(t)
    except json.JSONDecodeError:
        pass
    start = t.find("{")
    if start == -1:
        raise ValueError("no JSON object found")
    depth = 0
    for i in range(start, len(t)):
        if t[i] == "{":
            depth += 1
        elif t[i] == "}":
            depth -= 1
            if depth == 0:
                return json.loads(t[start:i + 1])
    raise ValueError("unterminated JSON object")


def _coerce(payload, required):
    for k in required:
        if k not in payload:
            payload[k] = [] if k in ("why_this_matters", "relationship_patterns", "improving",
                                     "work_on_areas", "key_moments", "unmet_needs", "next_time") else {}
    return payload


# --------------------------------------------------------------------------- #
# Demo / fallback payloads (contract-shaped) — used in mock mode or when audio
# transcription isn't available, so the app always gets a valid response.
# --------------------------------------------------------------------------- #

def demo_review(p1_label="You", p2_label="Your partner", p1_def="", p2_def=""):
    return {
        "summary": {
            "headline": "You were closest to success when the conversation stayed balanced instead of sliding into explanation.",
            "subheadline": "The biggest shift happened once the emotional point landed before either of you tried to solve it.",
        },
        "shared_success": "You both wanted understanding before problem-solving.",
        "metrics": {
            "word_balance": {"participant_one_percent": 54, "participant_two_percent": 46, "label": "Fairly even"},
            "interruptions": {"total": 7, "participant_one": 5, "participant_two": 2, "label": f"Mostly from {p1_label.lower()}"},
            "connection_score": {"score": 78, "delta_label": "+9 once you slowed down"},
            "repair_attempts": {"total": 3, "label": "Two landed well"},
        },
        "key_moments": [
            {"timestamp_ms": 190000, "type": "negative", "title": "Tension rose",
             "quote": "Yeah, but that's not what I meant.", "speaker": p1_label,
             "explanation": "This shifted from impact to intent, which may have left the emotional part feeling less met."},
            {"timestamp_ms": 525000, "type": "positive", "title": "Connection improved",
             "quote": "I can see why that felt lonely.", "speaker": p1_label,
             "explanation": "The feeling seemed to land before the problem got solved, and the tone softened right after."},
        ],
        "unmet_needs": [
            {"person": p1_label, "need": "Reassurance the conversation wasn't becoming a character judgment."},
            {"person": p2_label, "need": "A clearer sign the emotional part landed before problem-solving started."},
        ],
        "next_time": [
            {"person": f"For {p1_label.lower()}", "try": "Before explaining your intent, reflect back the feeling you think you heard in one sentence."},
            {"person": f"For {p2_label.lower()}", "try": "Name the underlying need earlier, before the conversation gets pulled into logistics."},
        ],
        "confidence": "low",
    }


def demo_work_on():
    return {
        "primary_focus": {
            "title": "Stay with the feeling before moving into solutions.",
            "summary": "The two of you tend to reconnect when the emotional part lands first. When one of you starts fixing too early, the conversation becomes more procedural and less connected.",
            "frequency_label": "6 of your last 10 conversations",
            "context_label": "Especially true in money and planning",
        },
        "why_this_matters": [
            {"title": "Connection is stronger when you slow down first",
             "detail": "When feelings are named before logistics, your connection score is about 14 points higher than usual."},
            {"title": "This pattern shows up in harder conversations",
             "detail": "It appears most often in money, planning, and chores, especially when you are both already tired."},
        ],
        "relationship_patterns": [
            {"title": "One of you tends to want reassurance while the other wants clarity",
             "detail": "The most productive conversations happen when both needs are visible early instead of competing under the surface."},
            {"title": "Money conversations become more efficient and less curious",
             "detail": "You both speak more directly and ask fewer follow-up questions when the topic turns to budgets or planning."},
        ],
        "improving": [
            {"title": "Interruptions are down this month",
             "detail": "You are both leaving more space before jumping in, especially in shorter check-ins."},
            {"title": "You are recovering from tension faster",
             "detail": "Even when conversations get sharp, you are finding your way back sooner than a few weeks ago."},
        ],
        "work_on_areas": [
            {"title": "Name the feeling underneath the logistics",
             "detail": "Try to say the emotional point out loud before discussing what the plan should be."},
            {"title": "Catch the first defensive response",
             "detail": "The moment one of you starts explaining instead of reflecting is usually when the conversation turns."},
            {"title": "Define success together earlier",
             "detail": "A simple shared goal at the start tends to keep the conversation from drifting into old patterns."},
        ],
    }
