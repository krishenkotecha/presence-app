"""
End-to-end walk of both Presence v2 flows, in-process (no separate server).

    python demo_flow.py

Backends: nothing set -> mock/demo; RELINT_BACKEND=local -> Ollama; ANTHROPIC_API_KEY -> Anthropic.
Audio isn't required here — the analyze endpoint accepts a `transcript` form field for
dev/testing, so this runs anywhere. It posts TWO conversations, then asks "work-on".
"""

import os
import json
import tempfile

os.environ.setdefault("RELINT_DB", os.path.join(tempfile.gettempdir(), "presence_demo.db"))
if os.path.exists(os.environ["RELINT_DB"]):
    os.remove(os.environ["RELINT_DB"])

from fastapi.testclient import TestClient  # noqa: E402
import main      # noqa: E402
import analysis  # noqa: E402

c = TestClient(main.app)
LINE = "-" * 66


def h(t):
    print(f"\n{LINE}\n{t}\n{LINE}")


TRANSCRIPT_1 = (
    "You: I feel like every time money comes up we end up snapping at each other.\n"
    "Your partner: Because you bring it up like I've already done something wrong.\n"
    "You: Yeah, but that's not what I meant.\n"
    "Your partner: (quiet) ...okay.\n"
    "You: Sorry. I can see why that felt lonely.\n"
    "Your partner: Thank you. That actually helps. Can we make a plan together now?\n"
    "You: Yes. Let's do it together this time.\n"
)
TRANSCRIPT_2 = (
    "You: Before we plan the trip, I just want to say I'm a little stressed about the cost.\n"
    "Your partner: I appreciate you naming that up front. I felt heard right away.\n"
    "You: So can we set a number we both feel okay with?\n"
    "Your partner: Yes, and I'll stop pushing for the expensive hotel.\n"
    "You: This felt way calmer than last time.\n"
    "Your partner: Agreed.\n"
)


def post_analyze(session_id, p1_def, p2_def, transcript, duration):
    return c.post("/api/v1/conversations/analyze", data={
        "session_id": session_id,
        "duration_seconds": duration,
        "participant_one_label": "You",
        "participant_two_label": "Your partner",
        "participant_one_success_definition": p1_def,
        "participant_two_success_definition": p2_def,
        "prototype_track": "v2",
        "transcript": transcript,
    })


def print_review(r):
    if r.status_code != 200:
        print(f"  ANALYZE FAILED [{r.status_code}]: {r.json().get('detail')}")
        return
    p = r.json()
    print(f"  model: {p.get('model')}  confidence: {p.get('confidence')}  diarized: {p.get('diarized')}")
    print(f"  metrics_source: {p.get('metrics_source')}")
    if p.get("note"):
        print(f"  note: {p['note']}")
    print(f"\n  HEADLINE\n    {p['summary']['headline']}")
    print(f"  SUB\n    {p['summary']['subheadline']}")
    print(f"\n  SHARED SUCCESS: {p['success_definition']['shared']}")
    m = p["metrics"]
    print("\n  METRICS")
    print(f"    word balance : {m['word_balance']['participant_one_percent']}/"
          f"{m['word_balance']['participant_two_percent']}  ({m['word_balance']['label']})")
    print(f"    interruptions: {m['interruptions']['total']}  ({m['interruptions']['label']})")
    print(f"    connection   : {m['connection_score']['score']}  ({m['connection_score']['delta_label']})")
    print(f"    repairs      : {m['repair_attempts']['total']}  ({m['repair_attempts']['label']})")
    print("\n  KEY MOMENTS")
    for km in p["key_moments"]:
        print(f"    [{km['timestamp_ms']}ms {km['type']}] {km['title']} — \"{km['quote']}\" ({km['speaker']})")
    print("\n  UNMET NEEDS")
    for n in p["unmet_needs"]:
        print(f"    - {n['person']}: {n['need']}")
    print("\n  NEXT TIME")
    for n in p["next_time"]:
        print(f"    - {n['person']}: {n['try']}")


def print_work_on(p):
    pf = p["primary_focus"]
    print(f"\n  PRIMARY FOCUS: {pf['title']}")
    print(f"    {pf['summary']}")
    print(f"    [{pf['frequency_label']}]  [{pf['context_label']}]")
    for section in ("why_this_matters", "relationship_patterns", "improving", "work_on_areas"):
        print(f"\n  {section.upper().replace('_', ' ')}")
        for item in p[section]:
            print(f"    - {item['title']}: {item['detail']}")


def main_flow():
    h("BACKEND")
    print(f"  {analysis.current_backend()}")
    print(f"  transcription: {main.transcribe.status()}")
    if analysis.BACKEND == "mock":
        print("  (mock — returns contract-shaped demo data; set RELINT_BACKEND=local for real analysis)")

    h("CONVERSATION 1  (the tense money talk)")
    print_review(post_analyze(
        "sess-1",
        "I want us to stay calm and actually feel understood before we solve anything.",
        "I want to feel heard first, then leave with a clear plan we both believe in.",
        TRANSCRIPT_1, 808))

    h("CONVERSATION 2  (the calmer follow-up)")
    print_review(post_analyze(
        "sess-2",
        "Name my stress early instead of letting it leak out.",
        "Feel like we're on the same team about money.",
        TRANSCRIPT_2, 540))

    h("WORK-ON  (longitudinal across the two)")
    r = c.get("/api/v1/relationships/work-on")
    if r.status_code != 200:
        print(f"  FAILED [{r.status_code}]: {r.json().get('detail')}")
    else:
        print_work_on(r.json())

    h("DONE")
    print("  Both contract endpoints exercised end-to-end.")


if __name__ == "__main__":
    main_flow()
