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
- HONESTY ABOUT PRECISION: connection_score and its delta_label are impressions, not measurements. \
delta_label must be QUALITATIVE and must NEVER state a fabricated precise number \
(write "warmer once the pace slowed", not "+9 once you slowed down"). Do not imply a metric was \
counted when it was estimated.
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
    # `transcript` already carries speaker labels + timestamps when available
    # (see signals.render_transcript), so we usually pass segments=None on purpose.
    user = _review_user_msg(meta, transcript, segments)
    d = _generate(REVIEW_SYSTEM, user, REVIEW_SCHEMA)
    d = _coerce(d, REVIEW_REQUIRED)
    return _fill_review_defaults(d, meta)


# Local models are less reliable than Claude at emitting strict JSON, so we
# guarantee every nested block the frontend decodes exists before returning.
def _fill_review_defaults(body, meta):
    p1 = meta.get("p1_label", "You")
    p2 = meta.get("p2_label", "Your partner")

    summary = body.get("summary") or {}
    summary.setdefault("headline", "Here's what stood out in this conversation.")
    summary.setdefault("subheadline", "")
    body["summary"] = summary

    body.setdefault("shared_success", "")

    metrics = body.get("metrics") or {}
    wb = metrics.get("word_balance") or {}
    wb.setdefault("participant_one_percent", 50)
    wb.setdefault("participant_two_percent", 100 - wb["participant_one_percent"])
    wb.setdefault("label", "Fairly even")
    metrics["word_balance"] = wb

    inter = metrics.get("interruptions") or {}
    inter.setdefault("total", 0)
    inter.setdefault("participant_one", 0)
    inter.setdefault("participant_two", 0)
    inter.setdefault("label", "Hard to tell")
    metrics["interruptions"] = inter

    cs = metrics.get("connection_score") or {}
    cs.setdefault("score", 50)
    cs.setdefault("delta_label", "")
    metrics["connection_score"] = cs

    ra = metrics.get("repair_attempts") or {}
    ra.setdefault("total", 0)
    ra.setdefault("label", "")
    metrics["repair_attempts"] = ra

    body["metrics"] = metrics

    body.setdefault("key_moments", [])
    body.setdefault("unmet_needs", [])
    body.setdefault("next_time", [])
    body.setdefault("confidence", "low")
    return body


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
— name what is getting better, not only what is wrong. \
HONESTY ABOUT PRECISION: frequency_label and any counts ("6 of your last 10") must reflect the \
actual number of conversations in the history — never invent a tally. Prefer qualitative phrasing \
("in most of your recent conversations") when you cannot count it exactly."""

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
# Solo (single-user) reflection — prompt + schema
# --------------------------------------------------------------------------- #

SOLO_SYSTEM = FRAMEWORK + """

You are helping ONE person (the absent partner is NOT here). Output ONLY a JSON object \
(no prose, no markdown fences, no <think> block) with this exact shape:
{
  "summary": {"headline": str},
  "translation": {"what_they_may_have_meant": str, "their_possible_need": str},
  "your_part": str,
  "suggested_next": str,
  "reframe": str,
  "confidence": "low"|"medium"
}

SOLO-SPECIFIC HARD CONSTRAINTS (never violate):
- TRANSLATE TOWARD UNDERSTANDING, NEVER TOWARD WINNING. Never help the user build a case, \
score a point, or prove the other person wrong. Orient everything to the other person's \
likely unmet need and to what the user can do.
- The partner is absent and cannot consent or correct, so be EVEN MORE tentative about their \
inner state ("may", "it seems", "one possibility"). Never assert what they "really" meant.
- "your_part" is a gentle, optional invitation to self-reflection — never blame the user \
either. It may be brief; keep it kind.
- "suggested_next" is ONE small, doable move: a soft, non-escalating thing to say (decode), a \
gentle start-up opener (prep), or a repair/reconnection move (reflect).
- If the text suggests abuse, coercion, or danger, do NOT coach "communication"; in \
"suggested_next" gently encourage reaching out to a trusted person or professional support."""

SOLO_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "object", "properties": {"headline": {"type": "string"}},
                    "required": ["headline"]},
        "translation": {"type": "object", "properties": {
            "what_they_may_have_meant": {"type": "string"},
            "their_possible_need": {"type": "string"}},
            "required": ["what_they_may_have_meant", "their_possible_need"]},
        "your_part": {"type": "string"},
        "suggested_next": {"type": "string"},
        "reframe": {"type": "string"},
        "confidence": {"type": "string", "enum": ["low", "medium"]},
    },
    "required": ["summary", "translation", "your_part", "suggested_next", "confidence"],
}

_SOLO_MODE_PROMPTS = {
    "decode": (
        "Mode: DECODE.\n"
        "Your partner said: \"{quote}\"\n"
        "Context from the user: {text}\n\n"
        "Help the user understand what their partner may have meant and the unmet need "
        "beneath it, and put a soft, non-escalating way to respond in \"suggested_next\"."
    ),
    "prep": (
        "Mode: PREP. The user wants to have this conversation: {text}\n"
        "(If a specific line is provided: \"{quote}\")\n\n"
        "Help them prepare. Use \"translation\" for what their partner may be experiencing and "
        "may need. Put a soft start-up opener in \"suggested_next\" and a pitfall to avoid in "
        "\"reframe\"."
    ),
    "reflect": (
        "Mode: REFLECT. The user is processing what happened: {text}\n"
        "(Relevant line, if any: \"{quote}\")\n\n"
        "Help them see the need under their own reaction and their partner's likely need. Put "
        "one repair or reconnection move in \"suggested_next\"."
    ),
}


def generate_reflection(mode, text, quote=None):
    mode = (mode or "decode").lower()
    template = _SOLO_MODE_PROMPTS.get(mode, _SOLO_MODE_PROMPTS["decode"])
    user = template.format(text=(text or "").strip(), quote=(quote or "").strip())
    d = _generate(SOLO_SYSTEM, user, SOLO_SCHEMA)
    return _fill_reflection_defaults(d)


# Local models are less reliable at strict JSON, so guarantee every block the app decodes.
def _fill_reflection_defaults(body):
    summary = body.get("summary") or {}
    summary.setdefault("headline", "Here's one way to make sense of this.")
    body["summary"] = summary

    tr = body.get("translation") or {}
    tr.setdefault("what_they_may_have_meant", "")
    tr.setdefault("their_possible_need", "")
    body["translation"] = tr

    body.setdefault("your_part", "")
    body.setdefault("suggested_next", "")
    body.setdefault("reframe", "")
    body.setdefault("confidence", "low")
    return body


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
            "connection_score": {"score": 78, "delta_label": "Felt warmer once the pace slowed"},
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
             "detail": "When feelings are named before logistics, the conversation tends to feel noticeably more connected."},
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


def demo_reflection(mode="decode"):
    mode = (mode or "decode").lower()
    base = {
        "decode": {
            "summary": {"headline": "Underneath the sharp words may be a bid for reassurance."},
            "translation": {
                "what_they_may_have_meant": "When they said that, it may have been less about the plan and more about feeling like they were carrying it alone.",
                "their_possible_need": "To feel that you're on the same side, and that their effort is seen.",
            },
            "your_part": "It's worth noticing whether you moved to fix the logistics before the feeling had landed — easy to do, and not a failing.",
            "suggested_next": "Try: \"It sounds like you felt alone in this — did I get that right?\" before anything about the plan.",
            "reframe": "This reads less like criticism of you and more like a reach for partnership.",
            "confidence": "low",
        },
        "prep": {
            "summary": {"headline": "Go in naming what you each need, before the logistics."},
            "translation": {
                "what_they_may_have_meant": "Hard to know yet — but they may come in braced for this to become a list of problems.",
                "their_possible_need": "To feel the conversation is with them, not at them.",
            },
            "your_part": "Get clear on the one thing you actually need from this talk, so it doesn't get lost in the details.",
            "suggested_next": "Open with: \"I want us to come out of this feeling closer, not just with a plan — can we start there?\"",
            "reframe": "Pitfall to avoid: leading with the solution before the feeling has been named.",
            "confidence": "low",
        },
        "reflect": {
            "summary": {"headline": "Your reaction may be pointing at a need that didn't get met."},
            "translation": {
                "what_they_may_have_meant": "Their pulling back may have been overwhelm rather than indifference.",
                "their_possible_need": "A moment to slow down before solving.",
            },
            "your_part": "The frustration you felt might be standing in for wanting to feel chosen and prioritized.",
            "suggested_next": "A small repair: \"I think I got sharp earlier — I actually just wanted to feel like we were a team. Can we try again?\"",
            "reframe": "A rough moment isn't the whole story; the repair matters more than the rupture.",
            "confidence": "low",
        },
    }
    return base.get(mode, base["decode"])
